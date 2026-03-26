List<ListView> views = [
    SELECT Id, Name, DeveloperName, SobjectType
    FROM ListView
    WHERE SobjectType IN ('WorkItem__c', 'WorkLog__c')
];
for (ListView lv : views) {
    System.debug(LoggingLevel.ERROR, lv.SobjectType + ' | ' + lv.DeveloperName + ' | ' + lv.Name);
}
System.debug(LoggingLevel.ERROR, 'Total: ' + views.size());
