List<delivery__DeliveryDocument__c> docs = [
    SELECT Id, Name, delivery__StatusPk__c, delivery__TemplatePk__c,
           delivery__NetworkEntityId__r.Name
    FROM delivery__DeliveryDocument__c
    WHERE delivery__TemplatePk__c = 'Client_Agreement'
];
System.debug(LoggingLevel.ERROR, 'Client_Agreement docs: ' + docs.size());
for (delivery__DeliveryDocument__c d : docs) {
    System.debug(LoggingLevel.ERROR, d.Name + ' | Status=' + d.delivery__StatusPk__c + ' | Entity=' + d.delivery__NetworkEntityId__r.Name);
}
