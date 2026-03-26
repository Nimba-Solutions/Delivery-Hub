Schema.DescribeFieldResult dfr = delivery__NetworkEntity__c.delivery__StatusPk__c.getDescribe();
List<Schema.PicklistEntry> entries = dfr.getPicklistValues();
System.debug(LoggingLevel.ERROR, 'NetworkEntity StatusPk values (' + entries.size() + '):');
for (Schema.PicklistEntry e : entries) {
    System.debug(LoggingLevel.ERROR, 'PV: ' + e.getValue() + ' Active=' + e.isActive());
}
System.debug(LoggingLevel.ERROR, 'Restricted: ' + dfr.isRestrictedPicklist());
