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
        public Decimal preApprovedHours; 
        public Decimal hourlyRate;
        public String brokerRequestId; 
    }

    /**
     * @description POST: Ingest a new ticket
     */
    @HttpPost
    global static void createTicket() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String jsonBody = req.requestBody.toString();
            InboundPacket packet = (InboundPacket) JSON.deserialize(jsonBody, InboundPacket.class);

            Ticket__c t = new Ticket__c();

            t.WorkItemNameTxt__c = packet.title; 
            t.BriefDescriptionTxt__c = packet.briefSummary;
            t.DetailsTxt__c = packet.detailedContent; 
            t.PriorityPk__c = packet.priority; 
            t.WorkItemTypeTxt__c = packet.type;
            t.ExternalSourceOrgTxt__c = packet.companyName;
            t.SourceEventReplayIdTxt__c = packet.brokerRequestId; 
            t.RequestTypePk__c = 'Partner Request';
            t.StatusPk__c = 'Backlog'; 

            // FIX: Added 'as user' to satisfy CRUD Check
            insert as user t;

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
     * @description GET: Check Status
     */
    @HttpGet
    global static void checkStatus() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        String ticketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);

        try {
            // FIX: Added 'WITH USER_MODE' to satisfy CRUD Check
            Ticket__c t = [SELECT StatusPk__c, TotalLoggedHoursNumber__c 
                           FROM Ticket__c 
                           WHERE Id = :ticketId 
                           WITH USER_MODE
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