/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read-only audit-trail viewer for ActivityLog__c rows.
 *               Mounts on a Lightning App Page (org-wide view) or on a
 *               record page (auto-filters to @api recordId via the
 *               controller's contextId param).
 *
 *               Closes the audit-trail-surfaces gap in the e2e walkthrough
 *               audit (docs/audits/e2e-walkthrough-2026-05-21.md). Wider
 *               in scope than deliveryActivityFeed (which only shows
 *               Stage_Change / Field_Change rows scoped to a WorkItem).
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import recent from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityLogController.recent';

const DEFAULT_LIMIT = 50;
const EMPTY = 0;

const COLUMNS = [
    { label: 'When', fieldName: 'activityDateTime', type: 'date',
        typeAttributes: {
            year: 'numeric', month: 'short', day: '2-digit',
            hour: '2-digit', minute: '2-digit'
        },
        sortable: true, initialWidth: 170 },
    { label: 'Actor', fieldName: 'userName', type: 'text', sortable: true, initialWidth: 180 },
    { label: 'Action', fieldName: 'actionType', type: 'text', sortable: true, initialWidth: 150 },
    { label: 'Component', fieldName: 'componentName', type: 'text', sortable: true, initialWidth: 170 },
    { label: 'Record', fieldName: 'recordId', type: 'text', initialWidth: 180 },
    { label: 'Details', fieldName: 'detailsTxt', type: 'text', wrapText: true }
];

export default class DeliveryActivityLog extends LightningElement {
    /**
     * @description Optional record Id used to scope the view. When the
     *              component sits on a record page, Salesforce injects
     *              this automatically; on an App Page it stays null and
     *              the viewer shows org-wide activity.
     */
    @api recordId;

    /** @description Max rows to fetch. Default 50. Capped at 200 by the controller. */
    @api recordLimit = DEFAULT_LIMIT;

    @track rows = [];
    @track sortedBy = 'activityDateTime';
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
            this.errorMessage = this.extractError(result.error) || 'Unable to load activity log.';
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
            ? 'Activity Log (this record)'
            : 'Activity Log (org-wide)';
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
