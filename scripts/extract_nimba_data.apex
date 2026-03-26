Integer entities = [SELECT COUNT() FROM delivery__NetworkEntity__c];
Integer items = [SELECT COUNT() FROM delivery__WorkItem__c];
Integer logs = [SELECT COUNT() FROM delivery__WorkLog__c];
Integer requests = [SELECT COUNT() FROM delivery__WorkRequest__c];
Integer docs = [SELECT COUNT() FROM delivery__DeliveryDocument__c];
Integer syncs = [SELECT COUNT() FROM delivery__SyncItem__c];
Integer comments = [SELECT COUNT() FROM delivery__WorkItemComment__c];
Integer actLogs = [SELECT COUNT() FROM delivery__ActivityLog__c];

System.debug(LoggingLevel.ERROR, 'NetworkEntity: ' + entities);
System.debug(LoggingLevel.ERROR, 'WorkItem: ' + items);
System.debug(LoggingLevel.ERROR, 'WorkLog: ' + logs);
System.debug(LoggingLevel.ERROR, 'WorkRequest: ' + requests);
System.debug(LoggingLevel.ERROR, 'DeliveryDocument: ' + docs);
System.debug(LoggingLevel.ERROR, 'SyncItem: ' + syncs);
System.debug(LoggingLevel.ERROR, 'WorkItemComment: ' + comments);
System.debug(LoggingLevel.ERROR, 'ActivityLog: ' + actLogs);
