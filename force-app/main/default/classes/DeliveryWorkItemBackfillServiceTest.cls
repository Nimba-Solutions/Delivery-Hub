/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryWorkItemBackfillService.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkItemBackfillServiceTest {

    @IsTest
    static void backfillReturnsZeroWhenNoStaleRecords() {
        WorkItem__c fresh = new WorkItem__c(
            BriefDescriptionTxt__c = 'Fresh WI',
            StageNamePk__c         = 'Backlog',
            StatusPk__c            = 'New'
        );
        insert fresh;

        Test.startTest();
        Integer updated = DeliveryWorkItemBackfillService.backfillStatusDefaults();
        Test.stopTest();

        System.assertEquals(0, updated,
            'Records younger than the stale floor must not be touched');
        WorkItem__c reloaded = [SELECT StatusPk__c FROM WorkItem__c WHERE Id = :fresh.Id];
        System.assertEquals('New', reloaded.StatusPk__c,
            'Recent record must remain at Status=New');
    }

    @IsTest
    static void backfillFlipsStaleStatusNewToActive() {
        WorkItem__c stale = new WorkItem__c(
            BriefDescriptionTxt__c = 'Stale WI',
            StageNamePk__c         = 'In Development',
            StatusPk__c            = 'New'
        );
        insert stale;
        Test.setCreatedDate(stale.Id, Datetime.now().addDays(-7));

        Test.startTest();
        Integer updated = DeliveryWorkItemBackfillService.backfillStatusDefaults();
        Test.stopTest();

        System.assertEquals(1, updated, 'Stale record at Status=New should be flipped');
        WorkItem__c reloaded = [SELECT StatusPk__c FROM WorkItem__c WHERE Id = :stale.Id];
        System.assertEquals('Active', reloaded.StatusPk__c,
            'Stale record must be Active after backfill');
    }

    @IsTest
    static void backfillLeavesNonNewStatusAlone() {
        WorkItem__c done = new WorkItem__c(
            BriefDescriptionTxt__c = 'Done WI',
            StageNamePk__c         = 'In Development',
            StatusPk__c            = 'Done'
        );
        insert done;
        Test.setCreatedDate(done.Id, Datetime.now().addDays(-30));

        Test.startTest();
        Integer updated = DeliveryWorkItemBackfillService.backfillStatusDefaults();
        Test.stopTest();

        System.assertEquals(0, updated, 'Records not at Status=New must not be touched');
        WorkItem__c reloaded = [SELECT StatusPk__c FROM WorkItem__c WHERE Id = :done.Id];
        System.assertEquals('Done', reloaded.StatusPk__c,
            'Done record must remain Done');
    }

    @IsTest
    static void backfillIsIdempotent() {
        WorkItem__c stale = new WorkItem__c(
            BriefDescriptionTxt__c = 'Stale WI',
            StageNamePk__c         = 'In Development',
            StatusPk__c            = 'New'
        );
        insert stale;
        Test.setCreatedDate(stale.Id, Datetime.now().addDays(-7));

        Test.startTest();
        Integer firstPass  = DeliveryWorkItemBackfillService.backfillStatusDefaults();
        Integer secondPass = DeliveryWorkItemBackfillService.backfillStatusDefaults();
        Test.stopTest();

        System.assertEquals(1, firstPass,  'First pass should flip the stale record');
        System.assertEquals(0, secondPass, 'Second pass should be a no-op');
    }

    @IsTest
    static void backfillHandlesMixedFreshAndStale() {
        WorkItem__c fresh = new WorkItem__c(
            BriefDescriptionTxt__c = 'Fresh WI',
            StageNamePk__c         = 'Backlog',
            StatusPk__c            = 'New'
        );
        WorkItem__c stale = new WorkItem__c(
            BriefDescriptionTxt__c = 'Stale WI',
            StageNamePk__c         = 'In Development',
            StatusPk__c            = 'New'
        );
        insert new List<WorkItem__c>{ fresh, stale };
        Test.setCreatedDate(stale.Id, Datetime.now().addDays(-7));

        Test.startTest();
        Integer updated = DeliveryWorkItemBackfillService.backfillStatusDefaults();
        Test.stopTest();

        System.assertEquals(1, updated, 'Only the stale record should be flipped');

        Map<Id, WorkItem__c> reloaded = new Map<Id, WorkItem__c>(
            [SELECT Id, StatusPk__c FROM WorkItem__c WHERE Id IN :new List<Id>{fresh.Id, stale.Id}]
        );
        System.assertEquals('New',    reloaded.get(fresh.Id).StatusPk__c, 'Fresh record stays New');
        System.assertEquals('Active', reloaded.get(stale.Id).StatusPk__c, 'Stale record becomes Active');
    }
}
