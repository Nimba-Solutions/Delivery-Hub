/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import STAGE_FIELD from '@salesforce/schema/WorkItem__c.StageNamePk__c';

// Phase definitions — order matters: index = visual position
const PHASES = [
    {
        index: 0,
        label: 'Scoping',
        color: '#6B7280',
        stages: [
            'Backlog', 'Scoping In Progress',
            'Clarification Requested (Pre-Dev)', 'Providing Clarification'
        ]
    },
    {
        index: 1,
        label: 'Estimation',
        color: '#D97706',
        stages: [
            'Ready for Sizing', 'Sizing Underway',
            'Ready for Prioritization', 'Prioritizing',
            'Proposal Requested', 'Drafting Proposal'
        ]
    },
    {
        index: 2,
        label: 'Approval',
        color: '#2563EB',
        stages: [
            'Ready for Tech Review', 'Tech Reviewing',
            'Ready for Client Approval', 'In Client Approval',
            'Ready for Final Approval', 'Final Approving'
        ]
    },
    {
        index: 3,
        label: 'Development',
        color: '#EA580C',
        stages: [
            'Ready for Development', 'In Development',
            'Dev Clarification Requested', 'Providing Dev Clarification',
            'Dev Blocked', 'Back For Development'
        ]
    },
    {
        index: 4,
        label: 'Testing',
        color: '#059669',
        stages: [
            'Ready for Scratch Test', 'Scratch Testing',
            'Ready for QA', 'QA In Progress',
            'Ready for Internal UAT', 'Internal UAT'
        ]
    },
    {
        index: 5,
        label: 'UAT',
        color: '#7C3AED',
        stages: [
            'Ready for Client UAT', 'In Client UAT',
            'Ready for UAT Sign-off', 'Processing Sign-off'
        ]
    },
    {
        index: 6,
        label: 'Deployment',
        color: '#4F46E5',
        stages: [
            'Ready for Merge', 'Merging',
            'Ready for Deployment', 'Deploying', 'Deployed to Prod'
        ]
    }
];

const DONE_CONNECTOR_COLOR = '#94A3B8';

export default class DeliveryWorkItemProgress extends LightningElement {
    @api recordId;

    wiredWorkItem;

    @wire(getRecord, { recordId: '$recordId', fields: [STAGE_FIELD] })
    wiredWorkItemHandler(result) {
        this.wiredWorkItem = result;
    }

    get currentStageName() {
        return getFieldValue(this.wiredWorkItem && this.wiredWorkItem.data, STAGE_FIELD) || '';
    }

    get isCancelled() {
        return this.currentStageName === 'Cancelled';
    }

    get isDone() {
        return this.currentStageName === 'Done';
    }

    get rootClass() {
        let cls = 'tp-root';
        if (this.isCancelled) cls += ' tp-root--cancelled';
        if (this.isDone) cls += ' tp-root--done';
        return cls;
    }

    get currentPhaseIndex() {
        if (this.isDone) return PHASES.length; // all phases completed
        const stage = this.currentStageName;
        for (let i = 0; i < PHASES.length; i++) {
            if (PHASES[i].stages.includes(stage)) return i;
        }
        return 0; // default to first phase if stage unknown
    }

    get phases() {
        const currentIdx = this.currentPhaseIndex;
        const last = PHASES.length - 1;

        return PHASES.map((p) => {
            const i = p.index;
            const isCompleted = i < currentIdx;
            const isCurrent   = i === currentIdx && !this.isDone;
            const isFuture    = !isCompleted && !isCurrent;

            // Dot inline style
            let dotStyle = '';
            if (isCompleted) {
                dotStyle = `background:${p.color};`;
            } else if (isCurrent) {
                dotStyle = `background:${p.color}; box-shadow:0 0 0 3px ${p.color}30, 0 0 0 6px ${p.color}12;`;
            }

            // Inner pip for current dot
            const pipStyle = `background:${p.color}; opacity:0.4;`;

            // Connector: colored when the span it covers is "done"
            //   left connector of phase i = the line between i-1 and i
            //   it's done when we've reached or passed phase i  (currentIdx >= i)
            const leftDone = i > 0 && currentIdx >= i;
            const rightDone = i < last && currentIdx > i;

            const connLeftClass  = `tp-conn${i === 0    ? ' tp-conn--hidden' : ''}${leftDone  ? ' tp-conn--done' : ''}`;
            const connRightClass = `tp-conn${i === last  ? ' tp-conn--hidden' : ''}${rightDone ? ' tp-conn--done' : ''}`;
            const connStyle = leftDone || rightDone ? `background:${DONE_CONNECTOR_COLOR};` : '';

            // Phase name label color
            const labelStyle = isCurrent ? `color:${p.color}; font-weight:700;` : '';

            // Stage chip style
            const chipStyle = `background:${p.color}14; color:${p.color}; border:1px solid ${p.color}35;`;

            return {
                ...p,
                isCompleted,
                isCurrent,
                isFuture,
                dotClass:       `tp-dot${isCompleted ? ' tp-dot--done' : isCurrent ? ' tp-dot--current' : ' tp-dot--future'}`,
                dotStyle,
                pipStyle,
                connLeftClass,
                connRightClass,
                connStyle,
                wrapClass:      `tp-phase-wrap${isCurrent ? ' is-current' : ''}${isCompleted ? ' is-done' : ''}`,
                labelStyle,
                chipStyle
            };
        });
    }
}
