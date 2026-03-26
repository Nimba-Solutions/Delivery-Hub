List<delivery__DeliveryDocument__c> docs = [
    SELECT Id, Name, delivery__StatusPk__c, delivery__NetworkEntityId__r.Name, delivery__TotalCurrency__c
    FROM delivery__DeliveryDocument__c
    WHERE delivery__StatusPk__c = 'Draft'
];
System.debug(LoggingLevel.ERROR, 'Found ' + docs.size() + ' draft docs');
for (delivery__DeliveryDocument__c d : docs) {
    System.debug(LoggingLevel.ERROR, d.Name + ' | ' + d.delivery__NetworkEntityId__r.Name + ' | $' + d.delivery__TotalCurrency__c);
}
