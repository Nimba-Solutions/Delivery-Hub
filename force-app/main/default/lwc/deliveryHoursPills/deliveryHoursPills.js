/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Per-WorkItem traffic-light pills showing On-Schedule (days remaining vs
 *               CalculatedETADate / EstimatedEndDevDate) and On-Budget (estimated vs total
 *               logged hours). Mirrors the Project_Health_Pills dashboard card. Mounts on the
 *               WorkItem__c record page; reads via lightning/uiRecordApi (no Apex round-trip).
 *               Suppresses itself for terminal stages (Done / Cancelled / Closed / Rejected).
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, wire } from "lwc";
import { getRecord } from "lightning/uiRecordApi";

// Field references — namespaced at runtime via the @salesforce/schema scheme is unavailable
// for managed-package fields used outside the package, so we use string field names that
// the bundler resolves through %%%NAMESPACE_DOT%%% replacement.
const FIELDS = [
    "%%%NAMESPACE_DOT%%%WorkItem__c.%%%NAMESPACE_DOT%%%EstimatedHoursNumber__c",
    "%%%NAMESPACE_DOT%%%WorkItem__c.%%%NAMESPACE_DOT%%%TotalLoggedHoursSum__c",
    "%%%NAMESPACE_DOT%%%WorkItem__c.%%%NAMESPACE_DOT%%%CalculatedETADate__c",
    "%%%NAMESPACE_DOT%%%WorkItem__c.%%%NAMESPACE_DOT%%%EstimatedEndDevDate__c",
    "%%%NAMESPACE_DOT%%%WorkItem__c.%%%NAMESPACE_DOT%%%StageNamePk__c"
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

    // ── Field readers (LDS getRecord shape) ───────────────────────

    _field(apiName) {
        if (!this.record || !this.record.fields) {
            return null;
        }
        const namespacedKey = Object.keys(this.record.fields).find(
            (k) => k.toLowerCase() === apiName.toLowerCase()
                || k.toLowerCase().endsWith("__" + apiName.toLowerCase())
        );
        if (!namespacedKey) {
            return null;
        }
        const f = this.record.fields[namespacedKey];
        return f ? f.value : null;
    }

    get _estimated() {
        return Number(this._field("EstimatedHoursNumber__c") || 0);
    }

    get _logged() {
        return Number(this._field("TotalLoggedHoursSum__c") || 0);
    }

    get _eta() {
        return this._field("CalculatedETADate__c") || this._field("EstimatedEndDevDate__c");
    }

    get _stage() {
        return this._field("StageNamePk__c");
    }

    // ── Pill computation ──────────────────────────────────────────

    get onBudgetPill() {
        const isTerminal = TERMINAL_STAGES.has(this._stage || "");
        if (this._estimated <= 0) {
            return this._pill("On-Budget", "—", "neutral", "No estimate set", "No data");
        }
        const ratio = this._estimated / (this._logged || 0.0001);
        const pct = Math.round(ratio * 100);
        let band, tooltip;
        if (this._logged === 0) {
            band = "neutral";
            tooltip = "No hours logged yet";
        } else if (pct >= 100) {
            band = "green";
            tooltip = `Earning ${pct}% of estimated hours per actual hour — at or under budget.`;
        } else if (pct >= 80) {
            band = "yellow";
            tooltip = `Earning ${pct}% of estimated hours per actual hour — drifting over.`;
        } else {
            band = "red";
            tooltip = `Earning only ${pct}% of estimated hours per actual hour — significantly over budget.`;
        }
        const label = isTerminal && pct < 100 ? `${pct}%` : `${pct}%`;
        return this._pill("On-Budget", label, band, tooltip,
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
