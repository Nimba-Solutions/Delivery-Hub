/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryDocumentPdfController. Verifies the Visualforce
 *               controller correctly parses document snapshots and exposes typed properties.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
@isTest
private class DeliveryDocumentPdfControllerTest {

    @TestSetup
    static void setup() {
        DeliveryTriggerControl.runAfterLogic = false;

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'PDF Test Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            DefaultHourlyRateCurrency__c = 90,
            ContactEmailTxt__c = 'billing@pdftest.com',
            AddressTxt__c = '123 Test St'
        );
        insert entity;

        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'PDF Test Vendor',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active'
        );
        insert vendor;

        WorkItem__c item = new WorkItem__c(
            BriefDescriptionTxt__c = 'PDF Test Work Item',
            StageNamePk__c = 'In Development',
            ClientNetworkEntityId__c = entity.Id,
            BillableRateCurrency__c = 90,
            EstimatedHoursNumber__c = 40
        );
        insert item;

        WorkRequest__c req = new WorkRequest__c(
            WorkItemId__c = item.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'In Progress',
            HourlyRateCurrency__c = 90,
            QuotedHoursNumber__c = 40,
            PreApprovedHoursNumber__c = 40
        );
        insert req;

        insert new WorkLog__c(
            WorkItemId__c = item.Id,
            RequestId__c = req.Id,
            HoursLoggedNumber__c = 8,
            WorkDateDate__c = Date.newInstance(2026, 3, 10),
            WorkDescriptionTxt__c = 'Test work entry'
        );
    }

    private static NetworkEntity__c getEntity() {
        return [SELECT Id FROM NetworkEntity__c WHERE Name = 'PDF Test Corp' LIMIT 1];
    }

    /**
     * @description Verify the PDF controller loads a document and parses snapshot data.
     */
    @isTest
    static void testControllerLoadsInvoice() {
        NetworkEntity__c entity = getEntity();

        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id, 'Invoice',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
        );

        Test.startTest();
        Test.setCurrentPage(Page.DeliveryDocumentPdf);
        ApexPages.currentPage().getParameters().put('id', docId);

        DeliveryDocumentPdfController ctrl = new DeliveryDocumentPdfController();
        Test.stopTest();

        System.assertEquals(true, ctrl.getHasDocument(), 'Should have loaded document');
        System.assertEquals('Invoice', ctrl.templateType, 'Template should be Invoice');
        System.assertEquals(true, ctrl.getIsInvoice(), 'Should be invoice type');
        System.assertEquals(false, ctrl.getIsAgreement(), 'Should not be agreement type');
        System.assertEquals('PDF Test Corp', ctrl.entityName, 'Entity name should match');
        System.assertEquals('123 Test St', ctrl.entityAddress, 'Address should match');
        System.assertEquals('billing@pdftest.com', ctrl.entityEmail, 'Email should match');
        System.assertEquals(90, ctrl.defaultRate, 'Default rate should be 90');
        System.assertEquals(8.0, ctrl.totalHours, 'Total hours should be 8');
        System.assertEquals(true, ctrl.getHasWorkItems(), 'Should have work items');
        System.assertEquals(true, ctrl.getHasWorkLogs(), 'Should have work logs');
        System.assertEquals(true, ctrl.getHasWorkRequests(), 'Should have work requests');
        System.assertEquals(true, ctrl.getHasEntityContact(), 'Should have entity contact info');
        System.assertNotEquals(null, ctrl.formattedTotalCost, 'Should have formatted cost');
        System.assertNotEquals(null, ctrl.getFormattedDefaultRate(), 'Should have formatted rate');
        System.assertNotEquals(null, ctrl.getFormattedTotalHours(), 'Should have formatted hours');
    }

    /**
     * @description Verify controller handles missing document ID gracefully.
     */
    @isTest
    static void testControllerNoId() {
        Test.setCurrentPage(Page.DeliveryDocumentPdf);
        // No id parameter set

        DeliveryDocumentPdfController ctrl = new DeliveryDocumentPdfController();

        System.assertEquals(false, ctrl.getHasDocument(), 'Should not have document');
        System.assertEquals(false, ctrl.getHasWorkItems(), 'Should not have work items');
    }

    /**
     * @description Verify controller handles AI narrative getter.
     */
    @isTest
    static void testControllerWithNarrative() {
        NetworkEntity__c entity = getEntity();

        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id, 'Invoice',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
        );
        DeliveryDocumentController.saveAiNarrative(docId, 'Test narrative for PDF.');

        Test.startTest();
        Test.setCurrentPage(Page.DeliveryDocumentPdf);
        ApexPages.currentPage().getParameters().put('id', docId);

        DeliveryDocumentPdfController ctrl = new DeliveryDocumentPdfController();
        Test.stopTest();

        System.assertEquals(true, ctrl.getHasAiNarrative(), 'Should have AI narrative');
        System.assertEquals('Test narrative for PDF.', ctrl.aiNarrative, 'Narrative should match');
    }

    /**
     * @description Verify controller recognizes agreement template types.
     */
    @isTest
    static void testControllerClientAgreement() {
        NetworkEntity__c entity = getEntity();

        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id, 'Client_Agreement',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
        );

        Test.startTest();
        Test.setCurrentPage(Page.DeliveryDocumentPdf);
        ApexPages.currentPage().getParameters().put('id', docId);

        DeliveryDocumentPdfController ctrl = new DeliveryDocumentPdfController();
        Test.stopTest();

        System.assertEquals(true, ctrl.getIsAgreement(), 'Should be agreement type');
        System.assertEquals(false, ctrl.getIsInvoice(), 'Should not be invoice type');
        System.assertEquals('Client Agreement', ctrl.templateDisplay, 'Template display should be formatted');
    }

    /**
     * @description Verify terms and due date getters.
     */
    @isTest
    static void testControllerTermsAndDueDate() {
        NetworkEntity__c entity = getEntity();

        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id, 'Invoice',
            Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
        );

        DeliveryDocument__c doc = [SELECT Id FROM DeliveryDocument__c WHERE Id = :docId];
        doc.TermsTxt__c = 'Net 30';
        doc.DueDateDate__c = Date.newInstance(2026, 4, 30);
        update doc;

        Test.startTest();
        Test.setCurrentPage(Page.DeliveryDocumentPdf);
        ApexPages.currentPage().getParameters().put('id', docId);

        DeliveryDocumentPdfController ctrl = new DeliveryDocumentPdfController();
        Test.stopTest();

        System.assertEquals(true, ctrl.getHasTerms(), 'Should have terms');
        System.assertEquals('Net 30', ctrl.terms, 'Terms should match');
        System.assertEquals(true, ctrl.getHasDueDate(), 'Should have due date');
        System.assertNotEquals(null, ctrl.getFormattedDueDate(), 'Should have formatted due date');
    }
}
