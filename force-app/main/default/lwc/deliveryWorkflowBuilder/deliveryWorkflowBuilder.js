/* eslint-disable */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import deployWorkflow from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowBuilderController.deployWorkflow';
import getWorkflowStages from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowBuilderController.getWorkflowStages';
import getWorkflowTypes from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowBuilderController.getWorkflowTypes';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// eslint-disable-next-line one-var
const PHASE_OPTIONS = [
    { label: 'Planning', value: 'Planning' },
    { label: 'Approval', value: 'Approval' },
    { label: 'Development', value: 'Development' },
    { label: 'Testing', value: 'Testing' },
    { label: 'UAT', value: 'UAT' },
    { label: 'Deployment', value: 'Deployment' }
];

// eslint-disable-next-line one-var
const COLOR_PRESETS = [
    { label: 'Gray', value: '#e2e8f0' },
    { label: 'Blue', value: '#bfdbfe' },
    { label: 'Green', value: '#bbf7d0' },
    { label: 'Yellow', value: '#fef08a' },
    { label: 'Red', value: '#fecaca' },
    { label: 'Purple', value: '#e9d5ff' },
    { label: 'Orange', value: '#fed7aa' },
    { label: 'Teal', value: '#99f6e4' }
];

const createEmptyStage = () => ({
    color: '#e2e8f0',
    id: Date.now() + Math.random(),
    isAttention: false,
    isBlocked: false,
    isTerminal: false,
    label: '',
    name: '',
    nextStages: '',
    phase: 'Planning'
});

export default class DeliveryWorkflowBuilder extends LightningElement {

    // ── State ────────────────────────────────────────────────────────────
    // 'list' | 'editor'
    @track currentScreen = 'list';
    @track workflowTypes = [];
    @track isLoading = true;
    @track isDeploying = false;

    // Editor state
    @track workflowName = '';
    @track workflowLabel = '';
    @track workflowDescription = '';
    @track workflowIcon = 'utility:flow';
    @track stages = [];
    @track editingExisting = false;
    @track editingTypeName = '';

    wiredTypesResult;

    // ── Wire: workflow types ─────────────────────────────────────────────
    @wire(getWorkflowTypes)
    wiredTypes(result) {
        this.wiredTypesResult = result;
        this.isLoading = false;
        if (result.data) {
            this.workflowTypes = result.data.map(t => ({
                ...t,
                cardClass: 'wb-type-card',
                stageLabel: t.stageCount === 1 ? '1 stage' : t.stageCount + ' stages',
                iconName: t.icon || 'utility:flow'
            }));
        } else if (result.error) {
            this.showToast('Error', 'Could not load workflow types.', 'error');
        }
    }

    // ── Getters ──────────────────────────────────────────────────────────
    get isListScreen() { return this.currentScreen === 'list'; }
    get isEditorScreen() { return this.currentScreen === 'editor'; }
    get hasWorkflowTypes() { return this.workflowTypes.length > 0; }
    get phaseOptions() { return PHASE_OPTIONS; }
    get colorOptions() { return COLOR_PRESETS; }
    get hasStages() { return this.stages.length > 0; }
    get editorTitle() {
        return this.editingExisting ? 'Edit Workflow: ' + this.workflowLabel : 'Create New Workflow';
    }
    get canDeploy() {
        return this.workflowName && this.workflowLabel && this.stages.length > 0 && !this.isDeploying;
    }
    get deployDisabled() { return !this.canDeploy; }
    get deployButtonLabel() { return this.isDeploying ? 'Deploying...' : 'Save & Deploy'; }

    get indexedStages() {
        return this.stages.map((s, idx) => ({
            ...s,
            index: idx,
            displayIndex: idx + 1,
            isFirst: idx === 0,
            isLast: idx === this.stages.length - 1,
            colorStyle: 'background-color: ' + s.color + '; width: 24px; height: 24px; border-radius: 4px; border: 1px solid #cbd5e1;'
        }));
    }

    // ── Navigation ───────────────────────────────────────────────────────
    handleCreateNew() {
        this.resetEditor();
        this.currentScreen = 'editor';
    }

    handleViewType(event) {
        const typeName = event.currentTarget.dataset.name;
        this.editingExisting = true;
        this.editingTypeName = typeName;
        this.isLoading = true;

        const typeData = this.workflowTypes.find(t => t.developerName === typeName);
        if (typeData) {
            this.workflowName = typeData.developerName;
            this.workflowLabel = typeData.label;
            this.workflowDescription = typeData.description || '';
            this.workflowIcon = typeData.icon || 'utility:flow';
        }

        getWorkflowStages({ workflowTypeName: typeName })
            .then(data => {
                this.stages = data.map((s, idx) => ({
                    color: s.cardColor || '#e2e8f0',
                    id: Date.now() + idx,
                    isAttention: s.isAttention || false,
                    isBlocked: s.isBlocked || false,
                    isTerminal: s.isTerminal || false,
                    label: s.displayName || s.apiValue,
                    name: s.developerName,
                    nextStages: s.forwardTransitions || '',
                    phase: s.phase || 'Planning'
                }));
                this.isLoading = false;
                this.currentScreen = 'editor';
            })
            .catch(() => {
                this.showToast('Error', 'Could not load stages.', 'error');
                this.isLoading = false;
            });
    }

    handleBackToList() {
        this.currentScreen = 'list';
        this.resetEditor();
        refreshApex(this.wiredTypesResult);
    }

    // ── Editor: workflow-level fields ────────────────────────────────────
    handleNameChange(event) {
        this.workflowLabel = event.target.value;
        if (!this.editingExisting) {
            this.workflowName = event.target.value
                .replace(/[^a-zA-Z0-9\s]/gu, '')
                .replace(/\s+/gu, '_');
        }
    }

    handleApiNameChange(event) {
        this.workflowName = event.target.value.replace(/[^a-zA-Z0-9_]/g, '');
    }

    handleDescriptionChange(event) {
        this.workflowDescription = event.target.value;
    }

    handleIconChange(event) {
        this.workflowIcon = event.target.value;
    }

    // ── Editor: stage operations ─────────────────────────────────────────
    handleAddStage() {
        this.stages = [...this.stages, createEmptyStage()];
    }

    handleRemoveStage(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this.stages = this.stages.filter((item, stageIdx) => stageIdx !== idx);
    }

    handleMoveUp(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        if (idx <= 0) return;
        const updated = [...this.stages];
        [updated[idx - 1], updated[idx]] = [updated[idx], updated[idx - 1]];
        this.stages = updated;
    }

    handleMoveDown(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        if (idx >= this.stages.length - 1) return;
        const updated = [...this.stages];
        [updated[idx], updated[idx + 1]] = [updated[idx + 1], updated[idx]];
        this.stages = updated;
    }

    handleStageLabelChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const updated = [...this.stages];
        updated[idx] = {
            ...updated[idx],
            label: event.target.value,
            name: event.target.value.replace(/[^a-zA-Z0-9\s]/g, '').replace(/\s+/g, '_')
        };
        this.stages = updated;
    }

    handleStagePhaseChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const updated = [...this.stages];
        updated[idx] = { ...updated[idx], phase: event.detail.value };
        this.stages = updated;
    }

    handleStageColorChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const updated = [...this.stages];
        updated[idx] = { ...updated[idx], color: event.detail.value };
        this.stages = updated;
    }

    handleStageTerminalChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const updated = [...this.stages];
        updated[idx] = { ...updated[idx], isTerminal: event.target.checked };
        this.stages = updated;
    }

    handleStageAttentionChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const updated = [...this.stages];
        updated[idx] = { ...updated[idx], isAttention: event.target.checked };
        this.stages = updated;
    }

    handleStageBlockedChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const updated = [...this.stages];
        updated[idx] = { ...updated[idx], isBlocked: event.target.checked };
        this.stages = updated;
    }

    // ── Deploy ───────────────────────────────────────────────────────────
    handleDeploy() {
        if (!this.canDeploy) return;

        // Validate
        const invalidStage = this.stages.find(s => !s.label);
        if (invalidStage) {
            this.showToast('Validation Error', 'All stages must have a name.', 'warning');
            return;
        }

        this.isDeploying = true;
        const payload = {
            name: this.workflowName,
            label: this.workflowLabel,
            description: this.workflowDescription,
            icon: this.workflowIcon,
            stages: this.stages.map(s => ({
                name: s.name,
                label: s.label,
                phase: s.phase,
                color: s.color,
                isTerminal: s.isTerminal,
                isBlocked: s.isBlocked,
                isAttention: s.isAttention,
                nextStages: s.nextStages
            }))
        };

        deployWorkflow({ workflowJson: JSON.stringify(payload) })
            .then(deploymentId => {
                this.showToast(
                    'Deployment Queued',
                    'Workflow deployment started. ID: ' + deploymentId +
                    '. Metadata changes may take a moment to appear.',
                    'success'
                );
                this.isDeploying = false;
            })
            .catch(error => {
                const msg = error.body ? error.body.message : error.message || 'Unknown error';
                this.showToast('Deployment Error', msg, 'error');
                this.isDeploying = false;
            });
    }

    // ── Helpers ──────────────────────────────────────────────────────────
    resetEditor() {
        this.workflowName = '';
        this.workflowLabel = '';
        this.workflowDescription = '';
        this.workflowIcon = 'utility:flow';
        this.stages = [];
        this.editingExisting = false;
        this.editingTypeName = '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
