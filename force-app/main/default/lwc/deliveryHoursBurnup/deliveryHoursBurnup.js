/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  "Fill toward the ceiling" burn-up card for the WorkItem__c record
 *               page. Reads Estimated / Client-Pre-Approved / Total-Logged hours via
 *               lightning/uiRecordApi (no Apex round-trip) and draws a single bar in
 *               which work fills toward the ceiling you set: shipped (logged) in the
 *               darkest shade, approved-in-flight medium, estimated-beyond-cap light,
 *               with anything logged past the cap drawn red and dashed headroom past
 *               the ceiling line. All geometry comes from the pure burnupModel.
 *
 *               Fields are imported via @salesforce/schema (bare object/field names,
 *               NO %%%NAMESPACE_DOT%%% tokens) so the platform resolves the namespace
 *               at compile time — the same pattern deliveryHoursPills documents after
 *               the 2026-05-29 LDS "object api names: [WorkItem__c]" fix.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import ESTIMATED_FIELD from "@salesforce/schema/WorkItem__c.EstimatedHoursNumber__c";
import APPROVED_FIELD from "@salesforce/schema/WorkItem__c.ClientPreApprovedHoursNumber__c";
import LOGGED_FIELD from "@salesforce/schema/WorkItem__c.TotalLoggedHoursSum__c";
import { computeBurnup } from "./burnupModel";

const FIELDS = [ESTIMATED_FIELD, APPROVED_FIELD, LOGGED_FIELD];

const HEALTH_META = {
    healthy: { label: "On track", icon: "utility:success", variant: "success" },
    approaching: { label: "Approaching cap", icon: "utility:warning", variant: "warning" },
    over: { label: "Over cap", icon: "utility:error", variant: "error" },
    empty: { label: "", icon: "", variant: "" }
};

export default class DeliveryHoursBurnup extends LightningElement {
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

    get model() {
        return computeBurnup({
            estimated: getFieldValue(this.record, ESTIMATED_FIELD),
            approved: getFieldValue(this.record, APPROVED_FIELD),
            logged: getFieldValue(this.record, LOGGED_FIELD)
        });
    }

    get hasData() {
        return !!this.record && !this.errorMessage;
    }

    get isEmpty() {
        return !this.hasData || this.model.empty;
    }

    get hasBar() {
        return !this.isEmpty;
    }

    // ── header / status ───────────────────────────────────────────
    get health() {
        return HEALTH_META[this.model.health] || HEALTH_META.empty;
    }

    get rootClass() {
        return `burnup burnup--${this.model.health}`;
    }

    get ceilingLabel() {
        return this.model.ceilingSource === "approved"
            ? "Approved ceiling"
            : "Estimated ceiling — not yet approved";
    }

    // ── numeric readout ───────────────────────────────────────────
    get loggedLabel() {
        return this._fmt(this.model.logged);
    }
    get approvedLabel() {
        return this._fmt(this.model.approved);
    }
    get estimatedLabel() {
        return this._fmt(this.model.estimated);
    }
    get ceilingHoursLabel() {
        return this._fmt(this.model.ceiling);
    }

    get blockCaption() {
        return this.model.blockUnit > 1 ? `each block ≈ ${this.model.blockUnit}h` : "";
    }

    get hasOverCap() {
        return this.model.segments.overCapPct > 0;
    }

    // ── inline bar geometry (getters, not template ternaries) ─────
    get shippedStyle() {
        return `width:${this.model.segments.shippedPct}%`;
    }
    get overCapStyle() {
        return `width:${this.model.segments.overCapPct}%`;
    }
    get approvedRemainingStyle() {
        return `width:${this.model.segments.approvedRemainingPct}%`;
    }
    get estimatedBeyondStyle() {
        return `width:${this.model.segments.estimatedBeyondPct}%`;
    }
    get headroomStyle() {
        return `width:${this.model.segments.headroomPct}%`;
    }
    get ceilingLineStyle() {
        return `left:${this.model.ceilingPct}%`;
    }
    get blockOverlayStyle() {
        const m = this.model;
        const periodPct = m.scaleMax > 0 ? (m.blockUnit / m.scaleMax) * 100 : 100;
        // a 2px light separator every block-period → the "blocks" texture, at any scale
        return (
            "background-image:repeating-linear-gradient(to right," +
            "rgba(255,255,255,0.6) 0 2px,transparent 2px " +
            periodPct +
            "%)"
        );
    }

    _fmt(num) {
        const n = Number(num);
        if (!Number.isFinite(n)) return "0";
        if (Math.abs(n) >= 100) return n.toFixed(0);
        if (Math.abs(n) >= 10) return n.toFixed(1);
        return String(Math.round(n * 100) / 100);
    }
}
