/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  "In Flight" card for the Home page — the middle of the
 *               pipeline, between Pending Work Approvals and Close Outs. Wires
 *               DeliveryTriageController.getInFlightItems and renders every
 *               WorkItem inside the dev → deploying band
 *               (DeliveryWorkflowConfigService.IN_FLIGHT_STAGES) in pipeline
 *               order: stage, developer, approved hours and time in stage.
 *               Read-only by design: the client reads it on a standup; nobody
 *               clicks anything except the item link (NavigationMixin +
 *               @salesforce/schema so the object API name stays
 *               namespace-safe) and the "Open full report" button, which links
 *               to the In_Flight_Work_Items report via the id the controller
 *               resolves by DeveloperName. Self-hides on Home when its HideHome
 *               setting is stamped, like the other Home cards.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import WORK_ITEM_OBJECT from "@salesforce/schema/WorkItem__c";
import getInFlightItems from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getInFlightItems";
import getInFlightReportId from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getInFlightReportId";
import getHiddenHomeComponents from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents";

const MS_PER_DAY = 86400000;
const HOME_COMPONENT_KEY = "deliveryInFlightQueue";

export default class DeliveryInFlightQueue extends NavigationMixin(LightningElement) {
    itemsRaw = [];
    errorMessage = "";
    isLoading = true;
    reportId = "";

    wiredResult;

    // Home-page visibility: when the HideHome setting for this card is set,
    // self-hide on Home only (it stays visible anywhere else it is placed).
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

    @wire(getInFlightItems)
    wiredItems(result) {
        this.wiredResult = result;
        if (result.data) {
            this.itemsRaw = result.data;
            this.errorMessage = "";
            this.isLoading = false;
        } else if (result.error) {
            this.errorMessage = this._errorText(result.error, "Unable to load the in-flight list.");
            this.itemsRaw = [];
            this.isLoading = false;
        }
    }

    @wire(getInFlightReportId)
    wiredReportId({ data }) {
        if (data) {
            this.reportId = data;
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
            stageDisplay: dto.stage || "In flight",
            developerDisplay: dto.developerName || "Unassigned",
            hoursDisplay: this._hoursDisplay(dto.approvedHours),
            ageDisplay: this._ageDisplay(dto.stageEnteredAt)
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

    get hasNoReport() {
        return !this.reportId;
    }

    get headlineDisplay() {
        const n = this.itemsRaw.length;
        const noun = n === 1 ? "item" : "items";
        return `${n} ${noun} in flight`;
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

    handleOpenReport() {
        if (!this.reportId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.reportId,
                objectApiName: "Report",
                actionName: "view"
            }
        });
    }

    handleRefresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    // ── Internals ────────────────────────────────────────────────

    _errorText(err, fallback) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        return fallback;
    }

    _hoursDisplay(approvedHours) {
        const n = Number(approvedHours);
        if (!Number.isFinite(n) || n <= 0) {
            return "no approved hours";
        }
        return `${n}h approved`;
    }

    _ageDisplay(stageEnteredAt) {
        if (!stageEnteredAt) {
            return "in stage";
        }
        const entered = new Date(stageEnteredAt).getTime();
        if (!Number.isFinite(entered)) {
            return "in stage";
        }
        const days = Math.max(0, Math.floor((Date.now() - entered) / MS_PER_DAY));
        if (days === 0) {
            return "in stage since today";
        }
        if (days === 1) {
            return "in stage 1 day";
        }
        return `in stage ${days} days`;
    }
}
