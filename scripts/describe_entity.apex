Map<String, Schema.SObjectField> fields = NetworkEntity__c.SObjectType.getDescribe().fields.getMap();
for (String fname : fields.keySet()) {
    if (fname.endsWith('__c')) {
        System.debug(LoggingLevel.ERROR, fname);
    }
}
