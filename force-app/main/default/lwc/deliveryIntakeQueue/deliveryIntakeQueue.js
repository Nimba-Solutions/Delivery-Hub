/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Intake queue card for the workspace "Intake" tab — the front
 *               of the pipeline. Wires DeliveryTriageController.getIntakeItems
 *               and renders each WorkItem that arrived but was never activated
 *               onto the timeline (ActivatedDateTime__c = NULL → invisible on
 *               the board/Gantt, which require it to be set). Jose triages each
 *               row two ways: "Route to dev" (assign the developer chosen in
 *               the inline picker, advance to Ready for Development, and stamp
 *               ActivatedDateTime so it appears on the timeline) via
 *               routeToDev, or "Dismiss" (resolve it himself to a terminal
 *               stage) via dismissIntake — both bulk-capable and called
 *               imperatively (mutations are non-cacheable). After any action
 *               the wire is refreshed and a toast confirms the outcome using
 *               OUR labels (managed-package AuraHandledException messages come
 *               back generic). Clicking an item name navigates to the
 *               WorkItem__c record via NavigationMixin + @salesforce/schema so
 *               the object API name stays namespace-safe.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import WORK_ITEM_OBJECT from "@salesforce/schema/WorkItem__c";
import getIntakeItems from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getIntakeItems";
import routeToDevApex from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.routeToDev";
import dismissIntakeApex from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.dismissIntake";
import getHiddenHomeComponents from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents";

const MS_PER_DAY = 86400000;
// This component's key in the Home-visibility map (matches its LWC folder name).
const HOME_COMPONENT_KEY = "deliveryIntakeQueue";
// Real-time channel: the ghost recorder publishes here when a new inbound
// request is created, so the queue refreshes live (no manual page reload).
const PE_CHANNEL = "/event/%%%NAMESPACE_DOT%%%DeliveryWorkItemChange__e";

export default class DeliveryIntakeQueue extends NavigationMixin(LightningElement) {
    // ── Home-page visibility (admin-toggleable, default = shown) ──
    // Hides ONLY on the Delivery Hub app Home page when an admin toggles it
    // off in Settings. Everywhere else this component always renders.
    @wire(CurrentPageReference) _homePageRef;
    @wire(getHiddenHomeComponents) _hiddenHomeComponents;

    get isOnHomePage() {
        const ref = this._homePageRef;
        if (!ref) {
            return false;
        }
        const attrs = ref.attributes || {};
        if (ref.type === "standard__namedPage" && attrs.pageName === "home") {
            return true;
        }
        const url = attrs.url
            || (typeof window !== "undefined" && window.location ? window.location.pathname : "");
        return typeof url === "string" && url.indexOf("/lightning/page/home") !== -1;
    }

    get isHiddenOnHome() {
        if (!this.isOnHomePage) {
            return false;
        }
        const map = this._hiddenHomeComponents && this._hiddenHomeComponents.data;
        return !!(map && map[HOME_COMPONENT_KEY] === true);
    }

    get isNotHiddenOnHome() {
        return !this.isHiddenOnHome;
    }

    itemsRaw = [];
    errorMessage = "";
    isLoading = true;
    isSaving = false;

    // Developer chosen in the inline picker (null = route unassigned).
    developerId = null;

    // Work item ids ticked for a bulk action.
    selectedIds = [];

    wiredResult;

    @wire(getIntakeItems)
    wiredItems(result) {
        this.wiredResult = result;
        if (result.data) {
            this.itemsRaw = result.data;
            this.errorMessage = "";
            this.isLoading = false;
        } else if (result.error) {
            this.errorMessage = this._errorText(result.error, "Unable to load the intake queue.");
            this.itemsRaw = [];
            this.isLoading = false;
        }
    }

    // ── Live refresh: pop new inbound requests in without a reload ──

    _subscription = null;

    connectedCallback() {
        onError((err) => {
            // Best-effort: the wired data still loads on its own if the
            // streaming channel hiccups — just log and carry on.
            // eslint-disable-next-line no-console
            console.warn("[DeliveryIntakeQueue] empApi error:", JSON.stringify(err));
        });
        subscribe(PE_CHANNEL, -1, () => {
            // A new or changed work item may belong in (or leave) the intake
            // queue — re-pull the wired list so it updates in place.
            refreshApex(this.wiredResult);
        }).then((response) => {
            this._subscription = response;
        });
    }

    disconnectedCallback() {
        if (this._subscription) {
            unsubscribe(this._subscription, () => {});
            this._subscription = null;
        }
    }

    // ── Row shaping (templates can't do ternaries — precompute) ──

    get rows() {
        return this.itemsRaw.map((dto) => ({
            key: dto.workItemId,
            workItemId: dto.workItemId,
            name: dto.name || "(unnamed item)",
            briefDescription: dto.briefDescription || "",
            hasBrief: Boolean(dto.briefDescription),
            arrivedDisplay: this._ageDisplay(dto.createdDate),
            stageDisplay: dto.currentStage || "",
            requestedByDisplay: dto.requestedByName || "",
            hasRequestedBy: Boolean(dto.requestedByName),
            isSelected: this.selectedIds.includes(dto.workItemId)
        }));
    }

    // ── State flags ──────────────────────────────────────────────

    get hasRows() {
        return !this.isLoading && !this.errorMessage && this.itemsRaw.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && this.itemsRaw.length === 0;
    }

    get hasError() {
        return !this.isLoading && this.errorMessage.length > 0;
    }

    // ── Headline + bulk state ────────────────────────────────────

    get headlineDisplay() {
        const n = this.itemsRaw.length;
        const noun = n === 1 ? "item" : "items";
        return `${n} inbound ${noun} to triage`;
    }

    get selectedCount() {
        return this._selectedPresentIds().length;
    }

    get bulkRouteLabel() {
        return `Route to dev (${this.selectedCount})`;
    }

    get isBulkRouteDisabled() {
        return this.isSaving || this.selectedCount === 0;
    }

    get isAllSelected() {
        return this.itemsRaw.length > 0 && this.selectedCount === this.itemsRaw.length;
    }

    // ── Navigation ───────────────────────────────────────────────

    handleItemClick(event) {
        const workItemId = event.currentTarget.dataset.workItemId;
        if (!workItemId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: workItemId,
                objectApiName: WORK_ITEM_OBJECT.objectApiName,
                actionName: "view"
            }
        });
    }

    // ── Developer picker + selection ─────────────────────────────

    handleDeveloperChange(event) {
        // lightning-record-picker emits the chosen record id in detail.
        this.developerId = (event.detail && event.detail.recordId) || null;
    }

    handleRowSelect(event) {
        const workItemId = event.target.dataset.workItemId;
        if (!workItemId) {
            return;
        }
        const next = this.selectedIds.filter((id) => id !== workItemId);
        if (event.target.checked) {
            next.push(workItemId);
        }
        this.selectedIds = next;
    }

    handleSelectAll(event) {
        this.selectedIds = event.target.checked
            ? this.itemsRaw.map((dto) => dto.workItemId)
            : [];
    }

    // ── Route to dev ─────────────────────────────────────────────

    handleBulkRoute() {
        this._routeIds(this._selectedPresentIds());
    }

    handleRowRoute(event) {
        const workItemId = event.currentTarget.dataset.workItemId;
        if (!workItemId) {
            return;
        }
        this._routeIds([workItemId]);
    }

    _routeIds(ids) {
        if (ids.length === 0 || this.isSaving) {
            return;
        }
        this.isSaving = true;
        routeToDevApex({ workItemIds: ids, developerUserId: this.developerId })
            .then((result) => {
                this.isSaving = false;
                this.selectedIds = [];
                this._toastBulkOutcome(result, "routed to dev", "Routed");
                return refreshApex(this.wiredResult);
            })
            .catch((err) => {
                this.isSaving = false;
                this._toast(
                    "Route failed",
                    this._errorText(err, "The selected items could not be routed."),
                    "error"
                );
            });
    }

    // ── Dismiss ──────────────────────────────────────────────────

    handleRowDismiss(event) {
        const workItemId = event.currentTarget.dataset.workItemId;
        if (!workItemId) {
            return;
        }
        this._dismissIds([workItemId]);
    }

    _dismissIds(ids) {
        if (ids.length === 0 || this.isSaving) {
            return;
        }
        this.isSaving = true;
        dismissIntakeApex({ workItemIds: ids })
            .then((result) => {
                this.isSaving = false;
                this.selectedIds = [];
                this._toastBulkOutcome(result, "dismissed", "Dismissed");
                return refreshApex(this.wiredResult);
            })
            .catch((err) => {
                this.isSaving = false;
                this._toast(
                    "Dismiss failed",
                    this._errorText(err, "The selected items could not be dismissed."),
                    "error"
                );
            });
    }

    handleRefresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    // ── Internals ────────────────────────────────────────────────

    _selectedPresentIds() {
        const present = new Set(this.itemsRaw.map((dto) => dto.workItemId));
        return this.selectedIds.filter((id) => present.has(id));
    }

    _toastBulkOutcome(result, verb, successTitle) {
        const succeeded = result && result.succeededCount ? result.succeededCount : 0;
        const failed = result && result.failedCount ? result.failedCount : 0;
        if (failed === 0) {
            const noun = succeeded === 1 ? "item" : "items";
            this._toast(successTitle, `${succeeded} ${noun} ${verb}.`, "success");
        } else if (succeeded === 0) {
            this._toast(`${successTitle} failed`, `0 ${verb}, ${failed} failed.`, "error");
        } else {
            this._toast("Partially complete", `${succeeded} ${verb}, ${failed} failed.`, "warning");
        }
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _errorText(err, fallback) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        return fallback;
    }

    _ageDisplay(createdDate) {
        if (!createdDate) {
            return "just arrived";
        }
        const created = new Date(createdDate).getTime();
        if (!Number.isFinite(created)) {
            return "just arrived";
        }
        const days = Math.max(0, Math.floor((Date.now() - created) / MS_PER_DAY));
        if (days === 0) {
            return "arrived today";
        }
        if (days === 1) {
            return "arrived 1 day ago";
        }
        return `arrived ${days} days ago`;
    }
}
