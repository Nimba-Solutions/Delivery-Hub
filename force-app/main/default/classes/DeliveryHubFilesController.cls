/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Delivery Work Item Files LWC.
 * Returns all files linked to a Work Item and its related Comments and Requests.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryHubFilesController {

    /** @description Represents a single file attachment linked to a work item or its related records. */
    public class FileItem {
        @AuraEnabled public String documentId;
        @AuraEnabled public String title;
        @AuraEnabled public String extension;
        @AuraEnabled public Long fileSize;
        @AuraEnabled public String linkedEntityId;
        @AuraEnabled public String linkedEntityType;
        @AuraEnabled public DateTime lastModifiedDate;
    }

    /**
     * @description Aggregates all ContentDocumentLinks from the work item, its comments, and its requests.
     * Deduplicates by ContentDocumentId so a file shared across multiple records appears once.
     * @param workItemId The WorkItem__c record Id to aggregate files for.
     * @return List of FileItem wrappers with document metadata.
     */
    @AuraEnabled(cacheable=true)
    public static List<FileItem> getWorkItemFiles(Id workItemId) {
        // 1. Collect all entity IDs: work item + comments + requests
        Set<Id> entityIds = new Set<Id>{ workItemId };

        List<WorkItemComment__c> comments = [
            SELECT Id FROM WorkItemComment__c
            WHERE WorkItemId__c = :workItemId
            WITH SYSTEM_MODE
        ];
        for (WorkItemComment__c c : comments) {
            entityIds.add(c.Id);
        }

        List<WorkRequest__c> requests = [
            SELECT Id FROM WorkRequest__c
            WHERE WorkItemId__c = :workItemId
            WITH SYSTEM_MODE
        ];
        for (WorkRequest__c r : requests) {
            entityIds.add(r.Id);
        }

        // 2. Query ContentDocumentLinks for all entity IDs
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId,
                   ContentDocument.Title, ContentDocument.FileExtension,
                   ContentDocument.ContentSize, ContentDocument.LastModifiedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :entityIds
            WITH SYSTEM_MODE
            ORDER BY ContentDocument.LastModifiedDate DESC
        ];

        // 3. Deduplicate by ContentDocumentId (same file might be linked to multiple records)
        Map<Id, FileItem> seen = new Map<Id, FileItem>();
        for (ContentDocumentLink link : links) {
            if (!seen.containsKey(link.ContentDocumentId)) {
                FileItem item = new FileItem();
                item.documentId = link.ContentDocumentId;
                item.title = link.ContentDocument.Title;
                item.extension = link.ContentDocument.FileExtension;
                item.fileSize = link.ContentDocument.ContentSize;
                item.linkedEntityId = link.LinkedEntityId;
                item.linkedEntityType = link.LinkedEntityId.getSObjectType().getDescribe().getLocalName();
                item.lastModifiedDate = link.ContentDocument.LastModifiedDate;
                seen.put(link.ContentDocumentId, item);
            }
        }

        return seen.values();
    }
}
