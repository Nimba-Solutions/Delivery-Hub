/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi'; // Removed updateRecord
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// --- APEX IMPORTS ---
import updateTicketStage from '@salesforce/apex/DeliveryHubBoardController.updateTicketStage';

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
    @track ticket;
    @track wiredTicketResult; 

    // State
    @track missingFields = [];
    @track advanceOptions = [];
    @track backtrackOptions = [];
    @track isFastTrackAvailable = false;
    @track isBlocked = false;
    @track processing = false;
    @track currentStage = '';

    // --- TRANSITION MAPS ---
    transitionMap = {
        // --- PHASE 1: DEFINITION & SCOPING ---
        "Backlog":                           ["Scoping In Progress",             "Clarification Requested (Pre-Dev)",    "Ready for Sizing",    "Ready for Prioritization",    "Proposal Requested",    "Ready for Tech Review",    "Ready for Client Approval"],
        "Scoping In Progress":               ["Clarification Requested (Pre-Dev)",                                       "Ready for Sizing",    "Ready for Prioritization",    "Proposal Requested",    "Ready for Tech Review",    "Ready for Client Approval"],
        "Clarification Requested (Pre-Dev)": ["Providing Clarification",                                                 "Ready for Sizing",    "Ready for Prioritization",    "Proposal Requested",    "Ready for Tech Review",    "Ready for Client Approval"],
        "Providing Clarification":           [                                                                           "Ready for Sizing",    "Ready for Prioritization",    "Proposal Requested",    "Ready for Tech Review",    "Ready for Client Approval"],

        // --- PHASE 2: ESTIMATION & PRIORITIZATION ---
        "Ready for Sizing":                  ["Sizing Underway",                                                         "Ready for Prioritization",    "Proposal Requested",    "Ready for Tech Review",    "Ready for Client Approval"],
        "Sizing Underway":                   [                                                                           "Ready for Prioritization",    "Proposal Requested",    "Ready for Tech Review",    "Ready for Client Approval"],
        "Ready for Prioritization":          ["Prioritizing",                                                                                           "Proposal Requested",    "Ready for Tech Review",    "Ready for Client Approval"],
        "Prioritizing":                      [                                                                                                          "Proposal Requested",    "Ready for Tech Review",    "Ready for Development"],
        "Proposal Requested":                ["Drafting Proposal"],
        "Drafting Proposal":                 [                                                                                                                                   "Ready for Tech Review",    "Ready for Prioritization"],

        // --- PHASE 3: TECHNICAL & CLIENT APPROVAL ---
        "Ready for Tech Review":             ["Tech Reviewing",                                                                                                                  "Ready for Client Approval",    "Ready for Development"],
        "Tech Reviewing":                    [                                                                                                                                   "Ready for Client Approval",    "Ready for Development"],
        "Ready for Client Approval":         ["In Client Approval",                                                                                                                                              "Ready for Development"],
        "In Client Approval":                [                                                                                                                                                                   "Ready for Development"],

        "Ready for Final Approval":          ["Final Approving"],
        "Final Approving":                   ["Ready for Development"],

        // --- PHASE 4: DEVELOPMENT ---
        "Ready for Development":             ["In Development"],
        "In Development":                    ["Dev Clarification Requested",     "Dev Blocked",     "Ready for Scratch Test",    "Ready for QA",    "Ready for Deployment"],
        "Dev Clarification Requested":       ["Providing Dev Clarification"],
        "Providing Dev Clarification":       ["Back For Development"],
        "Dev Blocked":                       ["In Development",                  "Providing Dev Clarification"],
        "Back For Development":              ["In Development"],

        // --- PHASE 5: TESTING (QA & INTERNAL) ---
        "Ready for Scratch Test":            ["Scratch Testing",                 "Ready for QA",              "Ready for Internal UAT",    "Ready for Client UAT"],
        "Scratch Testing":                   ["Ready for QA",                    "Ready for Internal UAT",    "Ready for Client UAT",      "Back For Development"],
        "Ready for QA":                      ["QA In Progress",                  "Ready for Internal UAT",    "Ready for Client UAT"],
        "QA In Progress":                    ["Ready for Internal UAT",          "Ready for Client UAT",      "Back For Development"],
        "Ready for Internal UAT":            ["Internal UAT",                    "Ready for Client UAT"],
        "Internal UAT":                      ["Ready for Client UAT",            "Back For Development"],

        // --- PHASE 6: CLIENT UAT ---
        "Ready for Client UAT":              ["In Client UAT",                   "Ready for UAT Sign-off",    "Ready for Merge",           "Ready for Deployment"],
        "In Client UAT":                     ["Ready for UAT Sign-off",          "Ready for Merge",           "Ready for Deployment",      "Back For Development"],
        "Ready for UAT Sign-off":            ["Processing Sign-off",             "Ready for Merge",           "Ready for Deployment"],
        "Processing Sign-off":               ["Ready for Merge",                 "Ready for Deployment",      "Back For Development"],

        // --- PHASE 7: DEPLOYMENT ---
        "Ready for Merge":                   ["Merging",                         "Ready for Deployment"],
        "Merging":                           ["Ready for Deployment"],
        "Ready for Deployment":              ["Deploying"],
        "Deploying":                         ["Deployed to Prod"],
        "Deployed to Prod":                  ["Done"],
        
        // --- PHASE 8: END STATES ---
        "Done":                              [],
        "Cancelled":                         ["Backlog", "Ready for Sizing"]
    };

    backtrackMap = {
        "Scoping In Progress":               ["Backlog", "Cancelled"],
        "Clarification Requested (Pre-Dev)": ["Scoping In Progress", "Backlog", "Cancelled"],
        "Providing Clarification":           ["Clarification Requested (Pre-Dev)", "Scoping In Progress", "Cancelled"],
        "Ready for Sizing":                  ["Providing Clarification", "Clarification Requested (Pre-Dev)", "Scoping In Progress", "Backlog", "Cancelled"],
        "Sizing Underway":                   ["Ready for Sizing", "Cancelled"],
        "Ready for Prioritization":          ["Sizing Underway", "Ready for Sizing", "Providing Clarification", "Cancelled"],
        "Prioritizing":                      ["Ready for Prioritization", "Cancelled"],
        "Proposal Requested":                ["Prioritizing", "Ready for Prioritization", "Sizing Underway", "Cancelled"],
        "Drafting Proposal":                 ["Proposal Requested", "Cancelled"],
        "Ready for Tech Review":             ["Drafting Proposal", "Proposal Requested", "Sizing Underway", "Cancelled"],
        "Tech Reviewing":                    ["Ready for Tech Review", "Cancelled"],
        "Ready for Client Approval":         ["Tech Reviewing", "Ready for Tech Review", "Drafting Proposal", "Sizing Underway", "Cancelled"],
        "In Client Approval":                ["Ready for Client Approval", "Cancelled"],
        "Ready for Final Approval":          ["Ready for Tech Review", "Cancelled"],
        "Final Approving":                   ["Ready for Final Approval", "Cancelled"],
        "Ready for Development":             ["In Client Approval", "Ready for Client Approval", "Tech Reviewing", "Prioritizing", "Cancelled"],
        "In Development":                    ["Ready for Development", "Cancelled"],
        "Dev Clarification Requested":       ["In Development", "Cancelled"],
        "Providing Dev Clarification":       ["Dev Clarification Requested", "Cancelled"],
        "Dev Blocked":                       ["In Development", "Cancelled"],
        "Back For Development":              ["Dev Clarification Requested", "In Development", "Cancelled"],
        "Ready for Scratch Test":            ["In Development", "Cancelled"],
        "Scratch Testing":                   ["Ready for Scratch Test", "Cancelled"],
        "Ready for QA":                      ["Scratch Testing", "Ready for Scratch Test", "In Development", "Cancelled"],
        "QA In Progress":                    ["Ready for QA", "Cancelled"],
        "Ready for Internal UAT":            ["QA In Progress", "Ready for QA", "Cancelled"],
        "Internal UAT":                      ["Ready for Internal UAT", "Cancelled"],
        "Ready for Client UAT":              ["Internal UAT", "Ready for Internal UAT", "QA In Progress", "Cancelled"],
        "In Client UAT":                     ["Ready for Client UAT", "Cancelled"],
        "Ready for UAT Sign-off":            ["In Client UAT", "Cancelled"],
        "Processing Sign-off":               ["Ready for UAT Sign-off", "Cancelled"],
        "Ready for Merge":                   ["Processing Sign-off", "Ready for UAT Sign-off", "In Client UAT", "Cancelled"],
        "Merging":                           ["Ready for Merge", "Cancelled"],
        "Ready for Deployment":              ["Merging", "Ready for Merge", "Processing Sign-off", "Cancelled"],
        "Deploying":                         ["Ready for Deployment", "Cancelled"],
        "Deployed to Prod":                  ["Deploying", "Ready for Deployment", "Cancelled"],
        "Done":                              ["Deployed to Prod", "Cancelled"],
        "Backlog":                           ["Cancelled"],
        "Cancelled":                         ["Backlog", "Ready for Sizing", "Ready for Development"] 
    };

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredTicket(result) {
        this.wiredTicketResult = result;
        const { data, error } = result;
        if (data) {
            this.ticket = data;
            this.evaluateState();
        } else if (error) {
            console.error('Error fetching ticket data', error);
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
        const stage = getFieldValue(this.ticket, STAGE_FIELD);
        this.currentStage = stage || '';
        const est = getFieldValue(this.ticket, ESTIMATED_HOURS_FIELD);
        const approved = getFieldValue(this.ticket, PRE_APPROVED_HOURS_FIELD);
        const dev = getFieldValue(this.ticket, DEVELOPER_FIELD);
        const criteria = getFieldValue(this.ticket, CRITERIA_FIELD);

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
        const phaseMap = {
            'Backlog': 'Phase 1 · Scoping', 'Scoping In Progress': 'Phase 1 · Scoping',
            'Clarification Requested (Pre-Dev)': 'Phase 1 · Scoping', 'Providing Clarification': 'Phase 1 · Scoping',
            'Ready for Sizing': 'Phase 2 · Estimation', 'Sizing Underway': 'Phase 2 · Estimation',
            'Ready for Prioritization': 'Phase 2 · Estimation', 'Prioritizing': 'Phase 2 · Estimation',
            'Proposal Requested': 'Phase 2 · Estimation', 'Drafting Proposal': 'Phase 2 · Estimation',
            'Ready for Tech Review': 'Phase 3 · Approval', 'Tech Reviewing': 'Phase 3 · Approval',
            'Ready for Client Approval': 'Phase 3 · Approval', 'In Client Approval': 'Phase 3 · Approval',
            'Ready for Final Approval': 'Phase 3 · Approval', 'Final Approving': 'Phase 3 · Approval',
            'Ready for Development': 'Phase 4 · Development', 'In Development': 'Phase 4 · Development',
            'Dev Clarification Requested': 'Phase 4 · Development', 'Providing Dev Clarification': 'Phase 4 · Development',
            'Dev Blocked': 'Phase 4 · Development', 'Back For Development': 'Phase 4 · Development',
            'Ready for Scratch Test': 'Phase 5 · Testing', 'Scratch Testing': 'Phase 5 · Testing',
            'Ready for QA': 'Phase 5 · Testing', 'QA In Progress': 'Phase 5 · Testing',
            'Ready for Internal UAT': 'Phase 5 · Testing', 'Internal UAT': 'Phase 5 · Testing',
            'Ready for Client UAT': 'Phase 6 · UAT', 'In Client UAT': 'Phase 6 · UAT',
            'Ready for UAT Sign-off': 'Phase 6 · UAT', 'Processing Sign-off': 'Phase 6 · UAT',
            'Ready for Merge': 'Phase 7 · Deployment', 'Merging': 'Phase 7 · Deployment',
            'Ready for Deployment': 'Phase 7 · Deployment', 'Deploying': 'Phase 7 · Deployment',
            'Deployed to Prod': 'Phase 7 · Deployment',
            'Done': 'Complete', 'Cancelled': 'Cancelled'
        };
        return phaseMap[this.currentStage] || '';
    }

    get stageBannerStyle() {
        const colorMap = {
            'Phase 1 · Scoping': '#6B7280',
            'Phase 2 · Estimation': '#D97706',
            'Phase 3 · Approval': '#2563EB',
            'Phase 4 · Development': '#EA580C',
            'Phase 5 · Testing': '#059669',
            'Phase 6 · UAT': '#7C3AED',
            'Phase 7 · Deployment': '#6D28D9',
            'Complete': '#15803D',
            'Cancelled': '#9CA3AF'
        };
        const phase = this.currentPhaseLabel;
        const color = colorMap[phase] || '#6B7280';
        return `border-left: 4px solid ${color}; background: ${color}18;`;
    }

    handleFixSuccess() {
        this.processing = true;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Ticket requirements updated.',
                variant: 'success'
            })
        );
        // Refresh the wire to re-evaluate gates immediately
        refreshApex(this.wiredTicketResult).then(() => {
            this.processing = false;
        });
    }

    async handleMove(event) {
        const targetStage = event.target.dataset.stage;
        this.processing = true;

        try {
            await updateTicketStage({ 
                ticketId: this.recordId, 
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
            await refreshApex(this.wiredTicketResult);

        } catch (error) {
            console.error('Move failed', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error moving ticket',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                })
            );
        } finally {
            this.processing = false;
        }
    }
}