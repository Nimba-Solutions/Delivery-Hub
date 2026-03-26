List<delivery__DocumentTemplate__mdt> templates = [
    SELECT DeveloperName, delivery__TemplatePk__c, delivery__IsActiveBool__c
    FROM delivery__DocumentTemplate__mdt
];
System.debug(LoggingLevel.ERROR, 'Templates found: ' + templates.size());
for (delivery__DocumentTemplate__mdt t : templates) {
    System.debug(LoggingLevel.ERROR, t.DeveloperName + ' | Type=' + t.delivery__TemplatePk__c + ' | Active=' + t.delivery__IsActiveBool__c);
}
