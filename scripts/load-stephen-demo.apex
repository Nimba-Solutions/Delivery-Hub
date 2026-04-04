Date t = Date.today();

NetworkEntity__c client1 = new NetworkEntity__c(Name = 'Acme Corp');
NetworkEntity__c client2 = new NetworkEntity__c(Name = 'TechStart Inc');
insert new List<NetworkEntity__c>{ client1, client2 };

List<WorkItem__c> items = new List<WorkItem__c>();
items.add(new WorkItem__c(BriefDescriptionTxt__c='Platform Migration', StageNamePk__c='In Development', EstimatedStartDevDate__c=t.addDays(-20), EstimatedEndDevDate__c=t.addDays(15), EstimatedHoursNumber__c=120, ClientNetworkEntityId__c=client1.Id, IsActiveBool__c=true));
items.add(new WorkItem__c(BriefDescriptionTxt__c='API Integration', StageNamePk__c='In Development', EstimatedStartDevDate__c=t.addDays(-10), EstimatedEndDevDate__c=t.addDays(5), EstimatedHoursNumber__c=40, ClientNetworkEntityId__c=client1.Id, IsActiveBool__c=true));
items.add(new WorkItem__c(BriefDescriptionTxt__c='Security Audit', StageNamePk__c='Code Review', EstimatedStartDevDate__c=t.addDays(-5), EstimatedEndDevDate__c=t.addDays(3), EstimatedHoursNumber__c=20, ClientNetworkEntityId__c=client1.Id, IsActiveBool__c=true));
items.add(new WorkItem__c(BriefDescriptionTxt__c='Dashboard Redesign', StageNamePk__c='Submitted', EstimatedStartDevDate__c=t.addDays(2), EstimatedEndDevDate__c=t.addDays(14), EstimatedHoursNumber__c=30, ClientNetworkEntityId__c=client2.Id, IsActiveBool__c=true));
items.add(new WorkItem__c(BriefDescriptionTxt__c='Mobile App MVP', StageNamePk__c='In Development', EstimatedStartDevDate__c=t.addDays(-15), EstimatedEndDevDate__c=t.addDays(20), EstimatedHoursNumber__c=80, ClientNetworkEntityId__c=client2.Id, IsActiveBool__c=true));
items.add(new WorkItem__c(BriefDescriptionTxt__c='Data Pipeline', StageNamePk__c='Submitted', EstimatedStartDevDate__c=t.addDays(5), EstimatedEndDevDate__c=t.addDays(25), EstimatedHoursNumber__c=50, ClientNetworkEntityId__c=client2.Id, IsActiveBool__c=true));
insert items;

// Set parent-child
items[1].ParentWorkItemId__c = items[0].Id;
items[2].ParentWorkItemId__c = items[0].Id;
items[4].ParentWorkItemId__c = items[3].Id;
items[5].ParentWorkItemId__c = items[3].Id;
update items;

// Dependencies
List<WorkItemDependency__c> deps = new List<WorkItemDependency__c>();
deps.add(new WorkItemDependency__c(BlockingWorkItemId__c=items[1].Id, BlockedWorkItemId__c=items[2].Id, TypePk__c='Blocks'));
deps.add(new WorkItemDependency__c(BlockingWorkItemId__c=items[4].Id, BlockedWorkItemId__c=items[5].Id, TypePk__c='Blocks'));
insert deps;

System.debug('Stephen demo: 6 items, 2 deps, 2 entities');
