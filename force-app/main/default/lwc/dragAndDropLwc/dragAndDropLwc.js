import { LightningElement, track } from 'lwc';

export default class DragAndDropLwc extends LightningElement {
    @track persona = 'Client';
    @track records = [
        { Id: '1',  Name: 'Ticket Backlog',                    StageName: 'Backlog',                       AccountId: '001000000000001', AccountName: 'Acme Corp.',        Amount: 12000, CloseDate: '2025-09-01' },
        { Id: '2',  Name: 'Ticket Active Scoping',             StageName: 'Active Scoping',                AccountId: '001000000000002', AccountName: 'Beta LLC',         Amount: 8500,  CloseDate: '2025-09-02' },
        { Id: '3',  Name: 'Sizing Feedback Needed',            StageName: 'Needs Dev Feedback (T-Shirt Sizing)', AccountId: '001000000000003', AccountName: 'Gamma Co.',    Amount: 15000, CloseDate: '2025-09-03' },
        { Id: '4',  Name: 'Proposal Feedback Needed',          StageName: 'Needs Dev Feedback (Proposal)', AccountId: '001000000000004', AccountName: 'Delta Inc.',       Amount: 5000,  CloseDate: '2025-09-04' },
        { Id: '5',  Name: 'Clarify Pre-Dev',                   StageName: 'Client Clarification (Pre-Dev)',AccountId: '001000000000005', AccountName: 'Epsilon Ltd.',     Amount: 7000,  CloseDate: '2025-09-05' },
        { Id: '6',  Name: 'Awaiting Client Approval',          StageName: 'Pending Client Approval',       AccountId: '001000000000006', AccountName: 'Zeta Org.',        Amount: 9200,  CloseDate: '2025-09-06' },
        { Id: '7',  Name: 'Awaiting Dev Approval',             StageName: 'Pending Development Approval', AccountId: '001000000000007', AccountName: 'Eta Partners',     Amount: 11000, CloseDate: '2025-09-07' },
        { Id: '8',  Name: 'Ready to Build',                    StageName: 'Ready for Development',         AccountId: '001000000000008', AccountName: 'Theta LLC',        Amount: 13000, CloseDate: '2025-09-08' },
        { Id: '9',  Name: 'In Dev',                            StageName: 'In Development',                AccountId: '001000000000009', AccountName: 'Iota Systems',     Amount: 7800,  CloseDate: '2025-09-09' },
        { Id: '10', Name: 'Dev Blocked – Bug',                 StageName: 'Dev Blocked',                   AccountId: '001000000000010', AccountName: 'Kappa Tech',       Amount: 4400,  CloseDate: '2025-09-10' },
        { Id: '11', Name: 'In-Dev Clarification',              StageName: 'Client Clarification (In-Dev)',AccountId: '001000000000011', AccountName: 'Lambda Co.',       Amount: 6600,  CloseDate: '2025-09-11' },
        { Id: '12', Name: 'Back for Dev',                      StageName: 'Back For Development',          AccountId: '001000000000012', AccountName: 'Mu Enterprises',   Amount: 7800,  CloseDate: '2025-09-12' },
        { Id: '13', Name: 'Dev Complete',                      StageName: 'Dev Complete',                  AccountId: '001000000000013', AccountName: 'Nu Innovations',   Amount: 9800,  CloseDate: '2025-09-13' },
        { Id: '14', Name: 'Scratch Org Test',                  StageName: 'Ready for Scratch Org Test',    AccountId: '001000000000014', AccountName: 'Xi Solutions',     Amount: 12000, CloseDate: '2025-09-14' },
        { Id: '15', Name: 'QA Ready',                          StageName: 'Ready for QA',                  AccountId: '001000000000015', AccountName: 'Omicron Ltd.',     Amount: 5400,  CloseDate: '2025-09-15' },
        { Id: '16', Name: 'In QA',                             StageName: 'In QA',                         AccountId: '001000000000016', AccountName: 'Pi Works',         Amount: 6200,  CloseDate: '2025-09-16' },
        { Id: '17', Name: 'In UAT',                            StageName: 'In UAT',                        AccountId: '001000000000017', AccountName: 'Rho Group',        Amount: 8300,  CloseDate: '2025-09-17' },
        { Id: '18', Name: 'UAT Client',                        StageName: 'Ready for UAT (Client)',        AccountId: '001000000000018', AccountName: 'Sigma Services',   Amount: 7100,  CloseDate: '2025-09-18' },
        { Id: '19', Name: 'UAT Approval',                      StageName: 'Ready for UAT Approval',        AccountId: '001000000000019', AccountName: 'Tau Corp.',        Amount: 9400,  CloseDate: '2025-09-19' },
        { Id: '20', Name: 'Merge Prep',                        StageName: 'Ready for Feature Merge',       AccountId: '001000000000020', AccountName: 'Upsilon Inc.',     Amount: 10500, CloseDate: '2025-09-20' },
        { Id: '21', Name: 'Prod Deploy',                       StageName: 'Deployed to Prod',             AccountId: '001000000000021', AccountName: 'Phi Enterprises',  Amount: 16000, CloseDate: '2025-09-21' },
        { Id: '22', Name: 'Done and Dusted',                   StageName: 'Done',                         AccountId: '001000000000022', AccountName: 'Chi Technologies', Amount: 15000, CloseDate: '2025-09-22' }
    ];

    // Persona ⇒ allowed stages
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

    get personaOptions() {
        return Object.keys(this.personaStatuses).map(p => ({ label: p, value: p }));
    }

    // only show each persona’s columns
    get stageColumns() {
        const visible = this.personaStatuses[this.persona] || [];
        return visible.map(stage => ({
            stage,
            tickets: this.records.filter(r => r.StageName === stage)
        }));
    }

    // evenly divide width among visible columns
    get calcWidth() {
        const count = (this.personaStatuses[this.persona] || []).length;
        return `width: calc(100vw / ${count})`;
    }

    handlePersonaChange(e) {
        this.persona = e.detail.value;
    }

    // Next-status transitions
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

    @track showModal = false;
    @track selectedRecord = null;
    @track selectedStage = null;

    get validTransitions() {
        return this.selectedRecord
            ? this.transitionMap[this.selectedRecord.StageName] || []
            : [];
    }
    get validTransitionOptions() {
        return this.validTransitions.map(s => ({ label: s, value: s }));
    }
    get isSaveDisabled() {
        return this.selectedStage === null;
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
        if (this.selectedRecord && this.selectedStage) {
            this.records = this.records.map(r =>
                r.Id === this.selectedRecord.Id
                    ? { ...r, StageName: this.selectedStage }
                    : r
            );
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

    // drag-and-drop stub
    handleListItemDrag() {}
    handleItemDrop() {}
}