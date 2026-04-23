/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryDocDeferralService — verifies the
 *               defer (Approved -> Draft + tag) and release
 *               (Draft + tag in period -> Approved + date shift) flows
 *               and that original WorkDescription text is recoverable.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class DeliveryDocDeferralServiceTest {

    private static final Date MILESTONE = Date.newInstance(2026, 6, 15);
    private static final String ORIGINAL_DESC = 'QuickBooks integration scaffold';

    @TestSetup
    static void setupData() {
        DeliveryTriggerControl.disableAfterLogic();

        NetworkEntity__c client = new NetworkEntity__c(
            Name = 'Defer Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Defer Test Vendor',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active'
        );
        insert new List<NetworkEntity__c>{ client, vendor };

        WorkItem__c workItem = new WorkItem__c(
            BriefDescriptionTxt__c       = 'Defer Test Item',
            StageNamePk__c               = 'In Development',
            ClientNetworkEntityLookup__c = client.Id
        );
        insert workItem;

        WorkRequest__c request = new WorkRequest__c(
            WorkItemId__c           = workItem.Id,
            DeliveryEntityLookup__c = vendor.Id,
            QuotedHoursNumber__c    = 20,
            HourlyRateCurrency__c   = 100,
            StatusPk__c             = 'Accepted'
        );
        insert request;

        // Three Approved logs in April that we will defer
        List<WorkLog__c> logs = new List<WorkLog__c>();
        for (Integer i = 0; i < 3; i++) {
            logs.add(new WorkLog__c(
                RequestId__c          = request.Id,
                WorkItemLookup__c     = workItem.Id,
                HoursLoggedNumber__c  = 2.0 + i,
                WorkDateDate__c       = Date.newInstance(2026, 4, 10 + i),
                WorkDescriptionTxt__c = ORIGINAL_DESC + ' #' + i,
                StatusPk__c           = 'Approved'
            ));
        }
        insert logs;

        DeliveryTriggerControl.enableAfterLogic();
    }

    private static List<WorkLog__c> getApprovedLogs() {
        return [
            SELECT Id, StatusPk__c, WorkDescriptionTxt__c, WorkDateDate__c
            FROM WorkLog__c
            WHERE StatusPk__c = 'Approved'
            ORDER BY WorkDateDate__c
        ];
    }

    private static Id getClientId() {
        return [SELECT Id FROM NetworkEntity__c WHERE Name = 'Defer Test Client' LIMIT 1].Id;
    }

    @IsTest
    static void testDeferSetsStatusToDraft() {
        DeliveryTriggerControl.disableAfterLogic();
        List<WorkLog__c> logs = getApprovedLogs();
        System.assertEquals(3, logs.size(), 'Setup should give us 3 Approved logs.');
        List<Id> ids = new List<Id>{ logs[0].Id, logs[1].Id, logs[2].Id };

        Test.startTest();
        Integer count = DeliveryDocDeferralService.deferWorkLogs(ids, MILESTONE, 'Client dispute');
        Test.stopTest();

        System.assertEquals(3, count, 'All 3 logs should report deferred.');
        List<WorkLog__c> after = [
            SELECT Id, StatusPk__c FROM WorkLog__c WHERE Id IN :ids
        ];
        for (WorkLog__c wl : after) {
            System.assertEquals('Draft', wl.StatusPk__c, 'Each deferred log must be Draft.');
        }
        DeliveryTriggerControl.enableAfterLogic();
    }

    @IsTest
    static void testDeferAppendsMilestoneTag() {
        DeliveryTriggerControl.disableAfterLogic();
        List<WorkLog__c> logs = getApprovedLogs();
        List<Id> ids = new List<Id>{ logs[0].Id };

        Test.startTest();
        DeliveryDocDeferralService.deferWorkLogs(ids, MILESTONE, 'Awaiting acceptance');
        Test.stopTest();

        WorkLog__c after = [SELECT WorkDescriptionTxt__c FROM WorkLog__c WHERE Id = :logs[0].Id];
        System.assert(
            after.WorkDescriptionTxt__c.startsWith('[DEFERRED to 2026-06-15]'),
            'Description should be prefixed with the milestone tag, got: ' + after.WorkDescriptionTxt__c
        );
        System.assert(
            after.WorkDescriptionTxt__c.contains(ORIGINAL_DESC),
            'Original description must be preserved after the tag.'
        );
        DeliveryTriggerControl.enableAfterLogic();
    }

    @IsTest
    static void testReleaseDeferredFlipsBackToApprovedAndUpdatesDate() {
        DeliveryTriggerControl.disableAfterLogic();
        List<WorkLog__c> logs = getApprovedLogs();
        List<Id> ids = new List<Id>{ logs[0].Id, logs[1].Id, logs[2].Id };

        DeliveryDocDeferralService.deferWorkLogs(ids, MILESTONE, 'Disputed cohort');

        Id clientId = getClientId();
        Date periodStart = Date.newInstance(2026, 6, 1);
        Date periodEnd   = Date.newInstance(2026, 6, 30);

        Test.startTest();
        Integer released = DeliveryDocDeferralService.releaseDeferredForPeriod(
            clientId, periodStart, periodEnd
        );
        Test.stopTest();

        System.assertEquals(3, released, 'All 3 deferred logs should release in June.');
        List<WorkLog__c> after = [
            SELECT StatusPk__c, WorkDateDate__c, WorkDescriptionTxt__c
            FROM WorkLog__c
            WHERE Id IN :ids
        ];
        for (WorkLog__c wl : after) {
            System.assertEquals('Approved', wl.StatusPk__c, 'Released log must be Approved.');
            System.assertEquals(MILESTONE, wl.WorkDateDate__c, 'WorkDate must be milestone.');
            System.assert(
                !wl.WorkDescriptionTxt__c.startsWith('[DEFERRED'),
                'Tag should be stripped from description after release.'
            );
        }
        DeliveryTriggerControl.enableAfterLogic();
    }

    @IsTest
    static void testReleaseDeferredIgnoresLogsOutsideTargetPeriod() {
        DeliveryTriggerControl.disableAfterLogic();
        List<WorkLog__c> logs = getApprovedLogs();
        List<Id> ids = new List<Id>{ logs[0].Id, logs[1].Id, logs[2].Id };

        // Defer to June 15, then attempt release for May (outside) — should release 0.
        DeliveryDocDeferralService.deferWorkLogs(ids, MILESTONE, 'Out-of-period test');

        Id clientId = getClientId();

        Test.startTest();
        Integer released = DeliveryDocDeferralService.releaseDeferredForPeriod(
            clientId,
            Date.newInstance(2026, 5, 1),
            Date.newInstance(2026, 5, 31)
        );
        Test.stopTest();

        System.assertEquals(0, released, 'No logs should release outside the milestone period.');
        List<WorkLog__c> after = [
            SELECT StatusPk__c FROM WorkLog__c WHERE Id IN :ids
        ];
        for (WorkLog__c wl : after) {
            System.assertEquals('Draft', wl.StatusPk__c, 'Logs outside period stay Draft.');
        }
        DeliveryTriggerControl.enableAfterLogic();
    }

    @IsTest
    static void testDeferPreservesOriginalDescription() {
        DeliveryTriggerControl.disableAfterLogic();
        List<WorkLog__c> logs = getApprovedLogs();
        Id targetId = logs[0].Id;
        String originalText = logs[0].WorkDescriptionTxt__c;

        DeliveryDocDeferralService.deferWorkLogs(new List<Id>{ targetId }, MILESTONE, 'Round-trip');

        Id clientId = getClientId();

        Test.startTest();
        DeliveryDocDeferralService.releaseDeferredForPeriod(
            clientId,
            Date.newInstance(2026, 6, 1),
            Date.newInstance(2026, 6, 30)
        );
        Test.stopTest();

        WorkLog__c restored = [
            SELECT WorkDescriptionTxt__c, StatusPk__c
            FROM WorkLog__c WHERE Id = :targetId
        ];
        System.assertEquals('Approved', restored.StatusPk__c, 'Should be Approved after release.');
        System.assertEquals(
            originalText, restored.WorkDescriptionTxt__c,
            'Original description must round-trip through defer + release unchanged.'
        );
        DeliveryTriggerControl.enableAfterLogic();
    }

    @IsTest
    static void testDeferWithEmptyListThrows() {
        Boolean threw = false;
        try {
            DeliveryDocDeferralService.deferWorkLogs(new List<Id>(), MILESTONE, 'x');
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assert(threw, 'Empty list must raise AuraHandledException.');
    }

    @IsTest
    static void testGetWorkLogsForEntityPeriodReturnsApprovedInRange() {
        Id clientId = getClientId();
        Test.startTest();
        List<WorkLog__c> result = DeliveryDocDeferralService.getWorkLogsForEntityPeriod(
            clientId,
            Date.newInstance(2026, 4, 1),
            Date.newInstance(2026, 4, 30)
        );
        Test.stopTest();
        System.assertEquals(3, result.size(), 'All 3 April Approved logs should return.');
    }

    @IsTest
    static void testReleaseWithNullEntityThrows() {
        Boolean threw = false;
        try {
            DeliveryDocDeferralService.releaseDeferredForPeriod(
                null, Date.today(), Date.today().addDays(10)
            );
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assert(threw, 'Null entity must raise AuraHandledException.');
    }
}
