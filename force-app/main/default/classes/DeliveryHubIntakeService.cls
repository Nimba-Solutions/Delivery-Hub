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
        // NEW: Brokerage Fields
        public Decimal preApprovedHours; 
        public Decimal hourlyRate;
        public String brokerRequestId; // The Mothership's ID for this request
    }

    /**
     * @description POST: Ingest a new ticket (The "Job Offer")
     */
    @HttpPost
    global static void createTicket() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String jsonBody = req.requestBody.toString();
            InboundPacket packet = (InboundPacket) JSON.deserialize(jsonBody, InboundPacket.class);

            Ticket__c t = new Ticket__c();

            // 1. Map Standard Content
            t.WorkItemNameTxt__c = packet.title; 
            t.BriefDescriptionTxt__c = packet.briefSummary;
            t.DetailsTxt__c = packet.detailedContent; 
            t.PriorityPk__c = packet.priority; 
            t.WorkItemTypeTxt__c = packet.type;

            // 2. Map Brokerage Data (The "Contract")
            // We map the Broker's Request ID to our "Source ID" so we can reference it later
            t.ExternalSourceOrgTxt__c = packet.companyName;
            t.SourceEventReplayIdTxt__c = packet.brokerRequestId; 
            
            // If you added "EstimatedHoursNumber__c" to your package, map it here:
            // t.EstimatedHoursNumber__c = packet.preApprovedHours; 

            // 3. Logic: Always 'Partner Request' if it comes via API with a rate
            t.RequestTypePk__c = 'Partner Request';
            t.StatusPk__c = 'Backlog'; 

            insert t;

            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'ticketId' => t.Id,
                'status' => t.StatusPk__c
            }));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage()
            }));
        }
    }

    /**
     * @description GET: Check Status (The "Sync Back")
     * Call this with ?id=THE_TICKET_ID to get live status.
     */
    @HttpGet
    global static void checkStatus() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        // Grab the ID from the URL: /intake/a01...
        String ticketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);

        try {
            Ticket__c t = [SELECT StatusPk__c, TotalLoggedHoursNumber__c 
                           FROM Ticket__c 
                           WHERE Id = :ticketId 
                           LIMIT 1];
                           
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'status' => t.StatusPk__c,
                'hoursLogged' => t.TotalLoggedHoursNumber__c
            }));
        } catch (Exception e) {
            res.statusCode = 404;
        }
    }
}