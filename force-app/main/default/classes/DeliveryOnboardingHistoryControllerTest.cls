/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryOnboardingHistoryController — the
 *               read-only audit-trail viewer for OnboardingProgress__c.
 *               Validates the derived status field, ordering (completed
 *               first then in-progress), recordLimit guardrails, and the
 *               UserLookup__c filter.
 * @author       Cloud Nimbus LLC
 */
@IsTest
private class DeliveryOnboardingHistoryControllerTest {

    private static User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void returnsRowsWithDerivedStatus() {
        System.runAs(runningUser) {
            // Completed row.
            TestDataFactory.newOnboardingProgress(new Map<String, Object>{
                'StartedDateTime__c' => Datetime.now().addHours(-2),
                'CompletedDateTime__c' => Datetime.now().addMinutes(-30)
            });
            // In-progress row.
            TestDataFactory.newOnboardingProgress(new Map<String, Object>{
                'StartedDateTime__c' => Datetime.now().addMinutes(-15),
                'CompletedDateTime__c' => null
            });
            // Not-started row (StartedDateTime__c cleared via override).
            TestDataFactory.newOnboardingProgress(new Map<String, Object>{
                'StartedDateTime__c' => null,
                'CompletedDateTime__c' => null
            });

            Test.startTest();
            List<DeliveryOnboardingHistoryController.OnboardingRow> out =
                DeliveryOnboardingHistoryController.recent(50, null);
            Test.stopTest();

            System.assertEquals(3, out.size(), 'Should return all 3 rows');

            Set<String> statuses = new Set<String>();
            for (DeliveryOnboardingHistoryController.OnboardingRow r : out) {
                statuses.add(r.status);
            }
            System.assert(statuses.contains('Completed'), 'Completed status should appear');
            System.assert(statuses.contains('In Progress'), 'In Progress status should appear');
            System.assert(statuses.contains('Not Started'), 'Not Started status should appear');
        }
    }

    @IsTest
    static void completedRowsAppearBeforeInProgress() {
        System.runAs(runningUser) {
            TestDataFactory.newOnboardingProgress(new Map<String, Object>{
                'StartedDateTime__c' => Datetime.now().addHours(-1),
                'CompletedDateTime__c' => null // in-progress
            });
            TestDataFactory.newOnboardingProgress(new Map<String, Object>{
                'StartedDateTime__c' => Datetime.now().addHours(-3),
                'CompletedDateTime__c' => Datetime.now().addMinutes(-10) // completed
            });

            Test.startTest();
            List<DeliveryOnboardingHistoryController.OnboardingRow> out =
                DeliveryOnboardingHistoryController.recent(50, null);
            Test.stopTest();

            System.assertEquals(2, out.size(), 'Should return both rows');
            // ORDER BY CompletedDateTime__c DESC NULLS LAST -> completed first
            System.assertEquals('Completed', out[0].status, 'Completed should sort first');
            System.assertEquals('In Progress', out[1].status, 'In Progress should sort after Completed');
        }
    }

    @IsTest
    static void filtersByUserContextId() {
        System.runAs(runningUser) {
            // Row for the running user.
            TestDataFactory.newOnboardingProgress(new Map<String, Object>{
                'UserLookup__c' => UserInfo.getUserId()
            });

            // Row for a different user (any valid Id will do — we don't need
            // a second User; UserLookup__c just stores the Id).
            Id otherUserId = [SELECT Id FROM User WHERE Id != :UserInfo.getUserId() AND IsActive = true LIMIT 1].Id;
            TestDataFactory.newOnboardingProgress(new Map<String, Object>{
                'UserLookup__c' => otherUserId
            });

            Test.startTest();
            List<DeliveryOnboardingHistoryController.OnboardingRow> out =
                DeliveryOnboardingHistoryController.recent(50, UserInfo.getUserId());
            Test.stopTest();

            System.assertEquals(1, out.size(), 'Only the row for the running user should be returned');
            System.assertEquals(UserInfo.getUserId(), out[0].userId, 'userId should match the filter');
        }
    }

    @IsTest
    static void nullLimitDefaultsToFifty() {
        System.runAs(runningUser) {
            for (Integer i = 0; i < 55; i++) {
                TestDataFactory.newOnboardingProgress(null);
            }

            Test.startTest();
            List<DeliveryOnboardingHistoryController.OnboardingRow> out =
                DeliveryOnboardingHistoryController.recent(null, null);
            Test.stopTest();

            System.assertEquals(50, out.size(), 'Null recordLimit should fall back to 50');
        }
    }

    @IsTest
    static void emptyResultsAreEmptyList() {
        System.runAs(runningUser) {
            Test.startTest();
            List<DeliveryOnboardingHistoryController.OnboardingRow> out =
                DeliveryOnboardingHistoryController.recent(50, null);
            Test.stopTest();

            System.assertEquals(0, out.size(), 'No rows -> empty list, no NPE');
        }
    }

    @IsTest
    static void resolvesUserNameFromLookup() {
        System.runAs(runningUser) {
            TestDataFactory.newOnboardingProgress(new Map<String, Object>{
                'UserLookup__c' => UserInfo.getUserId(),
                'CompletedDateTime__c' => Datetime.now()
            });

            Test.startTest();
            List<DeliveryOnboardingHistoryController.OnboardingRow> out =
                DeliveryOnboardingHistoryController.recent(50, null);
            Test.stopTest();

            System.assertEquals(1, out.size(), 'Should return the row');
            System.assertEquals(UserInfo.getName(), out[0].userName, 'userName should resolve from UserLookup__r.Name');
        }
    }
}
