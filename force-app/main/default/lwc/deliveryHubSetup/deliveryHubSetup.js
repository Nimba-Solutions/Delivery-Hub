/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Admin onboarding / connection-setup wizard for DeliveryHubSettings__c.
 *               Drives the local-entity prepare → handshake → mothership-approval flow via
 *               DeliveryHubSetupController. Renders a pending-approvals inbox when the local
 *               org is the mothership. Mounts on AppPage / HomePage. The @api showConnectedState
 *               toggle keeps the card visible after setup completes (use on admin home, leave
 *               off on client home so the component disappears once connected).
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getHiddenHomeComponents from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents';
import getSetupStatus from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.getSetupStatus';
import prepareLocalEntity from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.prepareLocalEntity';
import performHandshake from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.performHandshake';
import getPendingApprovalCount from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.getPendingApprovalCount';
import getPendingApprovals from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.getPendingApprovals';
import approveConnection from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.approveConnection';
import rejectConnection from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.rejectConnection';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// This component's key in the Home-visibility map (matches its LWC folder name).
const HOME_COMPONENT_KEY = 'deliveryHubSetup';

export default class DeliveryHubSetup extends LightningElement {
    /** When true, shows a persistent connected-state card after setup completes.
     *  Set to true on the admin home; leave false on the client home so the
     *  component disappears silently once the org is connected. */
    @api showConnectedState = false;

    @track status = { isConnected: false, isMothership: false, requiredRemoteSite: '', entity: {} };
    @track isLoading = true;
    @track isConnecting = false;
    @track connectingStep = '';
    @track pendingApprovalCount = 0;
    @track pendingApprovals = [];
    @track isProcessingApproval = false;

    _wiredStatusResult;
    _wiredPendingCountResult;
    _wiredPendingApprovalsResult;

    // ── Home-page visibility (admin-toggleable, default = shown) ──
    // Hides ONLY on the Delivery Hub app Home page when an admin toggles it
    // off in Settings. Everywhere else this component always renders.
    @wire(CurrentPageReference) _homePageRef;
    @wire(getHiddenHomeComponents) _hiddenHomeComponents;

    get isOnHomePage() {
        const ref = this._homePageRef;
        if (!ref) {
            return false;
        }
        const attrs = ref.attributes || {};
        if (ref.type === 'standard__namedPage' && attrs.pageName === 'home') {
            return true;
        }
        const url = attrs.url
            || (typeof window !== 'undefined' && window.location ? window.location.pathname : '');
        return typeof url === 'string' && url.indexOf('/lightning/page/home') !== -1;
    }

    get isHiddenOnHome() {
        if (!this.isOnHomePage) {
            return false;
        }
        const map = this._hiddenHomeComponents && this._hiddenHomeComponents.data;
        return !!(map && map[HOME_COMPONENT_KEY] === true);
    }

    get isNotHiddenOnHome() {
        return !this.isHiddenOnHome;
    }

    @wire(getSetupStatus)
    wiredStatus(result) {
        this._wiredStatusResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.status = data;
        } else if (error) {
            this.showToast('Error', 'Could not load setup status.', 'error');
        }
    }

    @wire(getPendingApprovalCount)
    wiredPendingCount(result) {
        this._wiredPendingCountResult = result;
        if (result.data !== undefined) {
            this.pendingApprovalCount = result.data;
        }
    }

    @wire(getPendingApprovals)
    wiredPendingApprovals(result) {
        this._wiredPendingApprovalsResult = result;
        if (result.data) {
            this.pendingApprovals = result.data;
        }
    }

    get hasPendingApprovals() {
        return this.pendingApprovalCount > 0;
    }

    handleApprove(event) {
        const entityId = event.target.dataset.id;
        this.isProcessingApproval = true;
        approveConnection({ networkEntityId: entityId })
            .then(() => {
                this.showToast('Approved', 'Connection has been approved.', 'success');
                return Promise.all([
                    refreshApex(this._wiredPendingCountResult),
                    refreshApex(this._wiredPendingApprovalsResult)
                ]);
            })
            .catch(error => {
                const message = error.body ? error.body.message : error.message;
                this.showToast('Error', message || 'Failed to approve connection.', 'error');
            })
            .finally(() => { this.isProcessingApproval = false; });
    }

    handleReject(event) {
        const entityId = event.target.dataset.id;
        this.isProcessingApproval = true;
        rejectConnection({ networkEntityId: entityId })
            .then(() => {
                this.showToast('Rejected', 'Connection has been rejected.', 'success');
                return Promise.all([
                    refreshApex(this._wiredPendingCountResult),
                    refreshApex(this._wiredPendingApprovalsResult)
                ]);
            })
            .catch(error => {
                const message = error.body ? error.body.message : error.message;
                this.showToast('Error', message || 'Failed to reject connection.', 'error');
            })
            .finally(() => { this.isProcessingApproval = false; });
    }

    get isVisible() {
        if (this.status.isConnected && !this.showConnectedState) return false;
        return true;
    }

    /** Apex-resolved partner/mothership display name (CMT-driven); generic
     *  fallback when the wire has not resolved or the name is blank. */
    get partnerName() {
        return (this.status && this.status.mothershipName) || 'your delivery partner';
    }

    get entityStatus() {
        return this.status.entity && this.status.entity.StatusPk__c
            ? this.status.entity.StatusPk__c
            : 'Active';
    }

    handleConnect() {
        if (this.isConnecting) return;
        this.isConnecting = true;
        this.connectingStep = 'Registering your org\u2026';

        prepareLocalEntity()
            .then(entity => {
                this.connectingStep = 'Establishing connection\u2026';
                return performHandshake({ localEntityId: entity.Id });
            })
            .then(() => {
                this.connectingStep = '';
                this.showToast('Connected!', 'Your org is now linked to ' + this.partnerName + '.', 'success');
                return refreshApex(this._wiredStatusResult);
            })
            .catch(error => {
                const message = error.body ? error.body.message : error.message;
                this.showToast('Connection Failed', message, 'error');
            })
            .finally(() => {
                this.isConnecting = false;
                this.connectingStep = '';
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
