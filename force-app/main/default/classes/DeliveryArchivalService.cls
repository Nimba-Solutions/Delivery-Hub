/**
 * @description Service for work item archival, legal hold, and data retention.
 *              Archived items are excluded from board views and sync operations.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryArchivalService {

    public static void archiveRecords(Set<Id> workItemIds) {
        if (workItemIds == null || workItemIds.isEmpty()) {
            return;
        }

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        Integer retentionDays = settings != null && settings.DefaultRetentionDaysNumber__c != null
            ? (Integer) settings.DefaultRetentionDaysNumber__c : 365;

        List<WorkItem__c> items = [
            SELECT Id FROM WorkItem__c WHERE Id IN :workItemIds WITH SYSTEM_MODE
        ];
        for (WorkItem__c wi : items) {
            wi.ArchivalStatusPk__c = 'Archived';
            wi.ArchivedDateTime__c = Datetime.now();
            wi.RetentionExpiresDate__c = Date.today().addDays(retentionDays);
        }
        Database.update(items, AccessLevel.SYSTEM_MODE);
    }

    public static void setLegalHold(Set<Id> workItemIds) {
        if (workItemIds == null || workItemIds.isEmpty()) {
            return;
        }
        List<WorkItem__c> items = [
            SELECT Id FROM WorkItem__c WHERE Id IN :workItemIds WITH SYSTEM_MODE
        ];
        for (WorkItem__c wi : items) {
            wi.ArchivalStatusPk__c = 'Legal_Hold';
            wi.RetentionExpiresDate__c = null;
        }
        Database.update(items, AccessLevel.SYSTEM_MODE);
    }

    public static void releaseLegalHold(Set<Id> workItemIds) {
        if (workItemIds == null || workItemIds.isEmpty()) {
            return;
        }

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        Integer retentionDays = settings != null && settings.DefaultRetentionDaysNumber__c != null
            ? (Integer) settings.DefaultRetentionDaysNumber__c : 365;

        List<WorkItem__c> items = [
            SELECT Id FROM WorkItem__c WHERE Id IN :workItemIds WITH SYSTEM_MODE
        ];
        for (WorkItem__c wi : items) {
            wi.ArchivalStatusPk__c = 'Archived';
            wi.RetentionExpiresDate__c = Date.today().addDays(retentionDays);
        }
        Database.update(items, AccessLevel.SYSTEM_MODE);
    }

    public static String exportArchivedData(Date fromDate, Date toDate) {
        List<WorkItem__c> items = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                   ArchivalStatusPk__c, ArchivedDateTime__c, RetentionExpiresDate__c
            FROM WorkItem__c
            WHERE ArchivalStatusPk__c IN ('Archived', 'Legal_Hold')
            AND ArchivedDateTime__c >= :DateTime.newInstance(fromDate, Time.newInstance(0, 0, 0, 0))
            AND ArchivedDateTime__c < :DateTime.newInstance(toDate.addDays(1), Time.newInstance(0, 0, 0, 0))
            WITH SYSTEM_MODE
            ORDER BY ArchivedDateTime__c ASC
        ];
        return JSON.serialize(items);
    }

    public static void purgeExpiredArchives() {
        List<WorkItem__c> expired = [
            SELECT Id FROM WorkItem__c
            WHERE ArchivalStatusPk__c = 'Archived'
            AND RetentionExpiresDate__c < :Date.today()
            WITH SYSTEM_MODE
            LIMIT 200
        ];
        if (!expired.isEmpty()) {
            Database.delete(expired, AccessLevel.SYSTEM_MODE);
        }
    }
}
