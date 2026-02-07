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
        public Decimal preApprovedHours; 
        public Decimal hourlyRate;
        public String brokerRequestId; 
    }

    @HttpPost
    global static void createTicket() {
        // 1. STOP THE ECHO (Critical)
        SyncEngine.setSyncContext();

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String jsonBody = req.requestBody.toString();
            InboundPacket packet = (InboundPacket) JSON.deserialize(jsonBody, InboundPacket.class);

            // 2. FIND OR CREATE CLIENT ENTITY
            Network_Entity__c clientEntity;
            List<Network_Entity__c> existingEntities = [
                SELECT Id, Name FROM Network_Entity__c 
                WHERE Name = :packet.companyName 
                LIMIT 1
            ];

            if (!existingEntities.isEmpty()) {
                clientEntity = existingEntities[0];
            } else {
                clientEntity = new Network_Entity__c(
                    Name = packet.companyName,
                    StatusPk__c = 'Active',
                    // FIX: Changed TypePk__c to EntityTypePk__c to match your schema
                    EntityTypePk__c = 'Client' 
                );
                insert as user clientEntity;
            }

            // 3. CREATE TICKET
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
            
            // FIX: Commented out until you create the Lookup field on Ticket__c
            // t.Network_Entity__c = clientEntity.Id; 

            insert as user t;

            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'ticketId' => t.Id,
                'status' => t.StatusPk__c,
                'entityId' => clientEntity.Id 
            }));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage()
            }));
        }
    }

    @HttpGet
    global static void checkStatus() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String ticketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);

        try {
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