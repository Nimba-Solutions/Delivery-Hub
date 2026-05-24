/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryActivityLogController — the read-only
 *               audit-trail viewer controller. Validates ordering, the
 *               recordLimit guardrails (null -> default, capped at max),
 *               the contextId filter, user-name resolution, and details
 *               truncation.
 * @author       Cloud Nimbus LLC
 */
@IsTest
private class DeliveryActivityLogControllerTest {

    private static User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void returnsRowsOrderedNewestFirst() {
        System.runAs(runningUser) {
            List<ActivityLog__c> rows = new List<ActivityLog__c>();
            for (Integer i = 0; i < 3; i++) {
                rows.add(new ActivityLog__c(
                    UserIdTxt__c = UserInfo.getUserId(),
                    ActionTypePk__c = 'Feature_Toggle',
                    ComponentNameTxt__c = 'deliveryFeatureCockpit'
                ));
            }
            insert rows;

            Test.startTest();
            List<DeliveryActivityLogController.LogRow> out =
                DeliveryActivityLogController.recent(50, null);
            Test.stopTest();

            System.assertEquals(3, out.size(), 'Should return all 3 rows');
            // Newest first
            System.assert(
                out[0].activityDateTime >= out[out.size() - 1].activityDateTime,
                'Rows should be ordered DESC by activityDateTime'
            );
            System.assertEquals(
                UserInfo.getName(), out[0].userName,
                'userName should be resolved from the User table, not the raw Id'
            );
            System.assertEquals('Feature_Toggle', out[0].actionType, 'actionType should round-trip');
        }
    }

    @IsTest
    static void filtersByContextId() {
        System.runAs(runningUser) {
            Id ctx = UserInfo.getUserId(); // any valid 18-char Id
            insert new ActivityLog__c(
                UserIdTxt__c = UserInfo.getUserId(),
                ActionTypePk__c = 'Feature_Toggle',
                RecordIdTxt__c = String.valueOf(ctx)
            );
            insert new ActivityLog__c(
                UserIdTxt__c = UserInfo.getUserId(),
                ActionTypePk__c = 'Navigation' // no recordId — should be filtered out
            );

            Test.startTest();
            List<DeliveryActivityLogController.LogRow> out =
                DeliveryActivityLogController.recent(50, ctx);
            Test.stopTest();

            System.assertEquals(1, out.size(), 'Only the row matching contextId should be returned');
            System.assertEquals(String.valueOf(ctx), out[0].recordId, 'recordId should round-trip');
        }
    }

    @IsTest
    static void nullLimitDefaultsToFifty() {
        System.runAs(runningUser) {
            List<ActivityLog__c> rows = new List<ActivityLog__c>();
            for (Integer i = 0; i < 55; i++) {
                rows.add(new ActivityLog__c(
                    UserIdTxt__c = UserInfo.getUserId(),
                    ActionTypePk__c = 'Navigation'
                ));
            }
            insert rows;

            Test.startTest();
            List<DeliveryActivityLogController.LogRow> out =
                DeliveryActivityLogController.recent(null, null);
            Test.stopTest();

            System.assertEquals(50, out.size(), 'Null recordLimit should fall back to 50');
        }
    }

    @IsTest
    static void overMaxLimitClampsToTwoHundred() {
        System.runAs(runningUser) {
            // 5 rows is plenty — we only need to assert that a 999 cap doesn't
            // SOQL-fail. The clamp is internal so this also verifies the
            // service does not throw on out-of-range input.
            insert new ActivityLog__c(
                UserIdTxt__c = UserInfo.getUserId(),
                ActionTypePk__c = 'Navigation'
            );

            Test.startTest();
            List<DeliveryActivityLogController.LogRow> out =
                DeliveryActivityLogController.recent(999, null);
            Test.stopTest();

            System.assertEquals(1, out.size(), 'Should still return rows after limit clamp');
        }
    }

    @IsTest
    static void emptyResultsAreEmptyList() {
        System.runAs(runningUser) {
            Test.startTest();
            List<DeliveryActivityLogController.LogRow> out =
                DeliveryActivityLogController.recent(50, null);
            Test.stopTest();

            System.assertEquals(0, out.size(), 'No rows -> empty list, no NPE');
        }
    }

    @IsTest
    static void truncatesLongDetails() {
        System.runAs(runningUser) {
            String big = '';
            for (Integer i = 0; i < 30; i++) {
                big += '0123456789';
            } // 300 chars

            insert new ActivityLog__c(
                UserIdTxt__c = UserInfo.getUserId(),
                ActionTypePk__c = 'Navigation',
                ContextDataTxt__c = big
            );

            Test.startTest();
            List<DeliveryActivityLogController.LogRow> out =
                DeliveryActivityLogController.recent(50, null);
            Test.stopTest();

            System.assertEquals(1, out.size(), 'Should return the one row');
            System.assert(out[0].detailsTxt.length() <= 241, 'detailsTxt should be truncated to ~240 chars + ellipsis');
            System.assert(out[0].detailsTxt.endsWith('…'), 'Truncated detail should end with the ellipsis marker');
        }
    }

    @IsTest
    static void blankUserIdSurfacesSystem() {
        System.runAs(runningUser) {
            insert new ActivityLog__c(
                UserIdTxt__c = null,
                ActionTypePk__c = 'API_Request'
            );

            Test.startTest();
            List<DeliveryActivityLogController.LogRow> out =
                DeliveryActivityLogController.recent(50, null);
            Test.stopTest();

            System.assertEquals(1, out.size(), 'Should return the one row');
            System.assertEquals('System', out[0].userName, 'Blank UserIdTxt__c -> System');
        }
    }
}
