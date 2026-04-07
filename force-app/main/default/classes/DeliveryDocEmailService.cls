/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Email sending, preview, and scheduling logic for DeliveryDocument__c records.
 *               Extracted from DeliveryDocumentController to reduce class size.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.ApexDoc')
public with sharing class DeliveryDocEmailService {

    /**
     * @description Sends a document as a PDF email attachment and marks it as Sent.
     * @param documentId The DeliveryDocument__c Id.
     * @param recipientEmail The primary recipient email. Falls back to entity contact email.
     * @return Map with 'success' and 'recipientEmail' keys.
     */
    public static Map<String, Object> sendDocumentEmail(Id documentId, String recipientEmail) {
        DeliveryDocument__c doc = [
            SELECT Id, Name, TemplatePk__c, NetworkEntityLookup__r.Name,
                   NetworkEntityLookup__r.ContactEmailTxt__c,
                   PeriodStartDate__c, PeriodEndDate__c,
                   StatusPk__c, TotalHoursNumber__c, TotalCurrency__c,
                   TermsTxt__c, DueDateDate__c, SentDateTime__c,
                   PublicTokenTxt__c, MetadataTxt__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        // Resolve recipient: explicit param > entity contact email
        String toEmail = String.isNotBlank(recipientEmail)
            ? recipientEmail.trim()
            : doc.NetworkEntityLookup__r.ContactEmailTxt__c;

        if (String.isBlank(toEmail)) {
            throw new AuraHandledException(
                'No recipient email provided and the entity has no contact email on file.'
            );
        }

        // Generate PDF from Visualforce page
        PageReference pdfPage = Page.DeliveryDocumentPdf;
        pdfPage.getParameters().put('id', String.valueOf(documentId));
        Blob pdfBlob;
        if (!Test.isRunningTest()) {
            pdfBlob = pdfPage.getContentAsPDF();
        } else {
            pdfBlob = Blob.valueOf('test-pdf-content');
        }

        // Build attachment
        String templateDisplay = doc.TemplatePk__c.replace('_', ' ');
        Messaging.EmailFileAttachment att = new Messaging.EmailFileAttachment();
        att.setFileName(doc.Name + ' - ' + templateDisplay + '.pdf');
        att.setContentType('application/pdf');
        att.setBody(pdfBlob);

        // Build email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toEmail });

        // CC from org settings (supports comma-separated list)
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings != null && String.isNotBlank(settings.DocumentCcEmailTxt__c)) {
            List<String> ccAddresses = new List<String>();
            for (String addr : settings.DocumentCcEmailTxt__c.split(',')) {
                String trimmed = addr.trim();
                if (String.isNotBlank(trimmed)) {
                    ccAddresses.add(trimmed);
                }
            }
            if (!ccAddresses.isEmpty()) {
                email.setCcAddresses(ccAddresses);
            }
        }

        // Resolve vendor name for email subject/body
        String vendorName = resolveVendorName();
        email.setSubject(vendorName + ' \u2014 ' + templateDisplay + ' ' + doc.Name);
        email.setHtmlBody(buildDocumentEmailBody(doc, templateDisplay, vendorName));
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ att });
        email.setSaveAsActivity(false);

        // Send
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });

        // Update document status to Sent
        doc.StatusPk__c = 'Sent';
        if (doc.SentDateTime__c == null) {
            doc.SentDateTime__c = Datetime.now();
        }
        if (doc.DueDateDate__c == null && String.isNotBlank(doc.TermsTxt__c)) {
            doc.DueDateDate__c = parseDueDate(doc.TermsTxt__c, Date.today());
        }
        Database.update(doc, AccessLevel.SYSTEM_MODE);

        Map<String, Object> result = new Map<String, Object>();
        result.put('success', true);
        result.put('recipientEmail', toEmail);
        return result;
    }

    /**
     * @description Returns a preview of the email that would be sent for this document.
     * @param documentId The DeliveryDocument__c Id.
     * @param recipientEmail Optional explicit recipient. Falls back to entity contact email.
     * @return Map with keys: toEmail, ccEmail, subject, bodyHtml, attachmentName, documentId, entityName.
     */
    public static Map<String, Object> previewDocumentEmail(Id documentId, String recipientEmail) {
        DeliveryDocument__c doc = [
            SELECT Id, Name, TemplatePk__c, NetworkEntityLookup__r.Name,
                   NetworkEntityLookup__r.ContactEmailTxt__c,
                   PeriodStartDate__c, PeriodEndDate__c,
                   StatusPk__c, TotalHoursNumber__c, TotalCurrency__c,
                   TermsTxt__c, DueDateDate__c, MetadataTxt__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        String toEmail = String.isNotBlank(recipientEmail)
            ? recipientEmail.trim()
            : doc.NetworkEntityLookup__r.ContactEmailTxt__c;

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        String ccEmail = (settings != null) ? settings.DocumentCcEmailTxt__c : null;

        String vendorName = resolveVendorName();
        String templateDisplay = doc.TemplatePk__c.replace('_', ' ');
        String subject = vendorName + ' \u2014 ' + templateDisplay + ' ' + doc.Name;
        String bodyHtml = buildDocumentEmailBody(doc, templateDisplay, vendorName);
        String attachmentName = doc.Name + ' - ' + templateDisplay + '.pdf';

        Map<String, Object> preview = new Map<String, Object>();
        preview.put('toEmail', toEmail != null ? toEmail : '');
        preview.put('ccEmail', ccEmail != null ? ccEmail : '');
        preview.put('subject', subject);
        preview.put('bodyHtml', bodyHtml);
        preview.put('attachmentName', attachmentName);
        preview.put('documentId', documentId);
        preview.put('entityName', doc.NetworkEntityLookup__r != null ? doc.NetworkEntityLookup__r.Name : '');
        return preview;
    }

    /**
     * @description Schedules a document to be automatically emailed at a future date/time.
     * @param documentId The DeliveryDocument__c Id.
     * @param recipientEmail The recipient email to lock in for the scheduled send.
     * @param sendAt The future DateTime when the email should be sent.
     * @return Map with 'success' and 'scheduledSend' keys.
     */
    public static Map<String, Object> scheduleDocumentSend(Id documentId, String recipientEmail, Datetime sendAt) {
        if (sendAt == null || sendAt <= Datetime.now()) {
            throw new AuraHandledException('Scheduled send time must be in the future.');
        }
        if (String.isBlank(recipientEmail)) {
            throw new AuraHandledException('Recipient email is required for scheduled send.');
        }

        DeliveryDocument__c doc = [
            SELECT Id, StatusPk__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        doc.ScheduledSendDateTime__c = sendAt;
        doc.ScheduledRecipientEmailTxt__c = recipientEmail.trim();
        if (doc.StatusPk__c == 'Draft') {
            doc.StatusPk__c = 'Ready';
        }
        Database.update(doc, AccessLevel.SYSTEM_MODE);

        Map<String, Object> result = new Map<String, Object>();
        result.put('success', true);
        result.put('scheduledSend', String.valueOf(sendAt));
        return result;
    }

    /**
     * @description Cancels a previously scheduled document send.
     * @param documentId The DeliveryDocument__c Id.
     * @return Map with 'success' key.
     */
    public static Map<String, Object> cancelScheduledSend(Id documentId) {
        DeliveryDocument__c doc = [
            SELECT Id
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        doc.ScheduledSendDateTime__c = null;
        doc.ScheduledRecipientEmailTxt__c = null;
        Database.update(doc, AccessLevel.SYSTEM_MODE);

        Map<String, Object> result = new Map<String, Object>();
        result.put('success', true);
        return result;
    }

    /**
     * @description Processes all documents whose scheduled send time has passed.
     *              Called by DeliveryHubScheduler every 15 minutes.
     */
    public static void processScheduledDocumentSends() {
        List<DeliveryDocument__c> dueDocs = [
            SELECT Id, ScheduledRecipientEmailTxt__c
            FROM DeliveryDocument__c
            WHERE ScheduledSendDateTime__c <= :Datetime.now()
            AND ScheduledSendDateTime__c != null
            AND SentDateTime__c = null
            WITH SYSTEM_MODE
            LIMIT 50
        ];

        for (DeliveryDocument__c doc : dueDocs) {
            try {
                sendDocumentEmail(doc.Id, doc.ScheduledRecipientEmailTxt__c);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    '[DeliveryDocEmailService] Scheduled send failed for ' + doc.Id + ': ' + e.getMessage());
            }
            // Clear schedule fields regardless of success (sendDocumentEmail already sets Sent on success;
            // on failure we don't want infinite retries — the admin can reschedule manually)
            doc.ScheduledSendDateTime__c = null;
            doc.ScheduledRecipientEmailTxt__c = null;
        }
        if (!dueDocs.isEmpty()) {
            Database.update(dueDocs, AccessLevel.SYSTEM_MODE);
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  HELPERS
    // ═══════════════════════════════════════════════════════════

    /** @description Resolves the vendor display name from the first Vendor/Both NetworkEntity. */
    public static String resolveVendorName() {
        List<NetworkEntity__c> vendors = [
            SELECT Name FROM NetworkEntity__c
            WHERE EntityTypePk__c IN ('Vendor', 'Both')
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC LIMIT 1
        ];
        return vendors.isEmpty() ? 'Delivery Hub' : vendors[0].Name;
    }

    /** @description Builds the HTML email body for a document using the resolved vendor name. */
    @TestVisible
    public static String buildDocumentEmailBody(DeliveryDocument__c doc, String templateDisplay) {
        return buildDocumentEmailBody(doc, templateDisplay, resolveVendorName());
    }

    /** @description Builds the HTML email body for a document with explicit vendor name. */
    @TestVisible
    public static String buildDocumentEmailBody(DeliveryDocument__c doc, String templateDisplay, String vendorName) {
        String entityName = doc.NetworkEntityLookup__r != null ? doc.NetworkEntityLookup__r.Name : '';
        Decimal totalHours = doc.TotalHoursNumber__c != null ? doc.TotalHoursNumber__c : 0;
        Decimal totalCost = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0;

        String body = '<div style="font-family: \'Helvetica Neue\', Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto;">'
            + '<div style="background: #0176d3; padding: 24px 30px; border-radius: 8px 8px 0 0;">'
            + '<h1 style="color: #fff; font-size: 20px; margin: 0;">' + String.valueOf(vendorName).escapeHtml4() + '</h1>'
            + '</div>'
            + '<div style="background: #fff; border: 1px solid #e5e5e5; border-top: none; padding: 30px; border-radius: 0 0 8px 8px;">';

        body += '<h2 style="color: #1a1a2e; font-size: 16px; margin: 0 0 6px;">'
            + templateDisplay + ' ' + String.valueOf(doc.Name).escapeHtml4() + '</h2>'
            + '<p style="color: #706e6b; font-size: 13px; margin: 0 0 20px;">Prepared for '
            + String.valueOf(entityName).escapeHtml4() + '</p>';

        // Parse prior balance from metadata
        Decimal priorBalance = 0;
        Decimal amountDue = totalCost;
        if (String.isNotBlank(doc.MetadataTxt__c)) {
            try {
                Map<String, Object> meta = (Map<String, Object>) JSON.deserializeUntyped(doc.MetadataTxt__c);
                if (meta.containsKey('priorBalance') && meta.get('priorBalance') != null) {
                    priorBalance = ((Decimal) meta.get('priorBalance')).setScale(2);
                }
                if (meta.containsKey('amountDue') && meta.get('amountDue') != null) {
                    amountDue = ((Decimal) meta.get('amountDue')).setScale(2);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, '[DeliveryDocEmailService] Metadata parse error: ' + e.getMessage());
            }
        }

        // Summary
        if (doc.TemplatePk__c != 'Client_Agreement' && doc.TemplatePk__c != 'Contractor_Agreement') {
            body += '<div style="background: #f3f3f5; border-radius: 6px; padding: 16px 20px; margin-bottom: 20px;">'
                + '<table style="width: 100%;"><tr>'
                + '<td style="text-align: center;"><div style="font-size: 11px; color: #706e6b; text-transform: uppercase;">Total Hours</div>'
                + '<div style="font-size: 18px; font-weight: 700; color: #1a1a2e;">' + totalHours.setScale(1) + '</div></td>'
                + '<td style="text-align: center;"><div style="font-size: 11px; color: #706e6b; text-transform: uppercase;">This Invoice</div>'
                + '<div style="font-size: 18px; font-weight: 700; color: #1a1a2e;">$' + totalCost.setScale(2).format() + '</div></td>';
            if (priorBalance > 0) {
                body += '<td style="text-align: center;"><div style="font-size: 11px; color: #706e6b; text-transform: uppercase;">Prior Balance</div>'
                    + '<div style="font-size: 18px; font-weight: 700; color: #c23934;">$' + priorBalance.format() + '</div></td>';
            }
            body += '<td style="text-align: center;"><div style="font-size: 11px; color: #706e6b; text-transform: uppercase;">Amount Due</div>'
                + '<div style="font-size: 18px; font-weight: 700; color: #0176d3;">$' + amountDue.format() + '</div></td>'
                + '</tr></table></div>';
        }

        // Period
        if (doc.PeriodStartDate__c != null && doc.PeriodEndDate__c != null) {
            body += '<p style="font-size: 13px; color: #444;"><strong>Period:</strong> '
                + doc.PeriodStartDate__c.format() + ' \u2013 ' + doc.PeriodEndDate__c.format() + '</p>';
        }

        // Terms
        if (String.isNotBlank(doc.TermsTxt__c)) {
            body += '<p style="font-size: 13px; color: #444;"><strong>Terms:</strong> ' + doc.TermsTxt__c + '</p>';
        }

        // Due date
        if (doc.DueDateDate__c != null) {
            body += '<p style="font-size: 13px; color: #444;"><strong>Due Date:</strong> '
                + doc.DueDateDate__c.format() + '</p>';
        }

        body += '<p style="font-size: 13px; color: #444; margin-top: 20px;">Please find the attached '
            + templateDisplay.toLowerCase() + ' for your review. '
            + 'If you have any questions, please don\'t hesitate to reach out.</p>';

        // Footer
        body += '<hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />'
            + '<p style="font-size: 11px; color: #aaa;">This document was generated by Delivery Hub.</p>'
            + '</div></div>';

        return body;
    }

    /** @description Parses payment terms (e.g. 'Net 30') into a due date relative to fromDate. */
    @TestVisible
    public static Date parseDueDate(String terms, Date fromDate) {
        if (String.isBlank(terms)) {
            return null;
        }
        String lower = terms.toLowerCase().trim();
        if (lower.startsWith('net ')) {
            try {
                Integer days = Integer.valueOf(lower.substringAfter('net ').trim());
                return fromDate.addDays(days);
            } catch (Exception e) {
                return null;
            }
        }
        if (lower == 'due on receipt') {
            return fromDate;
        }
        return null;
    }
}
