// TEST: External notification pilot
// Enables settings, creates a test item, then changes its stage to trigger the email

// 1. Enable all notification settings
DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
s.EnableEmailNotificationsDateTime__c = Datetime.now();
s.EnableExternalNotificationsDateTime__c = Datetime.now();
s.EnableNotificationsDateTime__c = Datetime.now();
upsert s;
System.debug('Settings enabled');

// 2. Create a work item with external requester email
WorkItem__c wi = new WorkItem__c(
    BriefDescriptionTxt__c = 'TEST: External notification pilot',
    StageNamePk__c = 'Submitted',
    ExternalRequesterEmailTxt__c = 'glen@cloudnimbusllc.com',
    PriorityPk__c = 'High',
    IsActiveBool__c = true
);
insert wi;
System.debug('Created: ' + wi.Id + ' — ' + wi.Name);

// 3. Change stage to trigger the notification
wi.StageNamePk__c = 'In Development';
update wi;
System.debug('Stage changed to In Development — external email should fire to glen@cloudnimbusllc.com');
