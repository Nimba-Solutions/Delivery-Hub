/**
 * @description Outbound service controller to send Ticket__c data to external partners.
 * Designed to be called from LWC or Aura components.
 * @author DeliveryHub Team
 * @date 2026-01-20
 */
public with sharing class DeliveryHubSender {

    // NOTE: In a production environment, it is best practice to move this URL 
    // to a Named Credential to avoid hardcoding.
    private static final String DEFAULT_NIMBUS_URL = 'https://orgfarm-928a77dfd6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/delivery/deliveryhub/v1/intake';

    /**
     * @description Fetches a ticket and POSTs its data to the specified target URL.
     * @param ticketId The Salesforce ID of the Ticket__c record to send.
     * @param targetUrl (Optional) The endpoint URL. Defaults to DEFAULT_NIMBUS_URL if blank.
     * @param senderEmail The email address of the sender to be included in the payload.
     * @return String Returns 'Success' if the callout completes with 200/201.
     * @throws AuraHandledException if the callout fails or permissions are invalid.
     */
    @AuraEnabled
    public static String sendTicketToPartner(Id ticketId, String targetUrl, String senderEmail) {
        try {
            // 1. If no URL provided, use the Nimbus default
            String endpoint = DEFAULT_NIMBUS_URL;

            // 2. Fetch Ticket Data
            // SECURITY FIX: Added 'WITH USER_MODE' to enforce Field Level Security (FLS)
            Ticket__c t = [
                SELECT WorkItemNameTxt__c, BriefDescriptionTxt__c, DetailsTxt__c, 
                       PriorityPk__c, WorkItemTypeTxt__c 
                FROM Ticket__c 
                WHERE Id = :ticketId 
                LIMIT 1
            ];

            // 3. Construct Payload
            Map<String, Object> payload = new Map<String, Object>{
                'title' => t.WorkItemNameTxt__c,
                'briefSummary' => t.BriefDescriptionTxt__c,
                'detailedContent' => t.DetailsTxt__c,
                'priority' => t.PriorityPk__c,
                'type' => t.WorkItemTypeTxt__c,
                'email' => senderEmail,
                'companyName' => UserInfo.getOrganizationName(),
                'orgId' => UserInfo.getOrganizationId()
            };

            // 4. Send Request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payload));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                return 'Success';
            } else {
                // Pass the error message back to the LWC
                throw new CalloutException('Partner returned error: ' + res.getBody());
            }

        } catch (Exception e) {
            // Ensure the error message is visible in the LWC/UI
            String msg = 'Integration Error: ' + e.getMessage();
            AuraHandledException auraEx = new AuraHandledException(msg);
            auraEx.setMessage(msg); // Required to expose message to UI in some contexts
            throw auraEx;
        }
    }
}