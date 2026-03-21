/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for client onboarding. Creates a NetworkEntity record
 *               and generates a Client Agreement document in one step.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryClientOnboardingController {

    /**
     * @description Creates a new client entity and generates a Client Agreement document.
     * @param clientName The client company name.
     * @param contactEmail The primary contact email address.
     * @param hourlyRate The agreed hourly rate.
     * @param contactPhone Optional phone number.
     * @param address Optional mailing address.
     * @return Map with entityId, documentId, documentName, and publicToken keys.
     */
    @AuraEnabled
    public static Map<String, Object> onboardClient(
        String clientName, String contactEmail, Decimal hourlyRate,
        String contactPhone, String address
    ) {
        if (String.isBlank(clientName)) {
            throw new AuraHandledException('Client name is required.');
        }
        if (String.isBlank(contactEmail)) {
            throw new AuraHandledException('Contact email is required.');
        }
        if (hourlyRate == null || hourlyRate <= 0) {
            throw new AuraHandledException('A valid hourly rate is required.');
        }

        // Check for duplicate entity name
        List<NetworkEntity__c> existing = [
            SELECT Id FROM NetworkEntity__c
            WHERE Name = :clientName
            WITH SYSTEM_MODE LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new AuraHandledException('A client named "' + clientName + '" already exists.');
        }

        // Create the NetworkEntity
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = clientName,
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            DefaultHourlyRateCurrency__c = hourlyRate,
            ContactEmailTxt__c = contactEmail
        );
        if (String.isNotBlank(contactPhone)) {
            entity.ContactPhoneTxt__c = contactPhone;
        }
        if (String.isNotBlank(address)) {
            entity.AddressTxt__c = address;
        }
        Database.insert(entity, AccessLevel.SYSTEM_MODE);

        // Generate Client Agreement
        Date today = Date.today();
        Id docId = DeliveryDocumentController.generateDocument(
            entity.Id,
            'Client_Agreement',
            today,
            today.addYears(1),
            null
        );

        DeliveryDocument__c doc = [
            SELECT Name, PublicTokenTxt__c
            FROM DeliveryDocument__c
            WHERE Id = :docId
            WITH SYSTEM_MODE
            LIMIT 1
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
