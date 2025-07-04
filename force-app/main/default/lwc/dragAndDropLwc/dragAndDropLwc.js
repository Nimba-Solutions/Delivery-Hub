import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { updateRecord } from 'lightning/uiRecordApi';
import getTickets from '@salesforce/apex/DH_TicketController.getTickets';
import STAGE_FIELD from '@salesforce/schema/DH_Ticket__c.StageNamePk__c';
import ID_FIELD    from '@salesforce/schema/DH_Ticket__c.Id';

export default class DragAndDropLwc extends NavigationMixin(LightningElement) {
    @track persona = 'Client';
    @track sizeMode = 'equalSized';
    @track showReal = true;
    @track showModal = false;
    @track selectedRecord = null;
    @track selectedStage = null;

    @track dummyRecords = [
        { Id: '1', StageNamePk__c: 'Backlog',        BriefDescriptionTxt__c: 'Alpha summary', DeveloperDaysSizeNumber__c: 2.5, CalculatedETADate__c: '2025-07-10' },
        { Id: '2', StageNamePk__c: 'Active Scoping', BriefDescriptionTxt__c: 'Beta scope',    DeveloperDaysSizeNumber__c: 3.0, CalculatedETADate__c: '2025-07-11' },
        { Id: '3', StageNamePk__c: 'Dev Complete',   BriefDescriptionTxt__c: 'Gamma done',    DeveloperDaysSizeNumber__c: 1.75, CalculatedETADate__c: '2025-07-09' },
        { Id: '4', StageNamePk__c: 'Done',           BriefDescriptionTxt__c: 'Delta final',   DeveloperDaysSizeNumber__c: 4.0, CalculatedETADate__c: '2025-07-08' }
    ];

    @track realRecords = [];
    @track records     = [];

    personaStatuses = {
        Client: [
            'Backlog',
            'Active Scoping',
            'Client Clarification (Pre-Dev)',
            'Pending Client Approval',
            'Client Clarification (In-Dev)',
            'Ready for UAT (Client)',
            'Deployed to Prod'
        ],
        Consultant: [
            'Needs Dev Feedback (T-Shirt Sizing)',
            'Pending Development Approval',
            'Ready for UAT Approval',
            'Ready for Feature Merge',
            'Ready for Deployment',
            'Done'
        ],
        Developer: [
            'Needs Dev Feedback (Proposal)',
            'Ready for Development',
            'In Development',
            'Dev Blocked',
            'Dev Complete',
            'Back For Development'
        ],
        QA: [
            'Ready for Scratch Org Test',
            'Ready for QA',
            'In QA',
            'In UAT'
        ]
    };

    @wire(getTickets)
    wiredTickets({ error, data }) {
        if (data) {
            this.realRecords = data;
            this.mergeRecords();
        }
    }

    connectedCallback() {
        this.records = [...this.dummyRecords];
    }

    toggleDataSource() {
        this.showReal = !this.showReal;
        this.mergeRecords();
    }

    mergeRecords() {
        if (this.showReal && this.realRecords.length) {
            const realIds = new Set(this.realRecords.map(r => r.Id));
            const filteredDummy = this.dummyRecords.filter(d => !realIds.has(d.Id));
            this.records = [...filteredDummy, ...this.realRecords];
        } else {
            this.records = [...this.dummyRecords];
        }
    }

    get toggleButtonLabel() {
        return this.showReal ? 'Use Dummy Data' : 'Use Real Data';
    }

    get personaOptions() {
        return Object.keys(this.personaStatuses).map(p => ({ label: p, value: p }));
    }
    get sizeModeOptions() {
        return [
            { label: 'Equal Sized', value: 'equalSized' },
            { label: 'Ticket Sized', value: 'ticketSize' }
        ];
    }
    get showSizeMode() {
        return true;
    }

    get stageColumns() {
        const visible = this.personaStatuses[this.persona] || [];
        return visible.map(stage => ({
            stage,
            tickets: this.records.filter(r => r.StageNamePk__c === stage)
        }));
    }

    get calcWidth() {
        const count = (this.personaStatuses[this.persona] || []).length || 1;
        return `width: calc(100vw / ${count})`;
    }

    get validTransitionOptions() {
        const next = this.selectedRecord
            ? this.transitionMap[this.selectedRecord.StageNamePk__c] || []
            : [];
        return next.map(s => ({ label: s, value: s }));
    }
    get isSaveDisabled() {
        return !this.selectedStage;
    }

    handlePersonaChange(e) {
        this.persona = e.detail.value;
    }
    handleSizeModeChange(e) {
        this.sizeMode = e.detail.value;
    }

    handleNavigate(e) {
        e.stopPropagation();
        e.preventDefault();
        const recId = e.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recId,
                objectApiName: 'DH_Ticket__c',
                actionName: 'view'
            }
        });
    }

    handleCardClick(e) {
        const id = e.currentTarget.dataset.id;
        this.selectedRecord = this.records.find(r => r.Id === id);
        this.selectedStage = null;
        this.showModal = true;
    }

    handleStageChange(e) {
        this.selectedStage = e.detail.value;
    }

    handleSaveTransition() {
        const rec = this.selectedRecord;
        const newStage = this.selectedStage;
        if (rec && newStage) {
            const fields = {};
            fields[ID_FIELD.fieldApiName]    = rec.Id;
            fields[STAGE_FIELD.fieldApiName] = newStage;

            updateRecord({ fields })
                .then(() => {
                    // update our realRecords array
                    this.realRecords = this.realRecords.map(r =>
                        r.Id === rec.Id
                            ? { ...r, StageNamePk__c: newStage }
                            : r
                    );
                    // re‐merge so the card shows in the new column
                    this.mergeRecords();
                })
                .catch(error => {
                    console.error('Error updating ticket stage:', error);
                });
        }
        this.closeModal();
    }

    handleCancelTransition() {
        this.closeModal();
    }

    closeModal() {
        this.showModal = false;
        this.selectedRecord = null;
        this.selectedStage = null;
    }

    transitionMap = {
        'Backlog': ['Active Scoping', 'Cancelled'],
        'Active Scoping': ['Backlog', 'Client Clarification (Pre-Dev)', 'Needs Dev Feedback (T-Shirt Sizing)', 'Needs Dev Feedback (Proposal)', 'Cancelled'],
        'Client Clarification (Pre-Dev)': ['Active Scoping', 'Pending Development Approval', 'Cancelled'],
        'Needs Dev Feedback (T-Shirt Sizing)': ['Active Scoping', 'Pending Development Approval', 'Cancelled'],
        'Needs Dev Feedback (Proposal)': ['Active Scoping', 'Pending Development Approval', 'Cancelled'],
        'Pending Development Approval': ['Pending Client Approval', 'Ready for Development', 'Cancelled'],
        'Pending Client Approval': ['Ready for Development', 'Cancelled'],
        'Ready for Development': ['In Development', 'Client Clarification (Pre-Dev)', 'Cancelled'],
        'In Development': ['Dev Blocked', 'Dev Complete', 'Client Clarification (In-Dev)'],
        'Dev Blocked': ['In Development', 'Client Clarification (In-Dev)', 'Pending Development Approval', 'Cancelled'],
        'Client Clarification (In-Dev)': ['Back For Development', 'Dev Blocked', 'Pending Development Approval', 'Cancelled'],
        'Back For Development': ['In Development', 'Cancelled'],
        'Dev Complete': ['Ready for Scratch Org Test', 'Cancelled'],
        'Ready for Scratch Org Test': ['Ready for QA', 'Cancelled'],
        'Ready for QA': ['In QA', 'Cancelled'],
        'In QA': ['Ready for UAT (Consultant)', 'Dev Complete', 'Cancelled'],
        'Ready for UAT (Consultant)': ['Ready for UAT (Client)', 'Cancelled'],
        'Ready for UAT (Client)': ['Ready for UAT Approval', 'Client Clarification (In-Dev)', 'Cancelled'],
        'Ready for UAT Approval': ['Ready for Feature Merge', 'Cancelled'],
        'Ready for Feature Merge': ['Ready for Deployment', 'Cancelled'],
        'Ready for Deployment': ['Deployed to Prod', 'Cancelled'],
        'Deployed to Prod': ['Done', 'Cancelled'],
        'Done': [],
        'Cancelled': []
    };
}