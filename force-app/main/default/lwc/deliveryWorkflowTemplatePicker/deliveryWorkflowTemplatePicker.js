/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Workflow template picker — displays available workflow templates
 * as selectable cards with mini-pipeline preview, stage counts, and persona lists.
 * Dispatches 'templateselected' event with the chosen workflow type DeveloperName.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track, api } from 'lwc';
import getWorkflowTemplates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowTemplates';

export default class DeliveryWorkflowTemplatePicker extends LightningElement {
    @track templates = [];
    @track selectedTemplate = '';
    @track isLoading = true;
    @track error = '';

    /** When true, hides the heading/description (for embedding in wizard). */
    @api compact = false;

    @wire(getWorkflowTemplates)
    wiredTemplates({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.templates = data.map(t => ({
                ...t,
                isSelected: t.developerName === this.selectedTemplate,
                cardClass: 'tp-card' + (t.developerName === this.selectedTemplate ? ' tp-card--selected' : ''),
                stageLabel: t.stageCount + (t.stageCount === 1 ? ' stage' : ' stages'),
                personaLabel: (t.personas || []).join(', ').replace(/_/g, ' '),
                personaCount: (t.personas || []).length,
                pipelineDots: (t.stageColors || []).map((color, idx) => ({
                    key: t.developerName + '_dot_' + idx,
                    style: 'background-color: ' + color
                })),
                defaultBadge: t.isDefault === true
            }));
            this.error = '';
        } else if (error) {
            this.error = error.body?.message || error.message || 'Failed to load workflow templates.';
            this.templates = [];
        }
    }

    get showHeading() {
        return !this.compact;
    }

    get hasTemplates() {
        return this.templates.length > 0;
    }

    get hasSelection() {
        return this.selectedTemplate !== '';
    }

    handleCardSelect(event) {
        const devName = event.currentTarget.dataset.name;
        this.selectedTemplate = devName;
        // Re-derive card classes
        this.templates = this.templates.map(t => ({
            ...t,
            isSelected: t.developerName === devName,
            cardClass: 'tp-card' + (t.developerName === devName ? ' tp-card--selected' : '')
        }));
        this.dispatchEvent(new CustomEvent('templateselected', {
            detail: { workflowType: devName }
        }));
    }
}
