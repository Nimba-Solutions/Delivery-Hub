/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Approval agenda summary card (PR3 of the work-approval
 *               queue): three click-through tiles — Hours Approved (this
 *               month), Pending Approval, and Approved & In Progress — fed by
 *               DeliveryApprovalSummaryController.getApprovalSummary. Each
 *               tile navigates to its backing report via NavigationMixin
 *               using the report record id the controller resolved by
 *               DeveloperName (namespace-safe: no hardcoded org ids). Tiles
 *               whose report is missing in the org render without the
 *               click-through affordance.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getApprovalSummary from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryApprovalSummaryController.getApprovalSummary";

const REPORT_HOURS_APPROVED = "Hours_Approved_This_Period";
const REPORT_PENDING = "Pending_Approval";
const REPORT_IN_PROGRESS = "Approved_In_Progress";

export default class DeliveryApprovalSummaryCard extends NavigationMixin(LightningElement) {
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
                key: "pending",
                label: "Pending approval",
                value: `${this.summary.pendingCount || 0}`,
                detail: `${this._formatHours(this.summary.pendingQuotedHours)}h quoted awaiting decision`,
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
}
