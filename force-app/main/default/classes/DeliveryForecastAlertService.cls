/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Daily forecast-alert sweep. Walks active root WorkItems
 *              (ParentWorkItemLookup__c = NULL), runs the velocity-based
 *              forecast for each, and dispatches bell + email + Slack alerts
 *              to the WI owner when projectedFinalHours exceeds the configured
 *              threshold (default 110% of EstimatedHoursNumber). Cooldown +
 *              delta-detection guard prevents re-alert spam.
 *
 *              Mirrors DeliveryOverdueReminderService shape — gated by an org
 *              setting DateTime opt-in (EnableForecastAlertsDateTime__c) +
 *              per-recipient channel opt-out via NotificationPreference__c with
 *              EventTypePk='Forecast_Risk'.
 *
 *              Persona routing (root-WI-only):
 *              - Primary recipient: WorkItem.OwnerId (when a User; Jose-class PM persona).
 *              - CC: WorkItem.DeveloperLookup__c if distinct from owner.
 *              - NEVER ClientNetworkEntityLookup — internal risk doesn't go to clients.
 *              - Glen is no recipient; he sees Project_Health_Pills on Home as the
 *                pull surface. This service is the transition push.
 *
 *              Re-alert rule (cooldown):
 *              - Skip if LastForecastAlertDateTime within 7 days AND projected
 *                final hours hasn't worsened by ≥10% from LastForecastAlertProjectedHours.
 *              - Mirrors DeliveryOverdueReminderService.shouldSendReminder pattern.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.OperationWithLimitsInLoop,PMD.ApexCRUDViolation,PMD.NcssMethodCount,PMD.ExcessiveParameterList')
global with sharing class DeliveryForecastAlertService {

    /** @description Default threshold % above which a WI is alertable. */
    @TestVisible
    private static final Decimal DEFAULT_THRESHOLD_PERCENT = 110;

    /** @description Cooldown days between successive alerts for the same WI when projection hasn't materially worsened. */
    @TestVisible
    private static final Integer COOLDOWN_DAYS = 7;

    /** @description Re-alert sooner if projection has worsened by ≥ this fraction since last alert. */
    @TestVisible
    private static final Decimal MATERIAL_WORSENING_FRACTION = 0.10;

    /** @description Cap on the number of WIs the daily sweep evaluates. */
    @TestVisible
    private static final Integer MAX_WORKITEMS_PER_SWEEP = 200;

    /** @description Terminal stages — exclude from sweep. */
    private static final Set<String> TERMINAL_STAGES = new Set<String>{
        'Done', 'Cancelled', 'Closed', 'Rejected'
    };

    /**
     * @description Runs the daily sweep. Called by DeliveryForecastAlertQueueable
     *              (which the scheduler enqueues at 8 GMT once per day).
     * @return Count of WorkItems for which an alert was dispatched.
     */
    global static Integer runSweep() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || settings.EnableForecastAlertsDateTime__c == null) {
            return 0;
        }

        Decimal thresholdPct = settings.ForecastAlertThresholdPercentNumber__c != null
            ? settings.ForecastAlertThresholdPercentNumber__c
            : DEFAULT_THRESHOLD_PERCENT;
        Decimal thresholdRatio = thresholdPct / 100;

        List<WorkItem__c> candidates = [
            SELECT Id, Name, BriefDescriptionTxt__c, OwnerId, DeveloperLookup__c,
                   EstimatedHoursNumber__c, TotalLoggedHoursSum__c,
                   StageNamePk__c, ActivatedDateTime__c,
                   LastForecastAlertDateTime__c, LastForecastAlertProjectedHoursNumber__c
            FROM WorkItem__c
            WHERE ParentWorkItemLookup__c = NULL
              AND ActivatedDateTime__c != NULL
              AND ArchivedDateTime__c = NULL
              AND TemplateMarkedDateTime__c = NULL
              AND StageNamePk__c NOT IN :TERMINAL_STAGES
              AND EstimatedHoursNumber__c != NULL
              AND EstimatedHoursNumber__c > 0
            WITH SYSTEM_MODE
            LIMIT :MAX_WORKITEMS_PER_SWEEP
        ];

        if (candidates.isEmpty()) {
            stampScanComplete(settings);
            return 0;
        }

        List<AlertCandidate> firing = new List<AlertCandidate>();
        for (WorkItem__c wi : candidates) {
            AlertCandidate ac = evaluate(wi, thresholdRatio);
            if (ac != null) {
                firing.add(ac);
            }
        }

        if (firing.isEmpty()) {
            stampScanComplete(settings);
            return 0;
        }

        dispatchAlerts(firing);
        stampWorkItems(firing);
        stampScanComplete(settings);
        return firing.size();
    }

    /**
     * @description Evaluates a single WI. Returns AlertCandidate when it should
     *              alert, null when it shouldn't (under threshold, in cooldown,
     *              or no projection available).
     */
    private static AlertCandidate evaluate(WorkItem__c wi, Decimal thresholdRatio) {
        DeliveryForecastService.ProjectForecast f;
        try {
            f = DeliveryForecastService.calculateProjectForecast(wi.Id);
        } catch (Exception ignored) {
            return null;
        }
        if (f == null || !f.hasEstimate || !f.hasVelocity) {
            return null;
        }
        if (f.projectedFinalHours == null || f.totalEstimatedHours == null
                || f.totalEstimatedHours <= 0) {
            return null;
        }
        Decimal ratio = f.projectedFinalHours / f.totalEstimatedHours;
        if (ratio < thresholdRatio) {
            return null;
        }
        if (inCooldown(wi, f)) {
            return null;
        }
        AlertCandidate ac = new AlertCandidate();
        ac.workItem = wi;
        ac.forecast = f;
        ac.overrunPercent = (ratio * 100 - 100).setScale(1, System.RoundingMode.HALF_UP);
        ac.overrunHours = (f.projectedFinalHours - f.totalEstimatedHours).setScale(2, System.RoundingMode.HALF_UP);
        return ac;
    }

    private static Boolean inCooldown(WorkItem__c wi, DeliveryForecastService.ProjectForecast f) {
        if (wi.LastForecastAlertDateTime__c == null) {
            return false;
        }
        Datetime cooldownExpires = wi.LastForecastAlertDateTime__c.addDays(COOLDOWN_DAYS);
        if (Datetime.now() >= cooldownExpires) {
            return false;
        }
        // Within cooldown — only re-alert when projection has materially worsened.
        if (wi.LastForecastAlertProjectedHoursNumber__c == null
                || wi.LastForecastAlertProjectedHoursNumber__c <= 0) {
            return false;
        }
        Decimal worseningFrac = (f.projectedFinalHours - wi.LastForecastAlertProjectedHoursNumber__c)
            / wi.LastForecastAlertProjectedHoursNumber__c;
        return worseningFrac < MATERIAL_WORSENING_FRACTION;
    }

    /**
     * @description Dispatches the three channels for each alert candidate.
     *              Bell (per-user opt-in), email (per-user opt-out via
     *              NotificationPreference__c), and Slack (org-level webhook).
     */
    private static void dispatchAlerts(List<AlertCandidate> firing) {
        Set<Id> recipientIds = collectRecipients(firing);
        Map<Id, User> userMap = recipientIds.isEmpty() ? new Map<Id, User>() : new Map<Id, User>([
            SELECT Id, Email FROM User
            WHERE Id IN :recipientIds AND IsActive = true
            WITH SYSTEM_MODE
        ]);

        String orgUrl = Url.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Map<String, String> slackMessages = new Map<String, String>();

        for (AlertCandidate ac : firing) {
            WorkItem__c wi = ac.workItem;
            String title = String.isNotBlank(wi.BriefDescriptionTxt__c)
                ? wi.BriefDescriptionTxt__c : wi.Name;
            String recordUrl = orgUrl + '/lightning/r/WorkItem__c/' + wi.Id + '/view';

            String bellTitle = 'Forecast risk: ' + wi.Name;
            String bellBody = 'Projected ' + ac.overrunPercent + '% over scope ('
                + ac.overrunHours + 'h overrun) at current velocity. Tap to review.';

            for (Id recipientId : routeRecipients(wi)) {
                if (!userMap.containsKey(recipientId)) {
                    continue;
                }
                if (shouldNotifyChannel(recipientId, 'Bell')) {
                    DeliveryEscalationNotifService.sendBellNotification(
                        wi.Id, recipientId, bellTitle, bellBody);
                }
                if (shouldNotifyChannel(recipientId, 'Email')) {
                    String addr = userMap.get(recipientId).Email;
                    if (String.isNotBlank(addr)) {
                        emails.add(buildForecastEmail(wi, ac, addr, recordUrl, title));
                    }
                }
            }
            slackMessages.put(wi.Name, title + ' · projected ' + ac.overrunPercent
                + '% over scope (+' + ac.overrunHours + 'h) · ' + recordUrl);
        }

        if (!emails.isEmpty() && emailGloballyEnabled()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    '[DeliveryForecastAlertService] email send failed: ' + e.getMessage());
            }
        }
        sendForecastSlack(slackMessages);
    }

    private static Boolean emailGloballyEnabled() {
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
        if (s == null) {
            return false;
        }
        Schema.DescribeSObjectResult dsr = DeliveryHubSettings__c.SObjectType.getDescribe();
        if (!dsr.fields.getMap().containsKey('EnableEmailNotificationsDateTime__c')) {
            return true;
        }
        Object v = s.get('EnableEmailNotificationsDateTime__c');
        return v != null;
    }

    private static List<Id> routeRecipients(WorkItem__c wi) {
        List<Id> out = new List<Id>();
        Set<Id> seen = new Set<Id>();
        if (wi.OwnerId != null && String.valueOf(wi.OwnerId).startsWith('005')) {
            out.add(wi.OwnerId);
            seen.add(wi.OwnerId);
        }
        if (wi.DeveloperLookup__c != null && !seen.contains(wi.DeveloperLookup__c)) {
            out.add(wi.DeveloperLookup__c);
        }
        return out;
    }

    private static Set<Id> collectRecipients(List<AlertCandidate> firing) {
        Set<Id> ids = new Set<Id>();
        for (AlertCandidate ac : firing) {
            for (Id r : routeRecipients(ac.workItem)) {
                ids.add(r);
            }
        }
        return ids;
    }

    /**
     * @description Delegates to DeliveryNotificationPreferenceService.shouldNotify.
     *              Honors per-user, per-channel opt-out for Forecast_Risk event type.
     *              No row in NotificationPreference__c = opt-in by default.
     */
    private static Boolean shouldNotifyChannel(Id userId, String channel) {
        try {
            return DeliveryNotificationPreferenceService.shouldNotify(userId, channel, 'Forecast_Risk');
        } catch (Exception ignored) {
            return true;
        }
    }

    private static Messaging.SingleEmailMessage buildForecastEmail(
            WorkItem__c wi, AlertCandidate ac, String toAddress,
            String recordUrl, String title) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toAddress });
        email.setSubject('Delivery Hub Forecast Risk: ' + wi.Name
            + ' projected ' + ac.overrunPercent + '% over scope');
        email.setHtmlBody(buildForecastHtml(wi.Name, title, ac, recordUrl));
        email.setSaveAsActivity(false);
        return email;
    }

    private static String buildForecastHtml(String wiName, String title,
            AlertCandidate ac, String recordUrl) {
        return '<div style="font-family: Arial, sans-serif; max-width: 600px;">'
            + '<h2 style="color: #b91c1c; margin: 0 0 16px;">Forecast Risk: ' + escape(wiName) + '</h2>'
            + '<p style="font-size: 14px; color: #374151;">'
            + '<strong>' + escape(title) + '</strong> is trending past scope at current velocity.</p>'
            + '<table style="border-collapse: collapse; width: 100%; font-size: 13px; margin: 12px 0;">'
            + row('Estimated hours', String.valueOf(ac.forecast.totalEstimatedHours))
            + row('Logged hours', String.valueOf(ac.forecast.totalLoggedHours))
            + row('Projected final', String.valueOf(ac.forecast.projectedFinalHours)
                + ' (' + ac.overrunPercent + '% over)')
            + row('Velocity', String.valueOf(ac.forecast.currentVelocityHoursPerWeek) + 'h/wk')
            + row('Projected completion', String.valueOf(ac.forecast.projectedCompletionDate))
            + '</table>'
            + '<p style="margin-top: 20px;">'
            + '<a href="' + recordUrl + '" style="background:#7c3aed;color:#fff;padding:8px 16px;'
            + 'border-radius:6px;text-decoration:none;font-weight:500;">Open WorkItem</a></p>'
            + '<p style="font-size: 11px; color: #9ca3af; margin-top: 24px;">'
            + 'You are receiving this because your team has Forecast Alerts enabled. '
            + 'Adjust notification preferences in Delivery Hub Settings.</p></div>';
    }

    private static String row(String label, String value) {
        return '<tr><td style="border:1px solid #e5e7eb;padding:6px 10px;color:#6b7280;">' + escape(label)
            + '</td><td style="border:1px solid #e5e7eb;padding:6px 10px;color:#111827;font-weight:500;">'
            + escape(value) + '</td></tr>';
    }

    private static String escape(String s) {
        if (s == null) {
            return '';
        }
        return s.escapeHtml4();
    }

    /**
     * @description Posts forecast-risk Slack messages when the org has a webhook
     *              configured. Mirrors DeliveryEscalationNotifService.sendEscalationSlack.
     */
    private static void sendForecastSlack(Map<String, String> workItemNameToMessage) {
        if (workItemNameToMessage.isEmpty()) {
            return;
        }
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.SlackWebhookUrlTxt__c)) {
            return;
        }
        try {
            DeliverySlackService.postStageChanges(workItemNameToMessage);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryForecastAlertService] Slack post failed: ' + e.getMessage());
        }
    }

    private static void stampWorkItems(List<AlertCandidate> firing) {
        List<WorkItem__c> updates = new List<WorkItem__c>();
        Datetime now = Datetime.now();
        for (AlertCandidate ac : firing) {
            updates.add(new WorkItem__c(
                Id = ac.workItem.Id,
                LastForecastAlertDateTime__c = now,
                LastForecastAlertProjectedHoursNumber__c = ac.forecast.projectedFinalHours
            ));
        }
        try {
            Database.update(updates, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryForecastAlertService] WI stamp failed: ' + e.getMessage());
        }
    }

    private static void stampScanComplete(DeliveryHubSettings__c settings) {
        try {
            settings.LastForecastAlertScanDate__c = Date.today();
            Database.update(settings, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryForecastAlertService] settings stamp failed: ' + e.getMessage());
        }
    }

    /** @description One firing-candidate row passed between evaluate and dispatch. */
    @TestVisible
    private class AlertCandidate {
        WorkItem__c workItem;
        DeliveryForecastService.ProjectForecast forecast;
        Decimal overrunPercent;
        Decimal overrunHours;
    }
}
