/**
 * @description Controller for sending Requests to the Vendor via REST API.
 */
public with sharing class DeliveryHubSender {

    // Default Base URL matches the Setup Controller (Root of the API version)
    private static final String DEFAULT_BASE_URL = 'https://orgfarm-928a77dfd6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/deliveryhub/v1';

    /**
     * @description Sends a Request record to the connected Vendor.
     * @param requestId The ID of the Request record to send.
     * @return String 'Success' or error message.
     */
    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation') 
    public static String sendRequestToVendor(Id requestId) {
        try {
            // Fetch Request Data
            Request__c reqRec = [
                SELECT Id, Name, PreApprovedHoursNumber__c, HourlyRateCurrency__c, 
                       TicketId__r.WorkItemNameTxt__c, TicketId__r.BriefDescriptionTxt__c, 
                       TicketId__r.DetailsTxt__c, TicketId__r.PriorityPk__c, TicketId__r.WorkItemTypeTxt__c,
                       DeliveryEntityId__r.IntegrationEndpointUrlTxt__c, DeliveryEntityId__r.Name
                FROM Request__c 
                WHERE Id = :requestId 
                LIMIT 1
            ];

            // Determine Endpoint
            String baseUrl = reqRec.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
            if (String.isBlank(baseUrl)) {
                baseUrl = DEFAULT_BASE_URL;
            }

            // Append specific resource path
            if (!baseUrl.endsWith('/')) {
                baseUrl += '/';
            }
            String fullEndpoint = baseUrl + 'intake';

            // Construct Payload
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

            // Send Request
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(fullEndpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setBody(JSON.serialize(payload));
            
            Http http = new Http();
            HttpResponse res = http.send(httpReq);
            
            // Handle Response
            if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
                String remoteId;
                try {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    
                    // PMD Fix: Added braces for if/else blocks
                    if (responseMap.containsKey('ticketId')) {
                        remoteId = (String) responseMap.get('ticketId');
                    } else if (responseMap.containsKey('id')) {
                        remoteId = (String) responseMap.get('id');
                    } else if (responseMap.containsKey('brokerRequestId')) {
                        remoteId = (String) responseMap.get('brokerRequestId');
                    }
                } catch(Exception e) {
                    remoteId = res.getBody().replace('"', ''); 
                }
                
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

    /**
     * @description Checks the status of a remote ticket via API.
     * @param requestId The ID of the local Request record.
     * @return String Status message from the remote system.
     */
    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation') 
    public static String checkRequestStatus(Id requestId) {
        try {
            Request__c reqRec = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE Id = :requestId 
                LIMIT 1
            ];

            if (String.isBlank(reqRec.RemoteTicketIdTxt__c)) {
                return 'No Remote ID linked. Have you sent this request yet?';
            }

            String baseUrl = reqRec.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
            if (String.isBlank(baseUrl)) {
                baseUrl = DEFAULT_BASE_URL;
            }

            if (!baseUrl.endsWith('/')) {
                baseUrl += '/';
            }
            // Construct Status URL: .../deliveryhub/v1/intake/REC-123
            String fullEndpoint = baseUrl + 'intake/' + reqRec.RemoteTicketIdTxt__c;

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(fullEndpoint);
            httpReq.setMethod('GET');
            
            Http http = new Http();
            HttpResponse res = http.send(httpReq);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String remoteStatus = (String) responseMap.get('status');
                return 'Remote Status: ' + remoteStatus;
            } else {
                return 'Check Failed: ' + res.getStatusCode() + ' ' + res.getStatus();
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Status Check Error: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
}