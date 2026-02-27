/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// --- APEX IMPORTS ---
import updateWorkItemStage from '@salesforce/apex/DeliveryHubBoardController.updateWorkItemStage';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';

// --- SCHEMA IMPORTS ---
// Removed ID_FIELD import
import STAGE_FIELD from '@salesforce/schema/WorkItem__c.StageNamePk__c';
import ESTIMATED_HOURS_FIELD from '@salesforce/schema/WorkItem__c.EstimatedHoursNumber__c';
import PRE_APPROVED_HOURS_FIELD from '@salesforce/schema/WorkItem__c.ClientPreApprovedHoursNumber__c';
import DEVELOPER_FIELD from '@salesforce/schema/WorkItem__c.Developer__c';
import CRITERIA_FIELD from '@salesforce/schema/WorkItem__c.AcceptanceCriteriaTxt__c';
import PRIORITY_FIELD from '@salesforce/schema/WorkItem__c.PriorityPk__c';

const FIELDS = [
    STAGE_FIELD, 
    ESTIMATED_HOURS_FIELD, 
    PRE_APPROVED_HOURS_FIELD, 
    DEVELOPER_FIELD, 
    CRITERIA_FIELD,
    PRIORITY_FIELD
];

export default class DeliveryWorkItemActionCenter extends LightningElement {
    @api recordId;
    @track workItem;
    @track wiredWorkItemResult; 

    // State
    @track missingFields = [];
    @track advanceOptions = [];
    @track backtrackOptions = [];
    @track isFastTrackAvailable = false;
    @track isBlocked = false;
    @track processing = false;
    @track currentStage = '';

    // --- CMT-DRIVEN WORKFLOW STATE ---
    @track _workflowConfig = null;

    @wire(getWorkflowConfig, { workflowTypeName: 'Software_Delivery' })
    wiredConfig({ data, error }) {
        if (data) {
            this._workflowConfig = data;
            if (this.workItem) { this.evaluateState(); }
        } else if (error) {
            console.error('[ActionCenter] getWorkflowConfig error:', error);
        }
    }

    get _stageMap() {
        if (!this._workflowConfig?.stages) return {};
        return Object.fromEntries(this._workflowConfig.stages.map(s => [s.apiValue, s]));
    }

    get transitionMap() {
        const map = {};
        if (this._workflowConfig?.stages) {
            this._workflowConfig.stages.forEach(s => {
                map[s.apiValue] = s.forwardTransitions || [];
            });
        }
        return map;
    }

    get backtrackMap() {
        const map = {};
        if (this._workflowConfig?.stages) {
            this._workflowConfig.stages.forEach(s => {
                map[s.apiValue] = s.backtrackTransitions || [];
            });
        }
        return map;
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredWorkItem(result) {
        this.wiredWorkItemResult = result;
        const { data, error } = result;
        if (data) {
            this.workItem = data;
            this.evaluateState();
        } else if (error) {
            console.error('Error fetching work item data', error);
        }
    }

    get hasMissingFields() {
        return this.missingFields && this.missingFields.length > 0;
    }

    get showMoveOptions() {
        return !this.hasMissingFields;
    }

    evaluateState() {
        this.missingFields = [];
        const stage = getFieldValue(this.workItem, STAGE_FIELD);
        this.currentStage = stage || '';
        const est = getFieldValue(this.workItem, ESTIMATED_HOURS_FIELD);
        const approved = getFieldValue(this.workItem, PRE_APPROVED_HOURS_FIELD);
        const dev = getFieldValue(this.workItem, DEVELOPER_FIELD);
        const criteria = getFieldValue(this.workItem, CRITERIA_FIELD);

        // --- 1. DETERMINE MISSING FIELDS (Cumulative Health Check) ---
        
        // Rule: Need Pre-Approved Hours for Fast Track Analysis (Soft Gate - Info only)
        if (!approved && ['Scoping', 'Backlog', 'Ready for Sizing'].includes(stage)) {
            this.missingFields.push({ 
                apiName: 'ClientPreApprovedHoursNumber__c', 
                reason: 'Define Budget to enable Fast Track' 
            });
        }

        // Rule: Need Estimate before Proposal/Sizing completion (Hard Gate for Proposal)
        if (!est && ['Ready for Sizing', 'Sizing Underway', 'Drafting Proposal', 'Ready for Prioritization'].includes(stage)) {
            this.missingFields.push({ 
                apiName: 'EstimatedHoursNumber__c', 
                reason: 'Hours Estimate Required to Proceed' 
            });
        }

        // Rule: Need Developer before Dev (Hard Gate)
        const devStages = ['Ready for Development', 'In Development', 'Dev Blocked', 'Dev Clarification Requested'];
        if (!dev && devStages.includes(stage)) {
            this.missingFields.push({ 
                apiName: 'Developer__c', 
                reason: 'Assign Developer to Start Work' 
            });
        }

        // Rule: Need Acceptance Criteria before Dev
        if (!criteria && devStages.includes(stage)) {
            this.missingFields.push({
                apiName: 'AcceptanceCriteriaTxt__c',
                reason: 'Define Acceptance Criteria (Definition of Done)'
            });
        }

        // --- 2. CALCULATE FAST TRACK ---
        // If we have both numbers, and Estimate <= Approved, we are Green.
        this.isFastTrackAvailable = (est && approved && est <= approved);

        // --- 3. DETERMINE IF BLOCKED ---
        // If specific hard-stop fields are missing for the *current* stage, we block.
        this.isBlocked = this.hasMissingFields;

        // --- 4. CALCULATE BUTTONS ---
        this.calculateButtons(stage);
    }

    calculateButtons(currentStage) {
        // 1. Advance Options
        const nextStages = this.transitionMap[currentStage] || [];
        this.advanceOptions = nextStages.map(target => {
            let isDisabled = false;
            let title = 'Move to ' + target;
            let variant = 'neutral'; // Default

            // Logic: Disable Advance if blocked by critical missing info
            // Exception: Fast Track allows bypassing "Client Approval"
            if (this.isBlocked) {
                // However, we allow moving to "Cancelled" or "Backlog" even if blocked
                if (target !== 'Cancelled' && target !== 'Backlog') {
                    isDisabled = true;
                    title = 'Please complete required fields above to unlock.';
                }
            }

            // Highlight "Happy Path"
            if (this.isFastTrackAvailable && target === 'Ready for Development') {
                variant = 'success';
                title = 'Fast Track Available!';
                isDisabled = false; // Always unlock Fast Track destination
            }

            let btnClass = 'ac-advance-btn';
            if (isDisabled) {
                btnClass += ' is-disabled';
            } else if (variant === 'success') {
                btnClass += ' is-success';
            }

            return {
                stage: target,
                label: target,
                variant: variant,
                disabled: isDisabled,
                disabledReason: title,
                advanceBtnClass: btnClass
            };
        });

        // 2. Backtrack Options
        const prevStages = this.backtrackMap[currentStage] || [];
        this.backtrackOptions = prevStages.map(target => {
            return {
                stage: target,
                label: target,
                variant: 'neutral'
            };
        });
    }

    get currentPhaseLabel() {
        const stageInfo = this._stageMap[this.currentStage];
        return stageInfo ? stageInfo.phase : '';
    }

    get stageBannerStyle() {
        const stageInfo = this._stageMap[this.currentStage];
        const color = stageInfo?.headerBgColor || '#6B7280';
        return `border-left: 4px solid ${color}; background: ${color}18;`;
    }

    handleFixSuccess() {
        this.processing = true;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Work item requirements updated.',
                variant: 'success'
            })
        );
        // Refresh the wire to re-evaluate gates immediately
        refreshApex(this.wiredWorkItemResult).then(() => {
            this.processing = false;
        });
    }

    async handleMove(event) {
        const targetStage = event.target.dataset.stage;
        this.processing = true;

        try {
            await updateWorkItemStage({ 
                workItemId: this.recordId, 
                newStage: targetStage 
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Moved',
                    message: `Work item moved to ${targetStage}`,
                    variant: 'success'
                })
            );
            
            // Refresh data
            await refreshApex(this.wiredWorkItemResult);

        } catch (error) {
            console.error('Move failed', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error moving work item',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                })
            );
        } finally {
            this.processing = false;
        }
    }
}