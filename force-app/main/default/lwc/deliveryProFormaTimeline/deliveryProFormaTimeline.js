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
import { subscribe as empSubscribe, unsubscribe as empUnsubscribe, onError as empOnError } from 'lightning/empApi';
import NIMBUS_GANTT from '@salesforce/resourceUrl/nimbusgantt';
import NIMBUS_GANTT_APP from '@salesforce/resourceUrl/nimbusganttapp';
import CLOUDNIMBUS_CSS from '@salesforce/resourceUrl/cloudnimbustemplatecss';
import USER_ID from '@salesforce/user/Id';
import getProFormaTimelineData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getProFormaTimelineData';
import getGanttDependencies from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttDependencies';
import updateWorkItemDates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemDates';
import updateWorkItemSortOrder from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemSortOrder';
import reorderWorkItemDense from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.reorderWorkItemDense';
import updateWorkItemPriorityGroup from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemPriorityGroup';
import updateWorkItemParent from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemParent';
import createWorkItemDependency from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.createWorkItemDependency';
import deleteWorkItemDependency from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.deleteWorkItemDependency';
import updateWorkItemFields from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemFields';

// Tab DeveloperNames used by the fullscreen nav pair. Centralized here so the
// names are discoverable from a single search.
const EMBEDDED_TAB_API_NAME = 'Delivery_Timeline';
// Full_Bleed is the VF-wrapped chromeless tab (no SLDS header). The older
// Delivery_Gantt_Standalone is a FlexiPage with standard LEX chrome — that
// surface keeps the menu bar when navigated to, which is NOT the fullscreen
// UX. Always target Full_Bleed for the enter-fullscreen gesture.
const FULLSCREEN_TAB_API_NAME = 'Delivery_Gantt_Full_Bleed';

// Live updates channel — DeliveryWorkItemChange__e Platform Event.
// On `task_upsert` or `dependency_change` events the gantt schedules a
// debounced refetch via the existing `_scheduleRefetch` path (mirrors the
// chat LWC's refreshApex pattern; no separate per-row engine push).
// `stage_change` / `comment_*` values are owned by other LWCs and ignored.
const PE_CHANNEL = '/event/%%%NAMESPACE_DOT%%%DeliveryWorkItemChange__e';
const GANTT_REFRESH_CHANGE_TYPES = new Set(['task_upsert', 'dependency_change']);

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
    _dependencies = [];
    _mountHandle = null;
    _refetchTimer = null;
    _viewportWriteTimer = null;
    _headerVisible = false;
    menuVisible = false;
    menuX = 0;
    menuY = 0;
    menuView = 'main';
    pickerFilter = '';
    _pickerMode = null; // 'add-successor' | 'add-predecessor' | 'remove-predecessor' | 'remove-successor'
    _menuTaskId = null;
    _menuTaskPriorityGroup = null;

    get menuStyle() {
        return `left:${this.menuX}px;top:${this.menuY}px;`;
    }
    get menuShowMain() { return this.menuView === 'main'; }
    get menuShowPriority() { return this.menuView === 'priority'; }
    get menuShowPicker() { return this.menuView === 'picker'; }

    get hasPredecessors() {
        return (this._dependencies || []).some(d => d.target === this._menuTaskId);
    }
    get hasSuccessors() {
        return (this._dependencies || []).some(d => d.source === this._menuTaskId);
    }

    get pickerHeading() {
        switch (this._pickerMode) {
            case 'add-successor': return 'Block which task?';
            case 'add-predecessor': return 'Blocked by which task?';
            case 'remove-predecessor': return 'Remove which predecessor?';
            case 'remove-successor': return 'Remove which successor?';
            default: return 'Select a task';
        }
    }

    get pickerOptions() {
        const filter = (this.pickerFilter || '').trim().toLowerCase();
        const all = this._tasks || [];
        const byId = new Map(all.map(t => [t.id, t]));
        const mode = this._pickerMode;
        const me = this._menuTaskId;
        let list = [];
        if (mode === 'add-successor' || mode === 'add-predecessor') {
            // Exclude self and any existing direct pairing in that direction.
            const existing = new Set();
            (this._dependencies || []).forEach(d => {
                if (mode === 'add-successor' && d.source === me) existing.add(d.target);
                if (mode === 'add-predecessor' && d.target === me) existing.add(d.source);
            });
            list = all.filter(t => t.id !== me && !existing.has(t.id)).map(t => ({
                id: t.id,
                label: `${t.name || t.id} — ${t.priorityGroup || 'proposed'}`,
            }));
        } else if (mode === 'remove-predecessor') {
            list = (this._dependencies || [])
                .filter(d => d.target === me)
                .map(d => {
                    const t = byId.get(d.source);
                    return { id: d.id, label: t ? `${t.name || t.id}` : d.source };
                });
        } else if (mode === 'remove-successor') {
            list = (this._dependencies || [])
                .filter(d => d.source === me)
                .map(d => {
                    const t = byId.get(d.target);
                    return { id: d.id, label: t ? `${t.name || t.id}` : d.target };
                });
        }
        if (filter) {
            list = list.filter(o => (o.label || '').toLowerCase().includes(filter));
        }
        return list;
    }

    get pickerEmpty() {
        return this.pickerOptions.length === 0;
    }

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
        if (this._empSubscription) {
            try { empUnsubscribe(this._empSubscription, () => {}); } catch (e) { /* best-effort */ }
            this._empSubscription = null;
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
        this._uninstallCnEditBridge();
        this._uninstallFullscreenChromeHide();
    }

    _installFullscreenChromeHide() {
        // Default both embedded and fullscreen modes to chrome-hidden.
        // Glen's spec: one Timeline tab, opens headerless by default.
        // A future toggle will let users reveal the SF page header.
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

    // LEX closed-source (aura_prod.js) suppresses document-level contextmenu
    // for LWC hosts. Per-element listeners bound via the LWC template
    // (`oncontextmenu={handler}`) compile to elem.addEventListener and
    // bypass that document-proxy. Right-click on any NG-rendered child
    // bubbles up to .timeline-container, fires this handler, we call
    // handle.taskAt(x, y) for the hit-test (NG 0.185.32).
    handleCanvasContextMenu(e) {
        const handle = this._mountHandle;
        if (!handle || typeof handle.taskAt !== 'function') return;
        const task = handle.taskAt(e.clientX, e.clientY);
        if (!task) return;
        e.preventDefault();
        this._openContextMenu(task, e.clientX, e.clientY);
    }

    _openContextMenu(task, x, y) {
        const id = (task && task.id) || task;
        // eslint-disable-next-line no-console
        console.log('[DH ctx-open]', id, { x, y });
        const full = (this._tasks || []).find(t => t.id === id) || task || {};
        this._menuTaskId = id;
        this._menuTaskPriorityGroup = full.priorityGroup || null;
        this.menuX = x;
        this.menuY = y;
        this.menuView = 'main';
        this.menuVisible = true;
    }

    _dismissMenu() {
        this.menuVisible = false;
        this.menuView = 'main';
        this._menuTaskId = null;
        this._menuTaskPriorityGroup = null;
        this._pickerMode = null;
        this.pickerFilter = '';
    }

    handleRootClick() {
        if (this.menuVisible) this._dismissMenu();
    }

    handleMenuClick(e) {
        // Prevent root-click from dismissing when clicking inside menu.
        e.stopPropagation();
    }

    async handleMenuAction(e) {
        const action = e.currentTarget.dataset.action;
        const taskId = this._menuTaskId;
        if (!taskId || !action) return;
        if (action === 'back') {
            this.menuView = 'main';
            this._pickerMode = null;
            this.pickerFilter = '';
            return;
        }
        if (action === 'change-priority') { this.menuView = 'priority'; return; }
        if (action === 'add-successor' || action === 'add-predecessor'
            || action === 'remove-predecessor' || action === 'remove-successor') {
            this._pickerMode = action;
            this.pickerFilter = '';
            this.menuView = 'picker';
            return;
        }

        if (action === 'copy-id') {
            try {
                await navigator.clipboard.writeText(taskId);
            } catch (err) {
                // eslint-disable-next-line no-console
                console.error('[DH ctx] clipboard.writeText failed', err);
            }
            this._dismissMenu();
            return;
        }

        if (action === 'move-top' || action === 'move-bottom') {
            const group = this._menuTaskPriorityGroup || 'proposed';
            const sortOrder = this._computeBucketEdgeSortOrder(group, action === 'move-top' ? 'top' : 'bottom');
            this._dismissMenu();
            await this._handlePatch({ id: taskId, sortOrder });
            this._scheduleRefetch();
            return;
        }

        if (action.startsWith('priority-')) {
            const newGroup = action.slice('priority-'.length);
            this._dismissMenu();
            await this._handlePatch({ id: taskId, priorityGroup: newGroup });
            this._scheduleRefetch();
            return;
        }
    }

    handlePickerFilter(e) {
        this.pickerFilter = e.target.value || '';
    }

    async handlePickerSelect(e) {
        const optId = e.currentTarget.dataset.optId;
        const mode = this._pickerMode;
        const taskId = this._menuTaskId;
        if (!optId || !mode || !taskId) { this._dismissMenu(); return; }
        try {
            if (mode === 'add-successor' || mode === 'add-predecessor') {
                const blocking = mode === 'add-successor' ? taskId : optId;
                const blocked = mode === 'add-successor' ? optId : taskId;
                const dto = await createWorkItemDependency({ blockingId: blocking, blockedId: blocked, depType: 'Blocks' });
                this._dependencies = [
                    ...this._dependencies,
                    ...this._mapDependenciesForNg([dto]),
                ];
                this._pushDependenciesToNg();
            } else if (mode === 'remove-predecessor' || mode === 'remove-successor') {
                await deleteWorkItemDependency({ depId: optId });
                this._dependencies = (this._dependencies || []).filter(d => d.id !== optId);
                this._pushDependenciesToNg();
            }
        } catch (err) {
            this._showError('Dependency action failed', err);
        } finally {
            this._dismissMenu();
        }
    }

    _pushDependenciesToNg() {
        const h = this._mountHandle;
        if (!h) return;
        try {
            if (typeof h.setDependencies === 'function') {
                h.setDependencies(this._dependencies);
            } else if (typeof h.setData === 'function') {
                h.setData(this._mapTasksForNg(this._tasks), this._dependencies);
            }
        } catch (e) {
            // eslint-disable-next-line no-console
            console.warn('[DH] setDependencies push failed', e);
        }
    }

    _computeBucketEdgeSortOrder(group, edge) {
        const inBucket = (this._tasks || []).filter(t => (t.priorityGroup || 'proposed') === group);
        if (inBucket.length === 0) return 1000;
        const sorts = inBucket.map(t => Number(t.sortOrder) || 0);
        if (edge === 'top') return Math.min(...sorts) - 1000;
        return Math.max(...sorts) + 1000;
    }

    // Builds the host-contributed TitleBar buttons (NG 0.185.26+
    // titleBarButtons slot). DH contributes a Show/Hide Header toggle.
    // Full Screen stays owned by NG via the existing fullscreen contract.
    _buildHostTitleBarButtons() {
        return [{
            id: 'dh-show-header',
            label: this._headerVisible ? 'Hide Header' : 'Show Header',
            pressed: this._headerVisible,
            onClick: () => this._toggleHeaderChrome(),
        }];
    }

    // Flips the SLDS page-header hide-CSS and re-pushes the TitleBar
    // buttons so NG updates the button label + pressed state in place.
    _toggleHeaderChrome() {
        if (document.getElementById('dh-gantt-fs-chrome-hide')) {
            this._uninstallFullscreenChromeHide();
            this._headerVisible = true;
        } else {
            this._installFullscreenChromeHide();
            this._headerVisible = false;
        }
        if (this._mountHandle && typeof this._mountHandle.setTitleBarButtons === 'function') {
            this._mountHandle.setTitleBarButtons(this._buildHostTitleBarButtons());
        }
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
            // Parallel-fetch tasks + dependencies. Dependencies include
            // completed-dependent tasks (showCompleted:true) so dangling
            // arrows don't disappear when the target task is hidden — v0
            // NG renders them gracefully.
            const [data, deps] = await Promise.all([
                getProFormaTimelineData({ showCompleted: false }),
                getGanttDependencies({ showCompleted: true }),
            ]);
            this._tasks = data || [];
            this._dependencies = this._mapDependenciesForNg(deps);
            // Give DOM a tick to render the container
            await new Promise(resolve => setTimeout(resolve, 0));
            this._mount();
        } catch (error) {
            this._showError('Failed to load work items', error);
        }
    }

    // Apex DTO field is `dependencyType`; NG core expects `type`. Cheapest
    // fix is client-side map — renaming the Apex field would force a
    // managed-package upload. Default 'FS' when the DTO is missing it so
    // old records still render.
    _mapDependenciesForNg(raw) {
        // NG's DependencyRenderer throws when a referenced task has no rendered
        // bar (missing dates or not in the tasks array). Filter defensively so
        // orphan or date-less dep rows never reach the renderer.
        const byId = new Map();
        (this._tasks || []).forEach(t => byId.set(t.id, t));
        const isRenderable = (taskId) => {
            const t = byId.get(taskId);
            return !!(t && t.startDate && t.endDate);
        };
        return (raw || [])
            .filter(d => d && d.source && d.target && isRenderable(d.source) && isRenderable(d.target))
            .map(d => ({
                id: d.id,
                source: d.source,
                target: d.target,
                type: d.dependencyType || d.type || 'FS',
            }));
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
            // NG 0.185.34 shipped the defensive DependencyRenderer —
            // arrows draw between dated bars, missing endpoints skipped.
            dependencies: this._dependencies,
            // NG's own onTaskContextMenu callback never fires under LWS
            // (document captured inside the IIFE is sandboxed). DH installs
            // its own document-level contextmenu listener and calls
            // handle.taskAt(x, y) for the hit-test. See
            // _installContextMenuListener below.
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
            // NG 0.185.26 — generic TitleBar button slot. DH contributes a
            // Show/Hide Header toggle that reveals the SF page-header chrome
            // that the Timeline tab hides by default.
            titleBarButtons: this._buildHostTitleBarButtons(),
            // onItemClick wired — opens the standard SF record page for the
            // clicked WorkItem. The NG-default DetailPanel was reported as
            // not visible / not opening for users in the embedded Lightning
            // surface; explicit navigation via NavigationMixin is the durable
            // affordance. Side effect: NG suppresses its default TOGGLE_DETAIL
            // when host wires onItemClick — DetailPanel is reachable via
            // explicit Detail-toggle button in the chrome / from the record
            // page itself.
            onItemClick: (taskId) => this._handleItemClick(taskId),
            onViewportChange: (state) => this._handleViewportChange(state),
            initialViewport: this._readInitialViewport(),
            // Dormant prop wiring — NG implements the handler in a future
            // release. When NG ships, fullscreen first-load lands on today
            // instead of dataset earliest date (scrollLeft:0). No-op on
            // current NG 0.185.0.1 (unknown prop, silently ignored).
            // Precedence (per NG-side spec): explicit initialViewport.scrollLeft
            // from localStorage wins over initialFocusDate — so returning
            // users keep their saved pan position, new users land on today.
            initialFocusDate: new Date().toISOString().slice(0, 10),
            // NG 0.185.4+ renders the task ID in DetailPanel as an <a target="_top">
            // with {id} replaced. Namespace-aware via _vfPrefix() so scratch gets
            // "/lightning/r/WorkItem__c/..." and subscriber gets
            // "/lightning/r/delivery__WorkItem__c/...". Library never navigates
            // itself — it just wraps the text; the browser handles the link.
            recordUrlTemplate: `/lightning/r/${this._vfPrefix()}WorkItem__c/{id}/view`,
            chromeVisibleDefault: !this.chromeHiddenDefault,
            features: {
                hoursColumn: true,
                budgetUsedColumn: true,
            },
            // NG 0.185.16 — vertical-dominant canvas bar drag (absY > absX × 1.5,
            // 12px threshold) emits onItemReorder. Horizontal drag still shifts
            // dates. Default ON for DH because sidebar drag-hit-testing has
            // known issues for distant rows (705 → 704 case) and bar-drag is
            // the reliable reprioritize gesture. Admin panel can still toggle.
            enableDragBarToReprioritize: true,
            // Drag-reparent ON — gates BOTH parent-change (drag onto another
            // work item) AND group-change (drag into a different priority-group
            // bucket header). Engine has them under one flag today; semantic
            // split into separate enableDragReparent vs enableDragGroupChange
            // is queued for nimbus-gantt repo. Until then, ON enables both —
            // the dominant user need is bucket-move (NOW / NEXT / PROPOSED),
            // which was unavailable while this defaulted to false.
            enableDragReparent: true,
            // NG 0.185.15+ DetailPanel fieldSchema. Keys map to
            // WorkItem__c fields (unprefixed — Apex updateWorkItemFields
            // handles namespace resolution). Picklist options mirror the
            // sObject's current picklist values. Changes emitted via
            // onItemEdit flow through _handleItemEdit → updateWorkItemFields
            // for bulk patch. Date fields still work via the existing
            // startDate/endDate path.
            fieldSchema: [
                { key: 'BriefDescriptionTxt__c', label: 'Title', type: 'text', placeholder: 'Short task description' },
                { key: 'StageNamePk__c', label: 'Stage', type: 'picklist', options: [
                    'Backlog','Scoping In Progress','Clarification Requested (Pre-Dev)',
                    'Ready for Sizing','Sizing Underway','Ready for Prioritization',
                    'Proposal Requested','Drafting Proposal','Ready for Tech Review',
                    'Ready for Final Approval','Ready for Development','In Development',
                    'Dev Blocked','Ready for QA','QA In Progress','Ready for Internal UAT',
                    'Ready for Client UAT','In Client UAT','Ready for UAT Sign-off',
                    'Ready for Merge','Ready for Deployment','Deployed to Prod',
                    'Done','Cancelled'
                ] },
                { key: 'PriorityPk__c', label: 'Priority', type: 'picklist', options: ['Low','Medium','High'] },
                { key: 'EstimatedHoursNumber__c', label: 'Estimated Hours', type: 'number', min: 0 },
                { key: 'startDate', label: 'Start Date', type: 'date' },
                { key: 'endDate', label: 'End Date', type: 'date' },
                { key: 'AcceptanceCriteriaTxt__c', label: 'Acceptance Criteria', type: 'textarea', placeholder: 'Given / When / Then...' },
                { key: 'DetailsTxt__c', label: 'Details', type: 'textarea' },
            ],
            cssUrl: CLOUDNIMBUS_CSS,
            // Passed explicitly to avoid window-lookup races; the app shell
            // would otherwise reach for window.NimbusGantt at a point where
            // Locker Service proxies can still be settling.
            engine: window.NimbusGantt,
        };

        // Wire onItemEdit on both embedded + fullscreen. NG 0.185.15's
        // DetailPanel uses this callback for form-submit regardless of
        // surface. Prior fullscreen-only gate left embedded's DetailPanel
        // silently unable to save when user edited fields from task click.
        if (true) {
            mountConfig.onItemEdit = async (taskId, changes) => {
                const id = this._normalizeTaskId(taskId);
                let changesLog = {};
                try { changesLog = JSON.parse(JSON.stringify(changes || {})); } catch (e) { changesLog = { _unserializable: true }; }
                // eslint-disable-next-line no-console
                console.log('[DH onItemEdit inline]', { resolvedId: id, changes: changesLog });
                if (!id) { throw new Error('[DH] onItemEdit missing taskId'); }
                const keys = Object.keys(changes || {});
                if (keys.length === 0) {
                    // Canvas drag-commit-move emits onItemEdit with empty changes
                    // (dates flow via onTaskMove instead). Guard to avoid
                    // updateWorkItemDates(null, null) nuking the record dates.
                    // eslint-disable-next-line no-console
                    console.warn('[DH onItemEdit inline] empty changes — no save');
                    return;
                }
                // DetailPanel multi-field save (NG 0.185.15+). Split into:
                //  - startDate/endDate → updateWorkItemDates (validated date endpoint)
                //  - everything else   → updateWorkItemFields (generic patch)
                // Both fire in parallel. NG holds optimistic state; no refetch.
                const { startDate, endDate, ...restFields } = changes || {};
                const ops = [];
                if (startDate !== undefined || endDate !== undefined) {
                    ops.push(updateWorkItemDates({
                        workItemId: id,
                        startDate: startDate || null,
                        endDate: endDate || null,
                    }));
                }
                if (Object.keys(restFields).length > 0) {
                    ops.push(updateWorkItemFields({ workItemId: id, fields: restFields }));
                }
                try {
                    await Promise.all(ops);
                    // No refetch — causes visual "bounce" as setTasks rebuilds the
            // whole gantt while NG's optimistic state already has the edit
            // applied. Next page reload reads fresh from DB.
                } catch (error) {
                    this._showError('Failed to save change', error);
                    throw error;
                }
            };
            mountConfig.onItemEditError = (taskId, error) => this._showError('Failed to save change', error);
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
        const pathname = (typeof window !== 'undefined' && window.location && typeof window.location.pathname === 'string')
            ? window.location.pathname : '';
        const onApexRoute = pathname.indexOf('/apex/') !== -1;
        // Standalone Aura app URL: /<ns>/<AppName>.app — renders at top level
        // outside /one/one.app, so we're the whole viewport. User entered here
        // via _handleEnterFullscreen navigation; NG's exit button must navigate
        // BACK, not call document.exitFullscreen() (browser isn't actually in
        // fullscreen mode — we just loaded a different URL).
        const onStandaloneAppRoute = /^\/[^/]+\/[^/]+\.app(\/|$|#)/.test(pathname)
            || /\.app$/.test(pathname);
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
        } else if (onApexRoute || onStandaloneAppRoute) {
            // VF Full_Bleed mount (/apex/) OR standalone Aura app route (/c/...app)
            // — both top-level chromeless surfaces user entered via nav.
            // NG's toolbar button should fire our exit-nav callback.
            mountConfig.onExitFullscreen = () => this._handleExitFullscreen();
        } else {
            // Standalone FlexiPage without fullscreenUrl configured — fall
            // back to the Full_Bleed TAB URL (NOT /apex/ direct). Direct
            // /apex/ URLs routed through standard__webPage or NG's internal
            // window.location land in LEX's alohaPage wrapper which keeps
            // the menu bar; the tab URL renders chromeless because the VF
            // tab has showHeader=false + no standardStylesheets.
            mountConfig.fullscreenUrl = `/lightning/n/${this._vfPrefix()}${FULLSCREEN_TAB_API_NAME}`;
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
                initialFocusDate: mountConfig.initialFocusDate,
                recordUrlTemplate: mountConfig.recordUrlTemplate,
                mountedAt: new Date().toISOString(),
            };
            // eslint-disable-next-line no-console
            console.log('[DH mount]', JSON.stringify(mountSnapshot));
            // Triple-publish so the probe has multiple reading paths that
            // don't all depend on the same LWS/Locker proxy behaving. Each
            // publish target gets its own try/catch — in LWS strict mode on
            // subscriber orgs (verified on MF-Prod 2026-04-19), globalThis
            // evaluates to undefined and throws "Cannot set properties of
            // undefined", which in a single-try block aborts the downstream
            // CustomEvent dispatch too. Individual try/catches prevent one
            // silent fail from cascading.
            try { window.__DH_MOUNT_STATE = mountSnapshot; } catch (e) { /* Locker/LWS proxy */ }
            try {
                if (typeof globalThis !== 'undefined' && globalThis) {
                    globalThis.__DH_MOUNT_STATE = mountSnapshot;
                }
            } catch (e) { /* LWS strict — globalThis undefined */ }
            try {
                if (typeof document !== 'undefined' && document.body) {
                    document.body.__DH_MOUNT_STATE = mountSnapshot;
                }
            } catch (e) { /* body attach blocked */ }
            try {
                document.dispatchEvent(new CustomEvent('dh:mount-ready', {
                    detail: mountSnapshot,
                    bubbles: true,
                    composed: true,
                }));
            } catch (e) { /* dispatchEvent unavailable */ }
            this._mountHandle = window.NimbusGanttApp.mount(container, mountConfig);
            // Triple-publish the mount handle for the same LWS reasons as
            // __cnEdit — DevTools can't see `window.*` writes in strict mode.
            try { window.__DH_HANDLE = this._mountHandle; } catch (e) { /* LWS proxy */ }
            try {
                if (typeof document !== 'undefined' && document.body) {
                    document.body.__DH_HANDLE = this._mountHandle;
                }
            } catch (e) { /* body attach blocked */ }
            try {
                document.dispatchEvent(new CustomEvent('dh:handle-ready', {
                    detail: this._mountHandle,
                    bubbles: true,
                    composed: true,
                }));
            } catch (e) { /* dispatchEvent unavailable */ }
            this._mounted = true;
            this._installCnEditBridge();
            // Subscribe to DeliveryWorkItemChange__e — on `task_upsert` events
            // (other clients' writes), schedule a debounced refetch through
            // the existing _scheduleRefetch path. Mirrors the refreshApex
            // pattern in deliveryWorkItemChat.js.
            this._subscribeToWorkItemChanges();
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('[DeliveryTimeline] mount() threw — Locker Service container issue or bundle error:', error);
            this._showError('Timeline failed to render', error);
        }
    }

    _subscribeToWorkItemChanges() {
        empOnError((err) => {
            // eslint-disable-next-line no-console
            console.warn('[DeliveryTimeline] empApi error:', JSON.stringify(err));
        });
        empSubscribe(PE_CHANNEL, -1, (message) => {
            const payload = message && message.data && message.data.payload;
            if (!payload) {
                return;
            }
            // Namespace-aware key resolution — payloads expose unprefixed
            // or namespaced keys depending on context. Mirrors
            // deliveryWorkItemChat.js pattern.
            const changeType = payload.ChangeTypeTxt__c
                || payload[`${this._peNsPrefix()}ChangeTypeTxt__c`];
            if (!GANTT_REFRESH_CHANGE_TYPES.has(changeType)) {
                return;
            }
            this._scheduleRefetch();
        }).then((sub) => {
            this._empSubscription = sub;
        });
    }

    _peNsPrefix() {
        if (this.__peNsPrefix !== undefined) {
            return this.__peNsPrefix;
        }
        const m = PE_CHANNEL.match(/\/event\/(.*?)DeliveryWorkItemChange__e/);
        this.__peNsPrefix = (m && m[1]) ? m[1] : '';
        return this.__peNsPrefix;
    }

    async _handlePatch(patch) {
        // eslint-disable-next-line no-console
        console.log('[DH onPatch]', JSON.stringify(patch || {}));
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

        if (ops.length === 0) return;
        try {
            await Promise.all(ops);
            // No refetch — setTasks() rebuilds the whole gantt and causes
            // visual x-axis snap after every drop. NG's optimistic state
            // already reflects the patch; formula-field rollups refresh on
            // next page load.
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
        if (startDate === undefined && endDate === undefined) {
            // eslint-disable-next-line no-console
            console.warn('[DH onItemEdit] empty changes — skipping to avoid nulling dates');
            return;
        }
        await updateWorkItemDates({
            workItemId: taskId,
            startDate: startDate || null,
            endDate: endDate || null,
        });
        // No refetch — NG holds optimistic state; refetch races commit.
    }

    _handleItemEditError(taskId, error) {
        this._showError('Failed to save date change', error);
    }

    /**
     * NG 0.183.1 onItemReorder(taskId, { newIndex, newParentId?, newPriorityGroup? }).
     * Payload object — the optional fields fire only when the drag gesture
     * crossed a boundary:
     *   - newParentId: re-parent within the same priority group
     *   - newPriorityGroup: drag across priority lanes (NOW ↔ NEXT ↔ PLANNED)
     * Asymmetric reprioritize ("NEXT → NOW works, NOW → NEXT doesn't") on
     * MF-Prod traced to this handler ignoring newPriorityGroup — sort updated
     * on both but lane only changed visually; on refresh items snapped back.
     */
    /**
     * Print a flat table of every task grouped by priority bucket so a
     * drag + console scroll shows exactly where each task is before and
     * after the save. Use NG's current view (mount handle) if available,
     * else fall back to this._tasks (last refetch).
     */
    /** Refetch fresh data from Apex, push into NG via setTasks, then dump. */
    async _refetchAfterPatchAndDump(label) {
        try {
            const data = await getProFormaTimelineData({ showCompleted: false });
            this._tasks = data || [];
            if (this._mountHandle && typeof this._mountHandle.setTasks === 'function') {
                this._mountHandle.setTasks(this._mapTasksForNg(this._tasks));
            }
            this._dumpPositions(label);
        } catch (error) {
            // eslint-disable-next-line no-console
            console.warn('[DH refetch] failed:', error);
        }
    }

    _dumpPositions(label) {
        let tasks = null;
        try {
            if (this._mountHandle && typeof this._mountHandle.getTasks === 'function') {
                tasks = this._mountHandle.getTasks();
            }
        } catch (e) { /* fall through */ }
        if (!tasks) tasks = this._tasks || [];
        const rows = tasks.map(t => ({
            bucket: t.priorityGroup || '(none)',
            sortOrder: t.sortOrder,
            name: (t.name || t.title || '').slice(0, 50),
            id: t.id,
        }));
        rows.sort((a, b) => {
            if (a.bucket !== b.bucket) return String(a.bucket).localeCompare(String(b.bucket));
            return Number(a.sortOrder) - Number(b.sortOrder);
        });
        // Plain text lines so DevTools "Copy all messages" captures them.
        // console.table prints nicely but is empty in pasted logs.
        const lines = rows.map(r =>
            `  ${String(r.bucket).padEnd(14)} ${String(r.sortOrder).padEnd(10)} ${r.id}  ${r.name}`
        );
        // eslint-disable-next-line no-console
        console.log('[DH positions] ' + label + ' (' + rows.length + ' tasks)\n' + lines.join('\n'));
    }

    async _handleItemReorder(arg1, payload) {
        const taskId = this._normalizeTaskId(arg1);
        this._dumpPositions('BEFORE onItemReorder ' + taskId);
        // Expanded payload logging — plain stringify so Glen can copy from
        // console without needing to expand collapsed objects. Fields
        // enumerated so we can spot if NG sends date info via reorder
        // (misclassified canvas horizontal drag).
        const p = payload || {};
        // Stringify full payload so deparent flags + any NG-side metadata is
        // visible. Earlier log omitted fields like `deparent: true` which NG
        // emits for bucket-header drops; handler couldn't branch on them.
        let fullPayloadJson = '';
        try { fullPayloadJson = JSON.stringify(p); } catch (e) { fullPayloadJson = '[unserializable]'; }
        // eslint-disable-next-line no-console
        console.log('[DH onItemReorder]', 'taskId=', taskId, 'payload=', fullPayloadJson);
        if (!taskId) { throw new Error('[DH] onItemReorder missing taskId'); }
        const { newIndex, newParentId, newPriorityGroup, startDate, endDate, position, beforeTaskId, afterTaskId } = p;
        // If NG smuggled date info through the reorder callback (happens when
        // the template framework misclassifies a horizontal canvas drag as a
        // row reorder), route to the date-edit Apex instead of corrupting
        // sortOrder. Confirmed MF-Prod 2026-04-19: users reported "won't let
        // me move it" when dragging bars horizontally.
        if (startDate || endDate) {
            await updateWorkItemDates({
                workItemId: taskId,
                startDate: startDate || null,
                endDate: endDate || null,
            });
            // No refetch — setTasks() rebuilds the whole gantt and causes
            // visual x-axis snap. NG's optimistic state already reflects
            // the new dates.
            return;
        }
        const ops = [];
        // NG 0.185.35+ emits position/beforeTaskId/afterTaskId for dense 1..N
        // server-side renumber. When present, skip the legacy sparse-sort write
        // and call reorderWorkItemDense instead — the server deterministically
        // splices the task and rewrites the whole bucket to contiguous integers,
        // so no more -964/-481 drift. Legacy (pre-0.185.35) NG bundles still
        // fall through to updateWorkItemSortOrder via the else branch.
        // newPriorityGroup still writes separately if NG also sent it (bucket
        // change + drop in one gesture).
        const hasDensePayload = position && newPriorityGroup;
        if (hasDensePayload) {
            // Apply bucket change first so reorderWorkItemDense sees the task
            // in its target bucket when it queries.
            ops.push(updateWorkItemPriorityGroup({ workItemId: taskId, priorityGroup: newPriorityGroup })
                .then(() => reorderWorkItemDense({
                    workItemId: taskId,
                    position,
                    beforeTaskId: beforeTaskId || null,
                    afterTaskId: afterTaskId || null,
                    priorityGroup: newPriorityGroup,
                })));
        } else if (position) {
            // Same-bucket dense reorder — no priorityGroup change. Derive from
            // the task's current bucket on the server.
            const currentGroup = this._tasks.find((t) => t.id === taskId)?.priorityGroup;
            if (currentGroup) {
                ops.push(reorderWorkItemDense({
                    workItemId: taskId,
                    position,
                    beforeTaskId: beforeTaskId || null,
                    afterTaskId: afterTaskId || null,
                    priorityGroup: currentGroup,
                }));
            } else {
                // Defensive fallback: no bucket known, punt to legacy sparse write.
                if (Number.isFinite(Number(newIndex))) {
                    ops.push(updateWorkItemSortOrder({ workItemId: taskId, sortOrder: Number(newIndex) }));
                }
            }
        } else {
            // LEGACY PATH (pre-0.185.35 NG bundle): sparse midpoint write.
            // Number(undefined) is NaN, NaN || 0 is 0 — so the prior code
            // silently zeroed sortOrder on every reorder with no newIndex. Only
            // call the sort-order API when we have a real numeric index.
            if (newIndex !== undefined && newIndex !== null && Number.isFinite(Number(newIndex))) {
                ops.push(updateWorkItemSortOrder({ workItemId: taskId, sortOrder: Number(newIndex) }));
            }
            if (newParentId !== undefined) {
                ops.push(updateWorkItemParent({ workItemId: taskId, parentId: newParentId || '' }));
            }
            if (newPriorityGroup !== undefined && newPriorityGroup !== null) {
                ops.push(updateWorkItemPriorityGroup({ workItemId: taskId, priorityGroup: newPriorityGroup }));
            }
        }
        if (ops.length === 0) {
            // eslint-disable-next-line no-console
            console.warn('[DH onItemReorder] empty payload — skipping Apex calls to avoid corrupting sortOrder');
            return;
        }
        await Promise.all(ops);
        // No refetch — setTasks() rebuilds the whole gantt and causes
        // visual x-axis snap after every drop. NG's optimistic state
        // already reflects the reorder; Apex collision-nudges show up
        // on next page load.
    }

    _handleItemReorderError(taskId, error) {
        this._showError('Failed to save reorder', error);
    }

    /**
     * NG 0.183 onItemClick(taskId). Opens the standard SF record page for
     * the clicked WorkItem in a new browser tab. Namespace-aware via the
     * sObject API name resolved through the schema import — Salesforce
     * NavigationMixin handles namespace prefixing automatically when the
     * objectApiName is the unprefixed local name (subscriber orgs resolve
     * the package namespace at navigation time).
     *
     * Why new tab over same-tab: the gantt is the working surface;
     * preserving it lets users reorder + reprioritize without losing scroll
     * position / viewport state. Same-tab would dump that context.
     */
    _handleItemClick(arg1) {
        const taskId = this._normalizeTaskId(arg1);
        // eslint-disable-next-line no-console
        console.log('[DH onItemClick]', { arg1Type: typeof arg1, resolvedTaskId: taskId });
        if (!taskId) {
            return;
        }
        // Build URL via the recordUrlTemplate already in mount config so
        // namespace handling stays in one place; open in a new tab.
        const url = `/lightning/r/${this._vfPrefix()}WorkItem__c/${taskId}/view`;
        window.open(url, '_blank');
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
                // NG's TaskData spec uses `parentId`. Prior code emitted
                // `parentWorkItemId` (mirroring the Apex field name), which
                // NG silently ignored — tasks with parents always appeared
                // root-level, so drag-to-parent saved to DB but never
                // rendered as nested. Use NG's name. Keep parentWorkItemId
                // alias too in case a plugin still reads the old key.
                parentId: r.parentWorkItemId || null,
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
        return `dh.gantt.viewport.v3.${this.mode || 'embedded'}`;
    }

    _readInitialViewport() {
        try {
            const raw = window.localStorage.getItem(this._viewportStorageKey);
            if (!raw) return undefined;
            const parsed = JSON.parse(raw);
            if (!parsed || typeof parsed !== 'object') return undefined;
            // TTL-bounded pan memory: within 10 min of the last persist, restore
            // the user's scroll so tab-flip feels sticky. Past that, drop it and
            // fall through to initialFocusDate today-landing. This kills the
            // self-reinforcing trap where every load anchored to an old pan
            // (scrollLeft:388 pointed at "today when it was written" — once
            // today moves on or the dataset shifts, that pixel is no longer
            // today, and today-landing silently breaks).
            const age = Date.now() - Number(parsed.savedAt || 0);
            if (!Number.isFinite(age) || age < 0 || age > 600000) return undefined;
            if (!parsed.state || typeof parsed.state !== 'object') return undefined;
            return parsed.state;
        } catch (e) { /* storage unavailable — first mount, fall through */ }
        return undefined;
    }

    _handleViewportChange(state) {
        if (this._viewportWriteTimer) clearTimeout(this._viewportWriteTimer);
        this._viewportWriteTimer = setTimeout(() => {
            this._viewportWriteTimer = null;
            try {
                const payload = { state, savedAt: Date.now() };
                window.localStorage.setItem(this._viewportStorageKey, JSON.stringify(payload));
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
            // eslint-disable-next-line no-console
            console.log('[DH refetch] starting — mountHandle type=', typeof this._mountHandle, 'keys=', this._mountHandle ? Object.keys(this._mountHandle) : 'no handle');
            const data = await getProFormaTimelineData({ showCompleted: false });
            this._tasks = data || [];
            // eslint-disable-next-line no-console
            console.log('[DH refetch] fetched', this._tasks.length, 'tasks. Sample sortOrder values:', this._tasks.slice(0, 5).map(t => ({ id: t.id, so: t.sortOrder })));
            const setTasksType = this._mountHandle ? typeof this._mountHandle.setTasks : 'no handle';
            // eslint-disable-next-line no-console
            console.log('[DH refetch] handle.setTasks typeof=', setTasksType);
            const mapped = this._mapTasksForNg(this._tasks);
            // Re-filter deps against the refreshed task set so arrows whose
            // endpoints just dropped out of view (completed, date-cleared)
            // don't throw in DependencyRenderer. Map returns a new array
            // reference, which NG relies on for layoutMap invalidation.
            const deps = this._mapDependenciesForNg(this._dependencies || []);
            this._dependencies = deps;
            if (this._mountHandle && typeof this._mountHandle.setData === 'function') {
                // eslint-disable-next-line no-console
                console.log('[DH refetch] calling setData with', mapped.length, 'tasks,', deps.length, 'deps');
                this._mountHandle.setData(mapped, deps);
            } else if (this._mountHandle && typeof this._mountHandle.setTasks === 'function') {
                // eslint-disable-next-line no-console
                console.log('[DH refetch] setData unavailable — calling setTasks only with', mapped.length, 'tasks');
                this._mountHandle.setTasks(mapped);
            } else {
                // eslint-disable-next-line no-console
                console.warn('[DH refetch] NG handle missing setData/setTasks — visual state will not refresh');
            }
        } catch (error) {
            // eslint-disable-next-line no-console
            console.warn('[DeliveryTimeline] post-save re-fetch failed (non-critical):', error);
        }
    }

    _handleEnterFullscreen() {
        // Navigate to the standalone Aura application URL. An <aura:application>
        // extending force:slds is served at /<ns>/AppName.app as a TOP-LEVEL
        // page — outside /one/one.app, so no LEX chrome (no app launcher, no
        // nav tabs, no global header, no sidebar). Browser URL is the app;
        // viewport is 100% the gantt. User navigates back via browser Back
        // button or a Back-to-SF link inside the gantt.
        //
        // Prior attempts:
        //  - document.documentElement.requestFullscreen() → in-iframe only,
        //    LEX chrome stays visible outside the iframe. Doesn't work.
        //  - /lightning/n/Delivery_Gantt_Full_Bleed (VF tab) → wraps in LEX
        //    alohaPage, keeps menu bar. Doesn't work.
        //  - /apex/DeliveryGanttStandalone (raw VF) → same alohaPage wrap
        //    when routed through standard__webPage. Doesn't work.
        //
        // Standalone aura:app URL is the canonical Salesforce-documented
        // pattern for chromeless rendering inside a SF org session.
        const prefix = this._vfPrefix();
        const nsSegment = prefix ? prefix.replace('__', '') : 'c';
        const url = `/${nsSegment}/DeliveryTimelineStandalone.app`;
        // Use window.top so navigation escapes any iframe context (Lightning
        // Out, sub-frames). Falls back to window.location if top is blocked.
        try {
            if (window.top && window.top !== window) {
                window.top.location.href = url;
                return;
            }
        } catch (e) { /* fall through */ }
        window.location.href = url;
    }

    _handleExitFullscreen() {
        // The VF page may be rendered:
        //   (a) standalone at /apex/DeliveryGanttStandalone on the VF
        //       subdomain (host ends .vf.force.com) — window.top === window
        //   (b) inside a LEX Lightning Out iframe — window.top is LEX
        // Case (a): relative /lightning/n/... resolves against the VF
        // domain which has no /lightning path. Must navigate to absolute
        // LEX URL. Case (b): window.top.location.href breaks out to LEX.
        const prefix = this._vfPrefix();
        const path = `/lightning/n/${prefix}${EMBEDDED_TAB_API_NAME}`;
        const host = window.location.hostname || '';
        // VF host shape: "<instance>--<ns>.scratch.vf.force.com" or
        // "<instance>.<mydomain>.vf.force.com". LEX host drops the --<ns>
        // segment (or the plain vf. segment) and uses .lightning.force.com.
        let lexHost = host.replace('.vf.force.com', '.lightning.force.com');
        const nsPrefixMatch = lexHost.match(/^(.*?)--[^.]+\.(.*)$/);
        if (nsPrefixMatch) {
            lexHost = `${nsPrefixMatch[1]}.${nsPrefixMatch[2]}`;
        }
        const isVfHost = host.indexOf('.vf.force.com') !== -1;
        const url = isVfHost ? `${window.location.protocol}//${lexHost}${path}` : path;
        try {
            if (window.top && window.top !== window) {
                window.top.location.href = url;
                return;
            }
        } catch (e) { /* cross-origin; fall through */ }
        // Standalone VF or same-origin iframe — direct nav.
        window.location.href = url;
    }

    _showError(prefix, error) {
        const msg = (error && error.body && error.body.message) || (error && error.message) || 'Unknown error';
        // eslint-disable-next-line no-console
        console.error('[deliveryProFormaTimeline]', prefix, error);
        this.dispatchEvent(new ShowToastEvent({
            title: prefix, message: msg, variant: 'error',
        }));
    }

    // ------------------------------------------------------------------
    // __cnEdit bridge — window.__cnEdit publishes a programmatic edit API
    // so an external driver (Claude, a devtools scratchpad, a Lightning
    // console shortcut) can push the same patches our drag/reorder
    // handlers emit. Each mutation routes through _handlePatch so it
    // writes immediately to Apex and triggers a refetch.
    //
    // Shape (mirrors CN's useCnEditBridge):
    //   window.__cnEdit.help()
    //   window.__cnEdit.whoami()                 -> Promise<email|null>
    //   window.__cnEdit.getState()               -> { tasks, mounted, surface }
    //   window.__cnEdit.moveTask(id, startISO, endISO)
    //   window.__cnEdit.moveToGroup(id, group)
    //   window.__cnEdit.reorder(id, newIndex)
    //   window.__cnEdit.setParent(id, parentId|null)
    //   window.__cnEdit.submit(note?)            -> informational no-op (DH
    //                                               persists each patch
    //                                               immediately; there is
    //                                               no batched submit)
    //   window.__cnEdit.reset()                  -> informational no-op
    //                                               (reload the page to
    //                                               refetch from server)
    //
    // CN and DH deliberately share the same verb names so cross-context
    // scripts don't have to branch on surface.
    _installCnEditBridge() {
        if (typeof window === 'undefined') return;
        const self = this;
        const VERSION = '0.1.0';
        const HELP_TEXT = [
            '',
            'cn-edit v' + VERSION + ' (DH/Salesforce) — per-patch Apex write-back',
            '',
            '  __cnEdit.help()',
            '  __cnEdit.whoami()          -> running user Id',
            '  __cnEdit.getState()        -> { tasks, mounted, surface }',
            '  __cnEdit.moveTask(id, startISO, endISO)',
            '  __cnEdit.moveToGroup(id, group)',
            '  __cnEdit.reorder(id, newIndex)',
            '  __cnEdit.setParent(id, parentId|null)',
            '  __cnEdit.scrollToDate(date) -> scroll timeline to focus on date (NG 0.185.1+)',
            '  __cnEdit.toggleHeader()   -> show/hide the Salesforce page header chrome',
            '  __cnEdit.submit(note?)    -> no-op (DH writes every patch immediately)',
            '  __cnEdit.reset()          -> no-op (reload page to refetch)',
            '',
            'Each mutation calls _handlePatch which POSTs directly to Apex',
            '(updateWorkItemDates / SortOrder / PriorityGroup / Parent).',
            ''
        ].join('\n');

        const bridge = {
            version: VERSION,
            help: function () {
                // eslint-disable-next-line no-console
                console.log(HELP_TEXT);
                return HELP_TEXT;
            },
            whoami: function () {
                // LWC rule (LWC1503): $A is banned. Use @salesforce/user/Id
                // — synchronous static import, returns the running user's
                // 18-char Id. Email would require a @wire(getRecord) round
                // trip; Id is enough for the Aura-parity contract.
                return Promise.resolve(USER_ID || null);
            },
            getState: function () {
                return {
                    tasks: self._tasks || [],
                    mounted: !!self._mounted,
                    surface: (typeof window !== 'undefined' && window.location && window.location.pathname) || '',
                };
            },
            moveTask: function (id, startISO, endISO) {
                return self._handlePatch({ id: id, startDate: startISO, endDate: endISO });
            },
            moveToGroup: function (id, group) {
                return self._handlePatch({ id: id, priorityGroup: group });
            },
            reorder: function (id, newIndex) {
                return self._handlePatch({ id: id, sortOrder: Number(newIndex) || 0 });
            },
            setParent: function (id, parentId) {
                return self._handlePatch({ id: id, parentId: parentId || null });
            },
            toggleHeader: function () {
                // Toggles the SLDS page header / FlexiPage chrome hide-CSS.
                // Shared code path with the NG TitleBar button (0.185.26
                // titleBarButtons slot). Console still works as a backup.
                self._toggleHeaderChrome();
                return { ok: true, headerVisible: self._headerVisible };
            },
            scrollToDate: function (date) {
                // NG 0.185.1+ exposes scrollToDate on the mount handle.
                // Accepts Date object or ISO 'YYYY-MM-DD' string. Snaps
                // to start-of-period for the current zoom (week/month/quarter).
                // No-op on older bundles — handle method absent.
                if (!self._mountHandle || typeof self._mountHandle.scrollToDate !== 'function') {
                    const msg = 'scrollToDate unavailable — requires NG 0.185.1+ bundle';
                    // eslint-disable-next-line no-console
                    console.warn('[cn-edit]', msg);
                    return { ok: false, msg: msg };
                }
                const arg = date instanceof Date ? date : new Date(date || Date.now());
                self._mountHandle.scrollToDate(arg);
                return { ok: true };
            },
            submit: function (_note) {
                const msg = 'submit() is a no-op in DH: each patch is already persisted. Reload to refetch.';
                // eslint-disable-next-line no-console
                console.log('[cn-edit]', msg);
                return Promise.resolve({ ok: true, msg: msg });
            },
            reset: function () {
                const msg = 'reset() is a no-op in DH: there are no local overrides. Reload the page to refetch.';
                // eslint-disable-next-line no-console
                console.log('[cn-edit]', msg);
                return msg;
            }
        };

        this._cnEditBridge = bridge;
        // Triple-publish: LWS strict mode (MF-Prod, verified 2026-04-19)
        // sandboxes `window.*` writes so they're invisible to DevTools. The
        // console.log prints (shared channel) but `window.__cnEdit = bridge`
        // lands in a distorted window the user can't reach. Fallbacks:
        //   1. window.__cnEdit       — works on non-LWS orgs (scratch, older prod)
        //   2. document.body.__cnEdit — DOM-property attach; survives LWS because
        //                               document.body is a real Element reference
        //   3. CustomEvent dispatch  — bridge-ready signal for consumers that
        //                               prefer event-driven discovery
        // Each in its own try/catch so one failure doesn't cascade.
        try { window.__cnEdit = bridge; } catch (e) { /* LWS proxy */ }
        try {
            if (typeof document !== 'undefined' && document.body) {
                document.body.__cnEdit = bridge;
            }
        } catch (e) { /* body attach blocked */ }
        try {
            document.dispatchEvent(new CustomEvent('dh:bridge-ready', {
                detail: bridge,
                bubbles: true,
                composed: true,
            }));
        } catch (e) { /* dispatchEvent unavailable */ }
        try {
            // eslint-disable-next-line no-console
            console.log(
                '%c[cn-edit v' + VERSION + ' DH]%c editable timeline ready. Try %cdocument.body.__cnEdit.help()%c (LWS) or %cwindow.__cnEdit.help()%c (scratch).',
                'color:#a21caf;font-weight:bold',
                'color:inherit',
                'color:#a21caf;font-family:monospace',
                'color:inherit',
                'color:#a21caf;font-family:monospace',
                'color:inherit'
            );
        } catch (e) { /* console unavailable */ }
    }

    _uninstallCnEditBridge() {
        try {
            if (typeof window !== 'undefined' && window.__cnEdit && window.__cnEdit === this._cnEditBridge) {
                delete window.__cnEdit;
            }
        } catch (_e) { /* swallow */ }
        try {
            if (typeof document !== 'undefined' && document.body && document.body.__cnEdit === this._cnEditBridge) {
                delete document.body.__cnEdit;
            }
        } catch (_e) { /* swallow */ }
        this._cnEditBridge = null;
    }
}
