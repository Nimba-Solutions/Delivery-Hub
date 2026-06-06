/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Add-to-cart surface for the procurement Checkout Cart. A purchaser
 *               freeform-adds scoped work (description + estimated hours) as either
 *               Sizing Only (exploring) or Will Do (committed) — each creates a
 *               pre-activation WorkItem carrying ClientIntentionPk__c. A running total
 *               (Σ hours, Σ $ only when profile.showDollars) reflects the org-wide cart,
 *               and lines can be promoted/removed/reordered inline. Pure function of
 *               (cartData, profile). Wires DeliveryCartService.getCart / createCartItem /
 *               addToCart / removeFromCart / reorder.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getCart from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.getCart";
import createCartItem from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.createCartItem";
import addToCart from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.addToCart";
import removeFromCart from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.removeFromCart";
import reorder from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.reorder";

export default class DeliveryCartBuilder extends LightningElement {
    @track cart;
    @track errorMessage = "";
    @track statusMessage = "";
    isLoading = true;
    isBusy = false;

    // Freeform-add form state.
    newDescription = "";
    newHours = null;

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

    // ── State flags ──────────────────────────────────────────────

    get profile() {
        return this.cart ? this.cart.profile : null;
    }

    get showDollars() {
        return !!(this.profile && this.profile.showDollars);
    }

    get summary() {
        return this.cart ? this.cart.summary : null;
    }

    get hasError() {
        return !this.isLoading && this.errorMessage;
    }

    get isEmpty() {
        return !!(this.cart && (!this.cart.lines || this.cart.lines.length === 0));
    }

    get addDisabled() {
        return this.isBusy || !this.newDescription || !this.newDescription.trim();
    }

    // ── Running total ────────────────────────────────────────────

    get totalHoursLabel() {
        if (!this.summary) {
            return "0";
        }
        const total = (this.summary.willDoHours || 0) + (this.summary.sizingOnlyHours || 0);
        return this._formatHours(total);
    }

    get totalCostLabel() {
        if (!this.showDollars || !this.summary || !this.profile) {
            return "";
        }
        // Cost across the basket = (willDo + sizingOnly) hours x blended rate; the
        // committed cost is already known, the exploring lines are valued at the rate.
        const totalHours =
            (this.summary.willDoHours || 0) + (this.summary.sizingOnlyHours || 0);
        const rate = this.profile.blendedRate || 0;
        return this._formatMoney(totalHours * rate);
    }

    get cartCountLabel() {
        return this.summary ? this.summary.count : 0;
    }

    // ── Line list ────────────────────────────────────────────────

    get lines() {
        if (!this.cart || !this.cart.lines) {
            return [];
        }
        return this.cart.lines.map((l) => ({
            ...l,
            hoursLabel: this._formatHours(l.estimatedHours),
            costLabel: this.showDollars ? this._formatMoney(l.projectedCost) : "",
            intentionClass: l.isCommitted
                ? "builder-line-tag builder-line-tag--commit"
                : "builder-line-tag builder-line-tag--sizing",
            canCommit: !l.isCommitted
        }));
    }

    // ── Form handlers ────────────────────────────────────────────

    handleDescriptionChange(event) {
        this.newDescription = event.target.value;
    }

    handleHoursChange(event) {
        const v = event.target.value;
        this.newHours = v === "" || v === null ? null : Number(v);
    }

    handleAddSizing() {
        this._add("Sizing Only");
    }

    handleAddWillDo() {
        this._add("Will Do");
    }

    async _add(intention) {
        if (this.addDisabled) {
            return;
        }
        this.isBusy = true;
        this.statusMessage = "";
        try {
            await createCartItem({
                description: this.newDescription.trim(),
                estimatedHours: this.newHours,
                intention
            });
            this.newDescription = "";
            this.newHours = null;
            this.statusMessage = `Added to cart as ${intention}.`;
            await refreshApex(this._wiredCart);
        } catch (e) {
            this.statusMessage = this._extractError(e);
        } finally {
            this.isBusy = false;
        }
    }

    // ── Line handlers ────────────────────────────────────────────

    async handleCommit(event) {
        const workItemId = event.currentTarget.dataset.recordId;
        await this._mutate(() => addToCart({ workItemId, intention: "Will Do" }), "Committed.");
    }

    async handleRemove(event) {
        const workItemId = event.currentTarget.dataset.recordId;
        await this._mutate(() => removeFromCart({ workItemId }), "Removed from cart.");
    }

    async handleReorder(event) {
        const workItemId = event.currentTarget.dataset.recordId;
        const priority = event.detail.value;
        await this._mutate(() => reorder({ workItemId, priority }), "Reordered.");
    }

    async _mutate(action, okMessage) {
        this.isBusy = true;
        this.statusMessage = "";
        try {
            await action();
            this.statusMessage = okMessage;
            await refreshApex(this._wiredCart);
        } catch (e) {
            this.statusMessage = this._extractError(e);
        } finally {
            this.isBusy = false;
        }
    }

    get priorityOptions() {
        return [
            { label: "High", value: "High" },
            { label: "Medium", value: "Medium" },
            { label: "Low", value: "Low" }
        ];
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
