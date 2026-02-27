/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire } from 'lwc';
import getSLAStatusCounts from '@salesforce/apex/DeliverySLAService.getSLAStatusCounts';
import { refreshApex } from '@salesforce/apex';

export default class DeliverySLASummary extends LightningElement {
    @api workflowTypeName = 'Software_Delivery';

    onTrack = 0;
    atRisk = 0;
    breached = 0;
    met = 0;

    _wiredResult;

    @wire(getSLAStatusCounts, { workflowTypeName: '$workflowTypeName' })
    wiredCounts(result) {
        this._wiredResult = result;
        if (result.data) {
            this.onTrack = result.data['On Track'] || 0;
            this.atRisk = result.data['At Risk'] || 0;
            this.breached = result.data['Breached'] || 0;
            this.met = result.data['Met'] || 0;
        } else if (result.error) {
            console.error('Error loading SLA counts', result.error);
        }
    }

    get totalTracked() {
        return this.onTrack + this.atRisk + this.breached + this.met;
    }

    get hasData() {
        return this.totalTracked > 0;
    }

    handleRefresh() {
        refreshApex(this._wiredResult);
    }
}
