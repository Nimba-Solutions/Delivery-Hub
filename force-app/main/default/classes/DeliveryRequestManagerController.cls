/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the ManageDeliveryRequest LWC.
 * Aligned with Bidding Architecture. Uses System Mode to ensure 
 * status updates succeed regardless of UI user FLS.
 * @author Cloud Nimbus LLC
 */
// without sharing: Required so vendor request routing, status updates, and SyncItem creation
// succeed regardless of the running user's sharing rules on WorkRequest__c / SyncItem__c.
public without sharing class DeliveryRequestManagerController {
    
    /**
     * @description Sends a work request to the vendor by updating its status to 'Offer Sent'
     * and touching the parent WorkItem__c to trigger the DeliverySyncEngine push.
     * @param requestId The Id of the WorkRequest__c to send
     */
    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void sendRequestToVendor(Id requestId) {
        // 1. Fetch the Request using SYSTEM_MODE to ensure availability
        WorkRequest__c req = [
            SELECT Id, WorkItemId__c, StatusPk__c 
            FROM WorkRequest__c 
            WHERE Id = :requestId 
            WITH SYSTEM_MODE 
            LIMIT 1
        ];

        // 2. Update status to 'Offer Sent'
        req.StatusPk__c = 'Offer Sent';
        
        // Execute DML in System Mode to bypass FLS restrictions for this specific app action
        Database.update(req, AccessLevel.SYSTEM_MODE);
        
        // 3. "Touch" the parent Work Item to trigger the DeliverySyncEngine push
        if (req.WorkItemId__c != null) {
            WorkItem__c parentWorkItem = new WorkItem__c(Id = req.WorkItemId__c);
            Database.update(parentWorkItem, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Checks the current status of a work request and returns a formatted
     * string with the status, remote work item ID (if linked), and last modified date.
     * @param requestId The Id of the WorkRequest__c to check
     * @return String formatted status message or error if not found
     */
    @AuraEnabled
    public static String checkRequestStatus(Id requestId) {
        List<WorkRequest__c> reqs = [
            SELECT Id, StatusPk__c, RemoteWorkItemIdTxt__c, LastModifiedDate
            FROM WorkRequest__c
            WHERE Id = :requestId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (reqs.isEmpty()) {
            return 'Error: Request not found.';
        }
        WorkRequest__c req = reqs[0];
        String info = 'Status: ' + req.StatusPk__c;
        if (String.isNotBlank(req.RemoteWorkItemIdTxt__c)) {
            info += ' | Remote Work Item ID: ' + req.RemoteWorkItemIdTxt__c;
        }
        info += ' | Last Updated: ' + req.LastModifiedDate.format();
        return info;
    }
}