import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { updateRecord } from 'lightning/uiRecordApi';
import getTickets from '@salesforce/apex/DH_TicketController.getTickets';
import STAGE_FIELD from '@salesforce/schema/DH_Ticket__c.StageNamePk__c';
import ID_FIELD from '@salesforce/schema/DH_Ticket__c.Id';
import getTicketETAs from '@salesforce/apex/DH_TicketETAService.getTicketETAs';



export default class DragAndDropLwc extends NavigationMixin(LightningElement) {
    @track persona = 'Client';
    @track sizeMode = 'equalSized';
    @track displayMode = 'kanban';
    @track showModal = false;
    @track selectedRecord = null;
    @track selectedStage = null;
    @track realRecords = [];
    @track moveComment = '';
    @track recentComments = [];
    @track numDevs = 2; // Default to 2 devs, or whatever you want
    @track etaResults = [];

    statusColorMap = {
        'Backlog': '#FAFAFA',
        'Active Scoping': '#FFE082',
        'Client Clarification (Pre-Dev)': '#FFD54F',
        'Pending Client Approval': '#FFE0B2',
        'Client Clarification (In-Dev)': '#FFB300',
        'Needs Dev Feedback (T-Shirt Sizing)': '#FFD180',
        'Needs Dev Feedback (Proposal)': '#FFD180',
        'Pending Development Approval': '#B2DFDB',
        'Ready for Development': '#E1BEE7',
        'In Development': '#BBDEFB',
        'Dev Blocked': '#FF5252',
        'Back For Development': '#FFD180',
        'Dev Complete': '#A5D6A7',
        'Ready for Scratch Org Test': '#B2DFDB',
        'Ready for QA': '#64B5F6',
        'In QA': '#1976D2',
        'Ready for UAT (Consultant)': '#4FC3F7',
        'Ready for UAT (Client)': '#00BFAE',
        'Ready for Feature Merge': '#00897B',
        'Ready for Deployment': '#43A047',
        'Deployed to Prod': '#388E3C',
        'Done': '#263238',
        'Cancelled': '#BDBDBD'
    };

    personaColumnStatusMap = {
        Client: {
            'Backlog': ['Backlog'],
            'Active Scoping': ['Active Scoping'],
            'Client Clarification (Pre-Dev)': ['Client Clarification (Pre-Dev)'],
            'Pending Client Approval': ['Pending Client Approval'],
            'Client Clarification (In-Dev)': ['Client Clarification (In-Dev)'],
            'In Development': ['In Development', 'Dev Blocked', 'Back For Development', 'Dev Complete'],
            'In Review': ['Ready for Scratch Org Test', 'Ready for QA', 'In QA'],
            'Ready for UAT (Client)': ['Ready for UAT (Client)'],
            'Deployed to Prod': ['Deployed to Prod']
        },
        Consultant: {
            'Incoming': ['Active Scoping', 'Client Clarification (Pre-Dev)', 'Pending Client Approval'],
            'Needs Dev Feedback (T-Shirt Sizing)': ['Needs Dev Feedback (T-Shirt Sizing)'],
            'Pending Development Approval': ['Pending Development Approval'],
            'In Development': ['In Development', 'Dev Blocked', 'Back For Development', 'Dev Complete'],
            'In Review': ['Ready for Scratch Org Test', 'Ready for QA', 'In QA'],
            'Ready for UAT Approval': ['Ready for UAT (Consultant)'],
            'Ready for Feature Merge': ['Ready for Feature Merge'],
            'Ready for Deployment': ['Ready for Deployment'],
            'Done': ['Done']
        },
        Developer: {
            'Incoming': ['Pending Client Approval'],
            'Needs Dev Feedback (Proposal)': ['Needs Dev Feedback (Proposal)'],
            'Ready for Development': ['Ready for Development'],
            'In Development': ['In Development'],
            'Dev Blocked': ['Dev Blocked'],
            'Dev Complete': ['Dev Complete'],
            'Back For Development': ['Back For Development']
        },
        QA: {
            'Incoming': ['In Development', 'Dev Blocked', 'Back For Development', 'Dev Complete'],
            'Ready for Scratch Org Test': ['Ready for Scratch Org Test'],
            'Ready for QA': ['Ready for QA'],
            'In QA': ['In QA'],
            'In UAT': ['Ready for UAT (Consultant)', 'Ready for UAT (Client)']
        }
    };

    transitionMap = {
        'Backlog': ['Active Scoping'],
        'Active Scoping': ['Client Clarification (Pre-Dev)', 'Needs Dev Feedback (T-Shirt Sizing)', 'Needs Dev Feedback (Proposal)', 'Pending Development Approval'],
        'Client Clarification (Pre-Dev)': ['Pending Client Approval', 'Pending Development Approval'],
        'Needs Dev Feedback (T-Shirt Sizing)': ['Client Clarification (Pre-Dev)', 'Pending Client Approval', 'Pending Development Approval'],
        'Needs Dev Feedback (Proposal)': ['Pending Development Approval'],
        'Pending Development Approval': ['Ready for Development', 'Pending Client Approval'],
        'Pending Client Approval': ['Ready for Development'],
        'Ready for Development': ['In Development'],
        'In Development': ['Dev Complete', 'Dev Blocked', 'Client Clarification (In-Dev)'],
        'Dev Blocked': ['In Development', 'Client Clarification (In-Dev)', 'Pending Development Approval'],
        'Client Clarification (In-Dev)': ['Back For Development', 'Dev Blocked', 'Pending Development Approval'],
        'Back For Development': ['In Development'],
        'Dev Complete': ['Ready for Scratch Org Test', 'Ready for QA', 'Ready for UAT (Consultant)', 'Ready for UAT (Client)'],
        'Ready for Scratch Org Test': ['Ready for QA'],
        'Ready for QA': ['In QA'],
        'In QA': ['Ready for UAT (Consultant)', 'Ready for UAT (Client)', 'Dev Complete'],
        'Ready for UAT (Consultant)': ['Ready for UAT (Client)'],
        'Ready for UAT (Client)': ['Ready for Feature Merge'],
        'Ready for Feature Merge': ['Ready for Deployment'],
        'Ready for Deployment': ['Deployed to Prod'],
        'Deployed to Prod': ['Done'],
        'Done': [],
        'Cancelled': ['Backlog']
    };


    backtrackMap = {
    'Active Scoping': ['Backlog', 'Cancelled'],
    'Client Clarification (Pre-Dev)': ['Active Scoping', 'Cancelled'],
    'Needs Dev Feedback (T-Shirt Sizing)': ['Active Scoping', 'Backlog', 'Cancelled'],
    'Needs Dev Feedback (Proposal)': ['Active Scoping', 'Backlog', 'Cancelled'],
    'Pending Development Approval': ['Needs Dev Feedback (Proposal)', 'Client Clarification (Pre-Dev)'],
    'Pending Client Approval': ['Active Scoping', 'Client Clarification (Pre-Dev)', 'Needs Dev Feedback (T-Shirt Sizing)', 'Needs Dev Feedback (Proposal)', 'Cancelled'],
    'Ready for Development': ['Pending Development Approval', 'Pending Client Approval', 'Cancelled'],
    'In Development': ['Ready for Development', 'Back For Development','Client Clarification (In-Dev)', 'Cancelled'],
    'Dev Blocked': ['In Development', 'Ready for Development', 'Pending Development Approval', 'Cancelled'],
    'Client Clarification (In-Dev)': ['Dev Blocked', 'In Development', 'Back For Development', 'Cancelled'],
    'Back For Development': ['Client Clarification (In-Dev)', 'Dev Blocked', 'In Development', 'Cancelled'],
    'Dev Complete': ['In Development', 'Dev Blocked', 'Back For Development', 'Cancelled'],
    'Ready for Scratch Org Test': ['Dev Complete', 'In Development', 'Cancelled'],
    'Ready for QA': ['Ready for Scratch Org Test', 'Dev Complete', 'Cancelled'],
    'In QA': ['Ready for QA', 'Ready for Scratch Org Test', 'Cancelled'],
    'Ready for UAT (Consultant)': ['In QA', 'Ready for QA', 'Cancelled'],
    'Ready for UAT (Client)': ['Ready for UAT (Consultant)', 'In QA', 'Cancelled'],
    'Ready for Feature Merge': ['Ready for UAT (Client)', 'Ready for UAT (Consultant)', 'Cancelled'],
    'Ready for Deployment': ['Ready for Feature Merge', 'Ready for UAT (Client)', 'Cancelled'],
    'Deployed to Prod': ['Ready for Deployment', 'Ready for Feature Merge', 'Cancelled'],
    'Done': ['Deployed to Prod', 'Ready for Deployment', 'Cancelled'],
    'Backlog': [],
    'Cancelled': []
    };


    // ----------- ADVANCE/BACKTRACK BUTTON OVERRIDES -------------
    personaAdvanceOverrides = {
        Client: {
            'Backlog': {
                'Active Scoping': { icon: '🚀', label: 'Active Scoping', style: 'background:#38c172;color:#fff;' }
            },
            'Active Scoping': {
                'Client Clarification (Pre-Dev)': { icon: '💬', label: 'Clarification (Pre-Dev)', style: 'background:#fbcb43;color:#2d2d2d;' },
                'Needs Dev Feedback (T-Shirt Sizing)': { icon: '📝', label: 'Dev Feedback (Sizing)', style: 'background:#ffe082;color:#005fb2;' },
                'Needs Dev Feedback (Proposal)': { icon: '📝', label: 'Dev Feedback (Proposal)', style: 'background:#ffe082;color:#005fb2;' },
                'Pending Development Approval': { icon: '🛠️', label: 'Pending Dev Approval', style: 'background:#b2dfdb;color:#005fb2;' }
            }
            // ...Add more as needed...
        },
        Consultant: {
            'Needs Dev Feedback (T-Shirt Sizing)': {
                'Client Clarification (Pre-Dev)': { icon: '🗨️', label: 'Client Clarification (Pre-Dev)', style: 'background:#ffd54f;' },
                'Pending Client Approval': { icon: '✅', label: 'Pending Client Approval', style: 'background:#38c172;color:#fff;' }
            }
            // ...etc.
        }
        // ...Add for other personas as needed...
    };

    personaBacktrackOverrides = {
        Client: {
            'Backlog': {
                'Cancelled': { icon: '🛑', label: 'Cancelled', style: 'background:#ef4444;color:#fff;' }
            },
            'Active Scoping': {
                'Backlog': { icon: '↩️', label: 'Backlog', style: 'background:#ffa726;color:#222;' },
                'Cancelled': { icon: '🛑', label: 'Cancelled', style: 'background:#ef4444;color:#fff;' }
            }
            // ...Add more as needed...
        },
        Consultant: {
            'Needs Dev Feedback (T-Shirt Sizing)': {
                'Cancelled': { icon: '🛑', label: 'Cancelled', style: 'background:#ef4444;color:#fff;' },
                'Backlog': { icon: '↩️', label: 'Backlog', style: 'background:#ffa726;color:#222;' },
                'Active Scoping': { icon: '🔙', label: 'Active Scoping', style: 'background:#ffe082;color:#333;' }
            }
            // ...etc.
        }
        // ...Add for other personas as needed...
    };

    @wire(getTickets)
    wiredTickets({ error, data }) {
        if (data) {
            this.realRecords = data;
            this.loadETAs(); // Will refresh etaResults
            // Try forcing LWC to refresh rendering:
            this.realRecords = [...data]; // This helps trigger reactivity
        }
    }


    get personaOptions() {
        return Object.keys(this.personaColumnStatusMap).map(p => ({ label: p, value: p }));
    }
    get sizeModeOptions() {
        return [
            { label: 'Equal Sized', value: 'equalSized' },
            { label: 'Ticket Sized', value: 'ticketSize' }
        ];
    }
    get hasRecentComments() {
        return (this.recentComments || []).length > 0;
    }
    get displayModeOptions() {
        return [
            { label: 'Kanban', value: 'kanban' },
            { label: 'Compact', value: 'compact' },
            { label: 'Table', value: 'table' }
        ];
    }
    get mainBoardClass() {
        if (this.displayMode === 'table') return 'table-board';
        if (this.displayMode === 'compact') return 'stage-columns compact';
        return 'stage-columns';
    }
    get isTableMode() {
        return this.displayMode === 'table';
    }

    get enrichedTickets() {
        const norm = id => (id || '').substring(0, 15);

        const etaMap = new Map(
            (this.etaResults || [])
                .filter(dto => !!dto.ticketId)
                .map(dto => [norm(dto.ticketId), dto])
        );

        return (this.realRecords || []).map(rec => {
            const etaDto = etaMap.get(norm(rec.Id));
            if (!etaDto) {
                console.warn('⚠️ No ETA found for', rec.Name || rec.Id, norm(rec.Id));
            }
            return {
                ...rec,
                calculatedETA: etaDto && etaDto.calculatedETA
                    ? new Date(etaDto.calculatedETA).toLocaleDateString()
                    : '—'
            };
        });
    }



    get stageColumns() {
        const personaColumns = this.personaColumnStatusMap[this.persona] || {};
        return Object.keys(personaColumns).map(colName => {
            const groupedStatuses = personaColumns[colName];
            return {
                stage: colName,
                tickets: (this.enrichedTickets || [])
                    .filter(r => groupedStatuses.includes(r.StageNamePk__c))
                    .map(r => ({
                        ...r,
                        cardColor: this.statusColorMap[r.StageNamePk__c] || '#eee'
                    }))
            };
        });
    }


    get advanceOptions() {
        if (!this.selectedRecord) return [];
        const stage = this.selectedRecord.StageNamePk__c;
        const persona = this.persona;
        const nextStages = this.transitionMap[stage] || [];
        let opts = nextStages
            .filter(target => target !== stage)
            .map(target => {
                const override = this.personaAdvanceOverrides?.[persona]?.[stage]?.[target] || {};
                let defaultIcon = '➡️';
                let defaultStyle = 'background:#e6f3ff;color:#222;';
                if (target === 'Active Scoping') { defaultIcon = '🚀'; defaultStyle = 'background:#38c172;color:#fff;'; }
                if (target === 'Cancelled') { defaultIcon = '🛑'; defaultStyle = 'background:#ef4444;color:#fff;'; }
                return {
                    value: target,
                    label: override.label || target,
                    icon: override.icon || defaultIcon,
                    style: override.style || defaultStyle,
                    autofocus: override.autofocus || false
                };
            });
        return opts;
    }

    get backtrackOptions() {
        if (!this.selectedRecord) return [];
        const stage = this.selectedRecord.StageNamePk__c;
        const persona = this.persona;
        let opts = [];
        // Prefer persona-specific overrides if present
        if (this.personaBacktrackOverrides?.[persona]?.[stage]) {
            const custom = this.personaBacktrackOverrides[persona][stage];
            opts = Object.keys(custom).map(target => {
                const override = custom[target];
                return {
                    value: target,
                    label: override.label || target,
                    icon: override.icon || '🔙',
                    style: override.style || '',
                };
            });
        } else {
            // Use backtrack map if no overrides
            const prevStages = this.backtrackMap[stage] || [];
            opts = prevStages.map(target => ({
                value: target,
                label: target,
                icon: '⬅️',
                style: target === 'Cancelled' ? 'background:#ef4444;color:#fff;' : ''
            }));
        }
        return opts;
    }

    handleNumDevsChange(e) {
        this.numDevs = parseInt(e.target.value, 10) || 1;
        this.loadETAs();
        console.log('here');
    }

    loadETAs() {
        getTicketETAs({ numberOfDevs: this.numDevs })
            .then(data => {
                // Track-reactive copy for Lightning
                this.etaResults = [...data];

                /* ①  VERIFY WHAT APEX RETURNED */
                console.log('①  ETA DTOs from Apex');
                console.table(this.etaResults.map(d => ({
                    dtoId : d.ticketId,
                    eta   : d.calculatedETA
                })));
            })
            .catch(err => {
                this.etaResults = [];
                console.error('ETA error:', err);
            });
    }






    getTicketETA(ticketId) {
        return (this.etaResults || []).find(e => e.ticketId === ticketId) || {};
    }

    handlePersonaChange(e) {
        this.persona = e.detail ? e.detail.value : e.target.value;
    }
    handleSizeModeChange(e) {
        this.sizeMode = e.detail ? e.detail.value : e.target.value;
    }
    handleDisplayModeChange(e) {
        this.displayMode = e.detail ? e.detail.value : e.target.value;
    }
    handleTitleClick(e) {
        const id = e.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: id,
                objectApiName: 'DH_Ticket__c',
                actionName: 'view'
            }
        });
    }
    handleCardClick(e) {
        const id = e.currentTarget?.dataset?.id || e.target?.dataset?.id;
        this.selectedRecord = (this.realRecords || []).find(r => r.Id === id);
        this.selectedStage = null;
        this.showModal = true;
        this.moveComment = '';
    }
    handleAdvanceOption(e) {
        const newStage = e.target.dataset.value;
        this.selectedStage = newStage;
        this.handleSaveTransition();
    }
    handleBacktrackOption(e) {
        const newStage = e.target.dataset.value;
        this.selectedStage = newStage;
        this.handleSaveTransition();
    }
    handleStageChange(e) {
        this.selectedStage = e.detail ? e.detail.value : e.target.value;
    }
    handleCommentChange(e) {
        this.moveComment = e.detail ? e.detail.value : e.target.value;
    }
    handleSaveTransition() {
        const rec = this.selectedRecord;
        const newStage = this.selectedStage;
        if (rec && newStage) {
            const fields = {};
            fields[ID_FIELD.fieldApiName] = rec.Id;
            fields[STAGE_FIELD.fieldApiName] = newStage;
            updateRecord({ fields })
                .then(() => {
                    this.realRecords = this.realRecords.map(r =>
                        r.Id === rec.Id
                            ? { ...r, StageNamePk__c: newStage }
                            : r
                    );
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
        this.moveComment = '';
    }
}