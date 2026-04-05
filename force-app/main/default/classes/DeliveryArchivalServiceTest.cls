@IsTest
private class DeliveryArchivalServiceTest {

    @TestSetup
    static void setupData() {
        List<WorkItem__c> items = new List<WorkItem__c>();
        for (Integer i = 0; i < 5; i++) {
            items.add(new WorkItem__c(
                BriefDescriptionTxt__c = 'Test Item ' + i,
                StageNamePk__c = 'Backlog',
                PriorityPk__c = 'Medium'
            ));
        }
        insert items;
    }

    @IsTest
    static void testArchiveRecordsSetsFieldsCorrectly() {
        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c];
        Set<Id> ids = new Set<Id>();
        for (WorkItem__c wi : items) {
            ids.add(wi.Id);
        }

        Test.startTest();
        DeliveryArchivalService.archiveRecords(ids);
        Test.stopTest();

        List<WorkItem__c> updated = [
            SELECT ArchivalStatusPk__c, ArchivedDateTime__c, RetentionExpiresDate__c
            FROM WorkItem__c
            WHERE Id IN :ids
        ];
        for (WorkItem__c wi : updated) {
            System.assertEquals('Archived', wi.ArchivalStatusPk__c, 'Status should be Archived');
            System.assertNotEquals(null, wi.ArchivedDateTime__c, 'ArchivedDateTime should be set');
            System.assertNotEquals(null, wi.RetentionExpiresDate__c, 'RetentionExpiresDate should be set');
        }
    }

    @IsTest
    static void testArchiveRecordsWithCustomRetention() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.DefaultRetentionDaysNumber__c = 90;
        upsert settings;

        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c LIMIT 1];
        Set<Id> ids = new Set<Id>{ items[0].Id };

        Test.startTest();
        DeliveryArchivalService.archiveRecords(ids);
        Test.stopTest();

        WorkItem__c updated = [
            SELECT RetentionExpiresDate__c FROM WorkItem__c WHERE Id = :items[0].Id
        ];
        System.assertEquals(
            Date.today().addDays(90),
            updated.RetentionExpiresDate__c,
            'Retention should use custom setting value'
        );
    }

    @IsTest
    static void testArchiveRecordsNullAndEmptyAreNoOps() {
        Test.startTest();
        DeliveryArchivalService.archiveRecords(null);
        DeliveryArchivalService.archiveRecords(new Set<Id>());
        Test.stopTest();

        // No exception means pass
        System.assert(true, 'Null and empty sets should be no-ops');
    }

    @IsTest
    static void testSetLegalHoldSetsStatus() {
        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c LIMIT 2];
        Set<Id> ids = new Set<Id>();
        for (WorkItem__c wi : items) {
            ids.add(wi.Id);
        }

        Test.startTest();
        DeliveryArchivalService.setLegalHold(ids);
        Test.stopTest();

        List<WorkItem__c> updated = [
            SELECT ArchivalStatusPk__c, RetentionExpiresDate__c
            FROM WorkItem__c
            WHERE Id IN :ids
        ];
        for (WorkItem__c wi : updated) {
            System.assertEquals('Legal_Hold', wi.ArchivalStatusPk__c, 'Status should be Legal_Hold');
            System.assertEquals(null, wi.RetentionExpiresDate__c, 'Retention date should be null under hold');
        }
    }

    @IsTest
    static void testSetLegalHoldNullAndEmptyAreNoOps() {
        Test.startTest();
        DeliveryArchivalService.setLegalHold(null);
        DeliveryArchivalService.setLegalHold(new Set<Id>());
        Test.stopTest();

        System.assert(true, 'Null and empty sets should be no-ops');
    }

    @IsTest
    static void testReleaseLegalHoldResetsToArchived() {
        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c LIMIT 1];
        Set<Id> ids = new Set<Id>{ items[0].Id };

        // First put on legal hold
        DeliveryArchivalService.setLegalHold(ids);

        Test.startTest();
        DeliveryArchivalService.releaseLegalHold(ids);
        Test.stopTest();

        WorkItem__c updated = [
            SELECT ArchivalStatusPk__c, RetentionExpiresDate__c
            FROM WorkItem__c
            WHERE Id = :items[0].Id
        ];
        System.assertEquals('Archived', updated.ArchivalStatusPk__c, 'Status should revert to Archived');
        System.assertNotEquals(null, updated.RetentionExpiresDate__c, 'Retention date should be set after release');
    }

    @IsTest
    static void testReleaseLegalHoldNullAndEmptyAreNoOps() {
        Test.startTest();
        DeliveryArchivalService.releaseLegalHold(null);
        DeliveryArchivalService.releaseLegalHold(new Set<Id>());
        Test.stopTest();

        System.assert(true, 'Null and empty sets should be no-ops');
    }

    @IsTest
    static void testExportArchivedDataReturnsJson() {
        // Archive some items first
        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c LIMIT 3];
        Set<Id> ids = new Set<Id>();
        for (WorkItem__c wi : items) {
            ids.add(wi.Id);
        }
        DeliveryArchivalService.archiveRecords(ids);

        Test.startTest();
        String result = DeliveryArchivalService.exportArchivedData(
            Date.today().addDays(-1),
            Date.today().addDays(1)
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Export should return non-null JSON');
        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(result);
        System.assertEquals(3, parsed.size(), 'Should export 3 archived items');
    }

    @IsTest
    static void testExportArchivedDataEmptyRange() {
        Test.startTest();
        String result = DeliveryArchivalService.exportArchivedData(
            Date.today().addDays(-30),
            Date.today().addDays(-20)
        );
        Test.stopTest();

        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(result);
        System.assertEquals(0, parsed.size(), 'No archived items in range should return empty array');
    }

    @IsTest
    static void testPurgeExpiredArchivesDeletesRecords() {
        // Archive items with an already-expired retention date
        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c LIMIT 2];
        for (WorkItem__c wi : items) {
            wi.ArchivalStatusPk__c = 'Archived';
            wi.ArchivedDateTime__c = Datetime.now().addDays(-400);
            wi.RetentionExpiresDate__c = Date.today().addDays(-1);
        }
        update items;

        Integer beforeCount = [SELECT COUNT() FROM WorkItem__c];

        Test.startTest();
        DeliveryArchivalService.purgeExpiredArchives();
        Test.stopTest();

        Integer afterCount = [SELECT COUNT() FROM WorkItem__c];
        System.assertEquals(beforeCount - 2, afterCount, 'Two expired records should be purged');
    }

    @IsTest
    static void testPurgeDoesNotDeleteLegalHoldItems() {
        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c LIMIT 2];
        for (WorkItem__c wi : items) {
            wi.ArchivalStatusPk__c = 'Legal_Hold';
            wi.ArchivedDateTime__c = Datetime.now().addDays(-400);
            wi.RetentionExpiresDate__c = null;
        }
        update items;

        Integer beforeCount = [SELECT COUNT() FROM WorkItem__c];

        Test.startTest();
        DeliveryArchivalService.purgeExpiredArchives();
        Test.stopTest();

        Integer afterCount = [SELECT COUNT() FROM WorkItem__c];
        System.assertEquals(beforeCount, afterCount, 'Legal Hold items should not be purged');
    }

    @IsTest
    static void testPurgeDoesNotDeleteFutureRetention() {
        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c LIMIT 2];
        for (WorkItem__c wi : items) {
            wi.ArchivalStatusPk__c = 'Archived';
            wi.ArchivedDateTime__c = Datetime.now();
            wi.RetentionExpiresDate__c = Date.today().addDays(365);
        }
        update items;

        Integer beforeCount = [SELECT COUNT() FROM WorkItem__c];

        Test.startTest();
        DeliveryArchivalService.purgeExpiredArchives();
        Test.stopTest();

        Integer afterCount = [SELECT COUNT() FROM WorkItem__c];
        System.assertEquals(beforeCount, afterCount, 'Items with future retention should not be purged');
    }
}
