/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryDocumentController.
 * @author Cloud Nimbus LLC
 */
@isTest
private class DeliveryDocumentControllerTest {

    @TestSetup
    static void setup() {
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Test Client Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            DefaultHourlyRateCurrency__c = 90
        );
        insert entity;

        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Test Vendor LLC',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active'
        );
        insert vendor;

        WorkItem__c item1 = new WorkItem__c(
            BriefDescriptionTxt__c = 'MF-699 QuickBooks Integration',
            StageNamePk__c = 'In Development',
            ClientNetworkEntityId__c = entity.Id,
            BillableRateCurrency__c = 90,
            EstimatedHoursNumber__c = 100
        );
        WorkItem__c item2 = new WorkItem__c(
            BriefDescriptionTxt__c = 'MF-726 HubSpot Investigation',
            StageNamePk__c = 'Ready for Development',
            ClientNetworkEntityId__c = entity.Id,
            BillableRateCurrency__c = 90,
            EstimatedHoursNumber__c = 20
        );
        insert new List<WorkItem__c>{ item1, item2 };

        WorkRequest__c req1 = new WorkRequest__c(
            WorkItemId__c = item1.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'In Progress',
            HourlyRateCurrency__c = 90,
            QuotedHoursNumber__c = 100,
            PreApprovedHoursNumber__c = 100
        );
        WorkRequest__c req2 = new WorkRequest__c(
            WorkItemId__c = item2.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'Accepted',
            HourlyRateCurrency__c = 90,
            QuotedHoursNumber__c = 20,
            PreApprovedHoursNumber__c = 20
        );
        insert new List<WorkRequest__c>{ req1, req2 };

        List<WorkLog__c> logs = new List<WorkLog__c>();
        logs.add(new WorkLog__c(
            WorkItemId__c = item1.Id,
            RequestId__c = req1.Id,
            HoursLoggedNumber__c = 8,
            WorkDateDate__c = Date.newInstance(2026, 3, 1),
            WorkDescriptionTxt__c = 'Integration setup'
        ));
        logs.add(new WorkLog__c(
            WorkItemId__c = item1.Id,
            RequestId__c = req1.Id,
            HoursLoggedNumber__c = 4.5,
            WorkDateDate__c = Date.newInstance(2026, 3, 2),
            WorkDescriptionTxt__c = 'Testing and deployment'
        ));
        logs.add(new WorkLog__c(
            WorkItemId__c = item2.Id,
            RequestId__c = req2.Id,
            HoursLoggedNumber__c = 5,
            WorkDateDate__c = Date.newInstance(2026, 3, 3),
            WorkDescriptionTxt__c = 'Investigation and analysis'
        ));
        insert logs;
    }

    @isTest
    static void testGenerateInvoiceDocument() {
        NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Client Corp' LIMIT 1];

        Test.startTest();
        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id,
            'Invoice',
            Date.newInstance(2026, 3, 1),
            Date.newInstance(2026, 3, 31),
            '{"priorBalance":21105,"taxRate":0}'
        );
        Test.stopTest();

        DeliveryDocument__c doc = [
            SELECT Id, Name, TemplatePk__c, StatusPk__c, PublicTokenTxt__c,
                   TotalHoursNumber__c, TotalCurrency__c, SnapshotTxt__c
            FROM DeliveryDocument__c
            WHERE Id = :docId
        ];

        System.assertNotEquals(null, doc.Id, 'Document should be created');
        System.assertEquals('Invoice', doc.TemplatePk__c, 'Template should be Invoice');
        System.assertEquals('Draft', doc.StatusPk__c, 'Initial status should be Draft');
        System.assertNotEquals(null, doc.PublicTokenTxt__c, 'Public token should be generated');
        System.assertEquals(64, doc.PublicTokenTxt__c.length(), 'Token should be 64 hex chars');
        System.assertEquals(17.5, doc.TotalHoursNumber__c, 'Total hours should be 17.5');
        System.assertEquals(1575, doc.TotalCurrency__c, 'Total cost should be 17.5 * 90 = 1575');
        System.assert(doc.SnapshotTxt__c.contains('QuickBooks'), 'Snapshot should contain work item data');
    }

    @isTest
    static void testGetDocumentByToken() {
        NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Client Corp' LIMIT 1];

        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id, 'Invoice',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
        );

        DeliveryDocument__c doc = [SELECT PublicTokenTxt__c FROM DeliveryDocument__c WHERE Id = :docId];

        Test.startTest();
        Map<String, Object> result = DeliveryDocumentController.getDocumentByToken(doc.PublicTokenTxt__c);
        Test.stopTest();

        System.assertEquals('Invoice', result.get('template'), 'Template should match');
        System.assertEquals('Test Client Corp', result.get('entityName'), 'Entity name should match');
        System.assertNotEquals(null, result.get('snapshot'), 'Snapshot should be returned');
    }

    @isTest
    static void testGetDocumentByTokenNotFound() {
        Test.startTest();
        try {
            DeliveryDocumentController.getDocumentByToken('nonexistent-token');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not found'), 'Error should mention not found');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetDocumentsForEntity() {
        NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Client Corp' LIMIT 1];

        DeliveryDocumentController.generateDocument(
            entity.Id, 'Invoice',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
        );
        DeliveryDocumentController.generateDocument(
            entity.Id, 'Status_Report',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
        );

        Test.startTest();
        List<Map<String, Object>> docs = DeliveryDocumentController.getDocumentsForEntity(entity.Id);
        Test.stopTest();

        System.assertEquals(2, docs.size(), 'Should return 2 documents');
    }

    @isTest
    static void testUpdateDocumentStatusToSent() {
        NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Client Corp' LIMIT 1];

        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id, 'Invoice',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
        );

        // Set terms so due date auto-calculates
        DeliveryDocument__c doc = [SELECT Id FROM DeliveryDocument__c WHERE Id = :docId];
        doc.TermsTxt__c = 'Net 30';
        update doc;

        Test.startTest();
        DeliveryDocumentController.updateDocumentStatus(docId, 'Sent');
        Test.stopTest();

        doc = [SELECT StatusPk__c, SentDateTime__c, DueDateDate__c FROM DeliveryDocument__c WHERE Id = :docId];
        System.assertEquals('Sent', doc.StatusPk__c, 'Status should be Sent');
        System.assertNotEquals(null, doc.SentDateTime__c, 'Sent date should be populated');
        System.assertNotEquals(null, doc.DueDateDate__c, 'Due date should be calculated from Net 30');
    }

    @isTest
    static void testViewedOnFirstAccess() {
        NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Client Corp' LIMIT 1];

        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id, 'Invoice',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
        );

        // Mark as sent first
        DeliveryDocumentController.updateDocumentStatus(docId, 'Sent');

        DeliveryDocument__c doc = [SELECT PublicTokenTxt__c FROM DeliveryDocument__c WHERE Id = :docId];

        Test.startTest();
        DeliveryDocumentController.getDocumentByToken(doc.PublicTokenTxt__c);
        Test.stopTest();

        doc = [SELECT StatusPk__c, ViewedDateTime__c FROM DeliveryDocument__c WHERE Id = :docId];
        System.assertEquals('Viewed', doc.StatusPk__c, 'Status should flip to Viewed');
        System.assertNotEquals(null, doc.ViewedDateTime__c, 'Viewed date should be set');
    }

    @isTest
    static void testSaveAiNarrative() {
        NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Client Corp' LIMIT 1];

        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id, 'Invoice',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
        );

        Test.startTest();
        DeliveryDocumentController.saveAiNarrative(docId, 'AI generated summary of the work period.');
        Test.stopTest();

        DeliveryDocument__c doc = [SELECT AiNarrativeTxt__c FROM DeliveryDocument__c WHERE Id = :docId];
        System.assertEquals('AI generated summary of the work period.', doc.AiNarrativeTxt__c, 'Narrative should be saved');
    }

    @isTest
    static void testParseDueDate() {
        Date base = Date.newInstance(2026, 3, 11);
        System.assertEquals(Date.newInstance(2026, 4, 10), DeliveryDocumentController.parseDueDate('Net 30', base), 'Net 30 should add 30 days');
        System.assertEquals(base, DeliveryDocumentController.parseDueDate('Due on Receipt', base), 'Due on Receipt should return same date');
        System.assertEquals(null, DeliveryDocumentController.parseDueDate('', base), 'Blank should return null');
        System.assertEquals(null, DeliveryDocumentController.parseDueDate(null, base), 'Null should return null');
    }

    @isTest
    static void testBuildSnapshotContent() {
        NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Client Corp' LIMIT 1];

        Test.startTest();
        Map<String, Object> snapshot = DeliveryDocumentController.buildSnapshot(
            entity.Id, 'Invoice',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31)
        );
        Test.stopTest();

        System.assertNotEquals(null, snapshot.get('entity'), 'Should have entity data');
        System.assertNotEquals(null, snapshot.get('workItems'), 'Should have work items');
        System.assertNotEquals(null, snapshot.get('workLogs'), 'Should have work logs');
        System.assertNotEquals(null, snapshot.get('workRequests'), 'Should have work requests');

        List<Object> items = (List<Object>) snapshot.get('workItems');
        System.assertEquals(2, items.size(), 'Should have 2 work items');

        List<Object> logs = (List<Object>) snapshot.get('workLogs');
        System.assertEquals(3, logs.size(), 'Should have 3 work logs');
    }
}
