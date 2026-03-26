List<ListView> views = [
    SELECT Id, Name, DeveloperName, SobjectType
    FROM ListView
    WHERE SobjectType = 'delivery__WorkItem__c'
];
for (ListView lv : views) {
    System.debug(LoggingLevel.ERROR, 'LV: ' + lv.DeveloperName + ' | Name: ' + lv.Name + ' | Type: ' + lv.SobjectType);
}
