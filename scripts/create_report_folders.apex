// Create report folders for Delivery Hub reports
List<Folder> folders = new List<Folder>();
folders.add(new Folder(Name='Delivery Hub — Client', DeveloperName='DeliveryHubClient', Type='Report', AccessType='Public'));
folders.add(new Folder(Name='Delivery Hub — Vendor', DeveloperName='DeliveryHubVendor', Type='Report', AccessType='Public'));
insert folders;
System.debug(LoggingLevel.ERROR, 'Created ' + folders.size() + ' report folders');
