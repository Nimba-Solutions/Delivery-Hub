/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getClientDashboard from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getClientDashboard';
import getReportIds from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getReportIds';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';
import USER_ID from '@salesforce/user/Id';
import FIRST_NAME_FIELD from '@salesforce/schema/User.FirstName';

// Fallback phase order used when CMT config is not yet loaded
const FALLBACK_PHASE_ORDER = ['Planning', 'Approval', 'Development', 'Testing', 'UAT', 'Deployment'],
    HOUR_NOON = 12,
    HOUR_EVENING = 17,
    DAYS_IN_WEEK = 7,
    WEEK_END_OFFSET = 6,
    EMPTY = 0,
    FIRST_INDEX = 0,
    SINGLE_ITEM = 1,
    FIRST_DAY = 1,
    LAST_DAY_OFFSET = 0,
    MONTH_OFFSET = 1,
    PHASE_LIST_VIEWS = {
        Approval: 'WorkItems_Approval',
        Deployment: 'WorkItems_Deployment',
        Development: 'WorkItems_Development',
        Planning: 'WorkItems_Planning',
        Testing: 'WorkItems_Testing',
        UAT: 'WorkItems_UAT'
    },
    // Maps phase name to badge CSS modifier (for attention work item styling)
    PHASE_BADGE_SUFFIX = {
        Approval: 'approval',
        Deployment: 'signoff',
        UAT: 'uat'
    };

export default class DeliveryClientDashboard extends NavigationMixin(LightningElement) { // eslint-disable-line new-cap
    @api hideAttentionSection = false;
    @api hideInFlightSection = false;
    @api hideRecentSection = false;
    @api hideThisWeekSection = false;

    @track selectedTimeRange = 'thisWeek';
    @track activeWorkflowType = 'Software_Delivery';
    @track attentionWorkItems = [];
    @track phases = [];
    @track recentWorkItems = [];
    @track thisWeek = null;
    @track isLoading = true;
    @track announcements = [];
    @track inFlightCollapsed = false;
    @track recentCollapsed = false;
    @track thisWeekCollapsed = false;
    @track workflowConfig = null;
    @track reportIds = {};

    wiredDashboardResult;
    pendingData = null;

    @wire(getRecord, { recordId: USER_ID, fields: [FIRST_NAME_FIELD] })
    wiredUser;

    connectedCallback() {
        getReportIds({ developerNames: [
            'Recently_Completed', 'In_Flight_Work_Items', 'Blocked_Work_Items',
            'Monthly_Hours', 'Attention_Items',
            'WorkItems_Planning', 'WorkItems_Approval', 'WorkItems_Development',
            'WorkItems_Testing', 'WorkItems_UAT', 'WorkItems_Deployment'
        ]}).then(data => {
            this.reportIds = data;
        }).catch(() => {
            // Report IDs not available — navigation will fall back to list views
        });
    }

    @wire(getWorkflowConfig, { workflowTypeName: '$activeWorkflowType' })
    wiredConfig({ data }) {
        if (data) {
            this.workflowConfig = data;
            // If dashboard data arrived before config, process it now
            if (this.pendingData) {
                this.processData(this.pendingData);
                this.pendingData = null;
            }
        }
    }

    @wire(getClientDashboard, { timeRange: '$selectedTimeRange', workflowType: '$activeWorkflowType' })
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        const { data, error } = result;
        if (data) {
            if (this.workflowConfig) {
                this.processData(data);
            } else {
                // Wait for config
                this.pendingData = data;
            }
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
        }
    }

    // CMT-driven badge class for a given stage
    getBadgeClass(stage) {
        const stageData = (this.workflowConfig?.stages || []).find(stg => stg.apiValue === stage),
            phase = stageData?.phase,
            suffix = PHASE_BADGE_SUFFIX[phase] || null,
            base = 'slds-badge slds-badge_lightest stage-badge';
        if (suffix) {
            return `${base} stage-badge--${suffix}`;
        }
        return base;
    }

    // CMT-driven phase order (distinct non-terminal phases in CMT sort order)
    get phaseOrder() {
        if (!this.workflowConfig?.stages) {
            return FALLBACK_PHASE_ORDER;
        }
        const seen = new Set(),
            order = [];
        this.workflowConfig.stages.forEach(stg => {
            if (!stg.isTerminal && stg.phase && !seen.has(stg.phase)) {
                seen.add(stg.phase);
                order.push(stg.phase);
            }
        });
        if (order.length > EMPTY) {
            return order;
        }
        return FALLBACK_PHASE_ORDER;
    }

    processData(data) {
        this.attentionWorkItems = this.buildAttentionItems(data.attentionWorkItems || []);
        this.phases = this.buildPhases(data.phases || []);
        this.recentWorkItems = DeliveryClientDashboard.buildRecentItems(data.recentWorkItems || []);
        this.announcements = DeliveryClientDashboard.buildAnnouncements(data.announcements || []);
        this.thisWeek = DeliveryClientDashboard.buildThisWeekMetrics(data.thisWeek);
    }

    // Attention work items (pre-sorted by attention score from Apex)
    buildAttentionItems(items) {
        return items.map(item => ({
            attentionScore: item.attentionScore || EMPTY,
            badgeClass: this.getBadgeClass(item.stage),
            daysInStage: item.daysInStage || EMPTY,
            id: item.id,
            name: item.name,
            priority: item.priority || '',
            scoreLabel: DeliveryClientDashboard.formatScoreLabel(item),
            stage: item.stage,
            title: item.title || null,
            urgency: item.urgency || 'low',
            urgencyClass: `urgency-dot urgency-dot--${item.urgency || 'low'}`
        }));
    }

    buildPhases(phaseData) {
        const phaseCounts = {};
        phaseData.forEach(phaseItem => {
            phaseCounts[phaseItem.label] = phaseItem.count || EMPTY;
        });

        const largePhase = !this.hasAttentionItems;
        return this.phaseOrder.map(label => {
            const count = phaseCounts[label] || EMPTY;
            let colClass = 'slds-col slds-size_1-of-3 slds-m-bottom_x-small';
            if (largePhase) {
                colClass = 'slds-col slds-size_1-of-2 slds-m-bottom_x-small';
            }
            let activeClass = 'phase-tile--empty';
            if (count > EMPTY) {
                activeClass = 'phase-tile--active';
            }
            let sizeClass = '';
            if (largePhase) {
                sizeClass = 'phase-tile--large';
            }
            return {
                colClass,
                count,
                label,
                tileClass: [
                    'phase-tile phase-tile--btn slds-box slds-box_x-small slds-text-align_center',
                    activeClass,
                    sizeClass
                ].join(' ').trim()
            };
        });
    }

    // Recent work items (includes both work items and comments)
    static buildRecentItems(items) {
        return items.map(item => ({
            id: item.id,
            isComment: item.isComment || false,
            lastModified: item.lastModified,
            name: item.name,
            stage: item.stage,
            title: item.title || null
        }));
    }

    // Vendor announcements (one per active vendor with a message)
    static buildAnnouncements(items) {
        return items.map((text, idx) => ({
            key: idx,
            text
        }));
    }

    static buildThisWeekMetrics(weekData) {
        if (!weekData) {
            return null;
        }
        return {
            blocked: weekData.blocked || EMPTY,
            completed: weekData.completed || EMPTY,
            hoursLogged: weekData.hoursLogged || EMPTY,
            moved: weekData.moved || EMPTY
        };
    }

    static formatScoreLabel(item) {
        const parts = [];
        if (item.daysInStage > EMPTY) {
            parts.push(`${item.daysInStage}d`);
        }
        if (item.priority) {
            parts.push(item.priority);
        }
        return parts.join(' \u00b7 ');
    }

    get showAttentionSection() {
        return !this.hideAttentionSection;
    }

    get showInFlightSection() {
        return !this.hideInFlightSection;
    }

    get showRecentSection() {
        return !this.hideRecentSection;
    }

    get showThisWeekSection() {
        return !this.hideThisWeekSection;
    }

    get isLoaded() {
        return !this.isLoading;
    }

    get inFlightExpanded() {
        return !this.inFlightCollapsed;
    }

    get recentExpanded() {
        return !this.recentCollapsed;
    }

    get thisWeekExpanded() {
        return !this.thisWeekCollapsed;
    }

    get hasAttentionItems() {
        return this.attentionWorkItems && this.attentionWorkItems.length > EMPTY;
    }

    get hasRecentItems() {
        return this.recentWorkItems && this.recentWorkItems.length > EMPTY;
    }

    get hasAnnouncements() {
        return this.announcements && this.announcements.length > EMPTY;
    }

    get attentionCount() {
        if (this.attentionWorkItems) {
            return this.attentionWorkItems.length;
        }
        return EMPTY;
    }

    get greeting() {
        const hour = new Date().getHours();
        if (hour < HOUR_NOON) {
            return 'Good morning';
        }
        if (hour < HOUR_EVENING) {
            return 'Good afternoon';
        }
        return 'Good evening';
    }

    get firstName() {
        return getFieldValue(this.wiredUser && this.wiredUser.data, FIRST_NAME_FIELD) || '';
    }

    get greetingLine() {
        let name = '';
        if (this.firstName) {
            name = `, ${this.firstName}`;
        }
        if (this.isLoading) {
            return `${this.greeting}${name}`;
        }
        if (this.hasAttentionItems) {
            const count = this.attentionCount;
            let plural = 's',
                verb = '';
            if (count === SINGLE_ITEM) {
                plural = '';
                verb = 's';
            }
            return `${this.greeting}${name} \u2014 ${count} item${plural} need${verb} your attention`;
        }
        return `${this.greeting}${name} \u2014 You\u2019re all caught up`;
    }

    get greetingSubtext() {
        if (this.hasAttentionItems) {
            return 'Review the work items below and take action to keep your project moving.';
        }
        return 'Nothing is waiting on you right now. Check back after your team makes progress.';
    }

    get greetingClass() {
        if (this.hasAttentionItems) {
            return 'cd-greeting cd-greeting--attention';
        }
        return 'cd-greeting cd-greeting--clean';
    }

    get hasThisWeek() {
        return this.thisWeek !== undefined && this.thisWeek !== null;
    }

    timeRangeOptions = [
        { label: 'This Week', value: 'thisWeek' },
        { label: 'Last Week', value: 'lastWeek' },
        { label: 'This Month', value: 'thisMonth' }
    ];

    get timeRangeLabel() {
        const match = this.timeRangeOptions.find(opt => opt.value === this.selectedTimeRange);
        if (match) {
            return match.label;
        }
        return 'This Week';
    }

    get inFlightChevronIcon() {
        if (this.inFlightCollapsed) {
            return 'utility:chevronright';
        }
        return 'utility:chevrondown';
    }

    get recentChevronIcon() {
        if (this.recentCollapsed) {
            return 'utility:chevronright';
        }
        return 'utility:chevrondown';
    }

    get thisWeekChevronIcon() {
        if (this.thisWeekCollapsed) {
            return 'utility:chevronright';
        }
        return 'utility:chevrondown';
    }

    toggleInFlight() {
        this.inFlightCollapsed = !this.inFlightCollapsed;
    }

    toggleRecent() {
        this.recentCollapsed = !this.recentCollapsed;
    }

    toggleThisWeek() {
        this.thisWeekCollapsed = !this.thisWeekCollapsed;
    }

    handleTimeRangeChange(event) {
        this.selectedTimeRange = event.detail.value;
    }

    handleWorkItemClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
            attributes: {
                actionName: 'view',
                objectApiName: '%%%NAMESPACED_ORG%%%WorkItem__c',
                recordId
            },
            type: 'standard__recordPage'
        });
    }

    handlePhaseClick(event) {
        const phase = event.currentTarget.dataset.phase,
            listView = PHASE_LIST_VIEWS[phase];
        if (!listView) {
            return;
        }
        this.navigateToReport(listView, listView);
    }

    getDateRange() {
        const now = new Date();
        let start,
            end;
        if (this.selectedTimeRange === 'lastWeek') {
            const dayOfWeek = now.getDay();
            start = new Date(now);
            start.setDate(now.getDate() - dayOfWeek - DAYS_IN_WEEK);
            end = new Date(start);
            end.setDate(start.getDate() + WEEK_END_OFFSET);
        } else if (this.selectedTimeRange === 'thisMonth') {
            start = new Date(now.getFullYear(), now.getMonth(), FIRST_DAY);
            end = new Date(now.getFullYear(), now.getMonth() + MONTH_OFFSET, LAST_DAY_OFFSET);
        } else {
            // ThisWeek (default) — Sunday to Saturday
            const dayOfWeek = now.getDay();
            start = new Date(now);
            start.setDate(now.getDate() - dayOfWeek);
            end = new Date(start);
            end.setDate(start.getDate() + WEEK_END_OFFSET);
        }
        const formatDate = dateObj => dateObj.toISOString().split('T')[FIRST_INDEX];
        return { end: formatDate(end), start: formatDate(start) };
    }

    navigateToReport(reportDevName, fallbackListView, fallbackObject) {
        const reportId = this.reportIds[reportDevName];
        if (reportId) {
            this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
                attributes: {
                    actionName: 'view',
                    objectApiName: 'Report',
                    recordId: reportId
                },
                type: 'standard__recordPage'
            });
        } else {
            this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
                attributes: {
                    actionName: 'list',
                    objectApiName: fallbackObject || '%%%NAMESPACED_ORG%%%WorkItem__c'
                },
                state: { filterName: fallbackListView },
                type: 'standard__objectPage'
            });
        }
    }

    handleCompletedClick() {
        this.navigateToReport('Recently_Completed', 'Recently_Completed');
    }

    handleInProgressClick() {
        this.navigateToReport('In_Flight_Work_Items', 'In_Flight');
    }

    handleHoursClick() {
        const reportId = this.reportIds.Monthly_Hours;
        if (reportId) {
            const { start, end } = this.getDateRange();
            this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
                attributes: {
                    url: `/lightning/r/Report/${reportId}/view?fv0=${start}&fv1=${end}`
                },
                type: 'standard__webPage'
            });
        } else {
            this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
                attributes: {
                    actionName: 'list',
                    objectApiName: '%%%NAMESPACED_ORG%%%WorkLog__c'
                },
                state: { filterName: 'This_Month' },
                type: 'standard__objectPage'
            });
        }
    }

    handleBlockedClick() {
        this.navigateToReport('Blocked_Work_Items', 'Blocked');
    }

    handleViewAllAttention() {
        this.navigateToReport('Attention_Items', 'In_Flight');
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredDashboardResult).then(() => {
            this.isLoading = false;
        });
    }
}
