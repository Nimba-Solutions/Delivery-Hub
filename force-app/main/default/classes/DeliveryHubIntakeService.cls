@RestResource(urlMapping='/deliveryhub/v1/intake/*')
global without sharing class DeliveryHubIntakeService {

    global class InboundPacket {
        public String title;
        public String briefSummary;
        public String detailedContent;
        public String email;
        public String companyName;
        public String priority;
        public String type;
    }

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
            t.PriorityPk__c = packet.priority; // Ensure this matches your picklist values
            
            // --- 2. Map New "Lead Gen" Fields (Compliant Names) ---
            t.ExternalRequesterEmailTxt__c = packet.email;
            t.ExternalSourceOrgTxt__c = packet.companyName;
            
            // --- 3. Smart Segmentation Logic ---
            // Default to 'Public Lead' (Unknown installer)
            String requestType = 'Public Lead';
            
            // Check if we already know this person (Simple Domain or Email match)
            if (String.isNotBlank(packet.email)) {
                List<Contact> knownContacts = [SELECT Id, Account.Type FROM Contact WHERE Email = :packet.email LIMIT 1];
                if (!knownContacts.isEmpty()) {
                    // If we know them, upgrade them to Partner Request
                    requestType = 'Partner Request';
                    
                    // Optional: Link to the Account if you add an Account lookup later
                    // t.Account__c = knownContacts[0].AccountId; 
                }
            }
            
            t.RequestTypePk__c = requestType;
            t.StatusPk__c = 'Backlog'; 

            insert t;

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