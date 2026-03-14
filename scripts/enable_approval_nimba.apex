// =============================================================================
// Enable WorkLog Approval in Nimba Sandbox
// Run via: sf apex run -f scripts/enable_approval_nimba.apex --target-org nimba
//
// Sets RequireWorkLogApprovalDate__c to now. All WorkLogs created after this
// DateTime will be saved as Draft and require approval before syncing.
// Existing WorkLogs (null StatusPk__c) are treated as Approved by the trigger.
// =============================================================================

delivery__DeliveryHubSettings__c settings = delivery__DeliveryHubSettings__c.getOrgDefaults();

if (settings.Id == null) {
    System.debug('ERROR: No DeliveryHubSettings__c org defaults found. Run the Getting Started wizard first.');
    return;
}

if (settings.delivery__RequireWorkLogApprovalDate__c != null) {
    System.debug('Approval already enabled since: ' + settings.delivery__RequireWorkLogApprovalDate__c);
    System.debug('No changes made.');
    return;
}

settings.delivery__RequireWorkLogApprovalDate__c = Datetime.now();
update settings;

System.debug('SUCCESS: WorkLog approval enabled as of ' + settings.delivery__RequireWorkLogApprovalDate__c);
System.debug('New WorkLogs will be saved as Draft until approved.');
