/* eslint-disable no-underscore-dangle, one-var, class-methods-use-this */
import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getGuideContext from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGuideController.getGuideContext';

const PERSONAS = [
    { label: 'All Roles', value: '' },
    { label: 'Developer', value: 'Developer' },
    { label: 'Project Manager', value: 'Project Manager' },
    { label: 'Client', value: 'Client' },
    { label: 'Admin', value: 'Admin' }
];

/*
 * Section configuration.
 * Each entry defines a section key, its relevant personas, and an optional
 * navigation target so users can jump directly to the feature.
 * navType values:
 *   'tab'        - NavigationMixin to a named tab
 *   'objectList' - NavigationMixin to an object's list view (Recent)
 *   null         - no deep-link (informational sections)
 */
const SECTION_CONFIG = [
    {
        key: 'welcome',
        navLabel: null,
        navTarget: null,
        navType: null,
        personas: ['Developer', 'Project Manager', 'Client', 'Admin']
    },
    {
        key: 'board',
        navLabel: 'Open Board',
        navTarget: 'Delivery_Board',
        navType: 'tab',
        personas: ['Developer', 'Project Manager', 'Client', 'Admin']
    },
    {
        key: 'workItems',
        navLabel: 'View Work Items',
        navTarget: 'WorkItem__c',
        navType: 'objectList',
        personas: ['Developer', 'Project Manager', 'Admin']
    },
    {
        key: 'timeTracking',
        navLabel: null,
        navTarget: null,
        navType: null,
        personas: ['Developer', 'Project Manager', 'Client', 'Admin']
    },
    {
        key: 'documents',
        navLabel: 'View Documents',
        navTarget: 'DeliveryDocument__c',
        navType: 'objectList',
        personas: ['Project Manager', 'Client', 'Admin']
    },
    {
        key: 'activityFeed',
        navLabel: 'Open Activity Feed',
        navTarget: 'Delivery_Activity',
        navType: 'tab',
        personas: ['Developer', 'Project Manager', 'Client', 'Admin']
    },
    {
        key: 'ghostRecorder',
        navLabel: null,
        navTarget: null,
        navType: null,
        personas: ['Developer', 'Admin']
    },
    {
        key: 'sync',
        navLabel: 'View Sync Items',
        navTarget: 'SyncItem__c',
        navType: 'objectList',
        personas: ['Admin']
    },
    {
        key: 'portal',
        navLabel: null,
        navTarget: null,
        navType: null,
        personas: ['Project Manager', 'Client', 'Admin']
    },
    {
        key: 'settings',
        navLabel: 'Open Settings',
        navTarget: 'DeliveryHubSettings',
        navType: 'tab',
        personas: ['Admin']
    },
    {
        key: 'timeline',
        navLabel: 'Open Timeline',
        navTarget: 'Delivery_Timeline',
        navType: 'tab',
        personas: ['Developer', 'Project Manager', 'Admin']
    },
    {
        key: 'savedFilters',
        navLabel: 'Open Board',
        navTarget: 'Delivery_Board',
        navType: 'tab',
        personas: ['Developer', 'Project Manager']
    },
    {
        key: 'docVersioning',
        navLabel: 'View Documents',
        navTarget: 'DeliveryDocument__c',
        navType: 'objectList',
        personas: ['Project Manager', 'Admin']
    },
    {
        key: 'invoiceApproval',
        navLabel: 'View Documents',
        navTarget: 'DeliveryDocument__c',
        navType: 'objectList',
        personas: ['Client', 'Admin']
    },
    {
        key: 'portalTimeEntry',
        navLabel: null,
        navTarget: null,
        navType: null,
        personas: ['Client']
    },
    {
        key: 'emailInbound',
        navLabel: null,
        navTarget: null,
        navType: null,
        personas: ['Developer', 'Project Manager', 'Client']
    },
    {
        key: 'platformEvents',
        navLabel: null,
        navTarget: null,
        navType: null,
        personas: ['Developer', 'Admin']
    },
    {
        key: 'configurableSettings',
        navLabel: 'Open Settings',
        navTarget: 'DeliveryHubSettings',
        navType: 'tab',
        personas: ['Admin']
    },
    {
        key: 'pdfHyperlinks',
        navLabel: 'View Documents',
        navTarget: 'DeliveryDocument__c',
        navType: 'objectList',
        personas: ['Project Manager', 'Admin']
    },
    {
        key: 'hideEmptyColumns',
        navLabel: 'Open Board',
        navTarget: 'Delivery_Board',
        navType: 'tab',
        personas: ['Developer', 'Project Manager']
    },
    {
        key: 'appLogo',
        navLabel: null,
        navTarget: null,
        navType: null,
        personas: ['Admin']
    }
];

const SECTION_KEYS = SECTION_CONFIG.map(sec => sec.key),
    /* Build fast look-ups from the config array */
    sectionMap = Object.fromEntries(SECTION_CONFIG.map(sec => [sec.key, sec]));

export default class DeliveryGuide extends NavigationMixin(LightningElement) {
    @track _expanded = { welcome: true };
    @track _selectedPersona = '';
    guideContext;
    error;

    personaOptions = PERSONAS;

    @wire(getGuideContext)
    wiredContext({ data, error }) {
        if (data) {
            this.guideContext = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.guideContext = undefined;
        }
    }

    /* ── Persona filter ── */

    get selectedPersonaLabel() {
        const found = PERSONAS.find(opt => opt.value === this._selectedPersona);
        if (found) {
            return found.label;
        }
        return 'All Roles';
    }

    get isFiltered() {
        return this._selectedPersona !== '';
    }

    handlePersonaChange(event) {
        const { value } = event.detail;
        this._selectedPersona = value;
    }

    /* ── Section visibility based on persona ── */

    _isVisibleForPersona(key) {
        if (!this._selectedPersona) {
            return true;
        }
        const cfg = sectionMap[key];
        if (cfg) {
            return cfg.personas.includes(this._selectedPersona);
        }
        return true;
    }

    _isRecommended(key) {
        if (!this._selectedPersona) {
            return false;
        }
        const cfg = sectionMap[key];
        if (cfg) {
            return cfg.personas.includes(this._selectedPersona);
        }
        return false;
    }

    /* ── Deep-link navigation ── */

    _hasNavLink(key) {
        const cfg = sectionMap[key];
        return Boolean(cfg) && cfg.navType !== null;
    }

    _getNavLabel(key) {
        const cfg = sectionMap[key];
        if (cfg) {
            return cfg.navLabel;
        }
        return null;
    }

    handleNavigate(event) {
        event.stopPropagation();
        const { key } = event.currentTarget.dataset;
        const cfg = sectionMap[key];
        if (!cfg || !cfg.navType) {
            return;
        }

        if (cfg.navType === 'tab') {
            this[NavigationMixin.Navigate]({
                attributes: { apiName: cfg.navTarget },
                type: 'standard__navItemPage'
            });
        } else if (cfg.navType === 'objectList') {
            this[NavigationMixin.Navigate]({
                attributes: {
                    actionName: 'list',
                    objectApiName: cfg.navTarget
                },
                state: { filterName: 'Recent' },
                type: 'standard__objectPage'
            });
        }
    }

    /* ── Section toggle ── */

    handleSectionToggle(event) {
        const { key } = event.currentTarget.dataset;
        this._expanded = { ...this._expanded, [key]: !this._expanded[key] };
    }

    handleKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleSectionToggle(event);
        }
    }

    handleExpandAll() {
        const all = {};
        SECTION_KEYS.forEach(sKey => {
            if (this._isVisibleForPersona(sKey)) {
                all[sKey] = true;
            }
        });
        this._expanded = all;
    }

    handleCollapseAll() {
        this._expanded = {};
    }

    handleQuickLink(event) {
        const { key } = event.currentTarget.dataset;
        this._expanded = { ...this._expanded, [key]: true };
        /* Scroll after DOM update */
        setTimeout(() => {
            const el = this.template.querySelector(`[data-section="${key}"]`);
            if (el) {
                el.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }, 100);
    }

    /* ── Per-section getters ── */

    _isOpen(key) {
        return Boolean(this._expanded[key]);
    }

    _chevron(key) {
        if (this._expanded[key]) {
            return 'utility:chevrondown';
        }
        return 'utility:chevronright';
    }

    /* Welcome */
    get welcomeExpanded() { return this._isOpen('welcome'); }
    get welcomeChevron() { return this._chevron('welcome'); }
    get welcomeVisible() { return this._isVisibleForPersona('welcome'); }
    get welcomeRecommended() { return this._isRecommended('welcome'); }
    get welcomeHasNav() { return this._hasNavLink('welcome'); }
    get welcomeNavLabel() { return this._getNavLabel('welcome'); }

    /* Board */
    get boardExpanded() { return this._isOpen('board'); }
    get boardChevron() { return this._chevron('board'); }
    get boardVisible() { return this._isVisibleForPersona('board'); }
    get boardRecommended() { return this._isRecommended('board'); }
    get boardHasNav() { return this._hasNavLink('board'); }
    get boardNavLabel() { return this._getNavLabel('board'); }

    /* WorkItems */
    get workItemsExpanded() { return this._isOpen('workItems'); }
    get workItemsChevron() { return this._chevron('workItems'); }
    get workItemsVisible() { return this._isVisibleForPersona('workItems'); }
    get workItemsRecommended() { return this._isRecommended('workItems'); }
    get workItemsHasNav() { return this._hasNavLink('workItems'); }
    get workItemsNavLabel() { return this._getNavLabel('workItems'); }

    /* TimeTracking */
    get timeTrackingExpanded() { return this._isOpen('timeTracking'); }
    get timeTrackingChevron() { return this._chevron('timeTracking'); }
    get timeTrackingVisible() { return this._isVisibleForPersona('timeTracking'); }
    get timeTrackingRecommended() { return this._isRecommended('timeTracking'); }
    get timeTrackingHasNav() { return this._hasNavLink('timeTracking'); }
    get timeTrackingNavLabel() { return this._getNavLabel('timeTracking'); }

    /* Documents */
    get documentsExpanded() { return this._isOpen('documents'); }
    get documentsChevron() { return this._chevron('documents'); }
    get documentsVisible() { return this._isVisibleForPersona('documents'); }
    get documentsRecommended() { return this._isRecommended('documents'); }
    get documentsHasNav() { return this._hasNavLink('documents'); }
    get documentsNavLabel() { return this._getNavLabel('documents'); }

    /* ActivityFeed */
    get activityFeedExpanded() { return this._isOpen('activityFeed'); }
    get activityFeedChevron() { return this._chevron('activityFeed'); }
    get activityFeedVisible() { return this._isVisibleForPersona('activityFeed'); }
    get activityFeedRecommended() { return this._isRecommended('activityFeed'); }
    get activityFeedHasNav() { return this._hasNavLink('activityFeed'); }
    get activityFeedNavLabel() { return this._getNavLabel('activityFeed'); }

    /* GhostRecorder */
    get ghostRecorderExpanded() { return this._isOpen('ghostRecorder'); }
    get ghostRecorderChevron() { return this._chevron('ghostRecorder'); }
    get ghostRecorderVisible() { return this._isVisibleForPersona('ghostRecorder'); }
    get ghostRecorderRecommended() { return this._isRecommended('ghostRecorder'); }
    get ghostRecorderHasNav() { return this._hasNavLink('ghostRecorder'); }
    get ghostRecorderNavLabel() { return this._getNavLabel('ghostRecorder'); }

    /* Sync */
    get syncExpanded() { return this._isOpen('sync'); }
    get syncChevron() { return this._chevron('sync'); }
    get syncVisible() { return this._isVisibleForPersona('sync'); }
    get syncRecommended() { return this._isRecommended('sync'); }
    get syncHasNav() { return this._hasNavLink('sync'); }
    get syncNavLabel() { return this._getNavLabel('sync'); }

    /* Portal */
    get portalExpanded() { return this._isOpen('portal'); }
    get portalChevron() { return this._chevron('portal'); }
    get portalVisible() { return this._isVisibleForPersona('portal'); }
    get portalRecommended() { return this._isRecommended('portal'); }
    get portalHasNav() { return this._hasNavLink('portal'); }
    get portalNavLabel() { return this._getNavLabel('portal'); }

    /* Settings */
    get settingsExpanded() { return this._isOpen('settings'); }
    get settingsChevron() { return this._chevron('settings'); }
    get settingsVisible() { return this._isVisibleForPersona('settings'); }
    get settingsRecommended() { return this._isRecommended('settings'); }
    get settingsHasNav() { return this._hasNavLink('settings'); }
    get settingsNavLabel() { return this._getNavLabel('settings'); }

    /* Timeline */
    get timelineExpanded() { return this._isOpen('timeline'); }
    get timelineChevron() { return this._chevron('timeline'); }
    get timelineVisible() { return this._isVisibleForPersona('timeline'); }
    get timelineRecommended() { return this._isRecommended('timeline'); }
    get timelineHasNav() { return this._hasNavLink('timeline'); }
    get timelineNavLabel() { return this._getNavLabel('timeline'); }

    /* SavedFilters */
    get savedFiltersExpanded() { return this._isOpen('savedFilters'); }
    get savedFiltersChevron() { return this._chevron('savedFilters'); }
    get savedFiltersVisible() { return this._isVisibleForPersona('savedFilters'); }
    get savedFiltersRecommended() { return this._isRecommended('savedFilters'); }
    get savedFiltersHasNav() { return this._hasNavLink('savedFilters'); }
    get savedFiltersNavLabel() { return this._getNavLabel('savedFilters'); }

    /* DocVersioning */
    get docVersioningExpanded() { return this._isOpen('docVersioning'); }
    get docVersioningChevron() { return this._chevron('docVersioning'); }
    get docVersioningVisible() { return this._isVisibleForPersona('docVersioning'); }
    get docVersioningRecommended() { return this._isRecommended('docVersioning'); }
    get docVersioningHasNav() { return this._hasNavLink('docVersioning'); }
    get docVersioningNavLabel() { return this._getNavLabel('docVersioning'); }

    /* InvoiceApproval */
    get invoiceApprovalExpanded() { return this._isOpen('invoiceApproval'); }
    get invoiceApprovalChevron() { return this._chevron('invoiceApproval'); }
    get invoiceApprovalVisible() { return this._isVisibleForPersona('invoiceApproval'); }
    get invoiceApprovalRecommended() { return this._isRecommended('invoiceApproval'); }
    get invoiceApprovalHasNav() { return this._hasNavLink('invoiceApproval'); }
    get invoiceApprovalNavLabel() { return this._getNavLabel('invoiceApproval'); }

    /* PortalTimeEntry */
    get portalTimeEntryExpanded() { return this._isOpen('portalTimeEntry'); }
    get portalTimeEntryChevron() { return this._chevron('portalTimeEntry'); }
    get portalTimeEntryVisible() { return this._isVisibleForPersona('portalTimeEntry'); }
    get portalTimeEntryRecommended() { return this._isRecommended('portalTimeEntry'); }
    get portalTimeEntryHasNav() { return this._hasNavLink('portalTimeEntry'); }
    get portalTimeEntryNavLabel() { return this._getNavLabel('portalTimeEntry'); }

    /* EmailInbound */
    get emailInboundExpanded() { return this._isOpen('emailInbound'); }
    get emailInboundChevron() { return this._chevron('emailInbound'); }
    get emailInboundVisible() { return this._isVisibleForPersona('emailInbound'); }
    get emailInboundRecommended() { return this._isRecommended('emailInbound'); }
    get emailInboundHasNav() { return this._hasNavLink('emailInbound'); }
    get emailInboundNavLabel() { return this._getNavLabel('emailInbound'); }

    /* PlatformEvents */
    get platformEventsExpanded() { return this._isOpen('platformEvents'); }
    get platformEventsChevron() { return this._chevron('platformEvents'); }
    get platformEventsVisible() { return this._isVisibleForPersona('platformEvents'); }
    get platformEventsRecommended() { return this._isRecommended('platformEvents'); }
    get platformEventsHasNav() { return this._hasNavLink('platformEvents'); }
    get platformEventsNavLabel() { return this._getNavLabel('platformEvents'); }

    /* ConfigurableSettings */
    get configurableSettingsExpanded() { return this._isOpen('configurableSettings'); }
    get configurableSettingsChevron() { return this._chevron('configurableSettings'); }
    get configurableSettingsVisible() { return this._isVisibleForPersona('configurableSettings'); }
    get configurableSettingsRecommended() { return this._isRecommended('configurableSettings'); }
    get configurableSettingsHasNav() { return this._hasNavLink('configurableSettings'); }
    get configurableSettingsNavLabel() { return this._getNavLabel('configurableSettings'); }

    /* PdfHyperlinks */
    get pdfHyperlinksExpanded() { return this._isOpen('pdfHyperlinks'); }
    get pdfHyperlinksChevron() { return this._chevron('pdfHyperlinks'); }
    get pdfHyperlinksVisible() { return this._isVisibleForPersona('pdfHyperlinks'); }
    get pdfHyperlinksRecommended() { return this._isRecommended('pdfHyperlinks'); }
    get pdfHyperlinksHasNav() { return this._hasNavLink('pdfHyperlinks'); }
    get pdfHyperlinksNavLabel() { return this._getNavLabel('pdfHyperlinks'); }

    /* HideEmptyColumns */
    get hideEmptyColumnsExpanded() { return this._isOpen('hideEmptyColumns'); }
    get hideEmptyColumnsChevron() { return this._chevron('hideEmptyColumns'); }
    get hideEmptyColumnsVisible() { return this._isVisibleForPersona('hideEmptyColumns'); }
    get hideEmptyColumnsRecommended() { return this._isRecommended('hideEmptyColumns'); }
    get hideEmptyColumnsHasNav() { return this._hasNavLink('hideEmptyColumns'); }
    get hideEmptyColumnsNavLabel() { return this._getNavLabel('hideEmptyColumns'); }

    /* AppLogo */
    get appLogoExpanded() { return this._isOpen('appLogo'); }
    get appLogoChevron() { return this._chevron('appLogo'); }
    get appLogoVisible() { return this._isVisibleForPersona('appLogo'); }
    get appLogoRecommended() { return this._isRecommended('appLogo'); }
    get appLogoHasNav() { return this._hasNavLink('appLogo'); }
    get appLogoNavLabel() { return this._getNavLabel('appLogo'); }

    /* ── Ghost Recorder detection ── */

    _buildAppStatus(app) {
        if (app.hasGhostRecorder) {
            return {
                statusClass: 'dg-app-status dg-app-status--installed',
                statusIcon: 'utility:check',
                statusLabel: 'Installed',
                statusVariant: ''
            };
        }
        return {
            statusClass: 'dg-app-status dg-app-status--missing',
            statusIcon: 'utility:close',
            statusLabel: 'Not installed',
            statusVariant: 'error'
        };
    }

    get ghostRecorderApps() {
        if (!this.guideContext?.apps) {
            return [];
        }
        return this.guideContext.apps.map(app => ({ ...app, ...this._buildAppStatus(app) }));
    }

    get appsWithoutGhostRecorder() {
        return this.ghostRecorderApps.filter(app => !app.hasGhostRecorder);
    }

    get appsWithGhostRecorder() {
        return this.ghostRecorderApps.filter(app => app.hasGhostRecorder);
    }

    get hasAppsWithoutGhostRecorder() {
        return this.appsWithoutGhostRecorder.length > 0;
    }

    get allAppsHaveGhostRecorder() {
        return this.ghostRecorderApps.length > 0 && this.appsWithoutGhostRecorder.length === 0;
    }

    get missingAppCount() {
        return this.appsWithoutGhostRecorder.length;
    }

    get setupAppManagerUrl() {
        return this.guideContext?.setupAppManager || '#';
    }

    handleOpenSetup() {
        window.open(this.setupAppManagerUrl, '_blank');
    }
}
