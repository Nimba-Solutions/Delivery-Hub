/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Monthly billing close-out card (approval-queue spec §9 — the
 *               "Approved vs Logged vs Billable" view): a month selector
 *               (defaults to the current month), a totals header whose
 *               headline ("Billable this month: Nh ≈ $X" when a single
 *               blended rate resolves) is the invoice preview that should ≈
 *               the actual invoice, and a per-item table where rows whose
 *               month hours exceed the remaining approved-cap headroom are
 *               visually flagged — the over-cap excess is non-billable until
 *               a budget increase is approved. Fed by
 *               DeliveryBillingPreviewController.getBillingPreview. Item
 *               labels click through to the WorkItem record via
 *               NavigationMixin (objectApiName from @salesforce/schema —
 *               namespace-safe). All display strings are computed in getters
 *               (templates can't do ternaries at API 62).
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import WORK_ITEM_OBJECT from "@salesforce/schema/WorkItem__c";
import getBillingPreview from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryBillingPreviewController.getBillingPreview";

const MONTH_NAMES = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];
const MONTH_OPTION_COUNT = 12;

export default class DeliveryBillingPreview extends NavigationMixin(LightningElement) {
    preview;
    errorMessage = "";
    isLoading = true;

    year;
    month;

    connectedCallback() {
        const now = new Date();
        this.year = now.getFullYear();
        this.month = now.getMonth() + 1;
    }

    @wire(getBillingPreview, { year: "$year", month: "$month" })
    wiredPreview({ data, error }) {
        if (data) {
            this.preview = data;
            this.errorMessage = "";
            this.isLoading = false;
        } else if (error) {
            this.errorMessage =
                error.body && error.body.message
                    ? error.body.message
                    : "Unable to load the billing preview.";
            this.preview = null;
            this.isLoading = false;
        }
    }

    // ── Month selector ───────────────────────────────────────────

    get monthValue() {
        return `${this.year}-${this.month}`;
    }

    get monthOptions() {
        const options = [];
        const now = new Date();
        let y = now.getFullYear();
        let m = now.getMonth() + 1;
        for (let i = 0; i < MONTH_OPTION_COUNT; i++) {
            options.push({
                label: `${MONTH_NAMES[m - 1]} ${y}`,
                value: `${y}-${m}`
            });
            m -= 1;
            if (m === 0) {
                m = 12;
                y -= 1;
            }
        }
        return options;
    }

    handleMonthChange(event) {
        const [y, m] = event.detail.value.split("-");
        this.year = parseInt(y, 10);
        this.month = parseInt(m, 10);
        this.isLoading = true;
    }

    // ── State flags ──────────────────────────────────────────────

    get hasError() {
        return !this.isLoading && this.errorMessage.length > 0;
    }

    get hasData() {
        return (
            !this.isLoading &&
            !this.errorMessage &&
            Boolean(this.preview) &&
            this.rows.length > 0
        );
    }

    get isEmpty() {
        return (
            !this.isLoading &&
            !this.errorMessage &&
            Boolean(this.preview) &&
            this.rows.length === 0
        );
    }

    get hasRate() {
        return Boolean(
            this.preview &&
                this.preview.totalBillableAmount !== null &&
                this.preview.totalBillableAmount !== undefined
        );
    }

    // ── Totals header (computed — no template ternaries) ─────────

    get monthLabel() {
        return this.preview && this.preview.monthLabel ? this.preview.monthLabel : "";
    }

    get billableHeadline() {
        if (!this.preview) {
            return "";
        }
        return `${this._formatHours(this.preview.totalBillable)}h`;
    }

    get billableDollarDisplay() {
        if (!this.hasRate) {
            return "";
        }
        return `≈ ${this._formatMoney(this.preview.totalBillableAmount)}`;
    }

    get loggedDisplay() {
        return this.preview ? `${this._formatHours(this.preview.totalMonthLogged)}h` : "";
    }

    get approvedCapDisplay() {
        return this.preview ? `${this._formatHours(this.preview.totalApprovedCap)}h` : "";
    }

    get overCapDisplay() {
        return this.preview ? `${this._formatHours(this.preview.totalOverCap)}h` : "";
    }

    get hasOverCapTotal() {
        return Boolean(this.preview) && Number(this.preview.totalOverCap) > 0;
    }

    get emptyStateDetail() {
        return `No hours were logged on client-approved work in ${this.monthLabel}.`;
    }

    // ── Table rows (computed — no template ternaries) ────────────

    get rows() {
        if (!this.preview || !this.preview.rows) {
            return [];
        }
        return this.preview.rows.map((row) => {
            const isOverCap = Boolean(row.isOverCap);
            return {
                key: row.workItemId,
                workItemId: row.workItemId,
                label: row.label,
                approvedCap: `${this._formatHours(row.approvedCap)}h`,
                loggedBefore: `${this._formatHours(row.loggedBefore)}h`,
                monthLogged: `${this._formatHours(row.monthLogged)}h`,
                billable: `${this._formatHours(row.billable)}h`,
                overCap: `${this._formatHours(row.overCap)}h`,
                isOverCap,
                rowClass: isOverCap
                    ? "preview-row preview-row--over"
                    : "preview-row"
            };
        });
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

    // ── Formatting ───────────────────────────────────────────────

    _formatHours(value) {
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

    _formatMoney(value) {
        const num = Number(value);
        if (!Number.isFinite(num)) {
            return "$0";
        }
        return `$${num.toLocaleString("en-US", {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        })}`;
    }
}
