/* eslint-disable */
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

import getTemplates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTemplateManagerController.getTemplates';
import createFromTemplate from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTemplateManagerController.createFromTemplate';
import deactivateTemplate from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTemplateManagerController.deactivateTemplate';
import activateTemplate from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTemplateManagerController.activateTemplate';

const PRIORITY_COLORS = {
    High: '#dc2626',
    Medium: '#f59e0b',
    Low: '#22c55e'
};

export default class DeliveryTemplateManager extends NavigationMixin(LightningElement) {
    @track templates = [];
    @track isLoading = true;
    @track error = '';
    @track showCloneModal = false;
    @track selectedTemplate = null;
    @track isCloning = false;
    @track overrideTitle = '';
    @track overridePriority = '';
    @track showInactive = false;

    _wiredResult;

    @wire(getTemplates)
    wiredTemplates(result) {
        this._wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.templates = result.data.map(t => ({
                ...t,
                priorityColor: PRIORITY_COLORS[t.PriorityPk__c] || '#94a3b8',
                priorityStyle: 'color: ' + (PRIORITY_COLORS[t.PriorityPk__c] || '#94a3b8') + '; font-weight: 600;',
                workflowLabel: (t.WorkflowTypeTxt__c || 'None').replace(/_/g, ' '),
                descPreview: t.DetailsTxt__c
                    ? t.DetailsTxt__c.replace(/<[^>]*>/g, '').substring(0, 80) + (t.DetailsTxt__c.length > 80 ? '...' : '')
                    : 'No description',
                estimateLabel: this._buildEstimate(t),
                statusLabel: t.IsActiveBool__c ? 'Active' : 'Inactive',
                statusClass: t.IsActiveBool__c ? 'tm-status tm-status--active' : 'tm-status tm-status--inactive',
                isActive: t.IsActiveBool__c === true,
                toggleLabel: t.IsActiveBool__c ? 'Deactivate' : 'Activate'
            }));
            this.error = '';
        } else if (result.error) {
            this.error = result.error.body?.message || result.error.message || 'Failed to load templates.';
            this.templates = [];
        }
    }

    get filteredTemplates() {
        if (this.showInactive) {
            return this.templates;
        }
        return this.templates.filter(t => t.isActive);
    }

    get hasTemplates() {
        return this.filteredTemplates.length > 0;
    }

    get showEmptyState() { return !this.hasTemplates; }
    get isLoaded() { return !this.isLoading; }
    get noError() { return !this.error; }

    get templateCount() {
        return this.filteredTemplates.length;
    }

    get totalCount() {
        return this.templates.length;
    }

    get toggleInactiveLabel() {
        return this.showInactive ? 'Hide Inactive' : 'Show Inactive';
    }

    get priorityOptions() {
        return [
            { label: '-- Keep Default --', value: '' },
            { label: 'High', value: 'High' },
            { label: 'Medium', value: 'Medium' },
            { label: 'Low', value: 'Low' }
        ];
    }

    // ---- Event Handlers ----

    handleToggleInactive() {
        this.showInactive = !this.showInactive;
    }

    handleNewTemplate() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: '%%%NAMESPACE%%%WorkItem__c',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: 'IsTemplateBool__c=true'
            }
        });
    }

    handleUseTemplate(event) {
        const templateId = event.currentTarget.dataset.id;
        this.selectedTemplate = this.templates.find(t => t.Id === templateId);
        this.overrideTitle = '';
        this.overridePriority = '';
        this.showCloneModal = true;
    }

    handleViewTemplate(event) {
        const templateId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: templateId,
                actionName: 'view'
            }
        });
    }

    async handleToggleActive(event) {
        const templateId = event.currentTarget.dataset.id;
        const tmpl = this.templates.find(t => t.Id === templateId);
        if (!tmpl) return;

        try {
            if (tmpl.isActive) {
                await deactivateTemplate({ templateId });
            } else {
                await activateTemplate({ templateId });
            }
            await refreshApex(this._wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: tmpl.isActive ? 'Template deactivated.' : 'Template activated.',
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || error.message || 'Operation failed.',
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
        if (!this.selectedTemplate) return;

        this.isCloning = true;
        try {
            const overrides = {};
            if (this.overrideTitle) {
                overrides.BriefDescriptionTxt__c = this.overrideTitle;
            }
            if (this.overridePriority) {
                overrides.PriorityPk__c = this.overridePriority;
            }

            const newId = await createFromTemplate({
                templateId: this.selectedTemplate.Id,
                overrides: Object.keys(overrides).length > 0 ? overrides : null
            });

            this.showCloneModal = false;
            this.selectedTemplate = null;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Work item created from template.',
                variant: 'success'
            }));

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: newId,
                    objectApiName: '%%%NAMESPACE%%%WorkItem__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || error.message || 'Failed to create from template.',
                variant: 'error'
            }));
        } finally {
            this.isCloning = false;
        }
    }

    // ---- Private ----

    _buildEstimate(t) {
        const parts = [];
        if (t.EstimatedHoursNumber__c != null) {
            parts.push(t.EstimatedHoursNumber__c + 'h');
        }
        if (t.DeveloperDaysSizeNumber__c != null) {
            parts.push(t.DeveloperDaysSizeNumber__c + 'd');
        }
        return parts.join(' / ') || '--';
    }
}
