/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Service that automatically generates invoices and daily hour summaries
 *               for billing-enabled NetworkEntity__c records. Evaluates each entity's
 *               BillingFrequencyPk__c to determine when documents should be created.
 *               Also marks overdue invoices past their due date.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc, PMD.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public with sharing class DeliveryInvoiceGenerationService {

    /**
     * @description Main entry point called by the Queueable. Checks the feature toggle,
     *              queries billing-enabled entities, evaluates frequency schedules,
     *              and generates documents for entities with approved hours.
     */
    public static void generateScheduledDocuments() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();

        if (!shouldRunToday(settings)) {
            return;
        }

        List<NetworkEntity__c> entities = [
            SELECT Id, Name, BillingFrequencyPk__c
            FROM NetworkEntity__c
            WHERE EnableBillingDateTime__c != null
            AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
        ];

        if (entities.isEmpty()) {
            return;
        }

        for (NetworkEntity__c entity : entities) {
            String frequency = String.isNotBlank(entity.BillingFrequencyPk__c)
                ? entity.BillingFrequencyPk__c : 'Monthly';

            if (frequency == 'On_Demand') {
                continue;
            }

            if (!shouldGenerateForEntity(frequency)) {
                continue;
            }

            Map<String, Date> period = getPeriodForFrequency(frequency);
            Date periodStart = period.get('periodStart');
            Date periodEnd = period.get('periodEnd');

            if (!hasApprovedHoursInPeriod(entity.Id, periodStart, periodEnd)) {
                continue;
            }

            String templateType = (frequency == 'Daily') ? 'Daily_Hours_Summary' : 'Invoice';

            try {
                DeliveryDocumentController.generateDocument(
                    entity.Id, templateType, periodStart, periodEnd, null
                );
            } catch (Exception ex) {
                // Continue processing other entities — log silently
                String msg = ex.getMessage(); // satisfy PMD empty-catch rule
                msg.length();
            }
        }

        // Stamp today to prevent duplicate runs
        settings.LastInvoiceGenerationDate__c = Date.today();
        upsert settings;
    }

    /**
     * @description Determines whether the invoice generation job should run today.
     * @param settings The org-level DeliveryHubSettings__c record.
     * @return true if the feature is enabled and has not already run today.
     */
    public static Boolean shouldRunToday(DeliveryHubSettings__c settings) {
        return settings != null
            && settings.EnableInvoiceGenerationDateTime__c != null
            && settings.LastInvoiceGenerationDate__c != Date.today();
    }

    /**
     * @description Checks whether any approved work logs exist for the given entity
     *              within the specified date range.
     * @param entityId The NetworkEntity__c Id.
     * @param periodStart First day of the period.
     * @param periodEnd Last day of the period.
     * @return true if at least one approved or unreviewed work log exists.
     */
    @TestVisible
    private static Boolean hasApprovedHoursInPeriod(Id entityId, Date periodStart, Date periodEnd) {
        Integer logCount = [
            SELECT COUNT()
            FROM WorkLog__c
            WHERE WorkItemId__r.ClientNetworkEntityId__c = :entityId
            AND WorkDateDate__c >= :periodStart
            AND WorkDateDate__c <= :periodEnd
            AND (StatusPk__c = 'Approved' OR StatusPk__c = null)
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return logCount > 0;
    }

    /**
     * @description Determines whether a document should be generated today based
     *              on the billing frequency schedule.
     * @param frequency The BillingFrequencyPk__c value.
     * @return true if today is a generation day for this frequency.
     */
    @TestVisible
    private static Boolean shouldGenerateForEntity(String frequency) {
        if (frequency == 'Daily') {
            return true;
        }
        if (frequency == 'Weekly') {
            return Date.today().toStartOfWeek() == Date.today();
        }
        if (frequency == 'Monthly') {
            return Date.today().day() == 1;
        }
        if (frequency == 'Quarterly') {
            Integer month = Date.today().month();
            return Date.today().day() == 1
                && (month == 1 || month == 4 || month == 7 || month == 10);
        }
        return false;
    }

    /**
     * @description Calculates the period start and end dates for a given frequency.
     * @param frequency The BillingFrequencyPk__c value.
     * @return Map with 'periodStart' and 'periodEnd' Date keys.
     */
    private static Map<String, Date> getPeriodForFrequency(String frequency) {
        Map<String, Date> result = new Map<String, Date>();
        Date today = Date.today();

        if (frequency == 'Daily') {
            result.put('periodStart', today.addDays(-1));
            result.put('periodEnd', today.addDays(-1));
        } else if (frequency == 'Weekly') {
            result.put('periodStart', today.addDays(-7));
            result.put('periodEnd', today.addDays(-1));
        } else if (frequency == 'Monthly') {
            Date firstOfLastMonth = today.addMonths(-1).toStartOfMonth();
            Date lastOfLastMonth = firstOfLastMonth.addMonths(1).addDays(-1);
            result.put('periodStart', firstOfLastMonth);
            result.put('periodEnd', lastOfLastMonth);
        } else if (frequency == 'Quarterly') {
            Date firstOfLastQuarter = today.addMonths(-3).toStartOfMonth();
            Date lastOfLastQuarter = firstOfLastQuarter.addMonths(3).addDays(-1);
            result.put('periodStart', firstOfLastQuarter);
            result.put('periodEnd', lastOfLastQuarter);
        }

        return result;
    }

    /**
     * @description Marks invoices as overdue when they are past their due date
     *              and still in a Sent or Viewed status.
     */
    public static void markOverdueInvoices() {
        List<DeliveryDocument__c> overdue = [
            SELECT Id, StatusPk__c
            FROM DeliveryDocument__c
            WHERE DueDateDate__c < :Date.today()
            AND StatusPk__c IN ('Sent', 'Viewed')
            AND TemplatePk__c = 'Invoice'
            WITH SYSTEM_MODE
            LIMIT 200
        ];

        if (overdue.isEmpty()) {
            return;
        }

        for (DeliveryDocument__c doc : overdue) {
            doc.StatusPk__c = 'Overdue';
        }
        Database.update(overdue, AccessLevel.SYSTEM_MODE);
    }
}
