/**
 * @description Service endpoint for external systems to submit delivery tickets.
 * Exposed via REST at /services/apexrest/deliveryhub/v1/intake/
 * @author DeliveryHub Team
 * @date 2026-01-20
 */
@RestResource(urlMapping='/deliveryhub/v1/intake/*')
global without sharing class DeliveryHubIntakeService {

    /**
     * @description DTO to map the incoming JSON structure.
     */
    global class InboundPacket {
        public String title;
        public String briefSummary;
        public String detailedContent;
        public String email;
        public String companyName;
        public String priority;
        public String type;
    }

    /**
     * @description POST method to ingest a new ticket.
     * Maps external data to Ticket__c and attempts to match existing Contacts.
     */
    @HttpPost
    global static void createTicket() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String jsonBody = req.requestBody.toString();
            InboundPacket packet = (InboundPacket) JSON.deserialize(jsonBody, InboundPacket.class);

            Ticket__c t = new Ticket__c();

            // --- 1. Map Standard Fields ---
            t.WorkItemNameTxt__c = packet.title; 
            t.BriefDescriptionTxt__c = packet.briefSummary;
            t.DetailsTxt__c = packet.detailedContent; 
            t.PriorityPk__c = packet.priority; 

            // --- 2. Map New "Lead Gen" Fields ---
            t.ExternalRequesterEmailTxt__c = packet.email;
            t.ExternalSourceOrgTxt__c = packet.companyName;

            // --- 3. Smart Segmentation Logic ---
            String requestType = 'Public Lead';

            // Check if we already know this person
            if (String.isNotBlank(packet.email)) {
                // SECURITY FIX: Added 'WITH USER_MODE' to enforce FLS/CRUD checks on the query
                List<Contact> knownContacts = [
                    SELECT Id, Account.Type 
                    FROM Contact 
                    WHERE Email = :packet.email 
                    WITH USER_MODE
                    LIMIT 1
                ];
                
                if (!knownContacts.isEmpty()) {
                    requestType = 'Partner Request';
                    // Optional: Link to Account logic here
                }
            }

            t.RequestTypePk__c = requestType;
            t.StatusPk__c = 'Backlog'; 

            // SECURITY FIX: Added 'as user' (equivalent to WITH USER_MODE for DML)
            // This ensures the running user has permission to create Ticket__c records.
            insert as user t;

            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'ticketId' => t.Id,
                'status' => requestType
            }));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage()
            }));
        }
    }
}