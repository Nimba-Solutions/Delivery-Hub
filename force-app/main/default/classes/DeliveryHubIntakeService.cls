@RestResource(urlMapping='/deliveryhub/v1/intake/*')
@SuppressWarnings('PMD.ApexCRUDViolation')
global without sharing class DeliveryHubIntakeService {

    /**
     * @description DTO to map the incoming JSON structure from the Client.
     */
    global class InboundPacket {
        public String title;
        public String briefSummary;
        public String detailedContent;
        public String email;
        public String companyName;
        public String priority;
        public String type;
        
        // Critical Identifiers for Smart Linking
        public String orgId;    
        public String entityId;        
        public String instanceUrl;  
        public String registeredBy; 
        
        public Decimal preApprovedHours; 
        public Decimal hourlyRate;
        public String brokerRequestId; 
    }

    /**
     * @description POST: Ingest a new ticket from a Client Org
     */
    @HttpPost
    global static void createTicket() {
        // 1. STOP THE ECHO (Critical)
        SyncEngine.setSyncContext();

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String jsonBody = req.requestBody.toString();
            InboundPacket packet = (InboundPacket) JSON.deserialize(jsonBody, InboundPacket.class);

            Network_Entity__c clientEntity;
            
            // 2. FIND OR CREATE CLIENT ENTITY (Waterfall Logic)
            
            // A. Try matching by Org ID (The Gold Standard - Unique & Immutable)
            if (String.isNotBlank(packet.orgId)) {
                List<Network_Entity__c> byOrgId = [
                    SELECT Id, Name, IntegrationEndpointUrlTxt__c, OrgIdTxt__c 
                    FROM Network_Entity__c 
                    WHERE OrgIdTxt__c = :packet.orgId 
                    LIMIT 1
                ];
                if (!byOrgId.isEmpty()) {
                    clientEntity = byOrgId[0];
                }
            }

            // B. Create New if not found
            if (clientEntity == null) {
                // 1. Generate Timestamp (e.g., " 2026-02-12")
                String timestamp = ' ' + Date.today().format(); 
                
                // 2. Calculate safe length for the Company Name
                Integer maxNameLength = 80 - timestamp.length();
                String truncatedName = packet.companyName;
                
                if (truncatedName.length() > maxNameLength) {
                    truncatedName = truncatedName.substring(0, maxNameLength);
                }

                clientEntity = new Network_Entity__c(
                    Name = truncatedName + timestamp,
                    StatusPk__c = 'Active',
                    EntityTypePk__c = 'Client',
                    OrgIdTxt__c = packet.orgId
                );
            }
            
            // 3. UPDATE & UPSERT (Self-Healing)
            SyncEngine.setSyncContext(); // Reinforce context before DML

            // Ensure the Org ID is stamped (Self-heals legacy records found by Name)
            clientEntity.OrgIdTxt__c = packet.orgId; 
            clientEntity.RemoteExternalIdTxt__c = packet.entityId; 

            if (String.isNotBlank(packet.instanceUrl)) {
                clientEntity.IntegrationEndpointUrlTxt__c = packet.instanceUrl;
            }
            
            // Upsert handles both the Insert (new) and Update (legacy/found) scenarios
            upsert clientEntity; 

            // 4. CREATE THE TICKET
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
            
            // Link to the Entity we found/created
            t.ClientNetworkEntityId__c = clientEntity.Id; 

            // Insert the Ticket (System Mode to avoid sharing rule conflicts)
            insert t;

            // 5. SUCCESS RESPONSE
            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'ticketId' => t.Id,
                'status' => t.StatusPk__c,
                'entityId' => clientEntity.Id,
                'orgId' => UserInfo.getOrganizationId() // Send Mothership Org ID back to Client
            }));

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in DeliveryHubIntakeService: ' + e.getMessage());
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage()
            }));
        }
    }

    /**
     * @description GET: Check Status of a Ticket
     */
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