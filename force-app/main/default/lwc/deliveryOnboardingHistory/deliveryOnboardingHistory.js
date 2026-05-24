/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read-only audit-trail viewer for OnboardingProgress__c —
 *               org-wide on App Pages, user-scoped on User record pages.
 *               Surfaces who has completed which onboarding track, who is
 *               in flight, and who has yet to start, with derived status
 *               + quiz attempt history.
 *
 *               Companion to deliveryFeatureOnboarding (the per-user
 *               learner UI). Closes the audit-trail-surfaces gap in the
 *               e2e walkthrough audit.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import recent from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryOnboardingHistoryController.recent';

const DEFAULT_LIMIT = 50;
const EMPTY = 0;

const COLUMNS = [
    { label: 'User', fieldName: 'userName', type: 'text', sortable: true, initialWidth: 180 },
    { label: 'Track', fieldName: 'track', type: 'text', sortable: true, initialWidth: 200 },
    { label: 'Status', fieldName: 'status', type: 'text', sortable: true, initialWidth: 130 },
    { label: 'Started', fieldName: 'startedDateTime', type: 'date',
        typeAttributes: {
            year: 'numeric', month: 'short', day: '2-digit',
            hour: '2-digit', minute: '2-digit'
        },
        sortable: true, initialWidth: 170 },
    { label: 'Completed', fieldName: 'completedDateTime', type: 'date',
        typeAttributes: {
            year: 'numeric', month: 'short', day: '2-digit',
            hour: '2-digit', minute: '2-digit'
        },
        sortable: true, initialWidth: 170 },
    { label: 'Quiz Attempts', fieldName: 'quizAttempts', type: 'number', initialWidth: 130 },
    { label: 'Quiz Score', fieldName: 'quizScore', type: 'number', initialWidth: 110 }
];

export default class DeliveryOnboardingHistory extends LightningElement {
    /** @description Optional record-page User Id used to filter rows.
     *               When the component sits on a User record page, this
     *               narrows the table to that user's onboarding history. */
    @api recordId;

    /** @description Max rows to fetch. Default 50. Capped at 200. */
    @api recordLimit = DEFAULT_LIMIT;

    @track rows = [];
    @track sortedBy = 'completedDateTime';
    @track sortedDirection = 'desc';
    @track errorMessage = '';
    @track isLoaded = false;

    columns = COLUMNS;
    wiredResult;

    @wire(recent, { recordLimit: '$recordLimit', contextId: '$recordId' })
    wiredRecent(result) {
        this.wiredResult = result;
        if (result.data) {
            this.rows = this.sort(result.data, this.sortedBy, this.sortedDirection);
            this.errorMessage = '';
            this.isLoaded = true;
        } else if (result.error) {
            this.errorMessage = this.extractError(result.error) || 'Unable to load onboarding history.';
            this.rows = [];
            this.isLoaded = true;
        }
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

    get headerLabel() {
        return this.recordId
            ? 'Onboarding History (this user)'
            : 'Onboarding History (org-wide)';
    }

    handleRefresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    handleSort(event) {
        const fieldName = event.detail.fieldName;
        const direction = event.detail.sortDirection;
        this.sortedBy = fieldName;
        this.sortedDirection = direction;
        this.rows = this.sort(this.rows, fieldName, direction);
    }

    sort(rows, fieldName, direction) {
        if (!rows || rows.length === EMPTY) {
            return rows || [];
        }
        const cloned = [...rows];
        const factor = direction === 'asc' ? 1 : -1;
        cloned.sort((a, b) => {
            const va = a[fieldName];
            const vb = b[fieldName];
            if (va === vb) return 0;
            if (va === null || va === undefined) return 1 * factor;
            if (vb === null || vb === undefined) return -1 * factor;
            return (va > vb ? 1 : -1) * factor;
        });
        return cloned;
    }

    extractError(error) {
        if (!error) return '';
        if (error.body && error.body.message) return error.body.message;
        if (typeof error === 'string') return error;
        return error.message || '';
    }
}
