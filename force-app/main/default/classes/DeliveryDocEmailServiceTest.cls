/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryDocEmailService.
 *               Covers sendDocumentEmail, previewDocumentEmail, scheduleDocumentSend,
 *               cancelScheduledSend, CC address from settings, and parseDueDate.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryDocEmailServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        DeliveryTriggerControl.disableAfterLogic();

        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Email Test Vendor LLC',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active'
        );
        insert vendor;

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Email Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            ContactEmailTxt__c = 'client@example.com'
        );
        insert entity;

        DeliveryDocument__c doc = new DeliveryDocument__c(
            NetworkEntityId__c = entity.Id,
            TemplatePk__c = 'Invoice',
            PeriodStartDate__c = Date.newInstance(2026, 2, 1),
            PeriodEndDate__c = Date.newInstance(2026, 2, 28),
            PublicTokenTxt__c = 'email0001email0001email0001email0001email0001email0001email00aa',
            StatusPk__c = 'Draft',
            TotalHoursNumber__c = 40,
            TotalCurrency__c = 6000,
            TermsTxt__c = 'Net 30'
        );
        insert doc;

        DeliveryTriggerControl.enableAfterLogic();
    }

    private static DeliveryDocument__c getDoc() {
        return [
            SELECT Id, StatusPk__c, SentDateTime__c, DueDateDate__c, PublicTokenTxt__c,
                   ScheduledSendDateTime__c, ScheduledRecipientEmailTxt__c
            FROM DeliveryDocument__c
            LIMIT 1
        ];
    }

    @IsTest
    static void testSendDocumentEmail() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();

            Test.startTest();
            Map<String, Object> result = DeliveryDocEmailService.sendDocumentEmail(
                doc.Id, 'recipient@example.com'
            );
            Test.stopTest();

            System.assertEquals(true, result.get('success'), 'Send should succeed');
            System.assertEquals('recipient@example.com', result.get('recipientEmail'), 'Recipient should match');

            DeliveryDocument__c updated = getDoc();
            System.assertEquals('Sent', updated.StatusPk__c, 'Status should be Sent after email');
            System.assertNotEquals(null, updated.SentDateTime__c, 'SentDateTime should be populated');
            System.assertNotEquals(null, updated.DueDateDate__c, 'DueDateDate should be calculated from Net 30');
        }
    }

    @IsTest
    static void testSendDocumentEmailFallsBackToEntityContact() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();

            Test.startTest();
            Map<String, Object> result = DeliveryDocEmailService.sendDocumentEmail(doc.Id, null);
            Test.stopTest();

            System.assertEquals(true, result.get('success'), 'Send should succeed');
            System.assertEquals('client@example.com', result.get('recipientEmail'),
                'Should fall back to entity contact email');
        }
    }

    @IsTest
    static void testCcEmailFromSettings() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.DocumentCcEmailTxt__c = 'cc1@example.com, cc2@example.com';
            upsert settings;

            DeliveryDocument__c doc = getDoc();

            Test.startTest();
            // Just verify the send completes without error with CC configured
            Map<String, Object> result = DeliveryDocEmailService.sendDocumentEmail(
                doc.Id, 'recipient@example.com'
            );
            Test.stopTest();

            System.assertEquals(true, result.get('success'), 'Send should succeed with CC addresses');
        }
    }

    @IsTest
    static void testPreviewDocumentEmail() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();

            Test.startTest();
            Map<String, Object> preview = DeliveryDocEmailService.previewDocumentEmail(
                doc.Id, 'preview@example.com'
            );
            Test.stopTest();

            System.assertEquals('preview@example.com', preview.get('toEmail'), 'To email should match');
            System.assertNotEquals(null, preview.get('subject'), 'Subject should be populated');
            System.assertNotEquals(null, preview.get('bodyHtml'), 'Body HTML should be populated');
            System.assertNotEquals(null, preview.get('attachmentName'), 'Attachment name should be populated');
            System.assertEquals(doc.Id, preview.get('documentId'), 'Document ID should match');
        }
    }

    @IsTest
    static void testScheduleDocumentSend() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Datetime futureTime = Datetime.now().addHours(2);

            Test.startTest();
            Map<String, Object> result = DeliveryDocEmailService.scheduleDocumentSend(
                doc.Id, 'scheduled@example.com', futureTime
            );
            Test.stopTest();

            System.assertEquals(true, result.get('success'), 'Schedule should succeed');

            DeliveryDocument__c updated = getDoc();
            System.assertNotEquals(null, updated.ScheduledSendDateTime__c, 'Scheduled send time should be set');
            System.assertEquals('scheduled@example.com', updated.ScheduledRecipientEmailTxt__c,
                'Scheduled recipient should be stored');
            System.assertEquals('Ready', updated.StatusPk__c,
                'Draft document should transition to Ready when scheduled');
        }
    }

    @IsTest
    static void testSchedulePastTimeThrows() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Boolean threw = false;

            Test.startTest();
            try {
                DeliveryDocEmailService.scheduleDocumentSend(
                    doc.Id, 'test@example.com', Datetime.now().addHours(-1)
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assert(threw, 'Should throw for past scheduled time');
        }
    }

    @IsTest
    static void testCancelScheduledSend() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();

            // First schedule it
            DeliveryDocEmailService.scheduleDocumentSend(
                doc.Id, 'cancel@example.com', Datetime.now().addHours(5)
            );

            Test.startTest();
            Map<String, Object> result = DeliveryDocEmailService.cancelScheduledSend(doc.Id);
            Test.stopTest();

            System.assertEquals(true, result.get('success'), 'Cancel should succeed');

            DeliveryDocument__c updated = getDoc();
            System.assertEquals(null, updated.ScheduledSendDateTime__c, 'Scheduled time should be cleared');
            System.assertEquals(null, updated.ScheduledRecipientEmailTxt__c, 'Scheduled recipient should be cleared');
        }
    }

    @IsTest
    static void testBuildDocumentEmailBody() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = [
                SELECT Id, Name, TemplatePk__c, NetworkEntityId__r.Name,
                       PeriodStartDate__c, PeriodEndDate__c,
                       TotalHoursNumber__c, TotalCurrency__c,
                       TermsTxt__c, DueDateDate__c, MetadataTxt__c
                FROM DeliveryDocument__c LIMIT 1
            ];

            Test.startTest();
            String body = DeliveryDocEmailService.buildDocumentEmailBody(doc, 'Invoice', 'Test Vendor');
            Test.stopTest();

            System.assert(String.isNotBlank(body), 'Email body should not be blank');
            System.assert(body.contains('Test Vendor'), 'Body should contain vendor name');
            System.assert(body.contains('Invoice'), 'Body should contain template display name');
        }
    }

    @IsTest
    static void testParseDueDateVariants() {
        System.runAs(testUser) {
            Date base = Date.newInstance(2026, 3, 1);

            Test.startTest();
            System.assertEquals(base.addDays(30), DeliveryDocEmailService.parseDueDate('Net 30', base),
                'Net 30 should add 30 days');
            System.assertEquals(base.addDays(15), DeliveryDocEmailService.parseDueDate('Net 15', base),
                'Net 15 should add 15 days');
            System.assertEquals(base, DeliveryDocEmailService.parseDueDate('Due on Receipt', base),
                'Due on Receipt should return base date');
            System.assertEquals(null, DeliveryDocEmailService.parseDueDate(null, base),
                'Null terms should return null');
            System.assertEquals(null, DeliveryDocEmailService.parseDueDate('', base),
                'Blank terms should return null');
            System.assertEquals(null, DeliveryDocEmailService.parseDueDate('Custom Terms', base),
                'Unrecognized terms should return null');
            Test.stopTest();
        }
    }

    @IsTest
    static void testResolveVendorName() {
        System.runAs(testUser) {
            Test.startTest();
            String vendorName = DeliveryDocEmailService.resolveVendorName();
            Test.stopTest();

            // We inserted a vendor in setup, so it should resolve to that name
            System.assertEquals('Email Test Vendor LLC', vendorName, 'Should resolve to the vendor entity name');
        }
    }
}
