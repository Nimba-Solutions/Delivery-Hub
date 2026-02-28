/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Interactive onboarding wizard for Delivery Hub.
 * 5-step guided flow: Org Type → Workflow → Partner Config → Test Ping → Connected.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSetupStatus from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.getSetupStatus';
import prepareLocalEntity from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.prepareLocalEntity';
import performHandshake from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.performHandshake';

const STEPS = [
    { index: 1, label: 'Org Type' },
    { index: 2, label: 'Workflow' },
    { index: 3, label: 'Partner' },
    { index: 4, label: 'Connect' },
    { index: 5, label: 'Done' }
];

export default class DeliveryGettingStarted extends LightningElement {
    @track isExpanded = false;
    @track currentStep = 1;
    @track orgType = ''; // 'client' or 'vendor'
    @track isConnecting = false;
    @track connectionError = '';
    @track isAlreadyConnected = false;
    @track connectedEntityName = '';
    @track isMothership = false;
    @track isCheckingStatus = false;
    @track selectedWorkflowType = '';

    steps = STEPS;

    connectedCallback() {
        this._checkExistingConnection();
    }

    _checkExistingConnection() {
        this.isCheckingStatus = true;
        getSetupStatus()
            .then(status => {
                if (status && status.isConnected && status.entity) {
                    this.isAlreadyConnected = true;
                    this.connectedEntityName = status.entity.Name;
                    this.currentStep = 5;
                }
                if (status && status.isMothership) {
                    this.isMothership = true;
                }
            })
            .catch(() => { /* swallow — first-run scenario */ })
            .finally(() => { this.isCheckingStatus = false; });
    }

    // ── Computed ──

    get rootClass() {
        return 'gs-root' + (this.isExpanded ? ' gs-root--expanded' : '');
    }

    get chevronIcon() {
        return this.isExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get headerTitle() {
        return this.isAlreadyConnected
            ? 'Delivery Hub — Connected'
            : 'Getting Started with Delivery Hub';
    }

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }

    get isClientOrg() { return this.orgType === 'client'; }
    get isVendorOrg() { return this.orgType === 'vendor'; }

    get noOrgTypeSelected() { return this.orgType === ''; }

    get progressSteps() {
        return STEPS.map(s => ({
            ...s,
            stepClass: [
                'wiz-step-dot',
                s.index < this.currentStep ? 'wiz-step-dot--done' : '',
                s.index === this.currentStep ? 'wiz-step-dot--active' : ''
            ].join(' ').trim()
        }));
    }

    // ── Handlers ──

    handleToggle() {
        this.isExpanded = !this.isExpanded;
    }

    handleKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleToggle();
        }
    }

    handleOrgTypeSelect(event) {
        this.orgType = event.currentTarget.dataset.type;
    }

    handleNext() {
        if (this.currentStep < 5) {
            this.currentStep++;
        }
    }

    handleBack() {
        if (this.currentStep > 1) {
            this.currentStep--;
            this.connectionError = '';
        }
    }

    handleTemplateSelected(event) {
        this.selectedWorkflowType = event.detail.workflowType;
    }

    handleConnect() {
        this.isConnecting = true;
        this.connectionError = '';

        prepareLocalEntity()
            .then(entity => {
                return performHandshake({ localEntityId: entity.Id })
                    .then(() => {
                        this.isAlreadyConnected = true;
                        this.connectedEntityName = entity.Name || 'Cloud Nimbus LLC';
                        this.currentStep = 5;
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Connected!',
                            message: 'Your portal is now connected to ' + this.connectedEntityName + '.',
                            variant: 'success'
                        }));
                    });
            })
            .catch(error => {
                const msg = error.body?.message || error.message || 'Connection failed. Please check your Remote Site Settings and try again.';
                this.connectionError = msg;
            })
            .finally(() => { this.isConnecting = false; });
    }

    handleRecheck() {
        this._checkExistingConnection();
    }
}
