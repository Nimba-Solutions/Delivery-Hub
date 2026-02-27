/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import STAGE_FIELD from '@salesforce/schema/WorkItem__c.StageNamePk__c';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';

const DONE_CONNECTOR_COLOR = '#94A3B8';

export default class DeliveryWorkItemProgress extends LightningElement {
    @api recordId;

    wiredWorkItem;
    _workflowConfig = null;

    @wire(getWorkflowConfig, { workflowTypeName: 'Software_Delivery' })
    wiredConfig({ data, error }) {
        if (data) {
            this._workflowConfig = data;
        } else if (error) {
            console.error('[WorkItemProgress] getWorkflowConfig error:', error);
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [STAGE_FIELD] })
    wiredWorkItemHandler(result) {
        this.wiredWorkItem = result;
    }

    /**
     * Derives phase data from CMT stages by grouping non-terminal stages by phase.
     * Each phase gets the headerBgColor from its first stage.
     */
    get _phaseData() {
        if (!this._workflowConfig?.stages) return [];
        const phaseMap = new Map();
        this._workflowConfig.stages.forEach(s => {
            if (s.isTerminal) return; // Exclude Done/Cancelled from progress track
            if (!phaseMap.has(s.phase)) {
                phaseMap.set(s.phase, {
                    label: s.phase,
                    color: s.headerBgColor || '#6B7280',
                    stages: []
                });
            }
            phaseMap.get(s.phase).stages.push(s.apiValue);
        });
        // Assign index based on insertion order
        let idx = 0;
        const result = [];
        for (const phase of phaseMap.values()) {
            result.push({ ...phase, index: idx++ });
        }
        return result;
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
        const phaseData = this._phaseData;
        if (this.isDone) return phaseData.length; // all phases completed
        const stage = this.currentStageName;
        for (let i = 0; i < phaseData.length; i++) {
            if (phaseData[i].stages.includes(stage)) return i;
        }
        return 0;
    }

    get phases() {
        const phaseData = this._phaseData;
        if (!phaseData.length) return [];
        const currentIdx = this.currentPhaseIndex;
        const last = phaseData.length - 1;

        return phaseData.map((p) => {
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
