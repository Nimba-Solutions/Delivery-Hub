// Delete old draft invoices for At Large so doc gen can create a fresh one
List<delivery__DeliveryDocument__c> docs = [
    SELECT Id, Name, delivery__StatusPk__c
    FROM delivery__DeliveryDocument__c
    WHERE delivery__NetworkEntityId__c = 'a3VRu000002ZPtdMAG'
    AND delivery__StatusPk__c = 'Draft'
];
System.debug('Found ' + docs.size() + ' draft docs to delete');
for (delivery__DeliveryDocument__c d : docs) {
    System.debug('Deleting: ' + d.Name + ' (' + d.Id + ')');
}
delete docs;
System.debug('Done - deleted ' + docs.size() + ' draft docs');
