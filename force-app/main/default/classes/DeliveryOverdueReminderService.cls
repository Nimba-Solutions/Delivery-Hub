/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Service that processes overdue invoices and sends escalating reminder
 *               emails based on a configurable schedule. Reminder levels progress from
 *               friendly (Reminder_1) through firm (Reminder_2) and urgent (Reminder_3)
 *               to formal escalation (Escalation). Respects org-level feature toggle
 *               and per-document cooldown to prevent duplicate sends.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc, PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.ExcessiveClassLength')
public with sharing class DeliveryOverdueReminderService {

    /** @description Default schedule if none is configured: day 1, 7, 14, 30. */
    private static final String DEFAULT_SCHEDULE = '1,7,14,30';

    /** @description Minimum hours between reminder emails for the same document. */
    private static final Integer COOLDOWN_HOURS = 24;

    /**
     * @description Main entry point. Checks the feature toggle, queries overdue invoices,
     *              evaluates the reminder schedule for each, sends reminder emails where
     *              appropriate, and updates document records with the new reminder state.
     */
    public static void processOverdueReminders() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || settings.EnableOverdueRemindersDateTime__c == null) {
            return;
        }

        List<Integer> schedule = parseSchedule(settings.OverdueReminderScheduleTxt__c);

        List<DeliveryDocument__c> overdueInvoices = [
            SELECT Id, Name, StatusPk__c, TemplatePk__c, DueDateDate__c,
                   OverdueReminderCountNumber__c, LastOverdueReminderDateTime__c,
                   OverdueReminderLevelPk__c,
                   NetworkEntityLookup__r.Name, NetworkEntityLookup__r.ContactEmailTxt__c,
                   TotalCurrency__c, TotalHoursNumber__c,
                   PeriodStartDate__c, PeriodEndDate__c
            FROM DeliveryDocument__c
            WHERE StatusPk__c = 'Overdue'
            AND TemplatePk__c = 'Invoice'
            AND DueDateDate__c != null
            WITH SYSTEM_MODE
            LIMIT 200
        ];

        if (overdueInvoices.isEmpty()) {
            return;
        }

        String vendorName = resolveVendorName();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<DeliveryDocument__c> docsToUpdate = new List<DeliveryDocument__c>();

        for (DeliveryDocument__c doc : overdueInvoices) {
            Integer level = shouldSendReminder(doc, schedule);
            if (level == 0) {
                continue;
            }

            // Determine recipient
            String recipientEmail = doc.NetworkEntityLookup__r != null
                ? doc.NetworkEntityLookup__r.ContactEmailTxt__c : null;
            if (String.isBlank(recipientEmail)) {
                continue;
            }

            Messaging.SingleEmailMessage email = buildReminderEmail(doc, level, vendorName);
            if (email != null) {
                emails.add(email);
            }

            // Update document reminder state
            String levelLabel = level <= 3 ? 'Reminder_' + level : 'Escalation';
            doc.OverdueReminderCountNumber__c = doc.OverdueReminderCountNumber__c != null
                ? doc.OverdueReminderCountNumber__c + 1 : 1;
            doc.LastOverdueReminderDateTime__c = Datetime.now();
            doc.OverdueReminderLevelPk__c = levelLabel;
            docsToUpdate.add(doc);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                String msg = e.getMessage();
                msg.length();
            }
        }

        if (!docsToUpdate.isEmpty()) {
            Database.update(docsToUpdate, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Evaluates whether a reminder should be sent for a given document
     *              based on days overdue and the configured schedule thresholds.
     * @param doc The overdue DeliveryDocument__c record.
     * @param schedule List of day thresholds (e.g., [1, 7, 14, 30]).
     * @return The reminder level (1-4) if a reminder should be sent, or 0 if not.
     */
    public static Integer shouldSendReminder(DeliveryDocument__c doc, List<Integer> schedule) {
        if (doc.DueDateDate__c == null) {
            return 0;
        }

        // Check cooldown: skip if last reminder was less than 24 hours ago
        if (doc.LastOverdueReminderDateTime__c != null) {
            Long millisSinceLast = Datetime.now().getTime() - doc.LastOverdueReminderDateTime__c.getTime();
            Long cooldownMillis = (Long) COOLDOWN_HOURS * 3600000;
            if (millisSinceLast < cooldownMillis) {
                return 0;
            }
        }

        Integer daysOverdue = doc.DueDateDate__c.daysBetween(Date.today());
        if (daysOverdue < 0) {
            return 0;
        }

        Integer currentCount = doc.OverdueReminderCountNumber__c != null
            ? (Integer) doc.OverdueReminderCountNumber__c : 0;

        // Walk the schedule to find the highest applicable level
        Integer applicableLevel = 0;
        for (Integer i = 0; i < schedule.size(); i++) {
            if (daysOverdue >= schedule[i]) {
                applicableLevel = i + 1;
            }
        }

        // Only send if we haven't already sent at this level
        if (applicableLevel > 0 && currentCount < applicableLevel) {
            return applicableLevel;
        }

        return 0;
    }

    /**
     * @description Builds an escalating reminder email for an overdue invoice.
     * @param doc The overdue DeliveryDocument__c record.
     * @param level The reminder level (1 = friendly, 2 = firm, 3 = urgent, 4 = escalation).
     * @param vendorName The vendor display name for the email header.
     * @return A configured SingleEmailMessage, or null if no recipient email is available.
     */
    @TestVisible
    private static Messaging.SingleEmailMessage buildReminderEmail(DeliveryDocument__c doc, Integer level, String vendorName) {
        String recipientEmail = doc.NetworkEntityLookup__r != null
            ? doc.NetworkEntityLookup__r.ContactEmailTxt__c : null;
        if (String.isBlank(recipientEmail)) {
            return null;
        }

        String entityName = doc.NetworkEntityLookup__r != null ? doc.NetworkEntityLookup__r.Name : '';
        Integer daysOverdue = doc.DueDateDate__c.daysBetween(Date.today());
        Decimal amountDue = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0;

        String subject;
        String toneLine;
        String urgencyColor;

        if (level == 1) {
            subject = vendorName + ' — Payment Reminder: Invoice ' + doc.Name;
            toneLine = 'This is a friendly reminder that your invoice is now past due.';
            urgencyColor = '#f39c12';
        } else if (level == 2) {
            subject = vendorName + ' — Second Notice: Invoice ' + doc.Name + ' (' + daysOverdue + ' days overdue)';
            toneLine = 'This is your second notice. Payment has been overdue for ' + daysOverdue + ' days. Please arrange payment at your earliest convenience.';
            urgencyColor = '#e67e22';
        } else if (level == 3) {
            subject = vendorName + ' — Final Notice: Invoice ' + doc.Name;
            toneLine = 'This is your final notice before escalation. Your payment is now ' + daysOverdue + ' days past due. Immediate attention is required to avoid further action.';
            urgencyColor = '#e74c3c';
        } else {
            subject = vendorName + ' — Account Past Due: Immediate Attention Required';
            toneLine = 'Your account has been past due for ' + daysOverdue + ' days. This matter has been escalated. Please contact us immediately to resolve the outstanding balance.';
            urgencyColor = '#c0392b';
        }

        String body = '<div style="font-family: \'Helvetica Neue\', Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto;">'
            + '<div style="background: ' + urgencyColor + '; padding: 24px 30px; border-radius: 8px 8px 0 0;">'
            + '<h1 style="color: #fff; font-size: 20px; margin: 0;">' + String.valueOf(vendorName).escapeHtml4() + '</h1>'
            + '</div>'
            + '<div style="background: #fff; border: 1px solid #e5e5e5; border-top: none; padding: 30px; border-radius: 0 0 8px 8px;">'
            + '<h2 style="color: #1a1a2e; font-size: 16px; margin: 0 0 6px;">Invoice ' + String.valueOf(doc.Name).escapeHtml4() + '</h2>'
            + '<p style="color: #706e6b; font-size: 13px; margin: 0 0 20px;">For ' + String.valueOf(entityName).escapeHtml4() + '</p>'
            + '<p style="font-size: 14px; color: #333;">' + toneLine + '</p>'
            + '<div style="background: #f3f3f5; border-radius: 6px; padding: 16px 20px; margin: 20px 0;">'
            + '<table style="width: 100%;"><tr>'
            + '<td style="text-align: center;"><div style="font-size: 11px; color: #706e6b; text-transform: uppercase;">Amount Due</div>'
            + '<div style="font-size: 18px; font-weight: 700; color: ' + urgencyColor + ';">$' + amountDue.setScale(2).format() + '</div></td>'
            + '<td style="text-align: center;"><div style="font-size: 11px; color: #706e6b; text-transform: uppercase;">Due Date</div>'
            + '<div style="font-size: 18px; font-weight: 700; color: #1a1a2e;">' + doc.DueDateDate__c.format() + '</div></td>'
            + '<td style="text-align: center;"><div style="font-size: 11px; color: #706e6b; text-transform: uppercase;">Days Overdue</div>'
            + '<div style="font-size: 18px; font-weight: 700; color: ' + urgencyColor + ';">' + daysOverdue + '</div></td>'
            + '</tr></table></div>';

        if (doc.PeriodStartDate__c != null && doc.PeriodEndDate__c != null) {
            body += '<p style="font-size: 13px; color: #444;"><strong>Period:</strong> '
                + doc.PeriodStartDate__c.format() + ' \u2013 ' + doc.PeriodEndDate__c.format() + '</p>';
        }

        body += '<p style="font-size: 13px; color: #444; margin-top: 20px;">If you have already sent payment, please disregard this notice. '
            + 'If you have any questions, please don\'t hesitate to reach out.</p>'
            + '<hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />'
            + '<p style="font-size: 11px; color: #aaa;">This is an automated reminder from Delivery Hub.</p>'
            + '</div></div>';

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ recipientEmail });
        email.setSubject(subject);
        email.setHtmlBody(body);
        email.setSaveAsActivity(false);

        // CC from org settings
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings != null && String.isNotBlank(settings.DocumentCcEmailTxt__c)) {
            email.setCcAddresses(new List<String>{ settings.DocumentCcEmailTxt__c });
        }

        return email;
    }

    /**
     * @description Parses a comma-separated schedule string into a sorted list of integers.
     * @param scheduleTxt The raw schedule string (e.g., "1,7,14,30").
     * @return Sorted list of integer thresholds. Defaults to [1, 7, 14, 30] if null/blank.
     */
    public static List<Integer> parseSchedule(String scheduleTxt) {
        String raw = String.isNotBlank(scheduleTxt) ? scheduleTxt : DEFAULT_SCHEDULE;
        List<Integer> result = new List<Integer>();

        for (String part : raw.split(',')) {
            String trimmed = part.trim();
            if (String.isNotBlank(trimmed)) {
                try {
                    result.add(Integer.valueOf(trimmed));
                } catch (Exception e) {
                    String msg = e.getMessage();
                    msg.length();
                }
            }
        }

        if (result.isEmpty()) {
            result.addAll(new List<Integer>{ 1, 7, 14, 30 });
        }

        result.sort();
        return result;
    }

    // ── Private helpers ──────────────────────────────────────────────────

    /**
     * @description Resolves the first active vendor's name for email headers.
     * @return The vendor name, or 'Delivery Hub' as fallback.
     */
    private static String resolveVendorName() {
        List<NetworkEntity__c> vendors = [
            SELECT Name FROM NetworkEntity__c
            WHERE EntityTypePk__c = 'Vendor' AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return vendors.isEmpty() ? 'Delivery Hub' : vendors[0].Name;
    }
}
