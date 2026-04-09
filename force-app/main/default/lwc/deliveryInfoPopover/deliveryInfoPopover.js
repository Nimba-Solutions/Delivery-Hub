/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Reusable info indicator that shows a popover explaining how
 *               a component's data is populated. Accepts a componentName
 *               @api property and looks up the description from an internal
 *               registry. Renders as a small info-circle icon that can be
 *               placed anywhere (typically in the actions slot of a card).
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track } from 'lwc';

/**
 * Central registry of component descriptions.
 * Keyed by the value passed to the componentName @api property.
 * Each entry contains:
 *   friendlyName : Display title in the popover
 *   description  : What the component shows (plain English)
 *   dataSource   : How the data is populated
 *   keyFields    : Which fields / objects drive the display
 */
const INFO_REGISTRY = {
    deliveryActivityDashboard: {
        dataSource:
            'Calls getActivityDashboard which aggregates Activity_Log__c records. "This Week" and "This Month" counts come from records where CreatedDate falls in the current week/month. The 7-Day Trend queries daily counts for the past 7 days. Top Users, Top Components, and Top Pages are derived from GROUP BY aggregations on Activity_Log__c fields (UserNameTxt__c, ComponentNameTxt__c, PageUrlTxt__c) for the current month.',
        description:
            'A compact analytics dashboard for Ghost Recorder activity data. Shows weekly and monthly event totals, a 7-day activity trend bar chart, and ranked lists of top users, top components, and top pages — all powered by the Activity Log records that Ghost Recorder writes automatically as users navigate.',
        friendlyName: 'Activity Dashboard',
        keyFields:
            'Activity_Log__c.ActionTypePk__c, Activity_Log__c.CreatedDate, Activity_Log__c.UserNameTxt__c, Activity_Log__c.ComponentNameTxt__c, Activity_Log__c.PageUrlTxt__c'
    },
    deliveryActivityFeed: {
        dataSource:
            'The All/Hours/Changes tabs call getActivityFeed which queries Activity_Log__c records filtered by type and paginated. Conversations tab calls getConversations which groups WorkItemComment__c records by Work Item into threads. The Hours tab also loads getPendingApprovals showing WorkLog__c entries awaiting approval. Events are grouped by date (Today, Yesterday, or formatted date).',
        description:
            'A unified stream of all delivery activity — comments, hour entries, stage changes, and field updates. Supports tabs for All Activity, Conversations, Hours (with pending approval), and Changes. Auto-refreshes every 30 seconds.',
        friendlyName: 'Activity Feed',
        keyFields:
            'Activity_Log__c.ActionTypePk__c, Activity_Log__c.CreatedDate, WorkItemComment__c.BodyTxt__c, WorkLog__c.StatusPk__c, WorkLog__c.HoursNumber__c'
    },
    deliveryBoardMetrics: {
        dataSource:
            'Calls getBoardMetrics which calculates: velocity from completed Work Items grouped by week, throughput from average days between creation and completion, WIP from count of items in non-terminal stages, stage distribution from current stage counts, aging items (>14 days in a stage), and completion rate from done-vs-total in last 30 days.',
        description:
            'Delivery analytics dashboard showing velocity (items completed per week over 4 weeks), average throughput in days, work-in-progress gauge, stage distribution bar, aging alerts for stale items, priority breakdown, and 30-day completion rate.',
        friendlyName: 'Board Metrics',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.ActivatedDateTime__c, WorkItem__c.CreatedDate, WorkItem__c.PriorityPk__c, WorkItem__c.DaysInStageNumber__c, WorkflowStage__mdt.Phase'
    },
    deliveryBudgetSummary: {
        dataSource:
            'Calls getBudgetMetrics which counts active WorkItems (ActivatedDateTime__c set, not archived, not a template), sums WorkLog hours two ways: "Logged" uses CreatedDate (when the entry was made), "by Work Date" uses WorkDateDate__c (when the work was performed). Connection health tallies SyncItem__c by StatusPk__c. Click any number to open the Monthly Hours report filtered to that exact data set.',
        description:
            'System health at a glance. Shows active work items, hours logged this month (with a secondary "by Work Date" metric for backdated entries), and sync connection health. Each number is clickable and opens a report showing exactly the records behind that count.',
        friendlyName: 'System Pulse',
        keyFields:
            'WorkItem__c.ActivatedDateTime__c, WorkLog__c.HoursLoggedNumber__c, WorkLog__c.WorkDateDate__c, WorkLog__c.CreatedDate, SyncItem__c.StatusPk__c'
    },
    deliveryClientDashboard: {
        dataSource:
            'Queries active Work Items where the current user\'s persona requires action (e.g., client approval stages). Attention items are scored by days-in-stage, priority, and blocked status. Phase counts come from non-terminal workflow stages defined in Custom Metadata. The "This Week" metrics count completions, stage moves, hours logged, and blocked items within the selected time range.',
        description:
            'Your personal delivery overview. Shows a greeting, items needing your attention ranked by urgency, a phase-by-phase count of active work, a "This Week" snapshot, and recently updated items.',
        friendlyName: 'Client Dashboard',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.ActivatedDateTime__c, WorkItem__c.PriorityPk__c, WorkItem__c.DaysInStageNumber__c, WorkLog__c.HoursNumber__c, WorkflowStage__mdt (phase, isTerminal)'
    },
    deliveryClientOnboarding: {
        dataSource:
            'The form collects company name, contact email, hourly rate, phone, and address. On submit it calls onboardClient which creates a NetworkEntity__c record for the new client and generates a Client Agreement document via the Document Engine. The agreement can then be previewed or emailed directly from the success panel.',
        description:
            'A quick-entry form for onboarding new clients. Creates a Network Entity record with billing details and auto-generates a professional Client Agreement document ready for review and signing.',
        friendlyName: 'Client Onboarding',
        keyFields:
            'NetworkEntity__c.Name, NetworkEntity__c.ContactEmailTxt__c, NetworkEntity__c.HourlyRateNumber__c, Document__c.TemplatePk__c, Document__c.StatusPk__c'
    },
    deliveryDataLineage: {
        dataSource:
            'Calls getNetworkEntities which returns the local org identity and all connected Network Entities with their entity type (Vendor/Client/Both), connection status, and last sync timestamp. Health percentage is computed from Sync_Item__c success rates per entity.',
        description:
            'Visual map of the sync chain between connected orgs. Shows upstream vendors (pull) and downstream clients (push) with real-time connection health, entity type, and last sync timestamps.',
        friendlyName: 'Data Flow',
        keyFields:
            'NetworkEntity__c.Name, NetworkEntity__c.EntityTypePk__c, NetworkEntity__c.StatusPk__c, NetworkEntity__c.OrgIdTxt__c, Sync_Item__c.StatusPk__c'
    },
    deliveryDocumentViewer: {
        dataSource:
            'Loads documents via getDocumentsForEntity for the context entity. In preview mode, fetches a JSON snapshot that was captured at generation time — this snapshot contains the entity details, work items, work logs, rates, and totals frozen at the moment the document was created. Templates come from DocumentTemplate__mdt. Payments are tracked as transaction records.',
        description:
            'Manages invoices and other documents for a Network Entity. Shows a list of generated documents with status badges, and a detailed preview mode with line items, work logs, payment history, and PDF rendering.',
        friendlyName: 'Document Viewer',
        keyFields:
            'Document__c.StatusPk__c, Document__c.SnapshotJson__c, Document__c.TemplatePk__c, Document__c.TotalHoursNumber__c, Document__c.TotalCostNumber__c, NetworkEntity__c.Id, DocumentTemplate__mdt'
    },
    deliveryGeneralSettingsCard: {
        dataSource:
            'Loads all Delivery Hub settings via getSettings which reads the DeliveryHubSettings__c custom setting. Each toggle calls saveGeneralSettings or saveExtendedSettings to persist changes immediately. Slack webhook is saved separately via saveSlackWebhookUrl and tested via testWebhook.',
        description:
            'Central configuration panel for Delivery Hub. Manages notification preferences (email, bell, Slack), automation toggles (auto-sync, auto-create work requests, WorkLog approval), board display options, activity tracking, weekly digest scheduling, public status page, and document billing settings.',
        friendlyName: 'General Settings',
        keyFields:
            'DeliveryHubSettings__c (all fields — Notifications, AutoSync, EmailNotifications, BellNotifications, BoardMetrics, ActivityLogging, FieldTracking, WeeklyDigest, StatusPage, SlackWebhookUrl, DocumentCcEmail, DefaultBillingEntityId)'
    },
    deliveryGettingStarted: {
        dataSource:
            'Calls getSetupStatus to determine if the org is already connected. The 5-step wizard calls prepareLocalEntity to create the local Network Entity, checkPrerequisites to verify Site and Remote Site Settings, configureGuestUserAccess for guest user permissions, and performHandshake to establish the vendor connection.',
        description:
            'Interactive onboarding wizard that walks new users through connecting their Salesforce org to the Delivery Hub network. Covers org type selection, workflow choice, partner configuration, prerequisite checks, and the final connection handshake.',
        friendlyName: 'Getting Started',
        keyFields:
            'NetworkEntity__c.OrgTypePk__c, NetworkEntity__c.StatusPk__c, DeliveryHubSettings__c, Salesforce Site, Remote Site Setting'
    },
    deliveryGhostRecorder: {
        dataSource:
            'Logs navigation events via logUserActivity each time the page reference changes (debounced to 3s). The bug/feature form calls createQuickRequest which creates a Work Item with context metadata (URL, object name, record ID, browser). File uploads are linked via linkFilesAndSync. Attention count shown in the banner comes from getAttentionCount.',
        description:
            'Silent background tracker and quick-submit form. Tracks page navigation events for usage analytics. Also serves as a quick bug report / feature request form that captures URL context, browser info, and session data automatically.',
        friendlyName: 'Ghost Recorder',
        keyFields:
            'Activity_Log__c.ActionTypePk__c, WorkItem__c.BriefDescriptionTxt__c, WorkItem__c.PriorityPk__c, WorkItem__c.DetailsTxt__c'
    },
    deliveryHubBoard: {
        dataSource:
            'Loads all active Work Items via getWorkItems, grouped into columns defined by WorkflowStage__mdt for the selected WorkflowType__mdt. Persona views come from WorkflowPersonaView__mdt which controls which columns each persona sees and their sort order. Stage transitions (forward and backtrack) are also defined in CMT.',
        description:
            'The main drag-and-drop board for managing work items through workflow stages. Columns, transitions, and colors are driven by Custom Metadata, not hardcoded. Supports persona-based views (Client, Developer, PM), filtering by tags/priority/developer, swimlanes, and card quick-actions.',
        friendlyName: 'Kanban Board',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.ActivatedDateTime__c, WorkItem__c.WorkflowTypeTxt__c, WorkItem__c.PriorityPk__c, WorkItem__c.DeveloperLookup__c, WorkItem__c.TagsTxt__c, WorkflowType__mdt, WorkflowStage__mdt, WorkflowPersonaView__mdt'
    },
    deliveryHubSetup: {
        dataSource:
            'Calls getSetupStatus to check if the org is connected, is the mothership, or needs setup. On the admin home, also loads getPendingApprovalCount and getPendingApprovals for incoming connection requests. Approve/reject actions call approveConnection and rejectConnection respectively.',
        description:
            'Connection status card showing whether this org is linked to the Delivery Hub network. On the admin home, displays vendor details, sync schedule, entity status, and a queue of pending connection approval requests from client orgs.',
        friendlyName: 'Hub Setup',
        keyFields:
            'NetworkEntity__c.StatusPk__c, NetworkEntity__c.OrgTypePk__c, NetworkEntity__c.Name, DeliveryHubSettings__c.EnableAutoSyncNetworkEntityDateTime__c'
    },
    deliveryReleaseNotes: {
        dataSource:
            'Calls generateReleaseNotes with a configurable date range (defaults to last 30 days). The Apex method queries Work Items completed within that window and groups them by request type into sections. Results include item name, title, priority, and developer.',
        description:
            'Generates formatted release notes from completed work items within a date range. Items are grouped by category with priority badges and developer attribution. Supports one-click copy to clipboard for sharing.',
        friendlyName: 'Release Notes',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.CompletedDate__c, WorkItem__c.RequestTypePk__c, WorkItem__c.BriefDescriptionTxt__c, WorkItem__c.PriorityPk__c, WorkItem__c.DeveloperLookup__c'
    },
    deliveryScore: {
        dataSource:
            'Calls getDeliveryScore which evaluates multiple factors: completion velocity (items done per week), average cycle time, work-in-progress count vs. healthy thresholds, percentage of blocked items, and priority distribution. Each factor is scored 0-100 and weighted to produce the overall score. The grade (A-F) is derived from score thresholds.',
        description:
            'A 0-100 health rating for your delivery pipeline shown as an animated gauge. Breaks down into weighted factors like velocity, cycle time, WIP balance, and blocked-item ratio.',
        friendlyName: 'Delivery Score',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.ActivatedDateTime__c, WorkItem__c.PriorityPk__c, WorkItem__c.CreatedDate, WorkItem__c.DaysInStageNumber__c, NetworkEntity__c.Id'
    },
    deliverySyncRetryPanel: {
        dataSource:
            'Calls getSyncHealth which counts Sync_Item__c records where StatusPk__c = "Failed" and returns their most recent error messages. The retry action calls retryFailed which updates those records\' status back to "Queued" for reprocessing by SyncItemProcessor.',
        description:
            'Shows the count of failed sync items and recent error messages. Provides a one-click retry button that resets all failed items back to queued status so the sync engine reprocesses them.',
        friendlyName: 'Sync Retry Panel',
        keyFields:
            'Sync_Item__c.StatusPk__c, Sync_Item__c.ErrorMessageTxt__c, Sync_Item__c.RetryCountNumber__c'
    },
    deliveryWorkItemActionCenter: {
        dataSource:
            'Combines @wire(getRecord) for the current Work Item with @wire(getWorkflowConfig) for CMT-driven transitions. Forward and backtrack options come from WorkflowStage__mdt.ForwardTransitions and BacktrackTransitions. Missing fields are evaluated cumulatively — e.g., needing an estimate before proposal, a developer before development, and acceptance criteria before coding.',
        description:
            'Stage transition control panel on a Work Item record page. Shows the current stage with phase label, missing field warnings, forward move buttons, backtrack options, and fast-track indicators. Buttons are dynamically enabled/disabled based on field completeness.',
        friendlyName: 'Action Center',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.EstimatedHoursNumber__c, WorkItem__c.ClientPreApprovedHoursNumber__c, WorkItem__c.DeveloperLookup__c, WorkItem__c.AcceptanceCriteriaTxt__c, WorkflowStage__mdt.ForwardTransitions, WorkflowStage__mdt.BacktrackTransitions'
    },
    deliveryWorkItemStageGateWarning: {
        dataSource:
            'Uses @wire(getRecord) to read the current Work Item fields in real time. Three gate checks run: (1) Sizing gate — requires Hours Estimate before proposal stages. (2) Fast Track — compares Estimate vs. Pre-Approved Hours and shows green/red light. (3) Dev Readiness — requires both Developer and Estimate before development stages.',
        description:
            'Context-sensitive alert banner on a Work Item record page. Evaluates gating rules based on the current stage and shows warnings, errors, or "fast track" green-light messages when certain fields are missing or budget conditions are met.',
        friendlyName: 'Stage Gate Warning',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.EstimatedHoursNumber__c, WorkItem__c.ClientPreApprovedHoursNumber__c, WorkItem__c.DeveloperLookup__c'
    },
    deliveryNimbusGantt: {
        dataSource:
            'Calls DeliveryGanttController.getGanttData to load active WorkItem__c records with start/end dates and dependencies. Dependency arrows are loaded via getGanttDependencies. Drag-to-move and drag-to-resize update dates via updateWorkItemDates. Supports entity filtering and completed-item toggling.',
        description:
            'Interactive Gantt timeline built on the Nimbus Gantt canvas library. Five visualization modes: Gantt (timeline bars with dependencies), Treemap (rectangles sized by hours), Bubbles (scatter by timeline/entity/effort), Calendar (GitHub-style heatmap), and Flow (stage distribution). Supports drag-to-reschedule, zoom levels (day/week/month/quarter), dark mode, critical path highlighting, and phone remote control via Platform Events.',
        friendlyName: 'Project Timeline',
        keyFields:
            'WorkItem__c.EstimatedStartDevDate__c, WorkItem__c.EstimatedEndDevDate__c, WorkItem__c.StageNamePk__c, WorkItem__c.DeveloperLookup__c, WorkItem__c.EstimatedHoursNumber__c, WorkItemDependency__c'
    }
};

export default class DeliveryInfoPopover extends LightningElement {
    @api componentName = '';

    @track isOpen = false;
    @track lastRefreshedTime = null;

    connectedCallback() {
        this.lastRefreshedTime = new Date();
    }

    get info() {
        return INFO_REGISTRY[this.componentName] || null;
    }

    get hasInfo() {
        return this.info !== null;
    }

    get friendlyName() {
        if (this.info) {
            return this.info.friendlyName;
        }
        return this.componentName;
    }

    get description() {
        if (this.info) {
            return this.info.description;
        }
        return '';
    }

    get dataSource() {
        if (this.info) {
            return this.info.dataSource;
        }
        return '';
    }

    get keyFields() {
        if (this.info) {
            return this.info.keyFields;
        }
        return '';
    }

    get lastRefreshedLabel() {
        if (!this.lastRefreshedTime) {
            return 'Unknown';
        }
        return this.lastRefreshedTime.toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    handleToggle(event) {
        event.stopPropagation();
        this.isOpen = !this.isOpen;
        if (this.isOpen) {
            this.lastRefreshedTime = new Date();
        }
    }

    handleClose(event) {
        event.stopPropagation();
        this.isOpen = false;
    }

    handleBackdropClick(event) {
        if (event.target === event.currentTarget) {
            this.isOpen = false;
        }
    }

    handleKeyDown(event) {
        if (event.key === 'Escape') {
            this.isOpen = false;
        }
    }
}
