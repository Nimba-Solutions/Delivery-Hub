/**
 * @name         Delivery Hub — deliveryProFormaTimeline
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Thin Salesforce shell that mounts the nimbus-gantt v10 template
 *               shell (window.NimbusGanttApp) against real WorkItem__c data.
 *               Loads two static resources:
 *                 - nimbusgantt     → window.NimbusGantt (core Gantt engine)
 *                 - nimbusganttapp  → window.NimbusGanttApp (v10 template shell)
 *               Fetches data via DeliveryGanttController.getProFormaTimelineData,
 *               passes tasks + onPatch + nav callbacks + cssUrl into the shell's
 *               mount. The shell owns all visual chrome (toolbar, sidebar, audit,
 *               HRS/WK strip, etc.) and writes back through the onPatch callback.
 *
 *               Historical note (2026-04-16): an earlier bundle
 *               (deliverytimeline.resource → window.DeliveryTimeline) wrapped
 *               NimbusGanttChart directly and bypassed the v10 template shell
 *               entirely — that's why the Salesforce Gantt rendered chromeless
 *               while cloudnimbusllc.com v10 had a full toolbar. That bundle
 *               and its static resource have been removed; nimbusganttapp is
 *               now the single mount entry point.
 *
 *               Two render modes are supported via the @api mode prop (set from
 *               the FlexiPage config):
 *                 - "embedded"   (default) — minimal chrome, inside the Delivery
 *                                Hub app Timeline tab. Shell renders a compact
 *                                toolbar with an "↗ Full Screen" button that
 *                                routes to the standalone app via NavigationMixin.
 *                 - "fullscreen"           — full v10 toolbar, sidebar, audit,
 *                                shown in the Delivery_Gantt_Standalone app
 *                                page (chromeless Lightning app). Shell renders
 *                                an "← Exit Full Screen" button that routes
 *                                back to the Delivery_Timeline tab.
 *               The shell owns ALL visual differences between modes; this LWC
 *               only handles the navigation events the shell emits.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import NIMBUS_GANTT from '@salesforce/resourceUrl/nimbusgantt';
import NIMBUS_GANTT_APP from '@salesforce/resourceUrl/nimbusganttapp';
import CLOUDNIMBUS_CSS from '@salesforce/resourceUrl/cloudnimbustemplatecss';
import getProFormaTimelineData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getProFormaTimelineData';
import updateWorkItemDates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemDates';
import updateWorkItemSortOrder from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemSortOrder';
import updateWorkItemPriorityGroup from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemPriorityGroup';
import updateWorkItemParent from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemParent';

// Tab DeveloperNames used by the fullscreen nav pair. Centralized here so the
// names are discoverable from a single search.
const EMBEDDED_TAB_API_NAME = 'Delivery_Timeline';
const FULLSCREEN_TAB_API_NAME = 'Delivery_Gantt_Standalone';

export default class DeliveryProFormaTimeline extends NavigationMixin(LightningElement) {

    /**
     * Render mode — set from the FlexiPage config.
     * "embedded" (default) = Timeline tab inside Delivery Hub app, minimal chrome.
     * "fullscreen"         = Delivery_Gantt_Standalone tab in its own chromeless app.
     * The shell (window.NimbusGanttApp) reads this from the mount config and
     * renders the appropriate toolbar + the correct nav button (enter vs exit).
     */
    @api mode = 'embedded';

    _scriptLoaded = false;
    _mounted = false;
    _tasks = [];

    async connectedCallback() {
        // Load core first so window.NimbusGantt is available when the app shell
        // bundle runs. Locker Service may reject loadScript even when the
        // script actually executed — catch and continue.
        try {
            await loadScript(this, NIMBUS_GANTT);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.warn('[DeliveryTimeline] nimbusgantt script warning (may be Locker Service):', e && e.message);
        }
        try {
            await loadScript(this, NIMBUS_GANTT_APP);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.warn('[DeliveryTimeline] nimbusganttapp script warning (may be Locker Service):', e && e.message);
        }
        this._scriptLoaded = true;
        if (window.NimbusGanttApp) {
            await this._loadAndMount();
        } else {
            // eslint-disable-next-line no-console
            console.error('[DeliveryTimeline] window.NimbusGanttApp not set after script load — bundle may have failed');
            this._showError('Timeline bundle failed to load', new Error('window.NimbusGanttApp not defined'));
        }
    }

    disconnectedCallback() {
        if (this._mounted) {
            try {
                const container = this.template.querySelector('.timeline-container');
                if (container && window.NimbusGanttApp) {
                    window.NimbusGanttApp.unmount(container);
                }
            } catch (e) { /* swallow */ }
            this._mounted = false;
        }
    }

    async _loadAndMount() {
        try {
            const data = await getProFormaTimelineData({ showCompleted: false });
            this._tasks = data || [];
            // Give DOM a tick to render the container
            await new Promise(resolve => setTimeout(resolve, 0));
            this._mount();
        } catch (error) {
            this._showError('Failed to load work items', error);
        }
    }

    _mount() {
        const container = this.template.querySelector('.timeline-container');
        if (!container) {
            // eslint-disable-next-line no-console
            console.error('[DeliveryTimeline] Container element not found in template');
            return;
        }
        if (!window.NimbusGanttApp) {
            // eslint-disable-next-line no-console
            console.error('[DeliveryTimeline] window.NimbusGanttApp not set — static resource may have failed to load');
            return;
        }

        // Map Apex DTOs to SFTask shape the shell expects
        const tasks = this._tasks.map(r => ({
            id: r.id,
            title: r.title || r.name,
            priorityGroup: r.priorityGroup || 'follow-on',
            stage: r.stage || '',
            priority: r.priority || 'Medium',
            startDate: r.startDate || null,
            endDate: r.endDate || null,
            estimatedHours: Number(r.estimatedHours) || 0,
            loggedHours: Number(r.loggedHours) || 0,
            developerName: r.developerName || '',
            entityName: r.entityName || '',
            parentWorkItemId: r.parentWorkItemId || null,
            sortOrder: Number(r.sortOrder) || 0,
            isInactive: !!r.isInactive,
        }));

        try {
            window.NimbusGanttApp.mount(container, {
                mode: this.mode,
                tasks,
                onPatch: (patch) => this._handlePatch(patch),
                onEnterFullscreen: () => this._handleEnterFullscreen(),
                onExitFullscreen: () => this._handleExitFullscreen(),
                cssUrl: CLOUDNIMBUS_CSS,
                // Passed explicitly to avoid window-lookup races; the app shell
                // would otherwise reach for window.NimbusGantt at a point where
                // Locker Service proxies can still be settling.
                engine: window.NimbusGantt,
            });
            this._mounted = true;
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[DeliveryTimeline] mount() threw — Locker Service container issue or bundle error:', error);
            this._showError('Timeline failed to render', error);
        }
    }

    async _handlePatch(patch) {
        const { id, sortOrder, priorityGroup, parentId, startDate, endDate } = patch;
        const ops = [];

        if (sortOrder !== undefined) {
            ops.push(updateWorkItemSortOrder({ workItemId: id, sortOrder }));
        }
        if (priorityGroup !== undefined) {
            ops.push(updateWorkItemPriorityGroup({ workItemId: id, priorityGroup }));
        }
        if ('parentId' in patch) {
            ops.push(updateWorkItemParent({ workItemId: id, parentId: parentId || '' }));
        }
        if (startDate !== undefined || endDate !== undefined) {
            ops.push(updateWorkItemDates({
                workItemId: id,
                startDate: startDate || null,
                endDate: endDate || null,
            }));
        }

        try {
            await Promise.all(ops);
        } catch (error) {
            this._showError('Failed to save change', error);
        }
    }

    _handleEnterFullscreen() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: FULLSCREEN_TAB_API_NAME },
        });
    }

    _handleExitFullscreen() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: EMBEDDED_TAB_API_NAME },
        });
    }

    _showError(prefix, error) {
        const msg = (error && error.body && error.body.message) || (error && error.message) || 'Unknown error';
        // eslint-disable-next-line no-console
        console.error('[deliveryProFormaTimeline]', prefix, error);
        this.dispatchEvent(new ShowToastEvent({
            title: prefix, message: msg, variant: 'error',
        }));
    }
}
