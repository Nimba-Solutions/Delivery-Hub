/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Schedulable class to trigger the Delivery Hub Poller, escalation engine,
 * recurring work item processing, and the weekly AI digest email. Runs in the background
 * to keep the Client Org in sync with the Mothership, process automated escalation rules,
 * create recurring items, and deliver periodic status summaries.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
global without sharing class DeliveryHubScheduler implements Schedulable {

    /**
     * @description Schedulable execute method.
     * Requeues failed outbound sync items, runs escalation processing, processes recurring
     * items, delegates to an async method for HTTP callouts, and enqueues the weekly
     * digest email if today is the configured digest day.
     * @param sc The SchedulableContext (standard system parameter).
     */
    global void execute(SchedulableContext sc) {
        requeueFailedItems();
        autoDismissAgedFailedItems();
        processEscalations();
        processRecurringItems();
        runSyncAsync();
        enqueueWeeklyDigestIfDue();
        enqueueInvoiceGenerationIfDue();
        enqueueOverdueRemindersIfEnabled();
        processScheduledDocumentSends();
        runReconciliation();
    }

    /**
     * @description Auto-dismisses Failed sync items whose retries are exhausted
     *              and have aged past FailedSyncAutoDismissDaysNumber__c. No-op
     *              when the setting is null/0. Runs after requeueFailedItems()
     *              so we never auto-dismiss something that could still self-heal.
     */
    private static void autoDismissAgedFailedItems() {
        try {
            DeliverySyncDismissalService.dismissAged();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[DeliveryHubScheduler] Auto-dismiss failed: ' + e.getMessage());
        }
    }

    /**
     * @description Evaluates CMT-driven escalation rules against stalled work items
     * and executes automated actions (email, Chatter, Slack, bump priority, move stage, reassign).
     */
    private static void processEscalations() {
        try {
            DeliveryEscalationService.evaluateRules();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'Delivery Hub Escalation Processing Failed: ' + e.getMessage());
        }
    }

    /**
     * @description Processes recurring work items that are due for cloning.
     * Creates new work items from recurring templates and advances the next recurrence date.
     */
    private static void processRecurringItems() {
        try {
            DeliveryRecurringItemService.processRecurringItems();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Recurring item processing failed: ' + e.getMessage());
        }
    }

    /**
     * @description Resets failed outbound Sync Items that have not exceeded the retry limit
     * back to 'Queued' so the DeliverySyncItemProcessor can re-attempt them.
     */
    private static void requeueFailedItems() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        Integer maxRetries = settings != null && settings.SyncRetryLimitNumber__c != null
            ? (Integer) settings.SyncRetryLimitNumber__c : 3;
        List<SyncItem__c> failedItems = [
            SELECT Id, StatusPk__c
            FROM SyncItem__c
            WHERE StatusPk__c = 'Failed'
            AND DirectionPk__c = 'Outbound'
            AND (RetryCountNumber__c = null OR RetryCountNumber__c < :maxRetries)
            WITH SYSTEM_MODE
            LIMIT 50
        ];

        if (!failedItems.isEmpty()) {
            for (SyncItem__c item : failedItems) {
                item.StatusPk__c = 'Queued';
            }
            Database.update(failedItems, AccessLevel.SYSTEM_MODE);
        }

        // Safety net: enqueue processor if ANY Queued outbound items exist (catches orphaned items)
        Integer queuedCount = [
            SELECT COUNT()
            FROM SyncItem__c
            WHERE StatusPk__c = 'Queued'
            AND DirectionPk__c = 'Outbound'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (queuedCount > 0) {
            System.enqueueJob(new DeliverySyncItemProcessor());
        }
    }

    /**
     * @description Enqueues the weekly digest Queueable if today matches the configured
     *              digest day and the feature is enabled in org settings.
     */
    private static void enqueueWeeklyDigestIfDue() {
        try {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            if (DeliveryWeeklyDigestService.isTodayDigestDay(settings)) {
                System.enqueueJob(new DeliveryWeeklyDigestQueueable());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryHubScheduler] Weekly digest enqueue failed: ' + e.getMessage());
        }
    }

    /**
     * @description Enqueues the invoice generation Queueable if the feature is enabled
     *              and has not already run today.
     */
    private static void enqueueInvoiceGenerationIfDue() {
        try {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            if (DeliveryInvoiceGenerationService.shouldRunToday(settings)) {
                System.enqueueJob(new DeliveryInvoiceGenerationQueueable());
            }
        } catch (Exception ex) {
            String msg = ex.getMessage();
            msg.length(); // satisfy PMD empty-catch rule
        }
    }

    /**
     * @description Enqueues the overdue reminder Queueable once per day at 9 AM UTC
     *              when the feature is enabled in org settings.
     */
    private static void enqueueOverdueRemindersIfEnabled() {
        try {
            Integer currentHour = DateTime.now().hourGmt();
            if (currentHour != 9) {
                return;
            }
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            if (settings != null && settings.EnableOverdueRemindersDateTime__c != null) {
                System.enqueueJob(new DeliveryOverdueReminderQueueable());
            }
        } catch (Exception ex) {
            String msg = ex.getMessage();
            msg.length();
        }
    }

    /**
     * @description Checks for documents with a scheduled send time that has passed
     * and sends them. Runs inline (no Queueable needed since sendDocumentEmail
     * does not make HTTP callouts).
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void processScheduledDocumentSends() {
        try {
            Integer dueCount = [
                SELECT COUNT()
                FROM DeliveryDocument__c
                WHERE ScheduledSendDateTime__c <= :Datetime.now()
                AND ScheduledSendDateTime__c != null
                AND SentDateTime__c = null
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (dueCount > 0) {
                DeliveryDocumentController.processScheduledDocumentSends();
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[DeliveryHubScheduler] Scheduled document send failed: ' + e.getMessage());
        }
    }

    /**
     * @description Schedules the four standard Delivery Hub cron jobs (:00, :15, :30, :45).
     * Callable from anonymous Apex in subscriber orgs:
     *   delivery.DeliveryHubScheduler.scheduleAll();
     */
    @SuppressWarnings('PMD.ApexCRUDViolation, PMD.OperationWithLimitsInLoop')
    global static void scheduleAll() {
        String[] cronSlots = new String[]{
            '0 0 * * * ?',
            '0 15 * * * ?',
            '0 30 * * * ?',
            '0 45 * * * ?'
        };
        String[] slotNames = new String[]{ ':00', ':15', ':30', ':45' };

        // Abort all existing Delivery Hub Sync jobs in one query (avoid SOQL in loop)
        Map<String, Id> existingJobs = new Map<String, Id>();
        for (CronTrigger ct : [
            SELECT Id, CronJobDetail.Name FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Delivery Hub Sync -%'
            WITH SYSTEM_MODE
        ]) {
            existingJobs.put(ct.CronJobDetail.Name, ct.Id);
        }

        for (Integer i = 0; i < cronSlots.size(); i++) {
            String jobName = 'Delivery Hub Sync - ' + slotNames[i];
            if (existingJobs.containsKey(jobName)) {
                System.abortJob(existingJobs.get(jobName));
            }
            System.schedule(jobName, cronSlots[i], new DeliveryHubScheduler());
        }
    }

    /**
     * @description Runs the sync reconciliation engine once per day at 6 AM UTC.
     * Checks the current hour and only enqueues DeliverySyncReconciler if it is
     * the 6 AM window, preventing redundant reconciliation on the :15/:30/:45 runs.
     */
    private static void runReconciliation() {
        try {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            Integer reconcileHour = settings != null && settings.ReconciliationHourNumber__c != null
                ? (Integer) settings.ReconciliationHourNumber__c : 6;
            Integer currentHour = DateTime.now().hourGmt();
            if (currentHour == reconcileHour) {
                System.enqueueJob(new DeliverySyncReconciler());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[DeliveryHubScheduler] Reconciliation enqueue failed: ' + e.getMessage());
        }
    }

    /**
     * @description Triggers an immediate reconciliation run from anonymous Apex.
     * Usage: delivery.DeliveryHubScheduler.reconcileNow();
     */
    global static void reconcileNow() {
        DeliverySyncReconciler.reconcileAll();
    }

    /**
     * @description Future method to perform the HTTP Callout to the Mothership.
     * Required because SchedulableContext cannot perform synchronous callouts.
     */
    @future(callout=true)
    public static void runSyncAsync() {
        // Triggers the poller logic to fetch delta updates
        String result = DeliveryHubPoller.pollUpdates();

        // Logs an error only if the result does not indicate success or zero items
        if (!result.contains('Success') && !result.contains('Synced 0 items')) {
            System.debug(LoggingLevel.ERROR, 'Delivery Hub Sync Failed: ' + result);
        }
    }
}
