@IsTest
private class DeliveryRateLimitServiceTest {

    @IsTest
    static void testNotRateLimitedWhenUnderThreshold() {
        // Insert 2 request logs
        insert new List<ActivityLog__c>{
            new ActivityLog__c(ActionTypePk__c = 'API_Request', ComponentNameTxt__c = 'test-key-1', PageUrlTxt__c = 'SyncAPI'),
            new ActivityLog__c(ActionTypePk__c = 'API_Request', ComponentNameTxt__c = 'test-key-1', PageUrlTxt__c = 'SyncAPI')
        };

        Test.startTest();
        Boolean limited = DeliveryRateLimitService.isRateLimited('test-key-1', 'SyncAPI', 5, 1);
        Test.stopTest();

        System.assertEquals(false, limited, 'Should not be rate limited with 2 of 5 requests');
    }

    @IsTest
    static void testRateLimitedWhenAtThreshold() {
        List<ActivityLog__c> logs = new List<ActivityLog__c>();
        for (Integer i = 0; i < 5; i++) {
            logs.add(new ActivityLog__c(
                ActionTypePk__c = 'API_Request',
                ComponentNameTxt__c = 'test-key-2',
                PageUrlTxt__c = 'PublicAPI'
            ));
        }
        insert logs;

        Test.startTest();
        Boolean limited = DeliveryRateLimitService.isRateLimited('test-key-2', 'PublicAPI', 5, 1);
        Test.stopTest();

        System.assertEquals(true, limited, 'Should be rate limited at threshold of 5');
    }

    @IsTest
    static void testDifferentIdentifiersAreIndependent() {
        List<ActivityLog__c> logs = new List<ActivityLog__c>();
        for (Integer i = 0; i < 5; i++) {
            logs.add(new ActivityLog__c(
                ActionTypePk__c = 'API_Request',
                ComponentNameTxt__c = 'key-A',
                PageUrlTxt__c = 'SyncAPI'
            ));
        }
        insert logs;

        Test.startTest();
        Boolean limitedA = DeliveryRateLimitService.isRateLimited('key-A', 'SyncAPI', 5, 1);
        Boolean limitedB = DeliveryRateLimitService.isRateLimited('key-B', 'SyncAPI', 5, 1);
        Test.stopTest();

        System.assertEquals(true, limitedA, 'key-A should be rate limited');
        System.assertEquals(false, limitedB, 'key-B should not be rate limited');
    }

    @IsTest
    static void testDifferentSubtypesAreIndependent() {
        List<ActivityLog__c> logs = new List<ActivityLog__c>();
        for (Integer i = 0; i < 5; i++) {
            logs.add(new ActivityLog__c(
                ActionTypePk__c = 'API_Request',
                ComponentNameTxt__c = 'shared-key',
                PageUrlTxt__c = 'SyncAPI'
            ));
        }
        insert logs;

        Test.startTest();
        Boolean limitedSync = DeliveryRateLimitService.isRateLimited('shared-key', 'SyncAPI', 5, 1);
        Boolean limitedPublic = DeliveryRateLimitService.isRateLimited('shared-key', 'PublicAPI', 5, 1);
        Test.stopTest();

        System.assertEquals(true, limitedSync, 'SyncAPI should be rate limited');
        System.assertEquals(false, limitedPublic, 'PublicAPI should not be rate limited');
    }

    @IsTest
    static void testRecordRequestInsertsLog() {
        Test.startTest();
        DeliveryRateLimitService.recordRequest('rec-key', 'SyncAPI');
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT ComponentNameTxt__c, PageUrlTxt__c, ActionTypePk__c
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'API_Request'
        ];
        System.assertEquals(1, logs.size(), 'Should have inserted 1 activity log');
        System.assertEquals('rec-key', logs[0].ComponentNameTxt__c, 'Identifier should match');
        System.assertEquals('SyncAPI', logs[0].PageUrlTxt__c, 'Subtype should match');
    }

    @IsTest
    static void testBlankIdentifierReturnsNotLimited() {
        Boolean limited = DeliveryRateLimitService.isRateLimited('', 'SyncAPI', 5, 1);
        System.assertEquals(false, limited, 'Blank identifier should not be rate limited');
    }

    @IsTest
    static void testBlankIdentifierRecordRequestNoOp() {
        DeliveryRateLimitService.recordRequest('', 'SyncAPI');
        Integer count = [SELECT COUNT() FROM ActivityLog__c WHERE ActionTypePk__c = 'API_Request'];
        System.assertEquals(0, count, 'Blank identifier should not insert a log');
    }
}
