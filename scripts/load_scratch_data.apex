// Create Network Entities
List<NetworkEntity__c> entities = new List<NetworkEntity__c>();
entities.add(new NetworkEntity__c(Name='At Large', EntityTypePk__c='Client', StatusPk__c='Active', DefaultHourlyRateCurrency__c=90));
entities.add(new NetworkEntity__c(Name='Cloud Nimbus Dev Hub', EntityTypePk__c='Vendor', StatusPk__c='Active', DefaultHourlyRateCurrency__c=90));
entities.add(new NetworkEntity__c(Name='Mobilization Funding', EntityTypePk__c='Client', StatusPk__c='Active', DefaultHourlyRateCurrency__c=125));
insert entities;

// Create Work Items
List<WorkItem__c> items = new List<WorkItem__c>();
items.add(new WorkItem__c(BriefDescriptionTxt__c='MF-698 New Accounting Integration', StageNamePk__c='Clarification Requested', PriorityPk__c='Medium', EstimatedHoursNumber__c=10, ClientNetworkEntityId__c=entities[0].Id, WorkflowTypeTxt__c='Software_Delivery'));
items.add(new WorkItem__c(BriefDescriptionTxt__c='MF-699 Quickbooks Online Integration', StageNamePk__c='In Client UAT', PriorityPk__c='High', EstimatedHoursNumber__c=80, ClientNetworkEntityId__c=entities[0].Id, WorkflowTypeTxt__c='Software_Delivery'));
items.add(new WorkItem__c(BriefDescriptionTxt__c='MF-725 Default Fee Structure', StageNamePk__c='Ready for Development', PriorityPk__c='Medium', EstimatedHoursNumber__c=15, ClientNetworkEntityId__c=entities[0].Id, WorkflowTypeTxt__c='Software_Delivery'));
items.add(new WorkItem__c(BriefDescriptionTxt__c='MF-732 User Profile Lockdown', StageNamePk__c='Scoping', PriorityPk__c='High', EstimatedHoursNumber__c=12, ClientNetworkEntityId__c=entities[0].Id, WorkflowTypeTxt__c='Software_Delivery'));
items.add(new WorkItem__c(BriefDescriptionTxt__c='MF-733 Risk Rating & Servicing', StageNamePk__c='Clarification Requested', PriorityPk__c='High', EstimatedHoursNumber__c=50, ClientNetworkEntityId__c=entities[0].Id, WorkflowTypeTxt__c='Software_Delivery'));
items.add(new WorkItem__c(BriefDescriptionTxt__c='MF-712 Weekly Loan Report', StageNamePk__c='Deployed to Prod', ClientNetworkEntityId__c=entities[0].Id, WorkflowTypeTxt__c='Software_Delivery'));
items.add(new WorkItem__c(BriefDescriptionTxt__c='MF-713 Pay App Overhaul', StageNamePk__c='Done', ClientNetworkEntityId__c=entities[0].Id, WorkflowTypeTxt__c='Software_Delivery'));
items.add(new WorkItem__c(BriefDescriptionTxt__c='MF-726 HubSpot Investigation', StageNamePk__c='Ready for UAT Sign-off', PriorityPk__c='High', ClientNetworkEntityId__c=entities[0].Id, WorkflowTypeTxt__c='Software_Delivery'));
items.add(new WorkItem__c(BriefDescriptionTxt__c='Platform Events Setup', StageNamePk__c='In Development', PriorityPk__c='Medium', EstimatedHoursNumber__c=8, ClientNetworkEntityId__c=entities[1].Id, WorkflowTypeTxt__c='Software_Delivery'));
items.add(new WorkItem__c(BriefDescriptionTxt__c='Client Portal Auth', StageNamePk__c='Done', ClientNetworkEntityId__c=entities[1].Id, WorkflowTypeTxt__c='Software_Delivery'));
insert items;

// Create Work Requests FIRST (WorkLog depends on them)
List<WorkRequest__c> reqs = new List<WorkRequest__c>();
for (WorkItem__c wi : items) {
    reqs.add(new WorkRequest__c(WorkItemId__c=wi.Id, StatusPk__c='Draft', DeliveryEntityId__c=entities[1].Id, HourlyRateCurrency__c=90));
}
insert reqs;

// Build request lookup by work item Id
Map<Id, Id> itemToRequest = new Map<Id, Id>();
for (WorkRequest__c wr : reqs) {
    itemToRequest.put(wr.WorkItemId__c, wr.Id);
}

// Create WorkLogs with required RequestId__c
List<WorkLog__c> logs = new List<WorkLog__c>();
logs.add(new WorkLog__c(WorkItemId__c=items[1].Id, RequestId__c=itemToRequest.get(items[1].Id), HoursLoggedNumber__c=11, WorkDateDate__c=Date.today().addDays(-24), WorkDescriptionTxt__c='Worked on QB integration'));
logs.add(new WorkLog__c(WorkItemId__c=items[1].Id, RequestId__c=itemToRequest.get(items[1].Id), HoursLoggedNumber__c=10.5, WorkDateDate__c=Date.today().addDays(-23), WorkDescriptionTxt__c='Completed QB auth flow'));
logs.add(new WorkLog__c(WorkItemId__c=items[1].Id, RequestId__c=itemToRequest.get(items[1].Id), HoursLoggedNumber__c=7.5, WorkDateDate__c=Date.today().addDays(-22), WorkDescriptionTxt__c='Test class and docs'));
logs.add(new WorkLog__c(WorkItemId__c=items[7].Id, RequestId__c=itemToRequest.get(items[7].Id), HoursLoggedNumber__c=5, WorkDateDate__c=Date.today().addDays(-20), WorkDescriptionTxt__c='HubSpot investigation'));
logs.add(new WorkLog__c(WorkItemId__c=items[7].Id, RequestId__c=itemToRequest.get(items[7].Id), HoursLoggedNumber__c=3, WorkDateDate__c=Date.today().addDays(-16), WorkDescriptionTxt__c='JS scripts for HubSpot'));
logs.add(new WorkLog__c(WorkItemId__c=items[5].Id, RequestId__c=itemToRequest.get(items[5].Id), HoursLoggedNumber__c=7.5, WorkDateDate__c=Date.today().addDays(-13), WorkDescriptionTxt__c='Updated flows for loan report'));
logs.add(new WorkLog__c(WorkItemId__c=items[5].Id, RequestId__c=itemToRequest.get(items[5].Id), HoursLoggedNumber__c=3.5, WorkDateDate__c=Date.today().addDays(-9), WorkDescriptionTxt__c='Updated flows continued'));
logs.add(new WorkLog__c(WorkItemId__c=items[6].Id, RequestId__c=itemToRequest.get(items[6].Id), HoursLoggedNumber__c=6, WorkDateDate__c=Date.today().addDays(-8), WorkDescriptionTxt__c='Pay app analysis and fixes'));
logs.add(new WorkLog__c(WorkItemId__c=items[2].Id, RequestId__c=itemToRequest.get(items[2].Id), HoursLoggedNumber__c=3.5, WorkDateDate__c=Date.today().addDays(-2), WorkDescriptionTxt__c='Default fee structure research'));
insert logs;

System.debug(LoggingLevel.ERROR, 'SUCCESS: ' + entities.size() + ' entities, ' + items.size() + ' items, ' + logs.size() + ' logs, ' + reqs.size() + ' requests');
