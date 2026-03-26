Schema.DescribeFieldResult dfr = delivery__DeliveryDocument__c.delivery__StatusPk__c.getDescribe();
List<Schema.PicklistEntry> entries = dfr.getPicklistValues();
for (Schema.PicklistEntry e : entries) {
    System.debug(LoggingLevel.ERROR, 'PV: ' + e.getValue());
}
System.debug(LoggingLevel.ERROR, 'Restricted: ' + dfr.isRestrictedPicklist());
