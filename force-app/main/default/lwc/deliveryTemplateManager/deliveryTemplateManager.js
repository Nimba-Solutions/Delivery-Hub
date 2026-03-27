/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Admin template management UI. Lists all work item templates
 *               with name, workflow type, description, stage, estimated hours.
 *               Supports creating work items from templates and creating new templates.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import activateTemplate from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTemplateManagerController.activateTemplate';
import createFromTemplate from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTemplateManagerController.createFromTemplate';
import deactivateTemplate from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTemplateManagerController.deactivateTemplate';
import getTemplates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTemplateManagerController.getTemplates';

const DESC_PREVIEW_LENGTH = 80;
const DEFAULT_PRIORITY_COLOR = '#94a3b8';

const PRIORITY_COLORS = {
    High: '#dc2626',
    Low: '#22c55e',
    Medium: '#f59e0b'
};

export default class DeliveryTemplateManager extends NavigationMixin(LightningElement) { // eslint-disable-line new-cap
    @track templates = [];
    @track isLoading = true;
    @track error = '';
    @track showCloneModal = false;
    @track selectedTemplate = null;
    @track isCloning = false;
    @track overrideTitle = '';
    @track overridePriority = '';
    @track showInactive = false;

    wiredResult;

    @wire(getTemplates)
    wiredTemplates(result) {
        this.wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.templates = result.data.map(tmpl => this.enrichTemplate(tmpl));
            this.error = '';
        } else if (result.error) {
            this.error = result.error.body?.message || result.error.message || 'Failed to load templates.';
            this.templates = [];
        }
    }

    enrichTemplate(tmpl) {
        const color = PRIORITY_COLORS[tmpl.PriorityPk__c] || DEFAULT_PRIORITY_COLOR;
        const descRaw = tmpl.DetailsTxt__c
            ? tmpl.DetailsTxt__c.replace(/<[^>]*>/gu, '').substring(0, DESC_PREVIEW_LENGTH)
            : '';
        const descSuffix = tmpl.DetailsTxt__c && tmpl.DetailsTxt__c.length > DESC_PREVIEW_LENGTH ? '...' : '';
        return {
            ...tmpl,
            descPreview: descRaw ? `${descRaw}${descSuffix}` : 'No description',
            estimateLabel: DeliveryTemplateManager.buildEstimate(tmpl),
            isActive: tmpl.IsActiveBool__c === true,
            priorityColor: color,
            priorityStyle: `color: ${color}; font-weight: 600;`,
            statusClass: tmpl.IsActiveBool__c ? 'tm-status tm-status--active' : 'tm-status tm-status--inactive',
            statusLabel: tmpl.IsActiveBool__c ? 'Active' : 'Inactive',
            toggleLabel: tmpl.IsActiveBool__c ? 'Deactivate' : 'Activate',
            workflowLabel: (tmpl.WorkflowTypeTxt__c || 'None').replace(/_/gu, ' ')
        };
    }

    get filteredTemplates() {
        if (this.showInactive) {
            return this.templates;
        }
        return this.templates.filter(tmpl => tmpl.isActive);
    }

    get hasTemplates() {
        return this.filteredTemplates.length > 0;
    }

    get showEmptyState() {
        return !this.hasTemplates;
    }

    get isLoaded() {
        return !this.isLoading;
    }

    get noError() {
        return !this.error;
    }

    get templateCount() {
        return this.filteredTemplates.length;
    }

    get totalCount() {
        return this.templates.length;
    }

    get toggleInactiveLabel() {
        if (this.showInactive) {
            return 'Hide Inactive';
        }
        return 'Show Inactive';
    }

    get priorityOptions() {
        return [
            { label: '-- Keep Default --', value: '' },
            { label: 'High', value: 'High' },
            { label: 'Medium', value: 'Medium' },
            { label: 'Low', value: 'Low' }
        ];
    }

    handleToggleInactive() {
        this.showInactive = !this.showInactive;
    }

    handleNewTemplate() {
        this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
            attributes: {
                actionName: 'new',
                objectApiName: '%%%NAMESPACE%%%WorkItem__c'
            },
            state: {
                defaultFieldValues: 'IsTemplateBool__c=true'
            },
            type: 'standard__objectPage'
        });
    }

    handleUseTemplate(event) {
        const templateId = event.currentTarget.dataset.id;
        this.selectedTemplate = this.templates.find(tmpl => tmpl.Id === templateId);
        this.overrideTitle = '';
        this.overridePriority = '';
        this.showCloneModal = true;
    }

    handleViewTemplate(event) {
        const templateId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
            attributes: {
                actionName: 'view',
                recordId: templateId
            },
            type: 'standard__recordPage'
        });
    }

    async handleToggleActive(event) {
        const templateId = event.currentTarget.dataset.id;
        const tmpl = this.templates.find(item => item.Id === templateId);
        if (!tmpl) {
            return;
        }

        try {
            if (tmpl.isActive) {
                await deactivateTemplate({ templateId });
            } else {
                await activateTemplate({ templateId });
            }
            await refreshApex(this.wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                message: tmpl.isActive ? 'Template deactivated.' : 'Template activated.',
                title: 'Success',
                variant: 'success'
            }));
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                message: err.body?.message || err.message || 'Operation failed.',
                title: 'Error',
                variant: 'error'
            }));
        }
    }

    handleOverrideTitleChange(event) {
        this.overrideTitle = event.detail.value;
    }

    handleOverridePriorityChange(event) {
        this.overridePriority = event.detail.value;
    }

    handleCloneCancel() {
        this.showCloneModal = false;
        this.selectedTemplate = null;
    }

    async handleCloneConfirm() {
        if (!this.selectedTemplate) {
            return;
        }

        this.isCloning = true;
        try {
            const overrides = {};
            if (this.overrideTitle) {
                overrides.BriefDescriptionTxt__c = this.overrideTitle;
            }
            if (this.overridePriority) {
                overrides.PriorityPk__c = this.overridePriority;
            }

            const hasOverrides = Object.keys(overrides).length > 0;
            const newId = await createFromTemplate({
                overrides: hasOverrides ? overrides : null,
                templateId: this.selectedTemplate.Id
            });

            this.showCloneModal = false;
            this.selectedTemplate = null;

            this.dispatchEvent(new ShowToastEvent({
                message: 'Work item created from template.',
                title: 'Success',
                variant: 'success'
            }));

            this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
                attributes: {
                    actionName: 'view',
                    objectApiName: '%%%NAMESPACE%%%WorkItem__c',
                    recordId: newId
                },
                type: 'standard__recordPage'
            });
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                message: err.body?.message || err.message || 'Failed to create from template.',
                title: 'Error',
                variant: 'error'
            }));
        } finally {
            this.isCloning = false;
        }
    }

    static buildEstimate(tmpl) {
        const parts = [];
        if (tmpl.EstimatedHoursNumber__c !== undefined && tmpl.EstimatedHoursNumber__c !== null) {
            parts.push(`${tmpl.EstimatedHoursNumber__c}h`);
        }
        if (tmpl.DeveloperDaysSizeNumber__c !== undefined && tmpl.DeveloperDaysSizeNumber__c !== null) {
            parts.push(`${tmpl.DeveloperDaysSizeNumber__c}d`);
        }
        return parts.join(' / ') || '--';
    }
}
