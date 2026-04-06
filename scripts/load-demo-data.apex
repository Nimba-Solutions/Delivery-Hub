// ============================================================
// Delivery Hub — Demo Data Loader
// Inserts realistic sample data for demos and evaluations.
// Run via: cci task run execute_anon --path scripts/load-demo-data.apex
// ============================================================

// --- Org Defaults (DeliveryHubSettings__c) ---
DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
settings.EnableActivityLoggingDateTime__c = Datetime.now();
settings.EnableFieldTrackingDateTime__c = Datetime.now();
settings.EnableBellNotificationsDateTime__c = Datetime.now();
settings.AutoCreateWorkRequestDateTime__c = Datetime.now();
settings.AutoSyncNetworkEntityDateTime__c = null;
settings.ShowBoardMetricsDateTime__c = Datetime.now();
settings.ActivityLogRetentionDaysNumber__c = 90;
settings.FieldChangeRetentionDaysNumber__c = 90;
settings.EscalationCooldownHoursNumber__c = 24;
settings.SyncRetryLimitNumber__c = 3;
settings.WeeklyDigestDayTxt__c = 'Monday';
settings.DocumentCcEmailTxt__c = 'billing@example.com';
upsert settings;
System.debug('Settings configured.');

// --- Network Entities ---
NetworkEntity__c acme = new NetworkEntity__c(
    Name = 'Acme Corp',
    EntityTypePk__c = 'Client',
    StatusPk__c = 'Active',
    DefaultHourlyRateCurrency__c = 150,
    ContactEmailTxt__c = 'pm@acmecorp.example.com',
    ContactPhoneTxt__c = '(212) 555-0147',
    AddressTxt__c = '350 Fifth Avenue, Suite 3400, New York, NY 10118'
);
insert acme;

NetworkEntity__c cn = new NetworkEntity__c(
    Name = 'Cloud Nimbus LLC',
    EntityTypePk__c = 'Both',
    StatusPk__c = 'Active',
    DefaultHourlyRateCurrency__c = 175,
    ContactEmailTxt__c = 'delivery@cloudnimbusllc.com',
    ContactPhoneTxt__c = '(202) 555-0199',
    AddressTxt__c = '1100 15th Street NW, Washington, DC 20005'
);
insert cn;
System.debug('Entities created: Acme Corp (Client), Cloud Nimbus LLC (Vendor/Both)');

// --- Work Items ---
// Spread across realistic stages, priorities, and request types.
Date today = Date.today();

WorkItem__c wi1 = new WorkItem__c(
    BriefDescriptionTxt__c = 'Implement SSO integration with Azure AD',
    DetailsTxt__c = '<p>Configure SAML 2.0 SSO between Salesforce and Azure Active Directory. Includes My Domain setup, IdP config, attribute mapping, and login flow for JIT provisioning.</p>',
    PriorityPk__c = 'High',
    StageNamePk__c = 'In Development',
    StatusPk__c = 'In Progress',
    WorkflowTypeTxt__c = 'Software_Delivery',
    EstimatedHoursNumber__c = 40,
    ClientPreApprovedHoursNumber__c = 40,
    ClientNetworkEntityId__c = acme.Id,
    TagsTxt__c = 'SSO, Security, Azure',
    EstimatedStartDevDate__c = today.addDays(-14),
    EstimatedEndDevDate__c = today.addDays(7)
);
insert wi1;

WorkItem__c wi2 = new WorkItem__c(
    BriefDescriptionTxt__c = 'Fix payment processing timeout on large invoices',
    DetailsTxt__c = '<p>Payments over $50K timeout when hitting the external gateway. Root cause: synchronous callout in a trigger context. Need to refactor to async queueable with retry logic.</p>',
    PriorityPk__c = 'High',
    StageNamePk__c = 'Ready for QA',
    StatusPk__c = 'In Progress',
    WorkflowTypeTxt__c = 'Software_Delivery',
    EstimatedHoursNumber__c = 16,
    ClientPreApprovedHoursNumber__c = 20,
    ClientNetworkEntityId__c = acme.Id,
    TagsTxt__c = 'Bug, Payments, Performance',
    EstimatedStartDevDate__c = today.addDays(-10),
    EstimatedEndDevDate__c = today.addDays(-1)
);
insert wi2;

WorkItem__c wi3 = new WorkItem__c(
    BriefDescriptionTxt__c = 'Add export to CSV feature for report dashboards',
    DetailsTxt__c = '<p>Users need to export dashboard data to CSV for offline analysis. Build a reusable LWC button component that serializes tabular data and triggers browser download.</p>',
    PriorityPk__c = 'Medium',
    StageNamePk__c = 'Backlog',
    StatusPk__c = 'New',
    WorkflowTypeTxt__c = 'Software_Delivery',
    EstimatedHoursNumber__c = 12,
    ClientNetworkEntityId__c = acme.Id,
    TagsTxt__c = 'Feature, Export, LWC',
    EstimatedStartDevDate__c = today.addDays(7),
    EstimatedEndDevDate__c = today.addDays(21)
);
insert wi3;

WorkItem__c wi4 = new WorkItem__c(
    BriefDescriptionTxt__c = 'Build automated email notification system for case updates',
    DetailsTxt__c = '<p>Triggered email alerts when case status changes, SLA breach approaching, or escalation occurs. Flow-based with custom email templates and merge fields.</p>',
    PriorityPk__c = 'Medium',
    StageNamePk__c = 'Ready for Client UAT',
    StatusPk__c = 'In Progress',
    WorkflowTypeTxt__c = 'Software_Delivery',
    EstimatedHoursNumber__c = 24,
    ClientPreApprovedHoursNumber__c = 24,
    ClientNetworkEntityId__c = acme.Id,
    TagsTxt__c = 'Email, Automation, Flow',
    EstimatedStartDevDate__c = today.addDays(-21),
    EstimatedEndDevDate__c = today.addDays(-3)
);
insert wi4;

WorkItem__c wi5 = new WorkItem__c(
    BriefDescriptionTxt__c = 'Design mobile-responsive Lightning record pages',
    DetailsTxt__c = '<p>Audit and redesign key record pages (Account, Contact, Case) for mobile usability. Consolidate related lists, add dynamic forms, and test on iOS/Android Salesforce app.</p>',
    PriorityPk__c = 'Low',
    StageNamePk__c = 'Scoping In Progress',
    StatusPk__c = 'New',
    WorkflowTypeTxt__c = 'Software_Delivery',
    EstimatedHoursNumber__c = 30,
    ClientNetworkEntityId__c = acme.Id,
    TagsTxt__c = 'Mobile, UX, Lightning',
    EstimatedStartDevDate__c = today.addDays(14),
    EstimatedEndDevDate__c = today.addDays(42)
);
insert wi5;

WorkItem__c wi6 = new WorkItem__c(
    BriefDescriptionTxt__c = 'Migrate legacy REST API to Salesforce Connect (OData)',
    DetailsTxt__c = '<p>Replace custom REST callouts to legacy ERP with Salesforce Connect external objects. Map 4 entities: Products, Orders, Inventory, Shipments. Includes adapter config and external lookup relationships.</p>',
    PriorityPk__c = 'High',
    StageNamePk__c = 'In Development',
    StatusPk__c = 'In Progress',
    WorkflowTypeTxt__c = 'Software_Delivery',
    EstimatedHoursNumber__c = 60,
    ClientPreApprovedHoursNumber__c = 65,
    ClientNetworkEntityId__c = acme.Id,
    TagsTxt__c = 'Integration, API, Migration',
    EstimatedStartDevDate__c = today.addDays(-7),
    EstimatedEndDevDate__c = today.addDays(28)
);
insert wi6;

WorkItem__c wi7 = new WorkItem__c(
    BriefDescriptionTxt__c = 'Create executive KPI dashboard with real-time metrics',
    DetailsTxt__c = '<p>C-suite dashboard showing pipeline value, win rate, average deal cycle, customer health score, and revenue forecast. Uses custom report types and dashboard filters.</p>',
    PriorityPk__c = 'Medium',
    StageNamePk__c = 'Deployed to Prod',
    StatusPk__c = 'Done',
    WorkflowTypeTxt__c = 'Software_Delivery',
    EstimatedHoursNumber__c = 20,
    ClientPreApprovedHoursNumber__c = 20,
    ClientNetworkEntityId__c = acme.Id,
    TagsTxt__c = 'Dashboard, Analytics, KPI',
    EstimatedStartDevDate__c = today.addDays(-45),
    EstimatedEndDevDate__c = today.addDays(-25)
);
insert wi7;

WorkItem__c wi8 = new WorkItem__c(
    BriefDescriptionTxt__c = 'Implement field-level encryption for PII data',
    DetailsTxt__c = '<p>Enable Shield Platform Encryption for SSN, DOB, and financial account fields. Includes deterministic encryption for filter/search, key rotation plan, and data masking for sandbox refreshes.</p>',
    PriorityPk__c = 'High',
    StageNamePk__c = 'Ready for Sizing',
    StatusPk__c = 'New',
    WorkflowTypeTxt__c = 'Software_Delivery',
    EstimatedHoursNumber__c = 35,
    ClientNetworkEntityId__c = acme.Id,
    TagsTxt__c = 'Security, Encryption, Compliance',
    EstimatedStartDevDate__c = today.addDays(3),
    EstimatedEndDevDate__c = today.addDays(21)
);
insert wi8;

WorkItem__c wi9 = new WorkItem__c(
    BriefDescriptionTxt__c = 'Set up CI/CD pipeline with CumulusCI and GitHub Actions',
    DetailsTxt__c = '<p>Internal tooling: configure CumulusCI scratch org flows, PMD static analysis, Apex test suite, and automated package version creation on merge to main.</p>',
    PriorityPk__c = 'Medium',
    StageNamePk__c = 'Done',
    StatusPk__c = 'Done',
    WorkflowTypeTxt__c = 'Software_Delivery',
    EstimatedHoursNumber__c = 16,
    ClientPreApprovedHoursNumber__c = 16,
    ClientNetworkEntityId__c = acme.Id,
    TagsTxt__c = 'DevOps, CI/CD, Internal',
    EstimatedStartDevDate__c = today.addDays(-60),
    EstimatedEndDevDate__c = today.addDays(-50)
);
insert wi9;

WorkItem__c wi10 = new WorkItem__c(
    BriefDescriptionTxt__c = 'Fix duplicate contact merge losing activity history',
    DetailsTxt__c = '<p>When contacts are merged via the standard duplicate management tool, task and event records on the losing contact are orphaned instead of reparented. Investigate trigger + after-merge flow fix.</p>',
    PriorityPk__c = 'Medium',
    StageNamePk__c = 'QA In Progress',
    StatusPk__c = 'In Progress',
    WorkflowTypeTxt__c = 'Software_Delivery',
    EstimatedHoursNumber__c = 10,
    ClientPreApprovedHoursNumber__c = 12,
    ClientNetworkEntityId__c = acme.Id,
    TagsTxt__c = 'Bug, Data Quality, Merge',
    EstimatedStartDevDate__c = today.addDays(-5),
    EstimatedEndDevDate__c = today.addDays(2)
);
insert wi10;

System.debug('Work Items created: 10');

// --- Work Requests (link work items to vendor) ---
WorkRequest__c wr1 = new WorkRequest__c(WorkItemId__c = wi1.Id, DeliveryEntityId__c = cn.Id, StatusPk__c = 'In Progress', HourlyRateCurrency__c = 175, PreApprovedHoursNumber__c = 40, QuotedHoursNumber__c = 38);
insert wr1;
WorkRequest__c wr2 = new WorkRequest__c(WorkItemId__c = wi2.Id, DeliveryEntityId__c = cn.Id, StatusPk__c = 'In Progress', HourlyRateCurrency__c = 175, PreApprovedHoursNumber__c = 20, QuotedHoursNumber__c = 16);
insert wr2;
WorkRequest__c wr4 = new WorkRequest__c(WorkItemId__c = wi4.Id, DeliveryEntityId__c = cn.Id, StatusPk__c = 'In Progress', HourlyRateCurrency__c = 175, PreApprovedHoursNumber__c = 24, QuotedHoursNumber__c = 22);
insert wr4;
WorkRequest__c wr6 = new WorkRequest__c(WorkItemId__c = wi6.Id, DeliveryEntityId__c = cn.Id, StatusPk__c = 'In Progress', HourlyRateCurrency__c = 175, PreApprovedHoursNumber__c = 65, QuotedHoursNumber__c = 58);
insert wr6;
WorkRequest__c wr7 = new WorkRequest__c(WorkItemId__c = wi7.Id, DeliveryEntityId__c = cn.Id, StatusPk__c = 'Completed', HourlyRateCurrency__c = 175, PreApprovedHoursNumber__c = 20, QuotedHoursNumber__c = 18);
insert wr7;
WorkRequest__c wr9 = new WorkRequest__c(WorkItemId__c = wi9.Id, DeliveryEntityId__c = cn.Id, StatusPk__c = 'Completed', HourlyRateCurrency__c = 175, PreApprovedHoursNumber__c = 16, QuotedHoursNumber__c = 15);
insert wr9;
WorkRequest__c wr10 = new WorkRequest__c(WorkItemId__c = wi10.Id, DeliveryEntityId__c = cn.Id, StatusPk__c = 'In Progress', HourlyRateCurrency__c = 175, PreApprovedHoursNumber__c = 12, QuotedHoursNumber__c = 10);
insert wr10;
System.debug('Work Requests created: 7');

// --- Work Logs (last 30 days, varied hours) ---
List<WorkLog__c> logs = new List<WorkLog__c>();

// SSO integration (wi1) — 22h logged
logs.add(new WorkLog__c(RequestId__c = wr1.Id, WorkItemId__c = wi1.Id, HoursLoggedNumber__c = 4,   WorkDateDate__c = today.addDays(-13), WorkDescriptionTxt__c = 'My Domain configuration and SAML metadata exchange with Azure AD', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr1.Id, WorkItemId__c = wi1.Id, HoursLoggedNumber__c = 6,   WorkDateDate__c = today.addDays(-11), WorkDescriptionTxt__c = 'Attribute mapping and JIT provisioning handler class', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr1.Id, WorkItemId__c = wi1.Id, HoursLoggedNumber__c = 8,   WorkDateDate__c = today.addDays(-9),  WorkDescriptionTxt__c = 'Login flow with MFA step-up for external users', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr1.Id, WorkItemId__c = wi1.Id, HoursLoggedNumber__c = 4,   WorkDateDate__c = today.addDays(-7),  WorkDescriptionTxt__c = 'Testing SSO with multiple Azure tenants', StatusPk__c = 'Draft'));

// Payment timeout fix (wi2) — 13h logged
logs.add(new WorkLog__c(RequestId__c = wr2.Id, WorkItemId__c = wi2.Id, HoursLoggedNumber__c = 3,   WorkDateDate__c = today.addDays(-9),  WorkDescriptionTxt__c = 'Root cause analysis — synchronous callout in trigger context', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr2.Id, WorkItemId__c = wi2.Id, HoursLoggedNumber__c = 6,   WorkDateDate__c = today.addDays(-7),  WorkDescriptionTxt__c = 'Refactored to async queueable with retry and dead-letter logging', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr2.Id, WorkItemId__c = wi2.Id, HoursLoggedNumber__c = 4,   WorkDateDate__c = today.addDays(-5),  WorkDescriptionTxt__c = 'Apex unit tests for bulkified payment processing', StatusPk__c = 'Approved'));

// Email notifications (wi4) — 20h logged
logs.add(new WorkLog__c(RequestId__c = wr4.Id, WorkItemId__c = wi4.Id, HoursLoggedNumber__c = 5,   WorkDateDate__c = today.addDays(-20), WorkDescriptionTxt__c = 'Email template design and merge field mapping', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr4.Id, WorkItemId__c = wi4.Id, HoursLoggedNumber__c = 7,   WorkDateDate__c = today.addDays(-17), WorkDescriptionTxt__c = 'Flow builder: case status change and SLA breach triggers', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr4.Id, WorkItemId__c = wi4.Id, HoursLoggedNumber__c = 4,   WorkDateDate__c = today.addDays(-14), WorkDescriptionTxt__c = 'Escalation path notification with manager CC logic', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr4.Id, WorkItemId__c = wi4.Id, HoursLoggedNumber__c = 4,   WorkDateDate__c = today.addDays(-12), WorkDescriptionTxt__c = 'QA testing and email deliverability validation', StatusPk__c = 'Approved'));

// Legacy API migration (wi6) — 14h logged
logs.add(new WorkLog__c(RequestId__c = wr6.Id, WorkItemId__c = wi6.Id, HoursLoggedNumber__c = 6,   WorkDateDate__c = today.addDays(-6),  WorkDescriptionTxt__c = 'OData adapter configuration and external data source setup', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr6.Id, WorkItemId__c = wi6.Id, HoursLoggedNumber__c = 8,   WorkDateDate__c = today.addDays(-4),  WorkDescriptionTxt__c = 'Entity mapping: Products and Orders via external objects', StatusPk__c = 'Draft'));

// Executive dashboard (wi7, completed) — 18h logged
logs.add(new WorkLog__c(RequestId__c = wr7.Id, WorkItemId__c = wi7.Id, HoursLoggedNumber__c = 6,   WorkDateDate__c = today.addDays(-42), WorkDescriptionTxt__c = 'Custom report types for pipeline and win rate metrics', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr7.Id, WorkItemId__c = wi7.Id, HoursLoggedNumber__c = 8,   WorkDateDate__c = today.addDays(-38), WorkDescriptionTxt__c = 'Dashboard layout with dynamic filters and KPI components', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr7.Id, WorkItemId__c = wi7.Id, HoursLoggedNumber__c = 4,   WorkDateDate__c = today.addDays(-35), WorkDescriptionTxt__c = 'Stakeholder review and final adjustments', StatusPk__c = 'Approved'));

// CI/CD pipeline (wi9, completed) — 14h logged
logs.add(new WorkLog__c(RequestId__c = wr9.Id, WorkItemId__c = wi9.Id, HoursLoggedNumber__c = 6,   WorkDateDate__c = today.addDays(-58), WorkDescriptionTxt__c = 'CumulusCI project setup, scratch org definition, and flow config', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr9.Id, WorkItemId__c = wi9.Id, HoursLoggedNumber__c = 8,   WorkDateDate__c = today.addDays(-55), WorkDescriptionTxt__c = 'GitHub Actions workflow: PMD, Apex tests, package version creation', StatusPk__c = 'Approved'));

// Duplicate merge fix (wi10) — 7h logged
logs.add(new WorkLog__c(RequestId__c = wr10.Id, WorkItemId__c = wi10.Id, HoursLoggedNumber__c = 3,   WorkDateDate__c = today.addDays(-4), WorkDescriptionTxt__c = 'Reproduced activity orphan bug in scratch org with sample data', StatusPk__c = 'Approved'));
logs.add(new WorkLog__c(RequestId__c = wr10.Id, WorkItemId__c = wi10.Id, HoursLoggedNumber__c = 4,   WorkDateDate__c = today.addDays(-2), WorkDescriptionTxt__c = 'After-merge trigger to reparent tasks and events to winning record', StatusPk__c = 'Draft'));

insert logs;
System.debug('Work Logs created: ' + logs.size() + ' (108h total)');

// --- Work Item Comments ---
List<WorkItemComment__c> comments = new List<WorkItemComment__c>();
comments.add(new WorkItemComment__c(
    WorkItemId__c = wi1.Id,
    AuthorTxt__c = 'Sarah Chen',
    BodyTxt__c = '<p>Azure AD team confirmed they can provide the federation metadata XML by EOD Wednesday. We should be unblocked for IdP config after that.</p>',
    SourcePk__c = 'Salesforce'
));
comments.add(new WorkItemComment__c(
    WorkItemId__c = wi2.Id,
    AuthorTxt__c = 'Marcus Rivera',
    BodyTxt__c = '<p>Good catch on the synchronous callout. We hit the same pattern in the inventory sync last quarter. The queueable + retry approach is solid.</p>',
    SourcePk__c = 'Salesforce'
));
comments.add(new WorkItemComment__c(
    WorkItemId__c = wi4.Id,
    AuthorTxt__c = 'Sarah Chen',
    BodyTxt__c = '<p>UAT feedback: the SLA breach email fires too early. Can we add a configurable threshold (e.g., 80% of SLA elapsed) instead of a fixed 24h window?</p>',
    SourcePk__c = 'Salesforce'
));
comments.add(new WorkItemComment__c(
    WorkItemId__c = wi6.Id,
    AuthorTxt__c = 'Glen Bradford',
    BodyTxt__c = '<p>Heads up — the legacy ERP rate-limits at 100 req/min. The OData adapter caching should help but we need to set the external data source cache TTL to at least 5 minutes.</p>',
    SourcePk__c = 'Salesforce'
));
insert comments;
System.debug('Comments created: ' + comments.size());

// --- Delivery Document (Invoice, Draft) ---
DeliveryDocument__c invoice = new DeliveryDocument__c(
    NetworkEntityId__c = acme.Id,
    TemplatePk__c = 'Invoice',
    StatusPk__c = 'Draft',
    PeriodStartDate__c = today.addDays(-30),
    PeriodEndDate__c = today.addDays(-1),
    DueDateDate__c = today.addDays(30),
    VersionNumber__c = 1,
    TermsTxt__c = 'Net 30. Payment due within 30 days of invoice date.'
);
insert invoice;
System.debug('Invoice created (Draft, last 30 days).');

// --- Summary ---
System.debug('=== DEMO DATA LOADED SUCCESSFULLY ===');
System.debug('Entities: 2 | Items: 10 | Requests: 7 | Logs: ' + logs.size() + ' | Comments: ' + comments.size() + ' | Docs: 1');
System.debug('Board stages populated: Backlog, Scoping In Progress, Ready for Sizing, In Development (x2), Ready for QA, QA In Progress, Ready for Client UAT, Deployed to Prod, Done (x2)');
