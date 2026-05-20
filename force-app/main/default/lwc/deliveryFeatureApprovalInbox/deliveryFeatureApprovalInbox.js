/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Approval inbox card for the Feature Cockpit (Layer 5).
 *               Lists Pending FeatureToggleApproval__c rows assigned to the
 *               running user, with inline Approve / Reject buttons + an
 *               optional decision-note field. PR 7 — single-step only.
 *               PR 8 will widen to multi-step chains + REST.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInbox from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureApprovalService.getInbox';
import grantApex from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureApprovalService.grant';
import rejectApex from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureApprovalService.reject';

const REASON_TRUNCATE_AT = 160,
    ELLIPSIS = '…',
    EMPTY = 0;

export default class DeliveryFeatureApprovalInbox extends LightningElement {
    @track rows = [];
    @track errorMessage = '';
    @track isLoaded = false;
    @track noteByApproval = {};

    wiredResult;

    @wire(getInbox)
    wiredInbox(result) {
        this.wiredResult = result;
        if (result.data) {
            this.rows = (result.data || []).map((r, idx) => this.shapeRow(r, idx));
            this.errorMessage = '';
            this.isLoaded = true;
        } else if (result.error) {
            this.errorMessage = (result.error && result.error.body && result.error.body.message)
                ? result.error.body.message
                : 'Unable to load approval inbox.';
            this.rows = [];
            this.isLoaded = true;
        }
    }

    shapeRow(r, idx) {
        const reason = r.reason || '';
        const truncatedReason = reason.length > REASON_TRUNCATE_AT
            ? reason.substring(0, REASON_TRUNCATE_AT) + ELLIPSIS
            : reason;
        const action = r.action || '';
        const isEnable = action === 'Enable';
        return {
            key: r.approvalId || `row-${idx}`,
            approvalId: r.approvalId,
            requestId: r.requestId,
            featureId: r.featureId,
            featureLabel: r.featureLabel || '(unnamed feature)',
            action,
            actionBadgeClass: isEnable
                ? 'slds-badge slds-theme_success'
                : 'slds-badge slds-theme_warning',
            reason,
            truncatedReason,
            hasReason: reason.length > EMPTY,
            requestedAt: r.requestedAt,
            requestedByName: r.requestedByName || '(unknown)',
            stepNumber: r.stepNumber || 1,
            status: r.status || 'Pending'
        };
    }

    get hasRows() {
        return this.rows.length > EMPTY;
    }

    get isEmpty() {
        return this.isLoaded && !this.hasRows && !this.errorMessage;
    }

    get hasError() {
        return this.errorMessage.length > EMPTY;
    }

    handleRefresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    handleNoteChange(event) {
        const approvalId = event.currentTarget.dataset.approvalId;
        if (!approvalId) {
            return;
        }
        this.noteByApproval = {
            ...this.noteByApproval,
            [approvalId]: event.target.value || ''
        };
    }

    handleApprove(event) {
        const approvalId = event.currentTarget.dataset.approvalId;
        if (!approvalId) {
            return;
        }
        const note = this.noteByApproval[approvalId] || '';
        grantApex({ approvalId, note })
            .then(() => this.onDecisionSuccess('Approved', approvalId))
            .catch(err => this.onDecisionError('approve', err));
    }

    handleReject(event) {
        const approvalId = event.currentTarget.dataset.approvalId;
        if (!approvalId) {
            return;
        }
        const note = this.noteByApproval[approvalId] || '';
        rejectApex({ approvalId, note })
            .then(() => this.onDecisionSuccess('Rejected', approvalId))
            .catch(err => this.onDecisionError('reject', err));
    }

    onDecisionSuccess(label, approvalId) {
        this.dispatchEvent(new ShowToastEvent({
            title: `${label}`,
            message: 'Approval decision recorded.',
            variant: 'success'
        }));
        if (approvalId && this.noteByApproval[approvalId] !== undefined) {
            const next = { ...this.noteByApproval };
            delete next[approvalId];
            this.noteByApproval = next;
        }
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    onDecisionError(verb, err) {
        const msg = (err && err.body && err.body.message)
            ? err.body.message
            : `Unable to ${verb} this request.`;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Decision failed',
            message: msg,
            variant: 'error'
        }));
    }
}
