/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for client onboarding. Creates a NetworkEntity record
 *               and generates a Client Agreement document in one step.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryClientOnboardingController {

    /**
     * @description Wrapper for client onboarding parameters to avoid excessive parameter lists.
     */
    public class OnboardingRequest {
        /** @description The client company name. */
        @AuraEnabled public String clientName;
        /** @description The primary contact email address. */
        @AuraEnabled public String contactEmail;
        /** @description The agreed hourly rate. */
        @AuraEnabled public Decimal hourlyRate;
        /** @description Optional phone number. */
        @AuraEnabled public String contactPhone;
        /** @description Optional mailing address. */
        @AuraEnabled public String address;
    }

    /**
     * @description Creates a new client entity and generates a Client Agreement document.
     * @param request The onboarding request containing client details.
     * @return Map with entityId, documentId, documentName, and publicToken keys.
     */
    @AuraEnabled
    public static Map<String, Object> onboardClient(OnboardingRequest request) {
        validateRequest(request);
        NetworkEntity__c entity = createEntity(request);
        return generateAgreement(entity);
    }

    @SuppressWarnings('PMD.CyclomaticComplexity')
    private static void validateRequest(OnboardingRequest request) {
        if (String.isBlank(request.clientName)) {
            throw new AuraHandledException('Client name is required.');
        }
        if (String.isBlank(request.contactEmail)) {
            throw new AuraHandledException('Contact email is required.');
        }
        if (request.hourlyRate == null || request.hourlyRate <= 0) {
            throw new AuraHandledException('A valid hourly rate is required.');
        }
        List<NetworkEntity__c> existing = [
            SELECT Id FROM NetworkEntity__c
            WHERE Name = :request.clientName
            WITH SYSTEM_MODE LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new AuraHandledException('A client named "' + request.clientName + '" already exists.');
        }
    }

    private static NetworkEntity__c createEntity(OnboardingRequest request) {
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = request.clientName,
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            DefaultHourlyRateCurrency__c = request.hourlyRate,
            ContactEmailTxt__c = request.contactEmail
        );
        if (String.isNotBlank(request.contactPhone)) {
            entity.ContactPhoneTxt__c = request.contactPhone;
        }
        if (String.isNotBlank(request.address)) {
            entity.AddressTxt__c = request.address;
        }
        Database.insert(entity, AccessLevel.SYSTEM_MODE);
        return entity;
    }

    private static Map<String, Object> generateAgreement(NetworkEntity__c entity) {
        Date today = Date.today();
        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id, 'Client_Agreement', today, today.addYears(1), null
        );
        DeliveryDocument__c doc = [
            SELECT Name, PublicTokenTxt__c
            FROM DeliveryDocument__c WHERE Id = :docId
            WITH SYSTEM_MODE LIMIT 1
        ];
        Map<String, Object> result = new Map<String, Object>();
        result.put('entityId', entity.Id);
        result.put('documentId', docId);
        result.put('documentName', doc.Name);
        result.put('publicToken', doc.PublicTokenTxt__c);
        return result;
    }

    /**
     * @description Returns a list of active client entities for the onboarding
     *              component to check existing clients.
     * @return List of maps with id and name keys.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getExistingClients() {
        List<Map<String, String>> clients = new List<Map<String, String>>();
        for (NetworkEntity__c ne : [
            SELECT Id, Name
            FROM NetworkEntity__c
            WHERE EntityTypePk__c IN ('Client', 'Both')
            AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            ORDER BY Name
        ]) {
            Map<String, String> m = new Map<String, String>();
            m.put('id', ne.Id);
            m.put('name', ne.Name);
            clients.add(m);
        }
        return clients;
    }
}
