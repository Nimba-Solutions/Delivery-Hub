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
            'WorkItem__c.StageNamePk__c, WorkItem__c.IsActiveBool__c, WorkItem__c.CreatedDate, WorkItem__c.PriorityPk__c, WorkItem__c.DaysInStageNumber__c, WorkflowStage__mdt.Phase'
    },
    deliveryBudgetSummary: {
        dataSource:
            'Calls getBudgetMetrics which counts active WorkItems (IsActive = true), sums WorkLog hours for current and previous months, and tallies Sync_Item__c records by status to compute connection health percentage.',
        description:
            'Quick health check showing active work item count, hours logged this month vs. last month, and (optionally) sync connection health with success/failure counts.',
        friendlyName: 'System Pulse',
        keyFields:
            'WorkItem__c.IsActiveBool__c, WorkLog__c.HoursNumber__c, WorkLog__c.WorkDateDate__c, Sync_Item__c.StatusPk__c'
    },
    deliveryClientDashboard: {
        dataSource:
            'Queries active Work Items where the current user\'s persona requires action (e.g., client approval stages). Attention items are scored by days-in-stage, priority, and blocked status. Phase counts come from non-terminal workflow stages defined in Custom Metadata. The "This Week" metrics count completions, stage moves, hours logged, and blocked items within the selected time range.',
        description:
            'Your personal delivery overview. Shows a greeting, items needing your attention ranked by urgency, a phase-by-phase count of active work, a "This Week" snapshot, and recently updated items.',
        friendlyName: 'Client Dashboard',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.IsActiveBool__c, WorkItem__c.PriorityPk__c, WorkItem__c.DaysInStageNumber__c, WorkLog__c.HoursNumber__c, WorkflowStage__mdt (phase, isTerminal)'
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
            'WorkItem__c.StageNamePk__c, WorkItem__c.IsActiveBool__c, WorkItem__c.WorkflowTypeTxt__c, WorkItem__c.PriorityPk__c, WorkItem__c.Developer__c, WorkItem__c.Tags__c, WorkflowType__mdt, WorkflowStage__mdt, WorkflowPersonaView__mdt'
    },
    deliveryScore: {
        dataSource:
            'Calls getDeliveryScore which evaluates multiple factors: completion velocity (items done per week), average cycle time, work-in-progress count vs. healthy thresholds, percentage of blocked items, and priority distribution. Each factor is scored 0-100 and weighted to produce the overall score. The grade (A-F) is derived from score thresholds.',
        description:
            'A 0-100 health rating for your delivery pipeline shown as an animated gauge. Breaks down into weighted factors like velocity, cycle time, WIP balance, and blocked-item ratio.',
        friendlyName: 'Delivery Score',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.IsActiveBool__c, WorkItem__c.PriorityPk__c, WorkItem__c.CreatedDate, WorkItem__c.DaysInStageNumber__c, NetworkEntity__c.Id'
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
    deliveryTimelineView: {
        dataSource:
            'Calls getTimelineData which returns active Work Items with their start/end dates, grouped by Network Entity. Stage colors come from WorkflowStage__mdt.CardColor. The timeline range is computed from the earliest start date to the latest end date of all visible items. A red dashed line marks today.',
        description:
            'A horizontal Gantt-style timeline showing active work items as bars across a calendar. Items are grouped by Network Entity and color-coded by their workflow stage. Supports week, month, and quarter zoom levels with scroll controls.',
        friendlyName: 'Timeline View',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.CreatedDate, WorkItem__c.CalculatedETADate__c, WorkItem__c.NetworkEntityId__c, WorkflowStage__mdt.CardColor'
    },
    deliveryWorkItemActionCenter: {
        dataSource:
            'Combines @wire(getRecord) for the current Work Item with @wire(getWorkflowConfig) for CMT-driven transitions. Forward and backtrack options come from WorkflowStage__mdt.ForwardTransitions and BacktrackTransitions. Missing fields are evaluated cumulatively — e.g., needing an estimate before proposal, a developer before development, and acceptance criteria before coding.',
        description:
            'Stage transition control panel on a Work Item record page. Shows the current stage with phase label, missing field warnings, forward move buttons, backtrack options, and fast-track indicators. Buttons are dynamically enabled/disabled based on field completeness.',
        friendlyName: 'Action Center',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.EstimatedHoursNumber__c, WorkItem__c.ClientPreApprovedHoursNumber__c, WorkItem__c.Developer__c, WorkItem__c.AcceptanceCriteriaTxt__c, WorkflowStage__mdt.ForwardTransitions, WorkflowStage__mdt.BacktrackTransitions'
    },
    deliveryWorkItemStageGateWarning: {
        dataSource:
            'Uses @wire(getRecord) to read the current Work Item fields in real time. Three gate checks run: (1) Sizing gate — requires Hours Estimate before proposal stages. (2) Fast Track — compares Estimate vs. Pre-Approved Hours and shows green/red light. (3) Dev Readiness — requires both Developer and Estimate before development stages.',
        description:
            'Context-sensitive alert banner on a Work Item record page. Evaluates gating rules based on the current stage and shows warnings, errors, or "fast track" green-light messages when certain fields are missing or budget conditions are met.',
        friendlyName: 'Stage Gate Warning',
        keyFields:
            'WorkItem__c.StageNamePk__c, WorkItem__c.EstimatedHoursNumber__c, WorkItem__c.ClientPreApprovedHoursNumber__c, WorkItem__c.Developer__c'
    }
};

export default class DeliveryInfoPopover extends LightningElement {
    @api componentName = '';

    @track isOpen = false;
    @track _lastRefreshed = null;

    connectedCallback() {
        this._lastRefreshed = new Date();
    }

    get info() {
        return INFO_REGISTRY[this.componentName] || null;
    }

    get hasInfo() {
        return this.info != null;
    }

    get friendlyName() {
        return this.info ? this.info.friendlyName : this.componentName;
    }

    get description() {
        return this.info ? this.info.description : '';
    }

    get dataSource() {
        return this.info ? this.info.dataSource : '';
    }

    get keyFields() {
        return this.info ? this.info.keyFields : '';
    }

    get lastRefreshedLabel() {
        if (!this._lastRefreshed) {
            return 'Unknown';
        }
        return this._lastRefreshed.toLocaleTimeString(undefined, {
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    handleToggle(event) {
        event.stopPropagation();
        this.isOpen = !this.isOpen;
        if (this.isOpen) {
            this._lastRefreshed = new Date();
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
