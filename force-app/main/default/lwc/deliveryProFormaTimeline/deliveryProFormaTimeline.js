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

    /**
     * Outbound URL for NG's fullscreen button — set declaratively on the
     * Standalone FlexiPage (componentInstanceProperty fullscreenUrl). When set,
     * NG's shell renders a button that navigates to this URL on click. Left
     * unset on Delivery_Timeline (embedded) + VF Full_Bleed (/apex/) mounts.
     *
     * Value from FlexiPage is the unprefixed URL (/apex/DeliveryGanttStandalone);
     * subscriber orgs need the namespaced URL. The _mount() path applies the
     * runtime-resolved VF prefix before handing it to NG (CLAUDE.md VF-URL rule).
     */
    @api fullscreenUrl;

    /**
     * Whether NG's chrome (titlebar rows) is HIDDEN by default on mount.
     * Inverted name per LWC1503 — boolean @api props can't default to true.
     * Default false = chrome visible; set true on the Embedded FlexiPage to
     * surface a minimal-chrome view when SF already surrounds the component.
     * Forwarded as `chromeVisibleDefault: !chromeHiddenDefault` to NG 0.183+.
     */
    @api chromeHiddenDefault = false;

    _scriptLoaded = false;
    _mounted = false;
    _tasks = [];
    _mountHandle = null;
    _refetchTimer = null;
    _viewportWriteTimer = null;

    async connectedCallback() {
        // Fullscreen FlexiPage route renders a Salesforce-injected SLDS page-header
        // band (tab label + motif) above the FlexiPage region. That band can only
        // be suppressed by a document-head CSS rule (LWC shadow DOM can't reach
        // the parent chrome); inject it when mode === 'fullscreen' so the
        // FlexiPage route visually matches the VF Full_Bleed route.
        this._installFullscreenChromeHide();
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
        if (!window.NimbusGanttApp) {
            // eslint-disable-next-line no-console
            console.error('[DeliveryTimeline] window.NimbusGanttApp not set after script load — bundle may have failed');
            this._showError('Timeline bundle failed to load', new Error('window.NimbusGanttApp not defined'));
            return;
        }
        // Defer mount via a macrotask so FlexiPage @api prop hydration
        // (fullscreenUrl in particular) is guaranteed complete before the
        // mount config snapshots them. connectedCallback's microtask awaits
        // are not always enough on FlexiPage-hosted components — HQ probe
        // at e8c20967 showed @api fullscreenUrl landing on the host element
        // AFTER NimbusGanttApp.mount() had already snapshotted an undefined
        // value, causing NG to fall through to native requestFullscreen.
        setTimeout(() => {
            if (!this._mounted) this._loadAndMount();
        }, 0);
    }

    disconnectedCallback() {
        if (this._refetchTimer) {
            clearTimeout(this._refetchTimer);
            this._refetchTimer = null;
        }
        if (this._viewportWriteTimer) {
            clearTimeout(this._viewportWriteTimer);
            this._viewportWriteTimer = null;
        }
        if (this._mounted) {
            try {
                // Prefer the handle's destroy() if NG 0.183 exposes one; fall
                // back to the older container-based unmount API.
                if (this._mountHandle && typeof this._mountHandle.destroy === 'function') {
                    this._mountHandle.destroy();
                } else {
                    const container = this.template.querySelector('.timeline-container');
                    if (container && window.NimbusGanttApp) {
                        window.NimbusGanttApp.unmount(container);
                    }
                }
            } catch (e) { /* swallow */ }
            this._mounted = false;
            this._mountHandle = null;
        }
        this._uninstallFullscreenChromeHide();
    }

    _installFullscreenChromeHide() {
        if (this.mode !== 'fullscreen') return;
        if (document.getElementById('dh-gantt-fs-chrome-hide')) return;
        const style = document.createElement('style');
        style.id = 'dh-gantt-fs-chrome-hide';
        // Real AppPage/FlexiPage chrome targets (confirmed via Glen's DevTools
        // on /lightning/n/Delivery_Gantt_Standalone): app_flexipage-header
        // custom element wrapping div.slds-page-header.header.flexipageHeader.
        // Earlier .forceAppHomePage selectors missed; kept for belt-and-
        // suspenders in case DOM shifts across LEX releases.
        style.textContent = [
            'app_flexipage-header,',
            '.flexipageHeader,',
            'div.slds-page-header.header.flexipageHeader,',
            '.forceAppHomePage section.slds-page-header,',
            '.appHomePage section.slds-page-header,',
            '[data-aura-class="forceAppHomePage"] section.slds-page-header,',
            '.forceHighlightsPanel { display: none !important; }'
        ].join(' ');
        document.head.appendChild(style);
    }

    _uninstallFullscreenChromeHide() {
        const s = document.getElementById('dh-gantt-fs-chrome-hide');
        if (s && s.parentNode) s.parentNode.removeChild(s);
    }

    // CLOUDNIMBUS_CSS resolves to `/resource/{ts}/cloudnimbustemplatecss` in a
    // non-namespaced scratch and `/resource/{ts}/delivery__cloudnimbustemplatecss`
    // in a subscriber org. Used to build the VF fullscreen URL so it resolves
    // correctly in both contexts (CLAUDE.md: never hardcode namespace in VF URL).
    _vfPrefix() {
        const m = /\/resource\/\d+\/([^/?]+?)__cloudnimbustemplatecss/.exec(CLOUDNIMBUS_CSS);
        return m ? `${m[1]}__` : '';
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

        const tasks = this._mapTasksForNg(this._tasks);

        const mountConfig = {
            mode: this.mode,
            tasks,
            // Save-path routing is mode-conditional:
            //
            //   Embedded (Delivery_Timeline tab): NG emits legacy onPatch for
            //     date edits. Glen's 12b6036a probe confirms one POST /aura
            //     fires per drag. _handlePatch → updateWorkItemDates works.
            //
            //   Fullscreen (Standalone FlexiPage + VF Full_Bleed): NG 0.183
            //     appears to emit ONLY onItemEdit (no legacy onPatch fallback).
            //     Removing onItemEdit at 12b6036a cut the save wire on both
            //     fullscreen surfaces (0 Apex fetches on drag). Restoring
            //     onItemEdit here for fullscreen only — inlined fully so NG's
            //     stub-detection heuristic (if that's what tripped earlier)
            //     can't misread a method-reference arrow as empty.
            onPatch: (patch) => this._handlePatch(patch),
            onItemReorder: (taskId, payload) => this._handleItemReorder(taskId, payload),
            onItemReorderError: (taskId, error) => this._handleItemReorderError(taskId, error),
            onItemClick: (taskId) => this._handleItemClick(taskId),
            onViewportChange: (state) => this._handleViewportChange(state),
            initialViewport: this._readInitialViewport(),
            chromeVisibleDefault: !this.chromeHiddenDefault,
            features: {
                hoursColumn: true,
                budgetUsedColumn: true,
            },
            cssUrl: CLOUDNIMBUS_CSS,
            // Passed explicitly to avoid window-lookup races; the app shell
            // would otherwise reach for window.NimbusGantt at a point where
            // Locker Service proxies can still be settling.
            engine: window.NimbusGantt,
        };

        // Fullscreen-only: wire onItemEdit/onItemEditError INLINE. Arrow
        // forwards directly to updateWorkItemDates without method-reference
        // indirection. Embedded stays on legacy onPatch (verified working).
        if (this.mode === 'fullscreen') {
            mountConfig.onItemEdit = async (taskId, changes) => {
                const id = this._normalizeTaskId(taskId);
                // eslint-disable-next-line no-console
                console.log('[DH onItemEdit inline]', { arg1Type: typeof taskId, resolvedId: id, changes });
                if (!id) { throw new Error('[DH] onItemEdit missing taskId'); }
                const { startDate, endDate } = changes || {};
                await updateWorkItemDates({
                    workItemId: id,
                    startDate: startDate || null,
                    endDate: endDate || null,
                });
                this._scheduleRefetch();
            };
            mountConfig.onItemEditError = (taskId, error) => this._showError('Failed to save date change', error);
        }

        // Surface-aware fullscreen-button routing. Give NG's shell exactly one
        // signal per route so the button direction is unambiguous:
        //
        //   Embedded (Delivery_Timeline tab, mode=embedded, no @api fullscreenUrl)
        //     → onEnterFullscreen only: "↗ Full Screen" navigates to Standalone tab
        //   Standalone FlexiPage (mode=fullscreen, @api fullscreenUrl set by FlexiPage)
        //     → fullscreenUrl only: outbound button to VF Full_Bleed route
        //   VF Full_Bleed (/apex/, mode=fullscreen, no @api fullscreenUrl — LightningOut
        //                  mount doesn't set it)
        //     → onExitFullscreen only: "← Exit" back to embedded Delivery_Timeline tab
        //
        // The @api fullscreenUrl prop is the primary signal for Standalone
        // routing — set declaratively on the FlexiPage. onApexRoute is the
        // fallback discriminator for the fullscreen-mode-no-fullscreenUrl case
        // (VF Lightning Out mount).
        const onApexRoute = typeof window !== 'undefined'
            && window.location
            && typeof window.location.pathname === 'string'
            && window.location.pathname.indexOf('/apex/') !== -1;
        if (this.mode === 'embedded') {
            mountConfig.onEnterFullscreen = () => this._handleEnterFullscreen();
        } else if (this.fullscreenUrl) {
            // Apply namespace prefix to the FlexiPage-declared URL for
            // subscriber orgs (FlexiPage stores a static string; scratch
            // stores /apex/Name, subscriber needs /apex/delivery__Name).
            let url = this.fullscreenUrl;
            const prefix = this._vfPrefix();
            if (prefix && url.indexOf('/apex/') === 0 && url.indexOf('__') === -1) {
                url = url.replace('/apex/', `/apex/${prefix}`);
            }
            mountConfig.fullscreenUrl = url;
        } else if (onApexRoute) {
            // VF Full_Bleed mount (no @api fullscreenUrl from LightningOut)
            mountConfig.onExitFullscreen = () => this._handleExitFullscreen();
        } else {
            // Standalone FlexiPage without fullscreenUrl configured — fall back
            // to computed URL so behavior is preserved even if FlexiPage prop
            // is missing.
            mountConfig.fullscreenUrl = `/apex/${this._vfPrefix()}DeliveryGanttStandalone`;
        }

        try {
            // eslint-disable-next-line no-console
            const mountSnapshot = {
                surface: (typeof window !== 'undefined' && window.location && window.location.pathname) || '',
                mode: mountConfig.mode,
                apiModeProp: this.mode,
                apiFullscreenUrlProp: this.fullscreenUrl,
                apiChromeHiddenDefaultProp: this.chromeHiddenDefault,
                resolvedFullscreenUrl: mountConfig.fullscreenUrl,
                hasOnEnter: !!mountConfig.onEnterFullscreen,
                hasOnExit: !!mountConfig.onExitFullscreen,
                hasOnPatch: !!mountConfig.onPatch,
                hasOnItemEdit: !!mountConfig.onItemEdit,
                hasOnItemReorder: !!mountConfig.onItemReorder,
                hasOnItemClick: !!mountConfig.onItemClick,
                hasOnViewportChange: !!mountConfig.onViewportChange,
                taskCount: mountConfig.tasks ? mountConfig.tasks.length : 0,
                chromeVisibleDefault: mountConfig.chromeVisibleDefault,
                features: mountConfig.features,
                initialViewport: mountConfig.initialViewport,
                mountedAt: new Date().toISOString(),
            };
            // eslint-disable-next-line no-console
            console.log('[DH mount]', JSON.stringify(mountSnapshot));
            // Expose to window so probe can read regardless of console cache.
            // Overwritten on every mount; multi-mount scenarios get last-wins.
            try { window.__DH_MOUNT_STATE = mountSnapshot; } catch (e) { /* Locker */ }
            // Capture the mount return value — NG 0.183 returns a handle with
            // toggleChrome(), destroy(), and (expected) an update method for
            // pushing fresh tasks after a save. Older bundles may return
            // undefined; guard all handle-method calls.
            this._mountHandle = window.NimbusGanttApp.mount(container, mountConfig);
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
            this._scheduleRefetch();
        } catch (error) {
            this._showError('Failed to save change', error);
        }
    }

    /**
     * NG 0.183 onItemEdit(taskId, { startDate?, endDate? }). Optimistic: NG
     * holds the dragged bar in an in-flight state, awaits this promise, then
     * commits on resolve or reverts on reject. Re-throw on Apex failure so
     * NG reverts — the error UI is emitted by NG through onItemEditError.
     *
     * Signature-drift guard: NG may pass the full task object as arg 1 on
     * some code paths (same risk flagged for onItemReorder). Normalize to
     * a string id defensively.
     */
    async _handleItemEdit(arg1, changes) {
        const taskId = this._normalizeTaskId(arg1);
        // eslint-disable-next-line no-console
        console.log('[DH onItemEdit]', { arg1Type: typeof arg1, resolvedTaskId: taskId, changes });
        if (!taskId) { throw new Error('[DH] onItemEdit missing taskId'); }
        const { startDate, endDate } = changes || {};
        await updateWorkItemDates({
            workItemId: taskId,
            startDate: startDate || null,
            endDate: endDate || null,
        });
        this._scheduleRefetch();
    }

    _handleItemEditError(taskId, error) {
        this._showError('Failed to save date change', error);
    }

    /**
     * NG 0.183 onItemReorder(taskId, { newIndex, newParentId? }). Payload
     * object — newParentId only present when the drag also changed parent
     * (re-parent + re-sort in a single gesture). Persists sort + optional
     * parent change via existing Apex. Same optimistic/revert semantics
     * as onItemEdit: re-throw on failure so NG reverts the visual.
     */
    async _handleItemReorder(arg1, payload) {
        const taskId = this._normalizeTaskId(arg1);
        // eslint-disable-next-line no-console
        console.log('[DH onItemReorder]', { arg1Type: typeof arg1, resolvedTaskId: taskId, payload });
        if (!taskId) { throw new Error('[DH] onItemReorder missing taskId'); }
        const { newIndex, newParentId } = payload || {};
        const ops = [
            updateWorkItemSortOrder({ workItemId: taskId, sortOrder: Number(newIndex) || 0 }),
        ];
        if (newParentId !== undefined) {
            ops.push(updateWorkItemParent({ workItemId: taskId, parentId: newParentId || '' }));
        }
        await Promise.all(ops);
        this._scheduleRefetch();
    }

    _handleItemReorderError(taskId, error) {
        this._showError('Failed to save reorder', error);
    }

    /**
     * NG 0.183 onItemClick(taskId). Opens the standard SF record page for
     * the clicked WorkItem__c. Namespace prefix applied at runtime for
     * subscriber orgs (scratch 'WorkItem__c' → subscriber 'delivery__WorkItem__c').
     */
    _handleItemClick(arg1) {
        const taskId = this._normalizeTaskId(arg1);
        // eslint-disable-next-line no-console
        console.log('[DH onItemClick]', { arg1Type: typeof arg1, resolvedTaskId: taskId });
        if (!taskId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: taskId,
                objectApiName: `${this._vfPrefix()}WorkItem__c`,
                actionName: 'view',
            },
        });
    }

    /**
     * NG 0.183 API is documented as (taskId, ...) but signature drift has
     * been observed (onItemReorder shipped with a payload object, not bare
     * newIndex). Normalize arg 1 to a string id: accept either a string id
     * or a task object with .id.
     */
    _normalizeTaskId(arg) {
        if (!arg) return null;
        if (typeof arg === 'string') return arg;
        if (typeof arg === 'object' && arg.id) return String(arg.id);
        return null;
    }

    _mapTasksForNg(rawTasks) {
        return (rawTasks || []).map(r => {
            const estimated = Number(r.estimatedHours) || 0;
            const logged = Number(r.loggedHours) || 0;
            // DM-3: per-row column value. Guard against div-by-zero; 0-estimate
            // items show 0% even when hours are logged (matches v9 behavior).
            const budgetUsedPercent = estimated > 0
                ? Math.round((logged / estimated) * 1000) / 10
                : 0;
            return {
                id: r.id,
                title: r.title || r.name,
                priorityGroup: r.priorityGroup || 'follow-on',
                stage: r.stage || '',
                priority: r.priority || 'Medium',
                startDate: r.startDate || null,
                endDate: r.endDate || null,
                estimatedHours: estimated,
                loggedHours: logged,
                budgetUsedPercent,
                developerName: r.developerName || '',
                entityName: r.entityName || '',
                parentWorkItemId: r.parentWorkItemId || null,
                sortOrder: Number(r.sortOrder) || 0,
                isInactive: !!r.isInactive,
            };
        });
    }

    /**
     * IM-7 viewport persistence. Per-mode key so Embedded and Standalone
     * don't clobber each other. localStorage is per-browser (not cross-device);
     * acceptable tradeoff vs. a UserPreference__c sObject. Try/catch guards
     * Locker Service / private-mode restrictions.
     */
    get _viewportStorageKey() {
        return `dh.gantt.viewport.${this.mode || 'embedded'}`;
    }

    _readInitialViewport() {
        try {
            const raw = window.localStorage.getItem(this._viewportStorageKey);
            if (!raw) return undefined;
            const parsed = JSON.parse(raw);
            if (parsed && typeof parsed === 'object') return parsed;
        } catch (e) { /* storage unavailable — first mount, fall through */ }
        return undefined;
    }

    _handleViewportChange(state) {
        // NG debounces the callback at 150ms; add a host-side throttle so
        // rapid scrolls don't thrash localStorage.
        if (this._viewportWriteTimer) clearTimeout(this._viewportWriteTimer);
        this._viewportWriteTimer = setTimeout(() => {
            this._viewportWriteTimer = null;
            try {
                window.localStorage.setItem(this._viewportStorageKey, JSON.stringify(state));
            } catch (e) { /* storage full / disabled — swallow */ }
        }, 500);
    }

    /**
     * Debounced post-save re-fetch. After a successful write, pull fresh
     * WorkItem__c data so rollups/formula fields (TotalLoggedHoursSum__c,
     * SLA dates, etc.) re-render with server-computed values. 500ms debounce
     * prevents Apex storms under rapid drag/patch sequences.
     *
     * Pushes fresh tasks into NG via the mount handle if 0.183+ exposes an
     * updateTasks() method; otherwise caches locally for next mount cycle.
     */
    _scheduleRefetch() {
        if (this._refetchTimer) clearTimeout(this._refetchTimer);
        this._refetchTimer = setTimeout(() => {
            this._refetchTimer = null;
            this._refetchAfterPatch();
        }, 500);
    }

    async _refetchAfterPatch() {
        try {
            const data = await getProFormaTimelineData({ showCompleted: false });
            this._tasks = data || [];
            if (this._mountHandle && typeof this._mountHandle.updateTasks === 'function') {
                this._mountHandle.updateTasks(this._mapTasksForNg(this._tasks));
            }
        } catch (error) {
            // eslint-disable-next-line no-console
            console.warn('[DeliveryTimeline] post-save re-fetch failed (non-critical):', error);
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
