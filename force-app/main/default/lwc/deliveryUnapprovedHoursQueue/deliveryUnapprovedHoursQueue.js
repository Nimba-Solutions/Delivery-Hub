/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  "Hours without approval" card for the Home page, directly
 *               under Pending Work Approvals. Approve-before-hours is a SOFT
 *               gate: hours always save, and hours logged (after the
 *               EnableUnapprovedHoursFlagDateTime__c cutover) on a request
 *               nobody approved land here. Wires
 *               DeliveryTriageController.getUnapprovedHours: the total, then
 *               one row per request (item link, status, hours, log count,
 *               work-date span). The approver clears them with "Approve hours"
 *               per row or "Approve all" (DeliveryTriageController
 *               .acknowledgeUnapprovedHours: request -> Accepted, work item
 *               untouched). Rows decided elsewhere (Offer Sent, declined,
 *               Budget Hold) show why instead of a button. Buttons render only
 *               for the approver / an admin (server enforces it regardless).
 *               Hidden entirely while the flag setting is null, and self-hides
 *               on Home when its HideHome setting is stamped.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import WORK_ITEM_OBJECT from "@salesforce/schema/WorkItem__c";
import getUnapprovedHours from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getUnapprovedHours";
import acknowledgeUnapprovedHours from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.acknowledgeUnapprovedHours";
import getHiddenHomeComponents from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents";

const HOME_COMPONENT_KEY = "deliveryUnapprovedHoursQueue";

export default class DeliveryUnapprovedHoursQueue extends NavigationMixin(LightningElement) {
    feed = null;
    errorMessage = "";
    isLoading = true;
    isSaving = false;

    wiredResult;

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

    /**
     * Render at all: only once the feed says the flag is on (no flash while
     * loading when it is off), or to surface a load error; never when hidden
     * on Home.
     */
    get isVisible() {
        if (this.isHiddenOnHome || this.isLoading) {
            return false;
        }
        if (this.errorMessage) {
            return true;
        }
        return !!(this.feed && this.feed.enabled);
    }

    @wire(getUnapprovedHours)
    wiredFeed(result) {
        this.wiredResult = result;
        if (result.data) {
            this.feed = result.data;
            this.errorMessage = "";
            this.isLoading = false;
        } else if (result.error) {
            this.errorMessage = this._errorText(result.error, "Unable to load hours without approval.");
            this.feed = null;
            this.isLoading = false;
        }
    }

    // ── Row shaping (templates can't do ternaries — precompute) ──

    get rawRows() {
        return (this.feed && this.feed.rows) || [];
    }

    get rows() {
        return this.rawRows.map((r) => {
            const logCount = Number(r.logCount) || 0;
            return {
                key: r.requestId,
                requestId: r.requestId,
                workItemId: r.workItemId,
                name: r.workItemName || "(unnamed item)",
                briefDescription: r.briefDescription || "",
                hasBrief: Boolean(r.briefDescription),
                statusDisplay: r.requestStatus || "No status",
                hoursDisplay: `${this._formatHours(r.hours)}h`,
                logsDisplay: logCount === 1 ? "1 log" : `${logCount} logs`,
                spanDisplay: this._spanDisplay(r.firstWorkDate, r.lastWorkDate),
                showButton: this.canApprove && r.canAcknowledge === true,
                blockedReason: r.blockedReason || "",
                hasBlockedReason: Boolean(r.blockedReason)
            };
        });
    }

    get canApprove() {
        return !!(this.feed && this.feed.canApprove);
    }

    get approvableIds() {
        return this.rawRows.filter((r) => r.canAcknowledge === true).map((r) => r.requestId);
    }

    get showBulkButton() {
        return this.canApprove && this.approvableIds.length > 1;
    }

    get isBusy() {
        return this.isSaving;
    }

    // ── State flags ──────────────────────────────────────────────

    get hasRows() {
        return !this.isLoading && !this.errorMessage && this.rawRows.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && this.rawRows.length === 0;
    }

    get hasError() {
        return !this.isLoading && this.errorMessage.length > 0;
    }

    get totalDisplay() {
        const total = this.feed ? this.feed.totalHours : 0;
        return `${this._formatHours(total)}h`;
    }

    get headlineDisplay() {
        const n = this.rawRows.length;
        const noun = n === 1 ? "request" : "requests";
        return `without approval across ${n} ${noun}`;
    }

    get cutoverDisplay() {
        const c = this.feed && this.feed.cutover;
        if (!c) {
            return "";
        }
        const d = new Date(c);
        if (!Number.isFinite(d.getTime())) {
            return "";
        }
        return `Counting hours logged since ${d.toLocaleDateString()}`;
    }

    // ── Actions ──────────────────────────────────────────────────

    handleApproveRow(event) {
        const requestId = event.currentTarget.dataset.requestId;
        if (requestId) {
            this._acknowledge([requestId]);
        }
    }

    handleApproveAll() {
        const ids = this.approvableIds;
        if (ids.length) {
            this._acknowledge(ids);
        }
    }

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

    handleRefresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    _acknowledge(requestIds) {
        this.isSaving = true;
        return acknowledgeUnapprovedHours({ requestIds })
            .then((result) => {
                const ok = (result && result.succeededCount) || 0;
                const failed = (result && result.failedCount) || 0;
                if (failed > 0) {
                    const first = result.failures && result.failures[0] ? result.failures[0].error : "";
                    this._toast("Some hours were not approved", `${ok} approved, ${failed} not. ${first}`, "warning");
                } else {
                    this._toast("Hours approved", `${ok} request(s) approved.`, "success");
                }
                return this.wiredResult ? refreshApex(this.wiredResult) : null;
            })
            .catch((error) => {
                this._toast("Could not approve hours", this._errorText(error, "Unexpected error."), "error");
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    // ── Internals ────────────────────────────────────────────────

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _errorText(err, fallback) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        return fallback;
    }

    _formatHours(value) {
        const n = Number(value);
        if (!Number.isFinite(n)) {
            return "0";
        }
        return String(Math.round(n * 100) / 100);
    }

    _spanDisplay(first, last) {
        if (!first) {
            return "";
        }
        if (!last || last === first) {
            return `worked ${first}`;
        }
        return `worked ${first} to ${last}`;
    }
}
