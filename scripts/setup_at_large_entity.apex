// Creates the At Large NetworkEntity for invoice generation
// Run in: Dev Hub or Nimba Sandbox (via Execute Anonymous)
// This entity represents Glen's billing client for the Document Engine.

NetworkEntity__c atLarge = new NetworkEntity__c(
    Name = 'At Large',
    EntityTypePk__c = 'Client',
    StatusPk__c = 'Active',
    DefaultHourlyRateCurrency__c = 90,
    ContactEmailTxt__c = 'danny@atlarge.com',
    AddressTxt__c = 'At Large'
);

// Check if it already exists
List<NetworkEntity__c> existing = [
    SELECT Id FROM NetworkEntity__c
    WHERE Name = 'At Large'
    WITH SYSTEM_MODE LIMIT 1
];

if (existing.isEmpty()) {
    Database.insert(atLarge, AccessLevel.SYSTEM_MODE);
    System.debug('Created At Large entity: ' + atLarge.Id);
} else {
    System.debug('At Large entity already exists: ' + existing[0].Id);
}
