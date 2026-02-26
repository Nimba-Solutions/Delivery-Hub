/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";

// Update this line to include createRecord, getRecord, and getFieldValue
import { updateRecord, createRecord, getRecord, getFieldValue } from "lightning/uiRecordApi";

// Add these new imports for the current user
import USER_ID from "@salesforce/user/Id";
import USER_NAME_FIELD from "@salesforce/schema/User.Name";

import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import draftBoardSummary from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryAiController.draftBoardSummary';

const WORK_ITEM_CHANGE_CHANNEL = '/event/%%%NAMESPACE_DOT%%%Delivery_WorkItem_Change__e';

// --- Apex Imports ---
import getWorkItems from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkItemController.getWorkItems";
import linkFilesAndSync from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkItemController.linkFilesAndSync";
import getAiEnhancedWorkItemDetails from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkItemController.getAiEnhancedWorkItemDetails";
import getWorkItemETAsWithPriority from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkItemETAService.getWorkItemETAsWithPriority";
import updateWorkItemStage from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.updateWorkItemStage";
import reorderWorkItem from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.reorderWorkItem";
import createDependency from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.createDependency";
import removeDependency from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.removeDependency";
import searchForPotentialBlockers from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.searchForPotentialBlockers";
import getRequiredFieldsForStage from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkItemController.getRequiredFieldsForStage';
import getSettings from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSettingsController.getSettings';
import getWorkflowTypes from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowTypes';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';

// --- NAMESPACE BRIDGE ---
const FIELDS = {
    ID: 'Id',
    NAME: 'Name',
    BRIEF_DESC: `%%%NAMESPACED_ORG%%%BriefDescriptionTxt__c`,
    DETAILS: `%%%NAMESPACED_ORG%%%DetailsTxt__c`,
    STAGE: `%%%NAMESPACED_ORG%%%StageNamePk__c`,
    PRIORITY: `%%%NAMESPACED_ORG%%%PriorityPk__c`,
    SORT_ORDER: `%%%NAMESPACED_ORG%%%SortOrderNumber__c`,
    IS_ACTIVE:  `%%%NAMESPACED_ORG%%%IsActiveBool__c`,
    STATUS_PK:  `%%%NAMESPACED_ORG%%%StatusPk__c`,
    TAGS: `%%%NAMESPACED_ORG%%%Tags__c`,
    EPIC: `%%%NAMESPACED_ORG%%%Epic__c`,
    INTENTION: `%%%NAMESPACED_ORG%%%ClientIntentionPk__c`,
    DEV_DAYS_SIZE: `%%%NAMESPACED_ORG%%%DeveloperDaysSizeNumber__c`,
    CALCULATED_ETA: `%%%NAMESPACED_ORG%%%CalculatedETADate__c`,
    
    // NEW FIELDS FOR CARD UI
    TOTAL_LOGGED_HOURS: `%%%NAMESPACED_ORG%%%TotalLoggedHoursNumber__c`,
    ESTIMATED_HOURS: `%%%NAMESPACED_ORG%%%EstimatedHoursNumber__c`,
    PROJECTED_UAT_READY: `%%%NAMESPACED_ORG%%%ProjectedUATReadyDate__c`,
    
    CREATED_DATE: 'CreatedDate',
    DEVELOPER: `%%%NAMESPACED_ORG%%%Developer__c`,
    // Relationships
    DEP_REL_BLOCKED_BY: `%%%NAMESPACED_ORG%%%BlockedByDeps__r`,
    DEP_REL_BLOCKING: `%%%NAMESPACED_ORG%%%BlockingDeps__r`,
    BLOCKING_TICKET: `%%%NAMESPACED_ORG%%%BlockingWorkItemId__c`,
    BLOCKED_TICKET: `%%%NAMESPACED_ORG%%%BlockedWorkItemId__c`,
    WORKFLOW_TYPE: `%%%NAMESPACED_ORG%%%WorkflowTypeTxt__c`
};

export default class DeliveryHubBoard extends NavigationMixin(LightningElement) {
    @track persona = "Client";
    @track sizeMode = "equalSized";
    @track displayMode = "kanban";
    @track showModal = false;
    @track selectedRecord = null;
    @track selectedStage = null;
    @track realRecords = [];
    @track moveComment = "";
    @track recentComments = [];
    @track numDevs = 2;
    @track etaResults = [];
    @track showAllColumns = false; 
    @track showCreateModal = false;
    @track nextSortOrder = 1;
    @track overallFilter = "all";
    @track intentionFilter = "all";
    @track uploadedFileIds = [];
    @track showMode = "overall";
    @track draggedItem = {};
    @track isDragging = false;
    @track placeholder = null;
    @track AiEnhancementEnabled = true;
    @track AiEstimation = true;
    @track isAiProcessing = false;
    @track aiSuggestions = null;
    @track createWorkItemTitle = "";
    @track createWorkItemDescription = "";
    @track estimatedDaysValue = null;
    @track formFieldValues = {};
    @track showTransitionModal = false;
    @track transitionWorkItemId = null;
    @track transitionTargetStage = null;
    @track transitionRequiredFields = [];
    @track isModalOpen = false;
    @track selectedWorkItem = {};
    @track searchTerm = '';
    @track searchResults = [];
    @track isSearching = false;
    @track hasValidOpenAIKey = false;
    @track myWorkOnly = false;

    // --- CMT-DRIVEN WORKFLOW STATE ---
    @track activeWorkflowType = 'Software_Delivery';
    @track workflowTypes = [];
    @track workflowConfig = null;

    // Weekly AI summary modal
    @track showWeeklyModal = false;
    @track weeklyUpdate = '';
    @track isWeeklyLoading = false;
    @track weeklyError = '';
    @track weeklyCopied = false;

    workItemsWire;
    _empSubscription = {};

    @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME_FIELD] })
    currentUser;

    get currentUserName() {
        return getFieldValue(this.currentUser.data, USER_NAME_FIELD) || '';
    }

    connectedCallback() {
        this.loadSettings();
        this.subscribeToWorkItemChanges();
    }

    disconnectedCallback() {
        unsubscribe(this._empSubscription, () => {});
    }

    subscribeToWorkItemChanges() {
        subscribe(WORK_ITEM_CHANGE_CHANNEL, -1, () => {
            refreshApex(this.workItemsWire);
        }).then(response => {
            this._empSubscription = response;
        });
        onError(error => {
            console.error('[DeliveryHubBoard] EMP API error:', JSON.stringify(error));
        });
    }

    get weeklyCopyLabel() {
        return this.weeklyCopied ? 'Copied!' : 'Copy';
    }

    handleWeeklyUpdate() {
        this.showWeeklyModal = true;
        this.weeklyUpdate = '';
        this.weeklyError = '';
        this.weeklyCopied = false;
        this.isWeeklyLoading = true;
        draftBoardSummary()
            .then(result => { this.weeklyUpdate = result; })
            .catch(error => {
                this.weeklyError = error.body ? error.body.message : error.message;
            })
            .finally(() => { this.isWeeklyLoading = false; });
    }

    closeWeeklyModal() {
        this.showWeeklyModal = false;
    }

    handleWeeklyCopy() {
        navigator.clipboard.writeText(this.weeklyUpdate)
            .then(() => {
                this.weeklyCopied = true;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Copied',
                    message: 'Weekly update copied to clipboard.',
                    variant: 'success'
                }));
                setTimeout(() => { this.weeklyCopied = false; }, 3000); // reset label
            })
            .catch(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Copy failed',
                    message: 'Select the text manually and copy.',
                    variant: 'warning'
                }));
            });
    }

    async loadSettings() {
        try {
            const data = await getSettings();
            if (data) {
                this.AiEnhancementEnabled = data.aiSuggestionsEnabled || false;
                this.AiEstimation = data.aiEstimationEnabled || false;
                this.hasValidOpenAIKey = data.openAiApiTested || false;
            }
        } catch (error) {
            console.error('Error loading settings:', error);
        }
    }

    async createStatusComment(workItemId) {
        if (!this.moveComment || this.moveComment.trim() === "") {
            console.log('[createStatusComment] → Skipping empty comment');
            return;
        }

        const fields = {
            '%%%NAMESPACED_ORG%%%WorkItemId__c': workItemId,
            '%%%NAMESPACED_ORG%%%BodyTxt__c': this.moveComment,
            '%%%NAMESPACED_ORG%%%SourcePk__c': 'Salesforce',
            '%%%NAMESPACED_ORG%%%AuthorTxt__c': this.currentUserName 
        };

        const recordInput = { 
            // Note: apiName is a string value, so it was already fine, 
            // but the keys inside 'fields' MUST be quoted.
            apiName: '%%%NAMESPACED_ORG%%%WorkItemComment__c', 
            fields 
        };

        try {
            // Ensure createRecord is imported at the top!
            const result = await createRecord(recordInput);
            console.log('Comment created → ID:', result.id);
        } catch (error) {
            console.error('Failed to create WorkItemComment__c:', error);
            throw error;
        }
    }

    // --- CONFIGURATION MAPS REMOVED ---
    // statusColorMap, columnHeaderStyleMap, statusOwnerMap, ownerColorMap, columnDisplayNames,
    // personaColumnStatusMap, personaColumnExtensionMap, personaBoardViews,
    // transitionMap, backtrackMap are all now CMT-driven via workflowConfig.

    intentionColor = { "Will Do": "#2196F3", "Sizing Only": "#FFD54F" };
    personaAdvanceOverrides = {};
    personaBacktrackOverrides = {};

    @wire(getWorkflowTypes)
    wiredTypes({ data, error }) {
        if (data) { this.workflowTypes = data; }
        else if (error) { console.error('[DeliveryHubBoard] getWorkflowTypes error:', error); }
    }

    @wire(getWorkflowConfig, { workflowTypeName: '$activeWorkflowType' })
    wiredConfig({ data, error }) {
        if (data) { this.workflowConfig = data; }
        else if (error) { console.error('[DeliveryHubBoard] getWorkflowConfig error:', error); }
    }

    @wire(getWorkItems, { workflowType: '$activeWorkflowType' })
    wiredWorkItems(result) {
        this.workItemsWire = result;
        const { data, error } = result;
        if (data) {
            this.realRecords = [...data];
            this.loadETAs();
        } else if (error) {
            console.error("Work item wire error", error);
        }
    }

    openCreateModal() {
        const nums = (this.realRecords || [])
            .map((r) => {
                const val = r[FIELDS.SORT_ORDER] || r['delivery__SortOrderNumber__c'] || r['SortOrderNumber__c'];
                return val;
            })
            .filter((n) => n !== null && n !== undefined);
        
        this.nextSortOrder = nums.length ? Math.max(...nums) + 1 : 1;
        this.showCreateModal = true;
    }

    handleFileUpload(event) {
        const uploadedFiles = event.detail.files;
        this.uploadedFileIds.push(...uploadedFiles.map((file) => file.documentId));
    }

    handleCancelTransition() {
        this.closeModal();
    }

    closeModal() {
        this.showModal = false;
        this.selectedRecord = null;
        this.selectedStage = null;
        this.moveComment = "";
        this.isModalOpen = false;
        this.searchResults = [];
        this.searchTerm = '';
    }

    handleShowModeChange(event) {
        const selectedMode = event.currentTarget.dataset.mode;
        this.showMode = selectedMode;
        const buttons = this.template.querySelectorAll(".toolbar-button");
        buttons.forEach((button) => {
            if (button.dataset.mode === selectedMode) {
                button.classList.add("active");
            } else {
                button.classList.remove("active");
            }
        });
    }

    refreshWorkItems() {
        refreshApex(this.workItemsWire)
            .then(() => this.loadETAs())
            .catch((err) => console.error("Work item reload error", err));
    }

    get createDefaults() {
        return {
            [FIELDS.STAGE]:     'Backlog',
            [FIELDS.SORT_ORDER]: this.nextSortOrder,
            [FIELDS.PRIORITY]:  'Medium',
            [FIELDS.IS_ACTIVE]: true,
            [FIELDS.STATUS_PK]: 'New',
        };
    }

    // [Getter options]
    handleMyWorkToggle() {
        this.myWorkOnly = !this.myWorkOnly;
    }

    get myWorkButtonClass() {
        return this.myWorkOnly
            ? 'toolbar-button active my-work-btn'
            : 'toolbar-button my-work-btn';
    }

    get personaOptions() {
        const views = this.workflowConfig?.personaViews;
        if (views) return Object.keys(views).map(p => ({ label: p, value: p }));
        return ['Client', 'Consultant', 'Developer', 'QA'].map(p => ({ label: p, value: p }));
    }
    get sizeModeOptions() { return [{ label: "Equal Sized", value: "equalSized" }, { label: "Work Item Sized", value: "ticketSize" }]; }
    get hasRecentComments() { return (this.recentComments || []).length > 0; }
    get displayModeOptions() { return [{ label: "Kanban", value: "kanban" }, { label: "Compact", value: "compact" }, { label: "Table", value: "table" }]; }
    get mainBoardClass() { if (this.displayMode === "table") return "table-board"; if (this.displayMode === "compact") return "stage-columns compact"; return "stage-columns"; }
    get isTableMode() { return this.displayMode === "table"; }

    // --- ENRICHED WORK ITEMS (Namespace Agnostic & Sorted) ---
    get enrichedWorkItems() {
        const norm = (id) => (id || "").substring(0, 15);

        const etaMap = new Map(
            (this.etaResults || [])
                .filter((dto) => !!dto.workItemId)
                .map((dto) => [norm(dto.workItemId), dto])
        );

        // Helper to safely get field value regardless of namespace presence
        const getValue = (record, fieldName) => {
            if (!record) return null;
            if (record[fieldName] !== undefined) return record[fieldName];
            let localName = fieldName.replace('', '').replace('delivery__', '');
            if (record[localName] !== undefined) return record[localName];
            let nsName = 'delivery__' + localName;
            if (record[nsName] !== undefined) return record[nsName];
            return null;
        };

        // Helper to calculate day difference
        const getDayDiffString = (targetDateStr) => {
            if (!targetDateStr) return "";
            
            const today = new Date();
            today.setHours(0, 0, 0, 0); // Normalize to midnight
            
            const target = new Date(targetDateStr);
            target.setHours(0, 0, 0, 0); // Normalize to midnight
            
            // Calculate difference in milliseconds
            const diffTime = target - today;
            // Convert to days
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)); 

            if (diffDays > 0) return ` (+${diffDays}d)`;
            if (diffDays < 0) return ` (${diffDays}d)`; // Negative sign is automatic
            return " (Today)";
        };

        // 1. Sort Records Client-Side
        const sortedRecords = [...(this.realRecords || [])].sort((a, b) => {
            const orderA = getValue(a, FIELDS.SORT_ORDER) || 0;
            const orderB = getValue(b, FIELDS.SORT_ORDER) || 0;
            return orderA - orderB;
        });

        return sortedRecords.map((rec) => {
            const etaDto = etaMap.get(norm(rec.Id));

            // Extract values safely
            const briefDesc = getValue(rec, FIELDS.BRIEF_DESC);
            const details = getValue(rec, FIELDS.DETAILS);
            const priority = getValue(rec, FIELDS.PRIORITY);
            const tags = getValue(rec, FIELDS.TAGS);
            const stage = getValue(rec, FIELDS.STAGE); 
            const intention = getValue(rec, FIELDS.INTENTION);
            const size = getValue(rec, FIELDS.DEV_DAYS_SIZE);
            
            const actualHours = getValue(rec, FIELDS.TOTAL_LOGGED_HOURS) || 0;
            const estimatedHours = getValue(rec, FIELDS.ESTIMATED_HOURS) || 0;
            const uatDate = getValue(rec, FIELDS.PROJECTED_UAT_READY);
            const createdDate = getValue(rec, FIELDS.CREATED_DATE);
            const recordStoredETA = getValue(rec, FIELDS.CALCULATED_ETA);

            // --- DATE DISPLAY LOGIC ---
            let displayDate = "—";
            let dateLabel = "No Date";
            let rawDateForDiff = null; // Store the raw date to calculate the diff
            
            if (etaDto && etaDto.calculatedETA) {
                // 1. Live Calculation
                rawDateForDiff = etaDto.calculatedETA;
                displayDate = new Date(rawDateForDiff).toLocaleDateString();
                dateLabel = "Est. Completion (Live)";
            } else if (recordStoredETA) {
                // 2. Stored Value (Fallback)
                rawDateForDiff = recordStoredETA;
                // Parse date manually to avoid timezone shifts on simple YYYY-MM-DD strings
                displayDate = new Date(rawDateForDiff).toLocaleDateString(undefined, { timeZone: 'UTC' });
                dateLabel = "Est. Completion";
            } else if (createdDate) {
                // 3. Created Date
                displayDate = new Date(createdDate).toLocaleDateString();
                dateLabel = "Created";
                // We typically don't show (+5d) for created date, so we leave rawDateForDiff null
            }

            // Append day difference if we have a valid ETA date
            if (rawDateForDiff) {
                displayDate += getDayDiffString(rawDateForDiff);
            }

            // UAT Date Display
            let displayUAT = null;
            if (uatDate) {
                displayUAT = new Date(uatDate).toLocaleDateString(undefined, { month: 'short', day: 'numeric', timeZone: 'UTC' });
            }

            const hoursDisplay = `${actualHours} / ${estimatedHours}h`;

            const blockedByRaw = getValue(rec, FIELDS.DEP_REL_BLOCKED_BY) || [];
            const blockingRaw = getValue(rec, FIELDS.DEP_REL_BLOCKING) || [];

            const isBlockedBy = blockedByRaw.map(dep => ({
                id: getValue(dep, FIELDS.BLOCKING_TICKET),
                name: dep['BlockingWorkItemId__r']?.Name || dep['BlockingWorkItemId__r']?.Name || dep['BlockingWorkItemId__c'],
                dependencyId: dep.Id
            }));

            const isBlocking = blockingRaw.map(dep => ({
                id: getValue(dep, FIELDS.BLOCKED_TICKET),
                name: dep['BlockedWorkItemId__r']?.Name || dep['BlockedWorkItemId__r']?.Name || dep['BlockedWorkItemId__c'],
                dependencyId: dep.Id
            }));

            const getTagsArray = (tagsString) => {
                if (!tagsString || typeof tagsString !== "string") return [];
                return tagsString.split(",").map((tag) => tag.trim()).filter((tag) => tag);
            };

            return {
                ...rec,
                uiId: rec.Id,
                uiTitle: briefDesc,
                uiDescription: details,
                uiSize: size || "--",
                uiHours: hoursDisplay,
                uiUat: displayUAT,
                uiStage: stage,
                uiIntention: intention,
                uiPriority: priority,
                calculatedETA: displayDate,
                dateTooltip: dateLabel,
                isBlockedBy: isBlockedBy,
                isBlocking: isBlocking,
                isCurrentlyBlocked: isBlockedBy.length > 0,
                OwnerName: rec.Owner?.Name,
                uiOwnerId: rec.OwnerId || '',
                uiDeveloperId: getValue(rec, FIELDS.DEVELOPER) || '',
                isHighPriority: priority?.toLowerCase() === "high",
                tags: getTagsArray(tags),
                cardClasses: `work-item-card`,
                priorityClasses: `priority-badge priority-${priority?.toLowerCase()}`,
            };
        });
    }

    // -----------------------------------------------------------------------
    // CMT helper: stage lookup map keyed by apiValue
    // -----------------------------------------------------------------------
    get _stageMap() {
        if (!this.workflowConfig?.stages) return {};
        const map = {};
        this.workflowConfig.stages.forEach(s => { map[s.apiValue] = s; });
        return map;
    }

    // -----------------------------------------------------------------------
    // stageColumns — CMT-driven, replaces all hardcoded persona/color maps
    // -----------------------------------------------------------------------
    get stageColumns() {
        if (!this.workflowConfig) return [];

        const { type, stages, personaViews } = this.workflowConfig;
        const stageMap = this._stageMap;
        const enriched = this.enrichedWorkItems || [];

        // Phase-group filters for overallFilter
        const PREDEV_PHASES  = new Set(['Planning', 'Approval']);
        const INDEV_PHASES   = new Set(['Development', 'Testing']);
        const DEPLOYED_PHASES = new Set(['UAT', 'Deployment', 'Done']);

        const applyWorkItemFilters = (workItems, headerBg) =>
            workItems
                .filter(t => {
                    if (this.intentionFilter === 'all') return true;
                    return (t.uiIntention || '').trim().toLowerCase() === this.intentionFilter.toLowerCase();
                })
                .filter(t => {
                    if (!this.myWorkOnly) return true;
                    const uid = (USER_ID || '').substring(0, 15);
                    return (t.uiOwnerId || '').substring(0, 15) === uid ||
                           (t.uiDeveloperId || '').substring(0, 15) === uid;
                })
                .map(wi => ({ ...wi, cardStyle: `border-left-color: ${headerBg} !important;` }));

        let columns;

        if (type?.useSimplifiedView) {
            // SIMPLIFIED WORKFLOW (e.g. Loan Approval) — each stage is its own column
            columns = stages
                .filter(s => this.showAllColumns ? true : s.isVisibleByDefault)
                .map(s => {
                    const bg = s.headerBgColor || '#ffffff';
                    const color = s.headerTextColor || '#111827';
                    const columnWorkItems = applyWorkItemFilters(enriched.filter(t => t.uiStage === s.apiValue), bg);
                    return {
                        stage: s.apiValue,
                        displayName: s.displayName || s.apiValue,
                        headerStyle: `background:${bg};color:${color};`,
                        workItems: columnWorkItems,
                        bodyClasses: `kanban-column-body ${columnWorkItems.length > 0 ? 'has-items' : 'is-empty'}`
                    };
                });
        } else {
            // FULL WORKFLOW (e.g. Software Delivery) — use persona views
            const personaView = (personaViews || {})[this.persona] || [];

            columns = personaView
                .filter(col => {
                    if (!this.showAllColumns && col.isExtended) return false;
                    if (this.overallFilter === 'all') return true;
                    const colPhases = (col.stages || []).map(sv => stageMap[sv]?.phase).filter(Boolean);
                    if (this.overallFilter === 'predev')   return colPhases.some(p => PREDEV_PHASES.has(p));
                    if (this.overallFilter === 'indev')    return colPhases.some(p => INDEV_PHASES.has(p));
                    if (this.overallFilter === 'deployed') return colPhases.some(p => DEPLOYED_PHASES.has(p));
                    return true;
                })
                .map(col => {
                    const colStages = col.stages || [];
                    // Use header style from the first stage in this column
                    const firstStage = colStages.length > 0 ? stageMap[colStages[0]] : null;
                    const bg = firstStage?.headerBgColor || '#ffffff';
                    const color = firstStage?.headerTextColor || '#111827';
                    const columnWorkItems = applyWorkItemFilters(
                        enriched.filter(t => colStages.includes(t.uiStage)), bg
                    );
                    return {
                        stage: col.columnName,
                        displayName: col.columnName,
                        headerStyle: `background:${bg};color:${color};`,
                        workItems: columnWorkItems,
                        bodyClasses: `kanban-column-body ${columnWorkItems.length > 0 ? 'has-items' : 'is-empty'}`
                    };
                });
        }

        return this.showMode === 'active' ? columns.filter(col => col.workItems.length > 0) : columns;
    }

    getClientCardColor(status) {
        return this._stageMap[status]?.cardColor || '#eee';
    }

    get advanceOptions() {
        if (!this.selectedRecord || !this.workflowConfig) return [];
        const currStage = this.enrichedWorkItems.find(t => t.Id === this.selectedRecord.Id)?.uiStage;
        if (!currStage) return [];

        const stageMap = this._stageMap;
        const stageData = stageMap[currStage];
        const nextStages = stageData?.forwardTransitions || [];

        return nextStages.filter(tgt => tgt !== currStage).map(tgt => {
            const tgtData = stageMap[tgt];
            const bg = tgtData?.headerBgColor || '#e0e0e0';
            const color = tgtData?.headerTextColor || '#222';
            const icon = tgt === 'Cancelled' ? '🛑' : '➡️';
            return { value: tgt, label: tgt, icon, style: `background:${bg};color:${color};`, autofocus: false };
        });
    }

    get backtrackOptions() {
        if (!this.selectedRecord || !this.workflowConfig) return [];
        const currStage = this.enrichedWorkItems.find(t => t.Id === this.selectedRecord.Id)?.uiStage;
        if (!currStage) return [];

        const stageMap = this._stageMap;
        const stageData = stageMap[currStage];
        const prevStages = stageData?.backtrackTransitions || [];

        return prevStages.map(tgt => {
            const tgtData = stageMap[tgt];
            const bg = tgtData?.headerBgColor || '#e0e0e0';
            const color = tgtData?.headerTextColor || '#222';
            return { value: tgt, label: tgt, icon: '⬅️', style: `background:${bg};color:${color};` };
        });
    }

    // [Filter Options]
    get overallFilterOptions() { return [{ label: "All", value: "all" }, { label: "Pre-Dev", value: "predev" }, { label: "In-Dev & Review", value: "indev" }, { label: "Deployed/Done", value: "deployed" }]; }
    get intentionFilterOptions() { return [{ label: "All", value: "all" }, { label: "Will Do", value: "Will Do" }, { label: "Sizing Only", value: "Sizing Only" }]; }

    handleIntentionFilterChange(e) { this.intentionFilter = e.detail ? e.detail.value : e.target.value; }
    handleOverallFilterChange(e) { this.overallFilter = e.detail ? e.detail.value : e.target.value; }
    handleToggleColumns(e) { this.showAllColumns = e.target.checked; this.logBoardState(); }
    columnOwner(colName) {
        const personaView = (this.workflowConfig?.personaViews || {})[this.persona] || [];
        const col = personaView.find(c => c.columnName === colName);
        const firstStageApiValue = (col?.stages || [])[0];
        return this._stageMap[firstStageApiValue]?.ownerPersona || 'Default';
    }
    
    // --- LOAD ETAS ---
    handleNumDevsChange(e) { this.numDevs = parseInt(e.target.value, 10) || 1; this.loadETAs(); }
    
    loadETAs() {
        getWorkItemETAsWithPriority({
            numberOfDevs: this.numDevs,
            prioritizedWorkItemIds: null,
        })
        .then((result) => {
            this.etaResults = result && result.workItems ? [...result.workItems] : [];
        })
        .catch((err) => {
            this.etaResults = [];
            console.error("ETA error:", err);
        });
    }

    getWorkItemETA(workItemId) {
        return (this.etaResults || []).find((e) => e.workItemId === workItemId) || {};
    }

    handlePersonaChange(e) {
        this.persona = e.detail ? e.detail.value : e.target.value;
        this.logBoardState();
    }

    // FIX: Removed debugData which was causing lint error
    logBoardState() {
        setTimeout(() => {
            try {
                // Logic kept simple or removed to satisfy linter
                // const columns = this.stageColumns;
                // console.log('Board State Updated');
            } catch (error) {
                console.error('Error logging board state:', error);
            }
        }, 100);
    }

    handleSizeModeChange(e) { this.sizeMode = e.detail ? e.detail.value : e.target.value; }
    handleDisplayModeChange(e) { this.displayMode = e.detail ? e.detail.value : e.target.value; }
    
    handleTitleClick(e) {
        const id = e.currentTarget.dataset.id;
        if (id) {
            this[NavigationMixin.Navigate]({ type: "standard__recordPage", attributes: { recordId: id, objectApiName: "WorkItem__c", actionName: "view" } });
        }
    }

    handleCardClick(e) {
        const id = e.currentTarget?.dataset?.id || e.target?.dataset?.id;
        this.selectedRecord = (this.realRecords || []).find((r) => r.Id === id);
        this.selectedStage = null;
        this.showModal = true;
        this.moveComment = "";
    }

    async handleAdvanceOption(e) {
        const newStage = e.currentTarget.dataset.value; // Use currentTarget
        const workItemId = this.selectedRecord.Id;
        try {
            const requiredFields = await getRequiredFieldsForStage({ targetStage: newStage });
            if (requiredFields && requiredFields.length > 0) {
                this.closeModal();
                this.transitionWorkItemId = workItemId;
                this.transitionTargetStage = newStage;
                this.transitionRequiredFields = requiredFields;
                this.showTransitionModal = true;
            } else {
                this.selectedStage = newStage;
                this.handleSaveTransition();
            }
        } catch (error) {
            console.error('Stage Check Error:', error);
            this.showToast('Error', 'Could not check for stage requirements.', 'error');
        }
    }

    async handleBacktrackOption(e) {
        const newStage = e.target.dataset.value;
        const workItemId = this.selectedRecord.Id;
        try {
            const requiredFields = await getRequiredFieldsForStage({ targetStage: newStage });
            if (requiredFields && requiredFields.length > 0) {
                this.closeModal();
                this.transitionWorkItemId = workItemId;
                this.transitionTargetStage = newStage;
                this.transitionRequiredFields = requiredFields;
                this.showTransitionModal = true;
            } else {
                this.selectedStage = newStage;
                this.handleSaveTransition();
            }
        } catch (error) {
            this.showToast('Error', 'Could not check for stage requirements.', 'error');
        }
    }

    handleStageChange(e) { this.selectedStage = e.detail ? e.detail.value : e.target.value; }
    handleCommentChange(e) { this.moveComment = e.detail ? e.detail.value : e.target.value; }
    
    handleSaveTransition() {
        const rec = this.selectedRecord;
        const newStage = this.selectedStage;
        
        if (!rec || !newStage) {
            this.closeModal();
            return;
        }

        const fields = { 
            Id: rec.Id, 
            '%%%NAMESPACED_ORG%%%StageNamePk__c': newStage 
        };

        updateRecord({ fields })
            .then(async () => {
                let commentCreated = false;

                // this.moveComment is still valid here because we haven't closed the modal yet
                if (this.moveComment && this.moveComment.trim() !== "") {
                    try {
                        await this.createStatusComment(rec.Id);
                        commentCreated = true;
                    } catch (commentErr) {
                        console.warn('Comment creation failed but work item was updated', commentErr);
                    }
                }

                if (commentCreated) {
                    this.showToast("Success", "Work item moved and comment added.", "success");
                } else {
                    this.showToast("Success", "Work item moved to " + newStage + ".", "success");
                }

                this.refreshWorkItems(); 
                this.closeModal(); // MOVED HERE
            })
            .catch((error) => {
                console.error("Update Error:", error);
                this.showToast("Error", "Failed to update work item.", "error");
                this.closeModal(); // MOVED HERE
            });
            
        // REMOVED from here
    }

    // FIX: Removed unused event param
    async handleTransitionSuccess(event) {
        const workItemId = event.detail.id;
        let commentCreated = false;

        if (this.moveComment && this.moveComment.trim() !== "") {
            try {
                await this.createStatusComment(workItemId);
                commentCreated = true;
            } catch (err) {
                console.warn('Comment failed but stage transition succeeded', err);
                // Optionally: this.showToast('Warning', 'Comment could not be saved', 'warning');
            }
        }

        if (commentCreated) {
            this.showToast('Success', 'Work item updated and comment saved.', 'success');
        } else {
            this.showToast('Success', 'Work item moved successfully.', 'success');
        }

        this.closeTransitionModal();
        this.refreshWorkItems();
    }

    handleTransitionError(event) {
        this.showToast('Error Saving Work Item', 'Please review the fields and try again.', 'error');
        console.error('Error on transition save:', JSON.stringify(event.detail));
    }

    // [Drag Handlers]
    handleDragStart(event) {
        this.isDragging = true;
        const workItemId = event.target.dataset.id;
        event.dataTransfer.setData("text/plain", workItemId);
        event.dataTransfer.effectAllowed = "move";
        // Enriched work items are sorted; use this to find the drag item
        this.draggedItem = this.enrichedWorkItems.find((t) => t.uiId === workItemId);

        this.placeholder = document.createElement("div");
        this.placeholder.className = "drag-placeholder";
        this.placeholder.style.height = `${event.target.offsetHeight}px`;

        const board = this.template.querySelector(".js-kanban-board");
        if (board) {
            board.classList.add("drag-is-active");
        }
        setTimeout(() => {
            event.target.classList.add("is-dragging");
        }, 0);
    }

    handleDragEnd() {
        this.isDragging = false;
        const draggingCard = this.template.querySelector(".is-dragging");
        if (draggingCard) {
            draggingCard.classList.remove("is-dragging");
        }
        if (this.placeholder && this.placeholder.parentNode) {
            this.placeholder.parentNode.removeChild(this.placeholder);
        }
        this.placeholder = null;

        this.template.querySelectorAll(".kanban-column.drag-over").forEach((col) => {
            col.classList.remove("drag-over");
        });

        const board = this.template.querySelector(".js-kanban-board");
        if (board) {
            board.classList.remove("drag-is-active");
        }
    }

    handleDragOver(event) {
        event.preventDefault();
        const column = event.currentTarget.closest(".kanban-column");
        if (!column) return;

        if (!column.classList.contains("drag-over")) {
            this.template.querySelectorAll(".kanban-column.drag-over").forEach((col) => col.classList.remove("drag-over"));
            column.classList.add("drag-over");
        }

        const cardsContainer = column.querySelector(".kanban-column-body");
        const afterElement = this.getDragAfterElement(cardsContainer, event.clientY);

        if (afterElement == null) {
            cardsContainer.appendChild(this.placeholder);
        } else {
            cardsContainer.insertBefore(this.placeholder, afterElement);
        }
    }

    handleDragLeave(event) {
        const column = event.currentTarget.closest(".kanban-column");
        if (column) {
            column.classList.remove("drag-over");
        }
    }

    getDragAfterElement(container, y) {
        const draggableElements = [...container.querySelectorAll(".work-item-card:not(.is-dragging)")];
        return draggableElements.reduce((closest, child) => {
            const box = child.getBoundingClientRect();
            const offset = y - box.top - box.height / 2;
            if (offset < 0 && offset > closest.offset) {
                return { offset: offset, element: child };
            } else {
                return closest;
            }
        }, { offset: Number.NEGATIVE_INFINITY }).element;
    }

    // --- UPDATED DROP HANDLER ---
    async handleDrop(event) {
        event.preventDefault();
        const workItemId = this.draggedItem.uiId;
        const dropColumnEl = event.target.closest('.kanban-column');
        
        if (!dropColumnEl) {
            this.handleDragEnd();
            return;
        }

        const targetColumnStage = dropColumnEl.dataset.stage;

        // 1. Get the internal Salesforce Picklist value for this column (via CMT persona views)
        const personaView = (this.workflowConfig?.personaViews || {})[this.persona] || [];
        const col = personaView.find(c => c.columnName === targetColumnStage);
        const newInternalStage = (col?.stages || [])[0];
        if (!newInternalStage) {
            this.handleDragEnd();
            this.showToast('Error', 'Invalid target stage.', 'error');
            return;
        }

        // 2. Calculate the INTEGER Index where the user dropped the card
        const columnWorkItems = this.stageColumns.find(c => c.stage === targetColumnStage).workItems || [];
        let dropIndex = columnWorkItems.length; // Default to end

        // FIX: Calculate position BEFORE calling handleDragEnd (which destroys the placeholder)
        if (this.placeholder && this.placeholder.parentNode) {
            const nextSibling = this.placeholder.nextElementSibling;
            if (nextSibling) {
                const nextId = nextSibling.dataset.id;
                // Find index of that work item in the data array
                const indexInData = columnWorkItems.findIndex(t => t.uiId === nextId);
                // If we found the neighbor, put our work item at that index.
                if (indexInData !== -1) {
                    dropIndex = indexInData;
                }
            } else {
                // No next sibling means we dropped at the very bottom
                dropIndex = columnWorkItems.length;
            }
        }

        // 3. NOW it is safe to cleanup the drag visuals
        this.handleDragEnd();

        // 4. Call Apex to Reorder
        try {
            await reorderWorkItem({
                workItemId: workItemId,
                newStage: newInternalStage,
                newIndex: dropIndex
            });
            this.showToast('Success', 'Work item moved.', 'success');
            this.refreshWorkItems();
        } catch (error) {
            const errorMessage = error.body?.message || 'An unknown error occurred.';
            this.showToast('Move Failed', errorMessage, 'error');
        }
    }

    // 3. ADD this new helper function to calculate sort order
    calculateNewSortOrder(placeholder, columnWorkItems) {
        const prevSibling = placeholder.previousElementSibling;
        const nextSibling = placeholder.nextElementSibling;

        // Find the corresponding work item data for the siblings
        const prevWorkItem = prevSibling
            ? columnWorkItems.find((t) => t.uiId === prevSibling.dataset.id)
            : null;
        const nextWorkItem = nextSibling
            ? columnWorkItems.find((t) => t.uiId === nextSibling.dataset.id)
            : null;

        // FIX: Handle namespace for SortOrder here too using our new safe patterns or direct access
        const getSort = (t) => t[FIELDS.SORT_ORDER] || t['delivery__SortOrderNumber__c'] || t['SortOrderNumber__c'] || 0;

        const sortBefore = prevWorkItem ? getSort(prevWorkItem) : 0;

        if (nextWorkItem) {
            return (sortBefore + getSort(nextWorkItem)) / 2.0;
        } else {
            return sortBefore + 1;
        }
    }
    
    // --- NEW: Handle Create Submit to force Defaults ---
    handleCreateSubmit(event) {
        event.preventDefault(); 
        const fields = event.detail.fields;
        
        // Force defaults (namespaced keys)
        fields[FIELDS.IS_ACTIVE]     = true;
        fields[FIELDS.STATUS_PK]     = 'New';
        fields[FIELDS.WORKFLOW_TYPE] = this.activeWorkflowType;
        if (!fields[FIELDS.PRIORITY]) {
            fields[FIELDS.PRIORITY] = 'Medium';
        }

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }
    
    handleCreateCancel() {
        this.showCreateModal = false;
        this.aiSuggestions = null;
        this.isAiProcessing = false;
        this.createWorkItemTitle = "";
        this.createWorkItemDescription = "";
        this.formFieldValues = {};
    }

    handleCreateSuccess(event) {
        this.showCreateModal = false;
        const newWorkItemId = event.detail.id;

        if (this.uploadedFileIds.length > 0) {
            linkFilesAndSync({
                workItemId: newWorkItemId,
                contentDocumentIds: this.uploadedFileIds,
            }).catch((error) => {
                console.error("Error linking files:", error);
            });
            this.uploadedFileIds = [];
        }

        this.aiSuggestions = null;
        this.isAiProcessing = false;
        this.createWorkItemTitle = "";
        this.createWorkItemDescription = "";
        this.formFieldValues = {};

        this.refreshWorkItems();
    }
    
    // ... [Search Handlers & AI Handlers (handleFieldChange, handleAiEnhance, applyAiSuggestions, setFieldValue, dismissAiSuggestions)] ...
    
    handleFieldChange(event) {
        const fieldName = event.target.fieldName;
        const fieldValue = event.target.value;
    
        this.formFieldValues[fieldName] = fieldValue;
    
        if (fieldName === FIELDS.BRIEF_DESC) {
            this.createWorkItemTitle = fieldValue || "";
        } else if (fieldName === FIELDS.DETAILS) {
            this.createWorkItemDescription = fieldValue || "";
        }
    }

    // FIX: Removed unused event param
    async handleAiEnhance() {
        try {
            let titleValue = "";
            let descriptionValue = "";
    
            titleValue = this.formFieldValues[FIELDS.BRIEF_DESC] || "";
            descriptionValue = this.formFieldValues[FIELDS.DETAILS] || "";
    
            if (!titleValue || !descriptionValue) {
                const titleField = this.template.querySelector(
                    `lightning-input-field[field-name="${FIELDS.BRIEF_DESC}"]`
                );
                const descriptionField = this.template.querySelector(
                    `lightning-input-field[field-name="${FIELDS.DETAILS}"]`
                );
    
                if (titleField && !titleValue) {
                    const titleInput = titleField.querySelector("input, textarea");
                    titleValue = titleInput ? titleInput.value || "" : "";
                }
                if (descriptionField && !descriptionValue) {
                    const descInput = descriptionField.querySelector("input, textarea");
                    descriptionValue = descInput ? descInput.value || "" : "";
                }
            }
            
            if (!titleValue) titleValue = this.createWorkItemTitle || "";
            if (!descriptionValue) descriptionValue = this.createWorkItemDescription || "";

            this.createWorkItemTitle = titleValue;
            this.createWorkItemDescription = descriptionValue;

            if (!titleValue.trim() && !descriptionValue.trim()) {
                this.showToast("Input Required", "Please provide a title or description.", "warning");
                return;
            }

            if (this.isAiProcessing) return;

            this.isAiProcessing = true;
            this.aiSuggestions = null;

            const result = await Promise.race([
                getAiEnhancedWorkItemDetails({
                    currentTitle: this.createWorkItemTitle,
                    currentDescription: this.createWorkItemDescription,
                }),
                new Promise((_, reject) => setTimeout(() => reject(new Error("Request timeout")), 30000))
            ]);

            if (!result || typeof result !== "object" || (!result.title && !result.description)) {
                throw new Error("AI service returned empty/invalid suggestions");
            }

            this.aiSuggestions = result;
            this.showToast("Success", "AI suggestions generated successfully!", "success");

        } catch (error) {
            let errorMessage = "Could not retrieve AI suggestions.";
            if (error.body && error.body.message) errorMessage = error.body.message;
            this.showToast("AI Error", errorMessage, "error");
            console.error("AI Enhancement Error:", error);
        } finally {
            this.isAiProcessing = false;
        }
    }
    
    applyAiSuggestions() {
        try {
            if (!this.aiSuggestions) {
                this.showToast("Error", "No AI suggestions available.", "error");
                return;
            }
            
            if (this.aiSuggestions.title) {
                this.createWorkItemTitle = this.aiSuggestions.title;
                this.formFieldValues[FIELDS.BRIEF_DESC] = this.aiSuggestions.title;
            }
            if (this.aiSuggestions.description) {
                this.createWorkItemDescription = this.aiSuggestions.description;
                this.formFieldValues[FIELDS.DETAILS] = this.aiSuggestions.description;
            }
            if (this.aiSuggestions.estimatedDays && this.AiEstimation) {
                this.estimatedDaysValue = this.aiSuggestions.estimatedDays;
                this.formFieldValues[FIELDS.DEV_DAYS_SIZE] = this.aiSuggestions.estimatedDays;
            }
            
            // Re-render inputs to show values
             setTimeout(() => {
                this.template.querySelectorAll("lightning-input-field").forEach((field) => {
                    field.dispatchEvent(new CustomEvent("change", { bubbles: true }));
                });
            }, 100);
            
            this.aiSuggestions = null;
            this.showToast("Success", "AI suggestions applied.", "success");
        } catch (error) {
             this.showToast("Error", "Failed to apply AI suggestions.", "error");
        }
    }
    
    setFieldValue(fieldName, value) {
        if (!value) return;
        const inputField = this.template.querySelector(`lightning-input-field[field-name="${fieldName}"]`);
        if (inputField) {
            inputField.value = value;
        }
    }

    dismissAiSuggestions() { this.aiSuggestions = null; }
    
    handleSearchTermChange(event) { this.searchTerm = event.target.value; }

    // FIX: Added logging to empty catch blocks to satisfy linter
    async handleSearch() {
        if (this.searchTerm.length < 3) return;
        this.isSearching = true;
        const existingDependencyIds = [
            ...this.selectedWorkItem.isBlockedBy.map(d => d.id),
            ...this.selectedWorkItem.isBlocking.map(d => d.id)
        ];
        try {
            this.searchResults = await searchForPotentialBlockers({
                searchTerm: this.searchTerm,
                currentWorkItemId: this.selectedWorkItem.Id,
                existingDependencyIds: existingDependencyIds,
                workflowType: this.activeWorkflowType
            });
        } catch (error) { 
            console.error('Search error:', error);
        } finally { 
            this.isSearching = false; 
        }
    }

    async handleSelectBlockingWorkItem(event) {
        const blockingWorkItemId = event.currentTarget.dataset.blockingId;
        try {
            await createDependency({ blockedWorkItemId: this.selectedWorkItem.Id, blockingWorkItemId: blockingWorkItemId });
            this.closeModal();
            this.refreshWorkItems();
        } catch (error) { 
            console.error('Dependency create error:', error);
        }
    }

    async handleRemoveDependency(event) {
        const dependencyId = event.currentTarget.dataset.dependencyId;
        try {
            await removeDependency({ dependencyId: dependencyId });
            this.closeModal();
            this.refreshWorkItems();
        } catch (error) { 
            console.error('Dependency remove error:', error);
        }
    }

    // [Dependency Management & Search]
    handleManageDependenciesClick(event) {
        const workItemId = event.currentTarget.dataset.id;
        this.selectedWorkItem = this.enrichedWorkItems.find(t => t.uiId === workItemId);
        if (this.selectedWorkItem) {
            this.isModalOpen = true;
        }
    }

    // --- WORKFLOW TYPE TOGGLE ---
    get hasMultipleWorkflows() { return (this.workflowTypes || []).length > 1; }

    handleWorkflowTypeChange(event) {
        this.activeWorkflowType = event.currentTarget.dataset.type;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    
    // [Modal & Transition Handlers]
    closeTransitionModal() {
        this.showTransitionModal = false;
        this.transitionWorkItemId = null;
        this.transitionTargetStage = null;
        this.transitionRequiredFields = [];
    }
}