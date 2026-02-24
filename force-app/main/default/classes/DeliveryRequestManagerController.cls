/**
 * @description Controller for the ManageDeliveryRequest LWC.
 * Aligned with Bidding Architecture. Uses System Mode to ensure 
 * status updates succeed regardless of UI user FLS.
 */
// Changed to without sharing to ensure the process can complete in any org
public without sharing class DeliveryRequestManagerController {
    
    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void sendRequestToVendor(Id requestId) {
        // 1. Fetch the Request using SYSTEM_MODE to ensure availability
        Request__c req = [
            SELECT Id, TicketId__c, StatusPk__c 
            FROM Request__c 
            WHERE Id = :requestId 
            WITH SYSTEM_MODE 
            LIMIT 1
        ];

        // 2. Update status to 'Offer Sent'
        req.StatusPk__c = 'Offer Sent';
        
        // Execute DML in System Mode to bypass FLS restrictions for this specific app action
        Database.update(req, AccessLevel.SYSTEM_MODE);
        
        // 3. "Touch" the parent Ticket to trigger the DeliverySyncEngine push
        if (req.TicketId__c != null) {
            Ticket__c parentTicket = new Ticket__c(Id = req.TicketId__c);
            Database.update(parentTicket, AccessLevel.SYSTEM_MODE);
        }
    }

    @AuraEnabled
    public static String checkRequestStatus(Id requestId) {
        List<Request__c> reqs = [
            SELECT Id, StatusPk__c, RemoteTicketIdTxt__c, LastModifiedDate
            FROM Request__c
            WHERE Id = :requestId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (reqs.isEmpty()) {
            return 'Error: Request not found.';
        }
        Request__c req = reqs[0];
        String info = 'Status: ' + req.StatusPk__c;
        if (String.isNotBlank(req.RemoteTicketIdTxt__c)) {
            info += ' | Remote Ticket ID: ' + req.RemoteTicketIdTxt__c;
        }
        info += ' | Last Updated: ' + req.LastModifiedDate.format();
        return info;
    }
}