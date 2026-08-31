/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Approval agenda summary card (PR3 of the work-approval
 *               queue): three click-through tiles — Hours Approved (this
 *               month), Quotes Awaiting Acceptance (Offer-Sent WorkRequests;
 *               relabeled from "Pending Approval" per DECISION-G2 so it stops
 *               sharing a name with the WorkItem approval-stage surfaces),
 *               and Approved & In Progress — fed by
 *               DeliveryApprovalSummaryController.getApprovalSummary, plus
 *               the approved-vs-total pitch strip ("Nh of Mh approved (P%)")
 *               over the active portfolio — THE approval-queue pitch stat.
 *               The percentage is zero-guarded (a 0h denominator renders 0%,
 *               never Infinity/NaN). Each tile navigates to its backing
 *               report via NavigationMixin using the report record id the
 *               controller resolved by DeveloperName (namespace-safe: no
 *               hardcoded org ids). Tiles whose report is missing in the org
 *               render without the click-through affordance.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import getApprovalSummary from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryApprovalSummaryController.getApprovalSummary";
import getHiddenHomeComponents from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents";

const REPORT_HOURS_APPROVED = "Hours_Approved_This_Period";
const REPORT_PENDING = "Pending_Approval";
const REPORT_IN_PROGRESS = "Approved_In_Progress";
// This component's key in the Home-visibility map (matches its LWC folder name).
const HOME_COMPONENT_KEY = "deliveryApprovalSummaryCard";

export default class DeliveryApprovalSummaryCard extends NavigationMixin(LightningElement) {
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

    summary;
    errorMessage = "";
    isLoading = true;

    @wire(getApprovalSummary)
    wiredSummary({ data, error }) {
        if (data) {
            this.summary = data;
            this.errorMessage = "";
            this.isLoading = false;
        } else if (error) {
            this.errorMessage =
                error.body && error.body.message
                    ? error.body.message
                    : "Unable to load the approval summary.";
            this.summary = null;
            this.isLoading = false;
        }
    }

    // ── State flags ──────────────────────────────────────────────

    get hasError() {
        return !this.isLoading && this.errorMessage.length > 0;
    }

    get hasData() {
        return !this.isLoading && !this.errorMessage && Boolean(this.summary);
    }

    // ── Pitch strip (computed — templates can't do ternaries) ────

    get approvedShareStat() {
        if (!this.summary) {
            return "";
        }
        const total = this._toFiniteNumber(this.summary.totalActiveEstimatedHours);
        const approved = this._toFiniteNumber(this.summary.totalApprovedHours);
        // Zero-guard the ratio: a 0h denominator reads 0%, never Infinity.
        const pct = total > 0 ? (approved / total) * 100 : 0;
        return `${this._formatHours(approved)}h of ${this._formatHours(total)}h approved (${this._formatPercent(pct)}%)`;
    }

    // ── Tiles (computed — templates can't do ternaries) ──────────

    get tiles() {
        if (!this.summary) {
            return [];
        }
        const reportIds = this.summary.reportIdsByDeveloperName || {};
        return [
            {
                key: "approved",
                label: "Hours approved (this month)",
                value: `${this._formatHours(this.summary.hoursApprovedThisMonth)}h`,
                detail: "Granted on accepted requests",
                reportId: reportIds[REPORT_HOURS_APPROVED] || "",
                hasReport: Boolean(reportIds[REPORT_HOURS_APPROVED]),
                hasNoReport: !reportIds[REPORT_HOURS_APPROVED]
            },
            {
                // DECISION-G2 (2026-07-03): "pending approval" now means WorkItems in
                // approval stages. This tile counts WorkRequests at Offer Sent —
                // quotes sitting with the client — so it carries the honest name.
                key: "pending",
                label: "Quotes awaiting acceptance",
                value: `${this.summary.pendingCount || 0}`,
                detail: `${this._formatHours(this.summary.pendingQuotedHours)}h quoted awaiting acceptance`,
                reportId: reportIds[REPORT_PENDING] || "",
                hasReport: Boolean(reportIds[REPORT_PENDING]),
                hasNoReport: !reportIds[REPORT_PENDING]
            },
            {
                key: "inProgress",
                label: "Approved & in progress",
                value: `${this.summary.inProgressCount || 0}`,
                detail: `${this._formatHours(this.summary.inProgressApprovedHours)}h approved in flight`,
                reportId: reportIds[REPORT_IN_PROGRESS] || "",
                hasReport: Boolean(reportIds[REPORT_IN_PROGRESS]),
                hasNoReport: !reportIds[REPORT_IN_PROGRESS]
            }
        ];
    }

    // ── Navigation ───────────────────────────────────────────────

    handleTileClick(event) {
        const reportId = event.currentTarget.dataset.reportId;
        if (!reportId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: reportId,
                objectApiName: "Report",
                actionName: "view"
            }
        });
    }

    // ── Formatting ───────────────────────────────────────────────

    _formatHours(value) {
        if (value === null || value === undefined) {
            return "0";
        }
        const num = Number(value);
        if (!Number.isFinite(num)) {
            return "0";
        }
        if (Math.abs(num) >= 100) {
            return num.toFixed(0);
        }
        if (Math.abs(num) >= 10) {
            return num.toFixed(1);
        }
        return num.toFixed(2);
    }

    _formatPercent(value) {
        const num = Number(value);
        if (!Number.isFinite(num)) {
            return "0";
        }
        if (Math.abs(num) >= 10) {
            return num.toFixed(0);
        }
        return num.toFixed(1);
    }

    _toFiniteNumber(value) {
        const num = Number(value);
        return Number.isFinite(num) ? num : 0;
    }
}
