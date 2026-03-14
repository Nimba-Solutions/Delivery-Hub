/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Interactive onboarding wizard for Delivery Hub.
 * 5-step guided flow: Org Type → Workflow → Partner Config → Test Ping → Connected.
 * Step 4 includes prerequisite checks for Site, Guest User, and Remote Site Settings.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSetupStatus from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.getSetupStatus';
import prepareLocalEntity from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.prepareLocalEntity';
import performHandshake from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.performHandshake';
import checkPrerequisites from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.checkPrerequisites';
import configureGuestUserAccess from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.configureGuestUserAccess';

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

    // Prerequisites state
    @track isCheckingPrereqs = false;
    @track prereqs = null;
    @track prereqsChecked = false;

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

    // Prerequisites computed getters
    get showPrereqs() {
        return this.isStep4 && this.isClientOrg;
    }

    get prereqSiteClass() {
        if (!this.prereqs) return 'prereq-item';
        return this.prereqs.siteActive ? 'prereq-item prereq-item--pass' : 'prereq-item prereq-item--fail';
    }
    get prereqGuestClass() {
        if (!this.prereqs) return 'prereq-item';
        return this.prereqs.guestUserConfigured ? 'prereq-item prereq-item--pass' : 'prereq-item prereq-item--fail';
    }
    get prereqRemoteClass() {
        if (!this.prereqs) return 'prereq-item';
        return this.prereqs.remoteSiteReachable ? 'prereq-item prereq-item--pass' : 'prereq-item prereq-item--fail';
    }

    get prereqSiteIcon() {
        return this.prereqs && this.prereqs.siteActive ? 'utility:check' : 'utility:close';
    }
    get prereqGuestIcon() {
        return this.prereqs && this.prereqs.guestUserConfigured ? 'utility:check' : 'utility:close';
    }
    get prereqRemoteIcon() {
        return this.prereqs && this.prereqs.remoteSiteReachable ? 'utility:check' : 'utility:close';
    }

    get canConnect() {
        if (this.isVendorOrg) return true;
        return this.prereqs && this.prereqs.allPassed;
    }

    get connectDisabled() {
        return this.isConnecting || !this.canConnect;
    }

    get showSiteHelp() {
        return this.prereqs && !this.prereqs.siteActive;
    }
    get showGuestHelp() {
        return this.prereqs && this.prereqs.siteActive && !this.prereqs.guestUserConfigured;
    }
    get showRemoteHelp() {
        return this.prereqs && !this.prereqs.remoteSiteReachable;
    }

    get remoteSiteUrl() {
        return this.prereqs ? this.prereqs.remoteSiteUrl : '';
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
            // Auto-run prereqs when entering Step 4 for client orgs
            if (this.currentStep === 4 && this.isClientOrg) {
                this._runPrerequisiteCheck();
            }
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

    handleRecheckPrereqs() {
        this._runPrerequisiteCheck();
    }

    handleFixGuestUser() {
        configureGuestUserAccess()
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Guest User Configured',
                    message: 'Permission set assigned to the Site guest user.',
                    variant: 'success'
                }));
                this._runPrerequisiteCheck();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || error.message || 'Failed to configure guest user.',
                    variant: 'error'
                }));
            });
    }

    handleCopyUrl() {
        const url = this.prereqs ? this.prereqs.remoteSiteUrl : '';
        if (url && navigator.clipboard) {
            navigator.clipboard.writeText(url).then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Copied',
                    message: 'URL copied to clipboard.',
                    variant: 'success'
                }));
            });
        }
    }

    // ── Prerequisites ──

    _runPrerequisiteCheck() {
        this.isCheckingPrereqs = true;
        this.prereqsChecked = false;
        checkPrerequisites()
            .then(result => {
                this.prereqs = result;
                this.prereqsChecked = true;
            })
            .catch(error => {
                this.connectionError = error.body?.message || 'Failed to check prerequisites.';
            })
            .finally(() => { this.isCheckingPrereqs = false; });
    }
}
