/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read-only audit-trail viewer for WatcherDigest__c. One row
 *               per scheduled (or manual) Watcher run. Surfaces signal
 *               counts, Slack-delivered proxy, run duration, and the
 *               digest body so an admin can trend Watcher health over time
 *               without writing SOQL.
 *
 *               Closes the audit-trail-surfaces gap in the e2e walkthrough
 *               audit. Pairs with deliveryActivityLog and
 *               deliveryOnboardingHistory.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import recent from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWatcherDigestHistoryController.recent';

const DEFAULT_LIMIT = 50;
const EMPTY = 0;

const COLUMNS = [
    { label: 'Run', fieldName: 'runDateTime', type: 'date',
        typeAttributes: {
            year: 'numeric', month: 'short', day: '2-digit',
            hour: '2-digit', minute: '2-digit'
        },
        sortable: true, initialWidth: 170 },
    { label: 'Status', fieldName: 'status', type: 'text', sortable: true, initialWidth: 110 },
    { label: 'Mode', fieldName: 'runMode', type: 'text', sortable: true, initialWidth: 110 },
    { label: 'Signal Counts', fieldName: 'signalCounts', type: 'text', initialWidth: 260 },
    { label: 'Duration (ms)', fieldName: 'runDurationMs', type: 'number', sortable: true, initialWidth: 130 },
    { label: 'Slack Delivered', fieldName: 'slackDelivered', type: 'boolean', initialWidth: 140 },
    { label: 'Notes', fieldName: 'notes', type: 'text', wrapText: true }
];

export default class DeliveryWatcherDigestHistory extends LightningElement {
    /** @description Optional record-page recordId. Currently ignored by the
     *               controller — WatcherDigest__c has no per-record FK —
     *               but accepted for FlexiPage parity. */
    @api recordId;

    /** @description Max rows to fetch. Default 50. Capped at 200. */
    @api recordLimit = DEFAULT_LIMIT;

    @track rows = [];
    @track sortedBy = 'runDateTime';
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
            this.errorMessage = this.extractError(result.error) || 'Unable to load Watcher digest history.';
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
