/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Layer 6 — Dev-Loop Mirror LWC. Renders the matching
 *               DevLoopGuide__mdt checklist + linked ScratchOrgInstance__c
 *               rows on the WorkItem__c and Feature__c record pages.
 *
 *               DH stores the recipe + mirrors GH-Actions-pushed state.
 *               This LWC does NOT shell out to cci — subscriber orgs don't
 *               have CCI. On subscriber installs the component renders a
 *               one-line "dev-loop guidance is for package developers"
 *               badge instead of the checklist.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getGuideForWorkItem from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDevLoopController.getGuideForWorkItem';
import getScratchOrgsForWorkItem from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDevLoopController.getScratchOrgsForWorkItem';

const EMPTY = 0;

export default class DeliveryDevLoopGuide extends LightningElement {
    @api recordId;

    @track guide = null;
    @track scratchOrgs = [];
    @track errorMessage = '';
    @track isGuideLoaded = false;
    @track isScratchOrgsLoaded = false;

    @wire(getGuideForWorkItem, { workItemId: '$recordId' })
    wiredGuide({ data, error }) {
        if (data) {
            this.guide = data;
            this.errorMessage = '';
            this.isGuideLoaded = true;
        } else if (error) {
            this.errorMessage = (error && error.body && error.body.message)
                ? error.body.message
                : 'Unable to load dev-loop guide.';
            this.guide = null;
            this.isGuideLoaded = true;
        }
    }

    @wire(getScratchOrgsForWorkItem, { workItemId: '$recordId' })
    wiredScratchOrgs({ data, error }) {
        if (data) {
            this.scratchOrgs = (data || []).map(o => {
                const stateLabel = o.state || 'Unknown';
                return {
                    key: o.scratchOrgId,
                    scratchOrgId: o.scratchOrgId,
                    branch: o.branch || '',
                    state: stateLabel,
                    stateBadgeClass: this.computeStateBadgeClass(stateLabel),
                    loginUrl: o.loginUrl || '',
                    hasLoginUrl: !!o.loginUrl,
                    expiresAt: o.expiresAt || null,
                    lastSyncAt: o.lastSyncAt || null
                };
            });
            this.isScratchOrgsLoaded = true;
        } else if (error) {
            this.scratchOrgs = [];
            this.isScratchOrgsLoaded = true;
        }
    }

    computeStateBadgeClass(state) {
        if (state === 'Active') {
            return 'slds-badge slds-theme_success';
        }
        if (state === 'Provisioning') {
            return 'slds-badge slds-theme_warning';
        }
        if (state === 'Expired') {
            return 'slds-badge slds-theme_shade';
        }
        if (state === 'Deleted') {
            return 'slds-badge slds-theme_inverse';
        }
        return 'slds-badge';
    }

    get isSubscriberOrg() {
        return this.guide && this.guide.isSubscriberOrg === true;
    }

    get hasGuide() {
        return this.guide
            && !this.guide.isSubscriberOrg
            && (this.guide.recommendedCciFlow
                || (this.guide.setupChecklist && this.guide.setupChecklist.length > EMPTY));
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get hasScratchOrgs() {
        return this.scratchOrgs.length > EMPTY;
    }

    get checklistSteps() {
        if (!this.guide || !this.guide.setupChecklist) {
            return [];
        }
        return this.guide.setupChecklist.map((s, idx) => ({
            key: `step-${idx}`,
            step: s.step || (idx + 1),
            label: s.label || '',
            command: s.command || '',
            hasCommand: !!s.command,
            docsUrl: s.docsUrl || '',
            hasDocsUrl: !!s.docsUrl
        }));
    }

    get permsetList() {
        if (!this.guide || !this.guide.requiredPermsets) {
            return [];
        }
        return this.guide.requiredPermsets.map(p => ({ key: p, name: p }));
    }

    get hasPermsets() {
        return this.permsetList.length > EMPTY;
    }

    get copyFlowCommand() {
        if (!this.guide || !this.guide.recommendedCciFlow) {
            return '';
        }
        return `cci flow run ${this.guide.recommendedCciFlow}`;
    }

    get hasFlowCommand() {
        return !!this.copyFlowCommand;
    }

    handleCopyFlow() {
        this.copyToClipboard(this.copyFlowCommand, 'CCI command copied');
    }

    handleCopyStep(event) {
        const command = event.currentTarget.dataset.command;
        if (!command) {
            return;
        }
        this.copyToClipboard(command, 'Step command copied');
    }

    copyToClipboard(text, successTitle) {
        if (!text) {
            return;
        }
        if (navigator && navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text)
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: successTitle,
                        message: text,
                        variant: 'success'
                    }));
                })
                .catch(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Copy failed',
                        message: 'Select the command manually and copy it.',
                        variant: 'warning'
                    }));
                });
        } else {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Clipboard unavailable',
                message: 'Select the command manually and copy it.',
                variant: 'warning'
            }));
        }
    }
}
