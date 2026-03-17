import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getGuideContext from '@salesforce/apex/DeliveryGuideController.getGuideContext';

const SECTION_KEYS = [
    'welcome', 'board', 'workItems', 'timeTracking',
    'documents', 'activityFeed', 'ghostRecorder',
    'sync', 'portal', 'settings'
];

export default class DeliveryGuide extends NavigationMixin(LightningElement) {
    @track _expanded = { welcome: true };
    guideContext;
    error;

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
        SECTION_KEYS.forEach(k => { all[k] = true; });
        this._expanded = all;
    }

    handleCollapseAll() {
        this._expanded = {};
    }

    handleQuickLink(event) {
        const key = event.currentTarget.dataset.key;
        this._expanded = { ...this._expanded, [key]: true };
        setTimeout(() => { // NOSONAR - scroll after DOM update
            const el = this.template.querySelector(`[data-section="${key}"]`);
            if (el) {
                el.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }, 100);
    }

    /* ── Per-section getters ── */

    _isOpen(key) { return !!this._expanded[key]; }
    _chevron(key) { return this._expanded[key] ? 'utility:chevrondown' : 'utility:chevronright'; }

    get welcomeExpanded() { return this._isOpen('welcome'); }
    get welcomeChevron() { return this._chevron('welcome'); }

    get boardExpanded() { return this._isOpen('board'); }
    get boardChevron() { return this._chevron('board'); }

    get workItemsExpanded() { return this._isOpen('workItems'); }
    get workItemsChevron() { return this._chevron('workItems'); }

    get timeTrackingExpanded() { return this._isOpen('timeTracking'); }
    get timeTrackingChevron() { return this._chevron('timeTracking'); }

    get documentsExpanded() { return this._isOpen('documents'); }
    get documentsChevron() { return this._chevron('documents'); }

    get activityFeedExpanded() { return this._isOpen('activityFeed'); }
    get activityFeedChevron() { return this._chevron('activityFeed'); }

    get ghostRecorderExpanded() { return this._isOpen('ghostRecorder'); }
    get ghostRecorderChevron() { return this._chevron('ghostRecorder'); }

    get syncExpanded() { return this._isOpen('sync'); }
    get syncChevron() { return this._chevron('sync'); }

    get portalExpanded() { return this._isOpen('portal'); }
    get portalChevron() { return this._chevron('portal'); }

    get settingsExpanded() { return this._isOpen('settings'); }
    get settingsChevron() { return this._chevron('settings'); }

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
