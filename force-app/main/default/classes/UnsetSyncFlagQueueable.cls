/**
 * @description       : A queueable job designed to unset the 'SalesforceToJiraBool__c' flag in the 'Sync_In_Propgress__c' custom setting. This is typically used to signal the completion of a sync process and prevent potential recursion from webhooks.
 * @author            : Mahipal Jat
 * @group             : 
 * @last modified on  : 08-28-2025
 * @last modified by  : Mahipal Jat
**/
public class UnsetSyncFlagQueueable implements Queueable {

    /**
    * @description Main execution method for the queueable job. It finds the org default 'Sync_In_Propgress__c' custom setting and, if the sync flag is true, sets it to false.
    * @author Mahipal Jat | 08-28-2025 
    * @param context QueueableContext object containing the job context
    **/
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