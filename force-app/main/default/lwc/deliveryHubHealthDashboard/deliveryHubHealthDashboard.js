/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Admin self-assessment dashboard. Runs every check defined in
 *               DeliveryHubHealthService and renders a card per result with
 *               an optional one-click repair button.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import runAllChecks from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubHealthService.runAllChecks';
import runRepair from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubRepairService.runRepair';

export default class DeliveryHubHealthDashboard extends LightningElement {
    @track checks = [];
    @track loading = false;
    @track lastRunIso = null;
    @track activeRepair = null;

    connectedCallback() {
        this.loadChecks();
    }

    handleRefresh() {
        this.loadChecks();
    }

    handleRepair(event) {
        const repairKey = event.currentTarget.dataset.repairKey;
        if (!repairKey) {
            return;
        }
        this.activeRepair = repairKey;
        runRepair({ repairKey })
            .then((message) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Repair complete',
                    message,
                    variant: 'success'
                }));
                return this.loadChecks();
            })
            .catch((error) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Repair failed',
                    message: error.body ? error.body.message : (error.message || 'Unknown error'),
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.activeRepair = null;
            });
    }

    loadChecks() {
        this.loading = true;
        return runAllChecks()
            .then((results) => {
                this.checks = (results || []).map((r) => ({
                    ...r,
                    cardClass: this._cardClass(r.statusPk),
                    iconName: this._iconName(r.statusPk),
                    iconVariant: this._iconVariant(r.statusPk),
                    canRepair: !!r.repairKey,
                    repairing: this.activeRepair === r.repairKey
                }));
                this.lastRunIso = new Date().toISOString();
            })
            .catch((error) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Health check failed',
                    message: error.body ? error.body.message : (error.message || 'Unknown error'),
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.loading = false;
            });
    }

    _cardClass(status) {
        if (status === 'pass') {
            return 'slds-box slds-theme_success slds-m-bottom_small';
        }
        if (status === 'warn') {
            return 'slds-box slds-theme_warning slds-m-bottom_small';
        }
        if (status === 'fail') {
            return 'slds-box slds-theme_error slds-m-bottom_small';
        }
        return 'slds-box slds-m-bottom_small';
    }

    _iconName(status) {
        if (status === 'pass') {
            return 'utility:success';
        }
        if (status === 'warn') {
            return 'utility:warning';
        }
        if (status === 'fail') {
            return 'utility:error';
        }
        return 'utility:info';
    }

    _iconVariant(status) {
        if (status === 'pass') {
            return 'success';
        }
        if (status === 'warn') {
            return 'warning';
        }
        if (status === 'fail') {
            return 'error';
        }
        return 'inverse';
    }

    get hasChecks() {
        return this.checks && this.checks.length > 0;
    }
}
