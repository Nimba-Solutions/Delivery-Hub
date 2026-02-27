/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Service that generates and sends a weekly AI-powered board summary
 *               digest email to configured stakeholders. Combines an AI narrative
 *               (via OpenAI) with concrete metrics: items completed, new items,
 *               attention items, and SLA health. Falls back to a metrics-only
 *               digest when AI is not configured or the callout fails.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class DeliveryWeeklyDigestService {

    /** @description Default day of week when none is configured */
    private static final String DEFAULT_DAY = 'Monday';

    // ── Public entry point ──────────────────────────────────────────────────

    /**
     * @description Main method called by the Queueable. Checks the digest toggle,
     *              gathers metrics, optionally calls the AI, builds the HTML email,
     *              resolves recipients, and sends.
     */
    public static void sendWeeklyDigest() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();

        if (settings == null || settings.WeeklyDigestEnabledBool__c != true) {
            return;
        }

        DigestData data = gatherDigestData(settings);
        String htmlBody = buildDigestHtml(data);
        List<String> recipients = resolveRecipients(settings);

        if (recipients.isEmpty()) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWeeklyDigestService] No recipients resolved — skipping send.');
            return;
        }

        dispatchDigest(recipients, htmlBody);
    }

    /**
     * @description Checks whether today matches the configured digest day.
     * @param settings The org-level DeliveryHubSettings__c record.
     * @return true if today is the configured digest day.
     */
    public static Boolean isTodayDigestDay(DeliveryHubSettings__c settings) {
        if (settings == null || settings.WeeklyDigestEnabledBool__c != true) {
            return false;
        }
        String configuredDay = String.isNotBlank(settings.WeeklyDigestDayTxt__c)
            ? settings.WeeklyDigestDayTxt__c.trim()
            : DEFAULT_DAY;

        String todayName = Datetime.now().format('EEEE');
        return todayName.equalsIgnoreCase(configuredDay);
    }

    // ── Data gathering ──────────────────────────────────────────────────────

    /**
     * @description Wrapper holding all digest data needed to render the email.
     */
    @TestVisible
    private class DigestData {
        @TestVisible String aiSummary;
        @TestVisible Integer completedThisWeek;
        @TestVisible Integer newThisWeek;
        @TestVisible Integer activeItems;
        @TestVisible Integer attentionItems;
        @TestVisible Decimal hoursLogged;
        @TestVisible Map<String, Integer> slaCounts;
        @TestVisible List<AttentionItem> topAttentionItems;
    }

    /**
     * @description Lightweight wrapper for an attention item row.
     */
    @TestVisible
    private class AttentionItem {
        @TestVisible String name;
        @TestVisible String title;
        @TestVisible String stage;
        @TestVisible String priority;
        @TestVisible Integer daysInStage;
    }

    /**
     * @description Gathers all data for the digest: metrics, attention items, SLA counts,
     *              and optionally the AI narrative.
     * @param settings The org-level DeliveryHubSettings__c record.
     * @return DigestData populated with all available data.
     */
    @TestVisible
    private static DigestData gatherDigestData(DeliveryHubSettings__c settings) {
        DigestData data = new DigestData();
        Date weekStart = Date.today().toStartOfWeek();
        Datetime weekStartDt = Datetime.newInstance(weekStart, Time.newInstance(0, 0, 0, 0));

        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');
        Set<String> attentionStages = DeliveryWorkflowConfigService.getAttentionStageValues('Software_Delivery');

        // Items completed this week
        data.completedThisWeek = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE StageNamePk__c IN :terminalStages
            AND LastModifiedDate >= :weekStartDt
            WITH SYSTEM_MODE
        ];

        // New items this week
        data.newThisWeek = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE CreatedDate >= :weekStartDt
            WITH SYSTEM_MODE
        ];

        // Active items
        data.activeItems = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
        ];

        // Attention items count
        data.attentionItems = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE StageNamePk__c IN :attentionStages
            WITH SYSTEM_MODE
        ];

        // Hours logged this week
        AggregateResult[] hoursAgg = [
            SELECT SUM(HoursLoggedNumber__c) total
            FROM WorkLog__c
            WHERE WorkDateDate__c >= :weekStart
            WITH SYSTEM_MODE
        ];
        data.hoursLogged = hoursAgg[0].get('total') != null
            ? (Decimal)hoursAgg[0].get('total') : 0;

        // SLA health counts
        data.slaCounts = new Map<String, Integer>{
            'On Track' => 0, 'At Risk' => 0, 'Breached' => 0, 'Met' => 0
        };
        for (WorkItem__c wi : [
            SELECT SLAStatusTxt__c
            FROM WorkItem__c
            WHERE SLATargetDate__c != NULL
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
        ]) {
            String status = wi.SLAStatusTxt__c;
            if (data.slaCounts.containsKey(status)) {
                data.slaCounts.put(status, data.slaCounts.get(status) + 1);
            }
        }

        // Top attention items (up to 5)
        data.topAttentionItems = new List<AttentionItem>();
        List<WorkItem__c> attRecs = [
            SELECT Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c, LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c IN :attentionStages
            WITH SYSTEM_MODE
            ORDER BY PriorityPk__c ASC, LastModifiedDate ASC
            LIMIT 5
        ];
        for (WorkItem__c wi : attRecs) {
            AttentionItem ai = new AttentionItem();
            ai.name = wi.Name;
            ai.title = String.isNotBlank(wi.BriefDescriptionTxt__c)
                ? wi.BriefDescriptionTxt__c : 'Untitled';
            ai.stage = wi.StageNamePk__c;
            ai.priority = wi.PriorityPk__c;
            ai.daysInStage = wi.LastModifiedDate != null
                ? (Integer)wi.LastModifiedDate.date().daysBetween(Date.today()) : 0;
            data.topAttentionItems.add(ai);
        }

        // AI narrative — attempt only if AI is configured
        data.aiSummary = tryGenerateAiSummary(settings);

        return data;
    }

    /**
     * @description Attempts to call the OpenAI API for a board summary. Returns null
     *              if AI is not configured or the callout fails.
     * @param settings The org settings.
     * @return The AI summary text, or null on failure.
     */
    @TestVisible
    private static String tryGenerateAiSummary(DeliveryHubSettings__c settings) {
        if (settings.AISuggestionsEnabledBool__c != true
            || String.isBlank(settings.OpenAIApiKeyTxt__c)) {
            return null;
        }
        try {
            return DeliveryAiController.draftBoardSummary();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWeeklyDigestService] AI summary failed: ' + e.getMessage());
            return null;
        }
    }

    // ── Recipient resolution ────────────────────────────────────────────────

    /**
     * @description Resolves the list of recipient email addresses.
     *              Uses the configured recipient list if present; otherwise queries
     *              all active users with PermissionSet assignment for Delivery_Hub_User.
     * @param settings The org settings.
     * @return List of email address strings.
     */
    @TestVisible
    private static List<String> resolveRecipients(DeliveryHubSettings__c settings) {
        if (String.isNotBlank(settings.WeeklyDigestRecipientsTxt__c)) {
            return parseEmailList(settings.WeeklyDigestRecipientsTxt__c);
        }
        // Fallback: all active users (limited to 200 to stay within email limits)
        List<String> emails = new List<String>();
        for (User u : [
            SELECT Email
            FROM User
            WHERE IsActive = true
            AND Email != null
            WITH SYSTEM_MODE
            ORDER BY LastName ASC
            LIMIT 200
        ]) {
            emails.add(u.Email);
        }
        return emails;
    }

    /**
     * @description Parses a comma-separated string of email addresses.
     * @param raw The raw comma-separated string.
     * @return List of trimmed, non-blank email addresses.
     */
    private static List<String> parseEmailList(String raw) {
        List<String> result = new List<String>();
        if (String.isBlank(raw)) {
            return result;
        }
        for (String addr : raw.split(',')) {
            String trimmed = addr.trim();
            if (String.isNotBlank(trimmed)) {
                result.add(trimmed);
            }
        }
        return result;
    }

    // ── Email dispatch ──────────────────────────────────────────────────────

    /**
     * @description Builds and sends the digest email.
     * @param recipients List of email addresses.
     * @param htmlBody The rendered HTML body.
     */
    private static void dispatchDigest(List<String> recipients, String htmlBody) {
        String weekOf = Date.today().toStartOfWeek().format();
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(recipients);
        email.setSubject('Delivery Hub Weekly Digest — Week of ' + weekOf);
        email.setHtmlBody(htmlBody);
        email.setSaveAsActivity(false);

        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[DeliveryWeeklyDigestService] Email send failed: ' + e.getMessage());
        }
    }

    // ── HTML builder ────────────────────────────────────────────────────────

    /**
     * @description Builds the full HTML email body from digest data.
     * @param data The populated DigestData instance.
     * @return HTML string for the email body.
     */
    @TestVisible
    private static String buildDigestHtml(DigestData data) {
        String html = '';

        // Wrapper start
        html += '<div style="font-family: \'Salesforce Sans\', Arial, sans-serif; '
             +  'max-width: 640px; margin: 0 auto; color: #181818;">';

        // Header
        html += '<div style="background: linear-gradient(135deg, #0176d3, #032d60); '
             +  'padding: 28px 32px; border-radius: 8px 8px 0 0;">';
        html += '<h1 style="margin: 0; color: #ffffff; font-size: 22px; font-weight: 700;">'
             +  'Delivery Hub Weekly Digest</h1>';
        html += '<p style="margin: 6px 0 0; color: #d4e5f7; font-size: 14px;">'
             +  'Week of ' + Date.today().toStartOfWeek().format() + '</p>';
        html += '</div>';

        // Body container
        html += '<div style="background: #ffffff; padding: 28px 32px; '
             +  'border: 1px solid #e5e5e5; border-top: none;">';

        // AI Summary section
        if (String.isNotBlank(data.aiSummary)) {
            html += '<div style="background: #f3f3f3; padding: 20px; border-radius: 6px; '
                 +  'margin-bottom: 24px; border-left: 4px solid #0176d3;">';
            html += '<h2 style="margin: 0 0 10px; font-size: 16px; color: #032d60;">'
                 +  'Board Summary</h2>';
            html += '<p style="margin: 0; font-size: 14px; line-height: 1.6; color: #444;">'
                 +  String.valueOf(data.aiSummary).escapeHtml4()
                     .replaceAll('\n\n', '</p><p style="margin: 10px 0 0; font-size: 14px; line-height: 1.6; color: #444;">')
                     .replaceAll('\n', '<br/>')
                 +  '</p>';
            html += '</div>';
        }

        // Key Metrics grid
        html += '<h2 style="margin: 0 0 14px; font-size: 16px; color: #032d60;">'
             +  'This Week at a Glance</h2>';
        html += '<table cellpadding="0" cellspacing="0" border="0" width="100%" '
             +  'style="margin-bottom: 24px;">';
        html += '<tr>';
        html += buildMetricCell('Completed', String.valueOf(data.completedThisWeek), '#2e844a');
        html += buildMetricCell('New Items', String.valueOf(data.newThisWeek), '#0176d3');
        html += buildMetricCell('Active', String.valueOf(data.activeItems), '#706e6b');
        html += buildMetricCell('Needs Attention', String.valueOf(data.attentionItems), '#ea001e');
        html += '</tr>';
        html += '</table>';

        // Hours logged
        if (data.hoursLogged != null && data.hoursLogged > 0) {
            html += '<p style="margin: 0 0 20px; font-size: 14px; color: #444;">'
                 +  '<strong>Hours Logged This Week:</strong> '
                 +  data.hoursLogged.setScale(1) + '</p>';
        }

        // SLA Health section
        if (data.slaCounts != null && !data.slaCounts.isEmpty()) {
            Integer totalSla = 0;
            for (Integer v : data.slaCounts.values()) {
                totalSla += v;
            }
            if (totalSla > 0) {
                html += '<h2 style="margin: 0 0 14px; font-size: 16px; color: #032d60;">'
                     +  'SLA Health</h2>';
                html += '<table cellpadding="0" cellspacing="0" border="0" width="100%" '
                     +  'style="margin-bottom: 24px;">';
                html += '<tr>';
                html += buildMetricCell('On Track',
                    String.valueOf(data.slaCounts.get('On Track')), '#2e844a');
                html += buildMetricCell('At Risk',
                    String.valueOf(data.slaCounts.get('At Risk')), '#fe9339');
                html += buildMetricCell('Breached',
                    String.valueOf(data.slaCounts.get('Breached')), '#ea001e');
                html += buildMetricCell('Met',
                    String.valueOf(data.slaCounts.get('Met')), '#0176d3');
                html += '</tr>';
                html += '</table>';
            }
        }

        // Top Attention Items
        if (data.topAttentionItems != null && !data.topAttentionItems.isEmpty()) {
            html += '<h2 style="margin: 0 0 14px; font-size: 16px; color: #032d60;">'
                 +  'Top Items Needing Attention</h2>';
            html += '<table cellpadding="0" cellspacing="0" border="0" width="100%" '
                 +  'style="border-collapse: collapse; margin-bottom: 24px;">';
            html += '<tr style="background: #f3f3f3;">';
            html += '<th style="padding: 8px 12px; text-align: left; font-size: 12px; '
                 +  'color: #706e6b; border-bottom: 1px solid #e5e5e5;">Item</th>';
            html += '<th style="padding: 8px 12px; text-align: left; font-size: 12px; '
                 +  'color: #706e6b; border-bottom: 1px solid #e5e5e5;">Stage</th>';
            html += '<th style="padding: 8px 12px; text-align: left; font-size: 12px; '
                 +  'color: #706e6b; border-bottom: 1px solid #e5e5e5;">Priority</th>';
            html += '<th style="padding: 8px 12px; text-align: right; font-size: 12px; '
                 +  'color: #706e6b; border-bottom: 1px solid #e5e5e5;">Days</th>';
            html += '</tr>';

            for (AttentionItem ai : data.topAttentionItems) {
                html += '<tr>';
                html += '<td style="padding: 8px 12px; font-size: 13px; '
                     +  'border-bottom: 1px solid #f0f0f0;">';
                html += '<strong>' + String.valueOf(ai.name).escapeHtml4() + '</strong> ';
                html += String.valueOf(ai.title).escapeHtml4();
                html += '</td>';
                html += '<td style="padding: 8px 12px; font-size: 13px; '
                     +  'border-bottom: 1px solid #f0f0f0;">'
                     +  String.valueOf(ai.stage).escapeHtml4() + '</td>';
                html += '<td style="padding: 8px 12px; font-size: 13px; '
                     +  'border-bottom: 1px solid #f0f0f0;">'
                     +  (String.isNotBlank(ai.priority) ? String.valueOf(ai.priority).escapeHtml4() : '--') + '</td>';
                html += '<td style="padding: 8px 12px; font-size: 13px; text-align: right; '
                     +  'border-bottom: 1px solid #f0f0f0;">' + ai.daysInStage + '</td>';
                html += '</tr>';
            }
            html += '</table>';
        }

        // Close body container
        html += '</div>';

        // Footer
        html += '<div style="background: #f3f3f3; padding: 18px 32px; '
             +  'border-radius: 0 0 8px 8px; border: 1px solid #e5e5e5; border-top: none;">';
        html += '<p style="margin: 0; font-size: 12px; color: #706e6b; text-align: center;">'
             +  'Powered by Delivery Hub | Cloud Nimbus LLC</p>';
        html += '<p style="margin: 6px 0 0; font-size: 11px; color: #939393; text-align: center;">'
             +  'To stop receiving this digest, ask your admin to disable Weekly Digest in '
             +  'Delivery Hub Settings.</p>';
        html += '</div>';

        // Wrapper end
        html += '</div>';

        return html;
    }

    /**
     * @description Builds a single metric cell for the summary grid.
     * @param label The metric label (e.g. 'Completed').
     * @param value The metric value.
     * @param color The accent color for the value.
     * @return HTML string for a table cell.
     */
    private static String buildMetricCell(String label, String value, String color) {
        return '<td width="25%" style="text-align: center; padding: 12px 8px;">'
             + '<div style="font-size: 28px; font-weight: 700; color: ' + color + ';">'
             + value + '</div>'
             + '<div style="font-size: 12px; color: #706e6b; margin-top: 4px;">'
             + label + '</div>'
             + '</td>';
    }
}
