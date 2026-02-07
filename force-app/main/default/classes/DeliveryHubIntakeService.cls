@RestResource(urlMapping='/deliveryhub/v1/intake/*')
global without sharing class DeliveryHubIntakeService {

    global class InboundPacket {
        public String title;
        public String briefSummary;
        public String detailedContent;
        public String email;
        public String companyName;     // Used as the "API Key" / Identifier
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

            // 2. FIND OR CREATE THE CLIENT ENTITY (The "Who are you?" Check)
            // We use the Company Name as the unique identifier for now.
            Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
            Network_Entity__c clientEntity;
            
            List<Network_Entity__c> existingEntities = [
                SELECT Id, Name FROM Network_Entity__c 
                WHERE Name = :packet.companyName 
                LIMIT 1
            ];

            if (!existingEntities.isEmpty()) {
                clientEntity = existingEntities[0];
            } else {
                // Auto-Onboard the new Client
                clientEntity = new Network_Entity__c(
                    Name = packet.companyName,
                    StatusPk__c = 'Active',
                    TypePk__c = 'Client' // Ensure you have this picklist value
                );
                insert as user clientEntity;
                System.debug('Auto-onboarded new Client Entity: ' + clientEntity.Name);
            }

            // 3. CREATE THE TICKET (Linked to Entity)
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
            
            // LINK IT! This enables the "Segregated Pull" later.
            // Assuming you have a lookup field 'Network_Entity__c' on Ticket__c.
            // If not, create it or use a generic parent field.
            t.Network_Entity__c = clientEntity.Id; 

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

    /**
     * @description GET: Check Status OR Pull New Tickets
     * Enhanced to support checking by Org Name (Security Filter)
     */
    @HttpGet
    global static void checkStatus() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        // Supports: /intake/{TicketID}  OR  /intake/?org={OrgName}&since={Timestamp}
        String ticketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
        String orgFilter = req.params.get('org');

        try {
            if (String.isNotBlank(orgFilter)) {
                // === BULK PULL (Segregated by Entity) ===
                // This allows the Client to ask "What's new for ME?"
                // Without this filter, they would see everyone's tickets.
                
                List<Ticket__c> updates = [
                    SELECT Id, WorkItemNameTxt__c, StatusPk__c, TotalLoggedHoursNumber__c 
                    FROM Ticket__c 
                    WHERE Network_Entity__r.Name = :orgFilter 
                    AND LastModifiedDate >= :DateTime.now().addDays(-1) // Example time filter
                    LIMIT 50
                ];
                
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(updates));

            } else {
                // === SINGLE STATUS CHECK ===
                Ticket__c t = [SELECT StatusPk__c, TotalLoggedHoursNumber__c, Network_Entity__c 
                               FROM Ticket__c 
                               WHERE Id = :ticketId 
                               WITH USER_MODE
                               LIMIT 1];
                               
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'status' => t.StatusPk__c,
                    'hoursLogged' => t.TotalLoggedHoursNumber__c
                }));
            }
        } catch (Exception e) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf('Not Found');
        }
    }
}