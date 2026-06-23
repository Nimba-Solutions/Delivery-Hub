/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Per-WorkItem traffic-light pills showing On-Schedule (days remaining vs
 *               CalculatedETADate / EstimatedEndDevDate) and On-Budget (estimated vs total
 *               logged hours). Mirrors the Project_Health_Pills dashboard card. Mounts on the
 *               WorkItem__c record page; reads via lightning/uiRecordApi (no Apex round-trip).
 *               Suppresses itself for terminal stages (Done / Cancelled / Closed / Rejected).
 *
 *               Fields are imported via @salesforce/schema so the platform resolves the
 *               namespace at compile time — `delivery__WorkItem__c.delivery__Field__c` in
 *               the managed package, plain `WorkItem__c.Field__c` in unmanaged. The earlier
 *               version used `%%%NAMESPACE_DOT%%%` tokens in raw string literals; that
 *               pattern does NOT round-trip through CCI's namespace injector for JS array
 *               contents, which produced the "fields query string parameter contained
 *               object api names: [WorkItem__c]" LDS error on MF prod's WorkItem record
 *               page (mismatching the record's `delivery__WorkItem__c` type). Fixed 2026-05-29.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import ESTIMATED_HOURS_FIELD from "@salesforce/schema/WorkItem__c.EstimatedHoursNumber__c";
import TOTAL_LOGGED_HOURS_FIELD from "@salesforce/schema/WorkItem__c.TotalLoggedHoursSum__c";
import CALCULATED_ETA_FIELD from "@salesforce/schema/WorkItem__c.CalculatedETADate__c";
import ESTIMATED_END_DEV_FIELD from "@salesforce/schema/WorkItem__c.EstimatedEndDevDate__c";
import STAGE_FIELD from "@salesforce/schema/WorkItem__c.StageNamePk__c";

const FIELDS = [
    ESTIMATED_HOURS_FIELD,
    TOTAL_LOGGED_HOURS_FIELD,
    CALCULATED_ETA_FIELD,
    ESTIMATED_END_DEV_FIELD,
    STAGE_FIELD
];

const TERMINAL_STAGES = new Set(["Done", "Cancelled", "Closed", "Rejected"]);

export default class DeliveryHoursPills extends LightningElement {
    @api recordId;
    record;
    errorMessage = "";

    @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            this.record = data;
            this.errorMessage = "";
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
        }
    }

    get hasData() {
        return !!this.record && !this.errorMessage;
    }

    // ── Field readers (namespace-safe via schema imports) ─────────

    get _estimated() {
        return Number(getFieldValue(this.record, ESTIMATED_HOURS_FIELD) || 0);
    }

    get _logged() {
        return Number(getFieldValue(this.record, TOTAL_LOGGED_HOURS_FIELD) || 0);
    }

    get _eta() {
        return getFieldValue(this.record, CALCULATED_ETA_FIELD)
            || getFieldValue(this.record, ESTIMATED_END_DEV_FIELD);
    }

    get _stage() {
        return getFieldValue(this.record, STAGE_FIELD);
    }

    // ── Pill computation ──────────────────────────────────────────

    get onBudgetPill() {
        if (this._estimated <= 0) {
            return this._pill("On-Budget", "—", "neutral", "No estimate set", "No data");
        }
        // Budget consumed = logged / estimated. Estimated is guaranteed > 0 here
        // (guarded above), so there is no divide-by-zero, and logged = 0 reads as
        // a correct 0% used. This previously computed estimated / logged, which
        // INVERTED the ratio — 14h logged against a 60h estimate rendered "429%"
        // under an "On-Budget" label instead of the correct 23% (F9). The label
        // means "percent of the estimate consumed," so over 100% is over budget.
        const pct = Math.round((this._logged / this._estimated) * 100);
        let band, tooltip;
        if (pct > 100) {
            band = "red";
            tooltip = `${pct}% of the estimated budget used — over budget.`;
        } else if (pct >= 80) {
            band = "yellow";
            tooltip = `${pct}% of the estimated budget used — approaching the estimate.`;
        } else {
            band = "green";
            tooltip = `${pct}% of the estimated budget used — under budget.`;
        }
        return this._pill("On-Budget", `${pct}%`, band, tooltip,
            `Est ${this._formatHours(this._estimated)}h · Logged ${this._formatHours(this._logged)}h`);
    }

    get onSchedulePill() {
        const isTerminal = TERMINAL_STAGES.has(this._stage || "");
        if (!this._eta) {
            return this._pill("On-Schedule", "—", "neutral", "No ETA set", "No data");
        }
        if (isTerminal) {
            return this._pill("On-Schedule", "Done", "green", "Stage is terminal — schedule complete.", "");
        }
        const today = new Date();
        const eta = new Date(this._eta);
        const days = Math.ceil((eta - today) / (1000 * 60 * 60 * 24));
        if (!Number.isFinite(days)) {
            return this._pill("On-Schedule", "—", "neutral", "ETA date is invalid", "No data");
        }
        let band, label, tooltip;
        if (days >= 7) {
            band = "green";
            label = `${days}d`;
            tooltip = `${days} days until ETA — on track.`;
        } else if (days >= 0) {
            band = "yellow";
            label = days === 0 ? "Today" : `${days}d`;
            tooltip = `${days} days until ETA — final stretch.`;
        } else {
            band = "red";
            label = `${Math.abs(days)}d over`;
            tooltip = `${Math.abs(days)} days past ETA — overdue.`;
        }
        return this._pill("On-Schedule", label, band, tooltip,
            `ETA ${this._formatDate(this._eta)}`);
    }

    _pill(name, label, band, tooltip, subtext) {
        return {
            name,
            label,
            tooltip,
            subtext,
            badgeClass: `pill-badge pill-badge--${band}`,
            pillClass: `pill pill--${band}`
        };
    }

    // ── Helpers ───────────────────────────────────────────────────

    _formatHours(num) {
        const n = Number(num);
        if (!Number.isFinite(n)) {
            return "0";
        }
        if (Math.abs(n) >= 100) {
            return n.toFixed(0);
        }
        if (Math.abs(n) >= 10) {
            return n.toFixed(1);
        }
        return n.toFixed(2);
    }

    _formatDate(iso) {
        if (!iso) {
            return "";
        }
        const parts = String(iso).split("-");
        if (parts.length < 3) {
            return String(iso);
        }
        const monthIdx = parseInt(parts[1], 10) - 1;
        const day = parseInt(parts[2], 10);
        const monthNames = [
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        ];
        return `${monthNames[monthIdx]} ${day}`;
    }
}
