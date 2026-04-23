/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Sibling-of-deliveryDocumentViewer panel that lists Approved
 *               WorkLogs for a NetworkEntity in a period and lets the user
 *               toggle StatusPk__c -> Draft (with a [DEFERRED to YYYY-MM-DD]
 *               tag). Companion "Release Deferred to this Period" button
 *               flips matching Drafts back to Approved with WorkDate shifted
 *               to the milestone date so they roll into that period's
 *               invoice. Wired in a follow-up PR; today this is dropped on
 *               the same FlexiPage as deliveryDocumentViewer.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getWorkLogsForEntityPeriod from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocDeferralService.getWorkLogsForEntityPeriod';
import deferWorkLogs from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocDeferralService.deferWorkLogs';
import releaseDeferredForPeriod from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocDeferralService.releaseDeferredForPeriod';

export default class DeliveryInvoicePreviewDeferPanel extends LightningElement {
    @api networkEntityId;
    @api periodStart;
    @api periodEnd;

    @track rows = [];
    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';

    @track isModalOpen = false;
    @track modalMilestoneDate = '';
    @track modalReason = '';

    _wiredResult;

    @wire(getWorkLogsForEntityPeriod, {
        networkEntityId: '$networkEntityId',
        periodStart: '$periodStart',
        periodEnd: '$periodEnd'
    })
    wiredLogs(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.rows = data.map((wl) => ({
                id: wl.Id,
                workDate: wl.WorkDateDate__c,
                hours: wl.HoursLoggedNumber__c,
                description: wl.WorkDescriptionTxt__c,
                selected: false
            }));
            this.isLoading = false;
            this.hasError = false;
        } else if (error) {
            this.isLoading = false;
            this.hasError = true;
            this.errorMessage = (error.body && error.body.message) || 'Failed to load work logs.';
        }
    }

    // ── Derived ─────────────────────────────────────────────

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    get selectedIds() {
        return this.rows.filter((r) => r.selected).map((r) => r.id);
    }

    get selectedCount() {
        return this.selectedIds.length;
    }

    get isDeferDisabled() {
        return this.selectedCount === 0;
    }

    get isConfirmDisabled() {
        return !this.modalMilestoneDate || this.selectedCount === 0;
    }

    // ── Row selection ───────────────────────────────────────

    handleRowSelect(event) {
        const target = event.currentTarget || event.target;
        const id = target && target.dataset ? target.dataset.id : null;
        // jsdom delivers the value via target.checked when set imperatively;
        // the standard lightning-input change event also exposes detail.checked.
        const checked = (event.detail && typeof event.detail.checked === 'boolean')
            ? event.detail.checked
            : !!(target && target.checked);
        if (!id) {
            return;
        }
        this.rows = this.rows.map((r) =>
            r.id === id ? { ...r, selected: checked } : r
        );
    }

    // ── Modal lifecycle ─────────────────────────────────────

    handleOpenDeferModal() {
        this.modalMilestoneDate = '';
        this.modalReason = '';
        this.isModalOpen = true;
    }

    handleCancelModal() {
        this.isModalOpen = false;
    }

    handleMilestoneChange(event) {
        this.modalMilestoneDate = event.detail.value;
    }

    handleReasonChange(event) {
        this.modalReason = event.detail.value;
    }

    // ── Actions ─────────────────────────────────────────────

    async handleConfirmDefer() {
        if (this.isConfirmDisabled) {
            return;
        }
        const ids = this.selectedIds;
        try {
            const updated = await deferWorkLogs({
                workLogIds: ids,
                milestoneDate: this.modalMilestoneDate,
                reason: this.modalReason
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Hours deferred',
                    message: `${updated} work log(s) moved to Draft for milestone ${this.modalMilestoneDate}.`,
                    variant: 'success'
                })
            );
            this.isModalOpen = false;
            await this.refresh();
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Defer failed',
                    message: (e && e.body && e.body.message) || 'Unable to defer.',
                    variant: 'error'
                })
            );
        }
    }

    async handleRelease() {
        try {
            const released = await releaseDeferredForPeriod({
                networkEntityId: this.networkEntityId,
                periodStart: this.periodStart,
                periodEnd: this.periodEnd
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Released',
                    message: `${released} previously-deferred work log(s) released into this period.`,
                    variant: released > 0 ? 'success' : 'info'
                })
            );
            await this.refresh();
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Release failed',
                    message: (e && e.body && e.body.message) || 'Unable to release.',
                    variant: 'error'
                })
            );
        }
    }

    async refresh() {
        if (this._wiredResult) {
            await refreshApex(this._wiredResult);
        }
    }
}
