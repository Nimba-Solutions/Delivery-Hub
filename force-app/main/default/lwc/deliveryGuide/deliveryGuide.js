/* eslint-disable no-underscore-dangle */
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
        personas: ['Developer', 'Project Manager', 'Client', 'Admin'],
        navType: null,
        navTarget: null,
        navLabel: null
    },
    {
        key: 'board',
        personas: ['Developer', 'Project Manager', 'Client', 'Admin'],
        navType: 'tab',
        navTarget: 'Delivery_Board',
        navLabel: 'Open Board'
    },
    {
        key: 'workItems',
        personas: ['Developer', 'Project Manager', 'Admin'],
        navType: 'objectList',
        navTarget: 'WorkItem__c',
        navLabel: 'View Work Items'
    },
    {
        key: 'timeTracking',
        personas: ['Developer', 'Project Manager', 'Client', 'Admin'],
        navType: null,
        navTarget: null,
        navLabel: null
    },
    {
        key: 'documents',
        personas: ['Project Manager', 'Client', 'Admin'],
        navType: 'objectList',
        navTarget: 'DeliveryDocument__c',
        navLabel: 'View Documents'
    },
    {
        key: 'activityFeed',
        personas: ['Developer', 'Project Manager', 'Client', 'Admin'],
        navType: 'tab',
        navTarget: 'Delivery_Activity',
        navLabel: 'Open Activity Feed'
    },
    {
        key: 'ghostRecorder',
        personas: ['Developer', 'Admin'],
        navType: null,
        navTarget: null,
        navLabel: null
    },
    {
        key: 'sync',
        personas: ['Admin'],
        navType: 'objectList',
        navTarget: 'SyncItem__c',
        navLabel: 'View Sync Items'
    },
    {
        key: 'portal',
        personas: ['Project Manager', 'Client', 'Admin'],
        navType: null,
        navTarget: null,
        navLabel: null
    },
    {
        key: 'settings',
        personas: ['Admin'],
        navType: 'tab',
        navTarget: 'DeliveryHubSettings',
        navLabel: 'Open Settings'
    },
    {
        key: 'timeline',
        personas: ['Developer', 'Project Manager', 'Admin'],
        navType: 'tab',
        navTarget: 'Delivery_Timeline',
        navLabel: 'Open Timeline'
    },
    {
        key: 'savedFilters',
        personas: ['Developer', 'Project Manager'],
        navType: 'tab',
        navTarget: 'Delivery_Board',
        navLabel: 'Open Board'
    },
    {
        key: 'docVersioning',
        personas: ['Project Manager', 'Admin'],
        navType: 'objectList',
        navTarget: 'DeliveryDocument__c',
        navLabel: 'View Documents'
    },
    {
        key: 'invoiceApproval',
        personas: ['Client', 'Admin'],
        navType: 'objectList',
        navTarget: 'DeliveryDocument__c',
        navLabel: 'View Documents'
    },
    {
        key: 'portalTimeEntry',
        personas: ['Client'],
        navType: null,
        navTarget: null,
        navLabel: null
    },
    {
        key: 'emailInbound',
        personas: ['Developer', 'Project Manager', 'Client'],
        navType: null,
        navTarget: null,
        navLabel: null
    },
    {
        key: 'platformEvents',
        personas: ['Developer', 'Admin'],
        navType: null,
        navTarget: null,
        navLabel: null
    },
    {
        key: 'configurableSettings',
        personas: ['Admin'],
        navType: 'tab',
        navTarget: 'DeliveryHubSettings',
        navLabel: 'Open Settings'
    },
    {
        key: 'pdfHyperlinks',
        personas: ['Project Manager', 'Admin'],
        navType: 'objectList',
        navTarget: 'DeliveryDocument__c',
        navLabel: 'View Documents'
    },
    {
        key: 'hideEmptyColumns',
        personas: ['Developer', 'Project Manager'],
        navType: 'tab',
        navTarget: 'Delivery_Board',
        navLabel: 'Open Board'
    },
    {
        key: 'appLogo',
        personas: ['Admin'],
        navType: null,
        navTarget: null,
        navLabel: null
    }
];

const SECTION_KEYS = SECTION_CONFIG.map(s => s.key);

/* Build fast look-ups from the config array */
const _sectionMap = Object.fromEntries(SECTION_CONFIG.map(s => [s.key, s]));

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
        const found = PERSONAS.find(p => p.value === this._selectedPersona);
        return found ? found.label : 'All Roles';
    }

    get isFiltered() {
        return this._selectedPersona !== '';
    }

    handlePersonaChange(event) {
        this._selectedPersona = event.detail.value;
    }

    /* ── Section visibility based on persona ── */

    _isVisibleForPersona(key) {
        if (!this._selectedPersona) return true;
        const cfg = _sectionMap[key];
        return cfg ? cfg.personas.includes(this._selectedPersona) : true;
    }

    _isRecommended(key) {
        if (!this._selectedPersona) return false;
        const cfg = _sectionMap[key];
        return cfg ? cfg.personas.includes(this._selectedPersona) : false;
    }

    /* ── Deep-link navigation ── */

    _hasNavLink(key) {
        const cfg = _sectionMap[key];
        return cfg && cfg.navType !== null;
    }

    _getNavLabel(key) {
        const cfg = _sectionMap[key];
        return cfg ? cfg.navLabel : null;
    }

    handleNavigate(event) {
        event.stopPropagation();
        const key = event.currentTarget.dataset.key;
        const cfg = _sectionMap[key];
        if (!cfg || !cfg.navType) return;

        if (cfg.navType === 'tab') {
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: { apiName: cfg.navTarget }
            });
        } else if (cfg.navType === 'objectList') {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: cfg.navTarget,
                    actionName: 'list'
                },
                state: { filterName: 'Recent' }
            });
        }
    }

    /* ── Section toggle ── */

    handleSectionToggle(event) {
        const key = event.currentTarget.dataset.key;
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
        SECTION_KEYS.forEach(k => {
            if (this._isVisibleForPersona(k)) {
                all[k] = true;
            }
        });
        this._expanded = all;
    }

    handleCollapseAll() {
        this._expanded = {};
    }

    handleQuickLink(event) {
        const key = event.currentTarget.dataset.key;
        this._expanded = { ...this._expanded, [key]: true };
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const el = this.template.querySelector(`[data-section="${key}"]`);
            if (el) {
                el.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }, 100);
    }

    /* ── Per-section getters ── */

    _isOpen(key) { return !!this._expanded[key]; }
    _chevron(key) { return this._expanded[key] ? 'utility:chevrondown' : 'utility:chevronright'; }

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

    get ghostRecorderApps() {
        if (!this.guideContext?.apps) return [];
        return this.guideContext.apps.map(app => ({
            ...app,
            statusClass: app.hasGhostRecorder
                ? 'dg-app-status dg-app-status--installed'
                : 'dg-app-status dg-app-status--missing',
            statusLabel: app.hasGhostRecorder ? 'Installed' : 'Not installed',
            statusIcon: app.hasGhostRecorder ? 'utility:check' : 'utility:close',
            statusVariant: app.hasGhostRecorder ? '' : 'error'
        }));
    }

    get appsWithoutGhostRecorder() {
        return this.ghostRecorderApps.filter(a => !a.hasGhostRecorder);
    }

    get appsWithGhostRecorder() {
        return this.ghostRecorderApps.filter(a => a.hasGhostRecorder);
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
