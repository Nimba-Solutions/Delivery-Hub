/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Data Lineage visualization — shows the sync chain between
 *               connected orgs with real-time health status.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import getNetworkEntities from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDataLineageController.getNetworkEntities';
import getSyncHealth from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDataLineageController.getSyncHealth';

export default class DeliveryDataLineage extends LightningElement {
    @track entities = [];
    @track syncHealth = {};
    @track localOrgName = '';
    @track localOrgId = '';
    @track isLoading = true;

    @wire(getNetworkEntities)
    wiredEntities({ data, error }) {
        if (data) {
            this.localOrgName = data.localOrgName;
            this.localOrgId = data.localOrgId;
            this.entities = (data.entities || []).map(e => ({
                ...e,
                isClient: e.entityType === 'Client',
                isVendor: e.entityType === 'Vendor' || e.entityType === 'Both',
                statusClass: 'dl-node dl-node--' + (e.connectionStatus === 'Connected' ? 'connected' : 'disconnected'),
                healthClass: 'dl-health dl-health--' + (e.healthPct >= 100 ? 'green' : e.healthPct >= 90 ? 'yellow' : 'red'),
                healthLabel: e.healthPct != null ? e.healthPct + '%' : 'N/A',
                directionLabel: e.entityType === 'Client' ? 'Outbound' : 'Inbound',
                directionIcon: e.entityType === 'Client' ? 'utility:right' : 'utility:left',
                lastSyncLabel: e.lastSync || 'Never'
            }));
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
        }
    }

    get hasEntities() {
        return this.entities.length > 0;
    }

    get clientEntities() {
        return this.entities.filter(e => e.isClient);
    }

    get vendorEntities() {
        return this.entities.filter(e => e.isVendor);
    }

    get hasClients() {
        return this.clientEntities.length > 0;
    }

    get hasVendors() {
        return this.vendorEntities.length > 0;
    }
}
