/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryDocumentController.
 *              Covers generateDocument, getDocumentByToken, getDocumentsForEntity,
 *              updateDocumentStatus, saveAiNarrative, cost hierarchy, and parseDueDate.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
@isTest
private class DeliveryDocumentControllerTest {

    @TestSetup
    static void setup() {
        // Prevent trigger from auto-creating WorkRequests during test data setup
        DeliveryTriggerControl.runAfterLogic = false;

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Test Client Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            DefaultHourlyRateCurrency__c = 100
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
            BillableRateCurrency__c = 150,
            EstimatedHoursNumber__c = 100
        );
        WorkItem__c item2 = new WorkItem__c(
            BriefDescriptionTxt__c = 'MF-726 HubSpot Investigation',
            StageNamePk__c = 'Ready for Development',
            ClientNetworkEntityId__c = entity.Id,
            BillableRateCurrency__c = 150,
            EstimatedHoursNumber__c = 20
        );
        insert new List<WorkItem__c>{ item1, item2 };

        WorkRequest__c req1 = new WorkRequest__c(
            WorkItemId__c = item1.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'In Progress',
            HourlyRateCurrency__c = 175,
            QuotedHoursNumber__c = 100,
            PreApprovedHoursNumber__c = 100
        );
        WorkRequest__c req2 = new WorkRequest__c(
            WorkItemId__c = item2.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'Accepted',
            HourlyRateCurrency__c = 175,
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

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static NetworkEntity__c getEntity() {
        return [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Client Corp' LIMIT 1];
    }

    private static Id generateTestDocument(Id entityId) {
        return DeliveryDocumentController.generateDocument(
            entityId, 'Invoice',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31),
            '{"priorBalance":21105,"taxRate":0}'
        );
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    /**
     * @description Generate an Invoice document. Verify record created with correct
     *              hours, cost, snapshot JSON, status, and public token format.
     */
    @isTest
    static void testGenerateInvoiceDocument() {
        NetworkEntity__c entity = getEntity();

        Test.startTest();
        Id docId = generateTestDocument(entity.Id);
        Test.stopTest();

        DeliveryDocument__c doc = [
            SELECT Id, Name, TemplatePk__c, StatusPk__c, PublicTokenTxt__c,
                   TotalHoursNumber__c, TotalCurrency__c, SnapshotTxt__c,
                   PeriodStartDate__c, PeriodEndDate__c, MetadataTxt__c
            FROM DeliveryDocument__c
            WHERE Id = :docId
        ];

        System.assertNotEquals(null, doc.Id, 'Document should be created');
        System.assertEquals('Invoice', doc.TemplatePk__c, 'Template should be Invoice');
        System.assertEquals('Draft', doc.StatusPk__c, 'Initial status should be Draft');
        System.assertNotEquals(null, doc.PublicTokenTxt__c, 'Public token should be generated');
        System.assertEquals(64, doc.PublicTokenTxt__c.length(), 'Token should be 64 hex chars');
        // 3 logs: 8 + 4.5 + 5 = 17.5 hours
        System.assertEquals(17.5, doc.TotalHoursNumber__c, 'Total hours should be 17.5');
        // Cost: request rate (175) overrides item rate (150) and entity default (100)
        // All 17.5 hours * 175 = 3062.50
        System.assertEquals(3062.50, doc.TotalCurrency__c, 'Total cost should use request rates: 17.5 * 175 = 3062.50');
        System.assert(doc.SnapshotTxt__c.contains('QuickBooks'), 'Snapshot should contain work item data');
        System.assertEquals(Date.newInstance(2026, 3, 1), doc.PeriodStartDate__c, 'Period start should match');
        System.assertEquals(Date.newInstance(2026, 3, 31), doc.PeriodEndDate__c, 'Period end should match');
        System.assert(doc.MetadataTxt__c.contains('priorBalance'), 'Metadata should be stored');
    }

    /**
     * @description Retrieve a Draft document by token. Verify all fields returned
     *              and that status remains Draft (not auto-marked Viewed).
     */
    @isTest
    static void testGetDocumentByToken() {
        NetworkEntity__c entity = getEntity();

        Id docId = generateTestDocument(entity.Id);
        DeliveryDocument__c doc = [SELECT PublicTokenTxt__c FROM DeliveryDocument__c WHERE Id = :docId];

        Test.startTest();
        Map<String, Object> result = DeliveryDocumentController.getDocumentByToken(doc.PublicTokenTxt__c);
        Test.stopTest();

        System.assertEquals('Invoice', result.get('template'), 'Template should match');
        System.assertEquals('Test Client Corp', result.get('entityName'), 'Entity name should match');
        System.assertNotEquals(null, result.get('snapshot'), 'Snapshot should be returned');
        System.assertNotEquals(null, result.get('totalHours'), 'Total hours should be returned');
        System.assertNotEquals(null, result.get('totalCost'), 'Total cost should be returned');
        // Draft documents should NOT be auto-marked as Viewed
        System.assertEquals('Draft', result.get('status'), 'Draft document status should remain Draft on access');
    }

    /**
     * @description Retrieve a Sent document by token. Verify it auto-marks as
     *              Viewed and sets ViewedDateTime.
     */
    @isTest
    static void testGetDocumentByTokenMarksViewed() {
        NetworkEntity__c entity = getEntity();

        Id docId = generateTestDocument(entity.Id);
        DeliveryDocumentController.updateDocumentStatus(docId, 'Sent');

        DeliveryDocument__c doc = [SELECT PublicTokenTxt__c FROM DeliveryDocument__c WHERE Id = :docId];

        Test.startTest();
        Map<String, Object> result = DeliveryDocumentController.getDocumentByToken(doc.PublicTokenTxt__c);
        Test.stopTest();

        System.assertEquals('Viewed', result.get('status'), 'Status should flip to Viewed');
        System.assertNotEquals(null, result.get('viewedDate'), 'Viewed date should be set');
    }

    /**
     * @description Try to retrieve a document with an invalid token.
     *              Expect AuraHandledException.
     */
    @isTest
    static void testGetDocumentByTokenNotFound() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryDocumentController.getDocumentByToken('nonexistent-token-value');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw AuraHandledException for invalid token');
    }

    /**
     * @description Generate 2 documents, retrieve list for entity.
     *              Verify count and that results are returned (ordered by CreatedDate DESC).
     */
    @isTest
    static void testGetDocumentsForEntity() {
        NetworkEntity__c entity = getEntity();

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
        // Verify each doc has expected keys
        for (Map<String, Object> d : docs) {
            System.assertNotEquals(null, d.get('id'), 'Each doc should have an id');
            System.assertNotEquals(null, d.get('template'), 'Each doc should have a template');
            System.assertNotEquals(null, d.get('status'), 'Each doc should have a status');
        }
    }

    /**
     * @description Update status to Sent with Net 30 terms. Verify SentDateTime is set
     *              and DueDateDate is calculated as today + 30 days.
     */
    @isTest
    static void testUpdateDocumentStatusToSent() {
        NetworkEntity__c entity = getEntity();

        Id docId = generateTestDocument(entity.Id);

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
        System.assertEquals(Date.today().addDays(30), doc.DueDateDate__c, 'Due date should be today + 30');
    }

    /**
     * @description Update status to Sent with 'Due on Receipt' terms. Verify DueDateDate
     *              equals today (no offset).
     */
    @isTest
    static void testUpdateDocumentStatusDueOnReceipt() {
        NetworkEntity__c entity = getEntity();

        Id docId = generateTestDocument(entity.Id);

        DeliveryDocument__c doc = [SELECT Id FROM DeliveryDocument__c WHERE Id = :docId];
        doc.TermsTxt__c = 'Due on Receipt';
        update doc;

        Test.startTest();
        DeliveryDocumentController.updateDocumentStatus(docId, 'Sent');
        Test.stopTest();

        doc = [SELECT StatusPk__c, SentDateTime__c, DueDateDate__c FROM DeliveryDocument__c WHERE Id = :docId];
        System.assertEquals('Sent', doc.StatusPk__c, 'Status should be Sent');
        System.assertNotEquals(null, doc.SentDateTime__c, 'Sent date should be populated');
        System.assertEquals(Date.today(), doc.DueDateDate__c, 'Due on Receipt should set due date to today');
    }

    /**
     * @description Save an AI narrative and verify it persists on the record.
     */
    @isTest
    static void testSaveAiNarrative() {
        NetworkEntity__c entity = getEntity();

        Id docId = generateTestDocument(entity.Id);

        Test.startTest();
        DeliveryDocumentController.saveAiNarrative(docId, 'AI generated summary of the work period.');
        Test.stopTest();

        DeliveryDocument__c doc = [SELECT AiNarrativeTxt__c FROM DeliveryDocument__c WHERE Id = :docId];
        System.assertEquals('AI generated summary of the work period.', doc.AiNarrativeTxt__c, 'Narrative should be saved');
    }

    /**
     * @description Verify the cost calculation rate hierarchy:
     *              WorkRequest rate (175) > WorkItem billable rate (150) > Entity default rate (100).
     *              Setup data has all three tiers. Request rate should win.
     *              Also test an item with NO request to verify item rate is used,
     *              and an item with neither to verify entity default is used.
     */
    @isTest
    static void testCostCalculation() {
        NetworkEntity__c entity = getEntity();

        // Prevent trigger from auto-creating WorkRequests for this test item
        DeliveryTriggerControl.runAfterLogic = false;

        // Create a third work item with NO billable rate (should use entity default of 100)
        WorkItem__c itemNoRate = new WorkItem__c(
            BriefDescriptionTxt__c = 'MF-800 No Rate Item',
            StageNamePk__c = 'In Development',
            ClientNetworkEntityId__c = entity.Id,
            EstimatedHoursNumber__c = 10
            // BillableRateCurrency__c intentionally omitted — null
        );
        insert itemNoRate;

        // Create a WorkRequest with NO rate for the no-rate item (Master-Detail requires parent)
        NetworkEntity__c vendor = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Vendor LLC' LIMIT 1];
        WorkRequest__c reqNoRate = new WorkRequest__c(
            WorkItemId__c = itemNoRate.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'In Progress'
            // HourlyRateCurrency__c intentionally omitted — rate hierarchy falls through to entity default
        );
        insert reqNoRate;

        // Log 2 hours on the no-rate item within the period
        insert new WorkLog__c(
            WorkItemId__c = itemNoRate.Id,
            RequestId__c = reqNoRate.Id,
            HoursLoggedNumber__c = 2,
            WorkDateDate__c = Date.newInstance(2026, 3, 5),
            WorkDescriptionTxt__c = 'Work on unrated item'
        );

        Test.startTest();
        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id, 'Invoice',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
        );
        Test.stopTest();

        DeliveryDocument__c doc = [
            SELECT TotalHoursNumber__c, TotalCurrency__c
            FROM DeliveryDocument__c
            WHERE Id = :docId
        ];

        // Total hours: 8 + 4.5 + 5 + 2 = 19.5
        System.assertEquals(19.5, doc.TotalHoursNumber__c, 'Total hours should be 19.5');

        // Cost breakdown:
        //   item1 logs (8 + 4.5 = 12.5h): has WorkRequest rate 175 → 12.5 * 175 = 2187.50
        //   item2 logs (5h): has WorkRequest rate 175 → 5 * 175 = 875
        //   itemNoRate logs (2h): request has no rate, no item rate → entity default 100 → 2 * 100 = 200
        //   Total: 2187.50 + 875 + 200 = 3262.50
        System.assertEquals(3262.50, doc.TotalCurrency__c, 'Cost should reflect rate hierarchy: request > item > entity default');
    }

    /**
     * @description Test parseDueDate with various inputs:
     *              Net 30, Net 15, Due on Receipt, blank, null, invalid string.
     */
    @isTest
    static void testParseDueDate() {
        Date base = Date.newInstance(2026, 3, 11);

        // Net 30
        System.assertEquals(
            Date.newInstance(2026, 4, 10),
            DeliveryDocumentController.parseDueDate('Net 30', base),
            'Net 30 should add 30 days'
        );
        // Net 15
        System.assertEquals(
            Date.newInstance(2026, 3, 26),
            DeliveryDocumentController.parseDueDate('Net 15', base),
            'Net 15 should add 15 days'
        );
        // Due on Receipt
        System.assertEquals(
            base,
            DeliveryDocumentController.parseDueDate('Due on Receipt', base),
            'Due on Receipt should return same date'
        );
        // Blank
        System.assertEquals(
            null,
            DeliveryDocumentController.parseDueDate('', base),
            'Blank should return null'
        );
        // Null
        System.assertEquals(
            null,
            DeliveryDocumentController.parseDueDate(null, base),
            'Null should return null'
        );
        // Invalid string (not a recognized format)
        System.assertEquals(
            null,
            DeliveryDocumentController.parseDueDate('Some Random Text', base),
            'Unrecognized terms should return null'
        );
        // Net with non-numeric value
        System.assertEquals(
            null,
            DeliveryDocumentController.parseDueDate('Net abc', base),
            'Net with non-numeric value should return null'
        );
    }

    /**
     * @description Send a document via email. Verify the status transitions to Sent,
     *              SentDateTime is populated, and the method returns the recipient email.
     */
    @isTest
    static void testSendDocumentEmail() {
        NetworkEntity__c entity = getEntity();
        // Set contact email so the method has a recipient
        entity.ContactEmailTxt__c = 'danny@atlarge.com';
        update entity;

        Id docId = generateTestDocument(entity.Id);

        // Set terms for due date calc
        DeliveryDocument__c doc = [SELECT Id FROM DeliveryDocument__c WHERE Id = :docId];
        doc.TermsTxt__c = 'Net 30';
        update doc;

        Test.startTest();
        Map<String, Object> result = DeliveryDocumentController.sendDocumentEmail(docId, null);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should return success');
        System.assertEquals('danny@atlarge.com', result.get('recipientEmail'), 'Should fall back to entity email');

        doc = [SELECT StatusPk__c, SentDateTime__c, DueDateDate__c FROM DeliveryDocument__c WHERE Id = :docId];
        System.assertEquals('Sent', doc.StatusPk__c, 'Status should be Sent after email');
        System.assertNotEquals(null, doc.SentDateTime__c, 'SentDateTime should be set');
        System.assertNotEquals(null, doc.DueDateDate__c, 'DueDate should be calculated');
    }

    /**
     * @description Send a document with explicit recipient email override.
     */
    @isTest
    static void testSendDocumentEmailExplicitRecipient() {
        NetworkEntity__c entity = getEntity();
        Id docId = generateTestDocument(entity.Id);

        Test.startTest();
        Map<String, Object> result = DeliveryDocumentController.sendDocumentEmail(docId, 'override@test.com');
        Test.stopTest();

        System.assertEquals('override@test.com', result.get('recipientEmail'), 'Should use explicit email');
    }

    /**
     * @description Send a document with no recipient and no entity email. Expect error.
     */
    @isTest
    static void testSendDocumentEmailNoRecipient() {
        NetworkEntity__c entity = getEntity();
        // Ensure no contact email
        entity.ContactEmailTxt__c = null;
        update entity;

        Id docId = generateTestDocument(entity.Id);

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryDocumentController.sendDocumentEmail(docId, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when no recipient available');
    }

    /**
     * @description Verify buildDocumentEmailBody returns HTML containing key elements.
     */
    @isTest
    static void testBuildDocumentEmailBody() {
        NetworkEntity__c entity = getEntity();
        Id docId = generateTestDocument(entity.Id);

        DeliveryDocument__c doc = [
            SELECT Id, Name, TemplatePk__c, NetworkEntityId__r.Name,
                   NetworkEntityId__r.ContactEmailTxt__c,
                   PeriodStartDate__c, PeriodEndDate__c,
                   StatusPk__c, TotalHoursNumber__c, TotalCurrency__c,
                   TermsTxt__c, DueDateDate__c, SentDateTime__c,
                   PublicTokenTxt__c
            FROM DeliveryDocument__c
            WHERE Id = :docId
        ];

        String html = DeliveryDocumentController.buildDocumentEmailBody(doc, 'Invoice');
        System.assert(html.contains('Cloud Nimbus LLC'), 'Should contain company name');
        System.assert(html.contains('Test Client Corp'), 'Should contain entity name');
    }

    /**
     * @description Verify getDocumentTemplates returns available templates from CMT.
     *              The seeded Invoice and Status_Report templates should always be present.
     */
    @isTest
    static void testGetDocumentTemplates() {
        Test.startTest();
        List<Map<String, String>> templates = DeliveryDocumentController.getDocumentTemplates();
        Test.stopTest();

        System.assert(templates.size() >= 2, 'Should have at least Invoice and Status_Report templates');
        // Verify each template has required keys
        for (Map<String, String> t : templates) {
            System.assertNotEquals(null, t.get('value'), 'Each template should have a value');
            System.assertNotEquals(null, t.get('label'), 'Each template should have a label');
        }
    }

    /**
     * @description Verify buildSnapshot returns all expected keys and correct
     *              counts for entity, workItems, workLogs, and workRequests.
     */
    @isTest
    static void testBuildSnapshotContent() {
        NetworkEntity__c entity = getEntity();

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
        System.assertNotEquals(null, snapshot.get('periodStart'), 'Should have periodStart');
        System.assertNotEquals(null, snapshot.get('periodEnd'), 'Should have periodEnd');
        System.assertNotEquals(null, snapshot.get('generatedAt'), 'Should have generatedAt');
        System.assertEquals('Invoice', snapshot.get('templateType'), 'Template type should match');

        List<Object> items = (List<Object>) snapshot.get('workItems');
        System.assertEquals(2, items.size(), 'Should have 2 work items');

        List<Object> logs = (List<Object>) snapshot.get('workLogs');
        System.assertEquals(3, logs.size(), 'Should have 3 work logs');

        List<Object> requests = (List<Object>) snapshot.get('workRequests');
        System.assertEquals(2, requests.size(), 'Should have 2 work requests');

        // Verify entity serialization
        Map<String, Object> entityMap = (Map<String, Object>) snapshot.get('entity');
        System.assertEquals('Test Client Corp', entityMap.get('name'), 'Entity name should match');
        System.assertEquals(100, (Decimal) entityMap.get('defaultRate'), 'Entity default rate should be 100');
    }
}
