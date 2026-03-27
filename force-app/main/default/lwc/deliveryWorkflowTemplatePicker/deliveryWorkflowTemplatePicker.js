/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Workflow template picker — displays available workflow templates
 * as selectable cards with mini-pipeline preview, stage counts, and persona lists.
 * Dispatches 'templateselected' event with the chosen workflow type DeveloperName.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track, wire } from 'lwc';
import getWorkflowTemplates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowTemplates';

const SINGLE_STAGE = 1;

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
            this.templates = data.map(tmpl => this.enrichTemplate(tmpl));
            this.error = '';
        } else if (error) {
            this.error = error.body?.message || error.message || 'Failed to load workflow templates.';
            this.templates = [];
        }
    }

    enrichTemplate(tmpl) {
        const selected = tmpl.developerName === this.selectedTemplate;
        const phases = tmpl.phases || [];
        return {
            ...tmpl,
            cardClass: selected ? 'tp-card tp-card--selected' : 'tp-card',
            defaultBadge: tmpl.isDefault === true,
            hasPhases: phases.length >= SINGLE_STAGE,
            isSelected: selected,
            personaCount: (tmpl.personas || []).length,
            personaLabel: (tmpl.personas || []).join(', ').replace(/_/gu, ' '),
            phaseList: phases.map((phase, idx) => ({
                key: `${tmpl.developerName}_phase_${idx}`,
                label: phase
            })),
            pipelineDots: (tmpl.stageColors || []).map((color, idx) => ({
                key: `${tmpl.developerName}_dot_${idx}`,
                style: `background-color: ${color}`
            })),
            stageLabel: `${tmpl.stageCount} ${tmpl.stageCount === SINGLE_STAGE ? 'stage' : 'stages'}`
        };
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
        this.templates = this.templates.map(tmpl => ({
            ...tmpl,
            cardClass: tmpl.developerName === devName ? 'tp-card tp-card--selected' : 'tp-card',
            isSelected: tmpl.developerName === devName
        }));
        this.dispatchEvent(new CustomEvent('templateselected', {
            detail: { workflowType: devName }
        }));
    }
}
