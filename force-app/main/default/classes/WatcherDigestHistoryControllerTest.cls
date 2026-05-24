/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryWatcherDigestHistoryController — the
 *               read-only audit-trail viewer for WatcherDigest__c. Covers
 *               ordering, the recordLimit guardrails, the slackDelivered
 *               proxy (RecipientUserIdsTxt__c populated -> true), notes
 *               truncation, and that contextId is ignored without erroring.
 * @author       Cloud Nimbus LLC
 */
@IsTest
private class WatcherDigestHistoryControllerTest {

    private static User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void returnsRowsNewestFirst() {
        System.runAs(runningUser) {
            List<WatcherDigest__c> rows = new List<WatcherDigest__c>();
            for (Integer i = 0; i < 3; i++) {
                rows.add(new WatcherDigest__c(
                    RunDateTime__c = Datetime.now().addMinutes(-i * 5),
                    StatusPk__c = 'Success',
                    RunModePk__c = 'Test',
                    SignalCountsTxt__c = 'SLA:0,Stuck:0,AR:0',
                    RunDurationMsNumber__c = 120,
                    RecipientUserIdsTxt__c = UserInfo.getUserId(),
                    DigestBodyTxt__c = 'All clear.'
                ));
            }
            insert rows;

            Test.startTest();
            List<DeliveryWatcherDigestHistoryController.DigestRow> out =
                DeliveryWatcherDigestHistoryController.recent(50, null);
            Test.stopTest();

            System.assertEquals(3, out.size(), 'Should return all 3 rows');
            System.assert(
                out[0].runDateTime >= out[out.size() - 1].runDateTime,
                'Rows should be ordered DESC by runDateTime'
            );
            System.assertEquals('Success', out[0].status, 'status should round-trip');
            System.assertEquals('Test', out[0].runMode, 'runMode should round-trip');
            System.assertEquals(true, out[0].slackDelivered, 'slackDelivered=true when recipient list populated');
        }
    }

    @IsTest
    static void slackDeliveredFalseWhenNoRecipients() {
        System.runAs(runningUser) {
            insert new WatcherDigest__c(
                RunDateTime__c = Datetime.now(),
                StatusPk__c = 'Success',
                RunModePk__c = 'Test',
                RecipientUserIdsTxt__c = null
            );

            Test.startTest();
            List<DeliveryWatcherDigestHistoryController.DigestRow> out =
                DeliveryWatcherDigestHistoryController.recent(50, null);
            Test.stopTest();

            System.assertEquals(1, out.size(), 'Should return the one row');
            System.assertEquals(false, out[0].slackDelivered, 'slackDelivered=false when recipient list is blank');
        }
    }

    @IsTest
    static void contextIdIsIgnoredWithoutError() {
        System.runAs(runningUser) {
            insert new WatcherDigest__c(
                RunDateTime__c = Datetime.now(),
                StatusPk__c = 'Success',
                RunModePk__c = 'Test'
            );

            Test.startTest();
            // contextId is accepted but ignored — should not throw, should
            // still return the row.
            List<DeliveryWatcherDigestHistoryController.DigestRow> out =
                DeliveryWatcherDigestHistoryController.recent(50, UserInfo.getUserId());
            Test.stopTest();

            System.assertEquals(1, out.size(), 'contextId should not filter — returned row stays');
        }
    }

    @IsTest
    static void nullLimitDefaultsToFifty() {
        System.runAs(runningUser) {
            List<WatcherDigest__c> rows = new List<WatcherDigest__c>();
            for (Integer i = 0; i < 55; i++) {
                rows.add(new WatcherDigest__c(
                    RunDateTime__c = Datetime.now().addMinutes(-i),
                    StatusPk__c = 'Success',
                    RunModePk__c = 'Test'
                ));
            }
            insert rows;

            Test.startTest();
            List<DeliveryWatcherDigestHistoryController.DigestRow> out =
                DeliveryWatcherDigestHistoryController.recent(null, null);
            Test.stopTest();

            System.assertEquals(50, out.size(), 'Null recordLimit should fall back to 50');
        }
    }

    @IsTest
    static void truncatesLongBody() {
        System.runAs(runningUser) {
            String big = '';
            for (Integer i = 0; i < 60; i++) {
                big += '0123456789';
            } // 600 chars

            insert new WatcherDigest__c(
                RunDateTime__c = Datetime.now(),
                StatusPk__c = 'Success',
                RunModePk__c = 'Test',
                DigestBodyTxt__c = big
            );

            Test.startTest();
            List<DeliveryWatcherDigestHistoryController.DigestRow> out =
                DeliveryWatcherDigestHistoryController.recent(50, null);
            Test.stopTest();

            System.assertEquals(1, out.size(), 'Should return the one row');
            System.assert(out[0].notes.length() <= 501, 'notes should be truncated to ~500 chars + ellipsis');
            System.assert(out[0].notes.endsWith('…'), 'Truncated notes should end with ellipsis marker');
        }
    }

    @IsTest
    static void emptyResultsAreEmptyList() {
        System.runAs(runningUser) {
            Test.startTest();
            List<DeliveryWatcherDigestHistoryController.DigestRow> out =
                DeliveryWatcherDigestHistoryController.recent(50, null);
            Test.stopTest();

            System.assertEquals(0, out.size(), 'No rows -> empty list, no NPE');
        }
    }
}
