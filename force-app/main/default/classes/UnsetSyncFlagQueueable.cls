public class UnsetSyncFlagQueueable implements Queueable {
    public void execute(QueueableContext context) {
        try {
            Sync_In_Propgress__c setting = Sync_In_Propgress__c.getOrgDefaults();
            if (setting != null && setting.SalesforceToJiraBool__c == true) {
                setting.SalesforceToJiraBool__c = false;
                upsert setting;
                System.debug('Salesforce-to-Jira sync flag has been unset.');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to unset sync flag: ' + e.getMessage());
        }
    }
}