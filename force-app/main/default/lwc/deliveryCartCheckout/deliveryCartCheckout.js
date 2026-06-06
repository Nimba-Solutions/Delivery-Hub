/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Checkout-review surface for the procurement Checkout Cart. Renders the
 *               org-wide basket — Will Do (committed) vs Sizing Only (exploring) sections,
 *               each line sequenced by priority + dependency, with hours (and $ only when
 *               profile.showDollars). A summary header shows total Will Do hours/$ and a
 *               forecast "lands across these months" line sourced from the portfolio pacing
 *               engine. One Checkout button activates the Will Do lines (label/behavior
 *               reflect profile.checkoutMode). Pure function of (cartData, profile). Wires
 *               DeliveryCartService.getCart / checkout and
 *               DeliveryHoursAnalyticsController.getPortfolioPacing for the month spread.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import WORK_ITEM_OBJECT from "@salesforce/schema/WorkItem__c";
import getCart from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.getCart";
import checkout from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.checkout";
import getPortfolioPacing from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHoursAnalyticsController.getPortfolioPacing";

export default class DeliveryCartCheckout extends NavigationMixin(LightningElement) {
    @track cart;
    @track pacing;
    @track errorMessage = "";
    @track checkoutMessage = "";
    isLoading = true;
    isCheckingOut = false;

    _wiredCart;

    @wire(getCart)
    wiredCart(result) {
        this._wiredCart = result;
        this.isLoading = false;
        if (result.data) {
            this.cart = result.data;
            this.errorMessage = "";
        } else if (result.error) {
            this.errorMessage = this._extractError(result.error);
            this.cart = null;
        }
    }

    // Forecast month-spread for the "lands across these months" line. Reuses the
    // portfolio pacing DTO; the cart's hours fold into the same active-portfolio
    // forecast once checked out. Best-effort — failure leaves the spread hidden.
    @wire(getPortfolioPacing, { granularity: "Month", periodsBack: 1, periodsForward: 6 })
    wiredPacing({ data }) {
        if (data) {
            this.pacing = data;
        }
    }

    // ── State flags ──────────────────────────────────────────────

    get hasError() {
        return !this.isLoading && this.errorMessage;
    }

    get profile() {
        return this.cart ? this.cart.profile : null;
    }

    get showDollars() {
        return !!(this.profile && this.profile.showDollars);
    }

    get summary() {
        return this.cart ? this.cart.summary : null;
    }

    get isEmpty() {
        if (this.isLoading || this.errorMessage || !this.cart) {
            return false;
        }
        return !this.cart.lines || this.cart.lines.length === 0;
    }

    get hasData() {
        return !this.isLoading && !this.errorMessage && !this.isEmpty && this.cart;
    }

    // ── Line sections ────────────────────────────────────────────

    get willDoLines() {
        if (!this.cart || !this.cart.lines) {
            return [];
        }
        return this.cart.lines
            .filter((l) => l.isCommitted)
            .map((l) => this._decorateLine(l));
    }

    get sizingOnlyLines() {
        if (!this.cart || !this.cart.lines) {
            return [];
        }
        return this.cart.lines
            .filter((l) => !l.isCommitted)
            .map((l) => this._decorateLine(l));
    }

    get hasWillDo() {
        return this.willDoLines.length > 0;
    }

    get hasSizingOnly() {
        return this.sizingOnlyLines.length > 0;
    }

    _decorateLine(line) {
        return {
            ...line,
            hoursLabel: this._formatHours(line.estimatedHours),
            costLabel: this.showDollars ? this._formatMoney(line.projectedCost) : "",
            priorityLabel: line.priority || "—",
            stageLabel: line.stage || "—",
            developerLabel: line.developerName || "Unassigned"
        };
    }

    // ── Summary header ───────────────────────────────────────────

    get willDoHoursLabel() {
        return this.summary ? this._formatHours(this.summary.willDoHours) : "0";
    }

    get sizingOnlyHoursLabel() {
        return this.summary ? this._formatHours(this.summary.sizingOnlyHours) : "0";
    }

    get willDoCostLabel() {
        if (!this.showDollars || !this.summary) {
            return "";
        }
        return this._formatMoney(this.summary.willDoCost);
    }

    get willDoCountLabel() {
        return this.summary ? this.summary.willDoCount : 0;
    }

    get sizingOnlyCountLabel() {
        return this.summary ? this.summary.sizingOnlyCount : 0;
    }

    // ── Forecast month spread ────────────────────────────────────

    get hasMonthSpread() {
        return !!(this.pacing && this.pacing.periods && this.pacing.periods.length > 0);
    }

    get monthSpreadLabel() {
        if (!this.hasMonthSpread) {
            return "";
        }
        const labels = this.pacing.periods
            .filter((p) => p.isForecast || p.forecastHours > 0)
            .map((p) => p.label);
        if (labels.length === 0) {
            return "";
        }
        if (labels.length === 1) {
            return `Lands in ${labels[0]} at the current run-rate.`;
        }
        return `Lands across ${labels[0]} – ${labels[labels.length - 1]} at the current run-rate.`;
    }

    // ── Checkout control ─────────────────────────────────────────

    get checkoutMode() {
        return this.profile ? this.profile.checkoutMode : "Invoice";
    }

    get checkoutLabel() {
        const mode = this.checkoutMode;
        if (mode === "Stripe") {
            return "Checkout & Pay";
        }
        if (mode === "Approve") {
            return "Submit for Approval";
        }
        return "Checkout & Generate Proposal";
    }

    get checkoutDisabled() {
        return this.isCheckingOut || !this.summary || this.summary.willDoCount === 0;
    }

    async handleCheckout() {
        this.isCheckingOut = true;
        this.checkoutMessage = "";
        try {
            const result = await checkout();
            this.checkoutMessage = result && result.message ? result.message : "Checkout complete.";
            await refreshApex(this._wiredCart);
        } catch (e) {
            this.checkoutMessage = this._extractError(e);
        } finally {
            this.isCheckingOut = false;
        }
    }

    // ── Row navigation ───────────────────────────────────────────

    handleRowClick(event) {
        const recordId = event.currentTarget.dataset.recordId;
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
            attributes: {
                actionName: "view",
                objectApiName: WORK_ITEM_OBJECT.objectApiName,
                recordId
            },
            type: "standard__recordPage"
        });
    }

    // ── Formatting helpers ───────────────────────────────────────

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
            return "";
        }
        return `$${num.toLocaleString(undefined, {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        })}`;
    }

    _extractError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return "Something went wrong.";
    }
}
