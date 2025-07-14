import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import { updateRecord } from 'lightning/uiRecordApi';
import getTickets from '@salesforce/apex/DH_TicketController.getTickets';
import STAGE_FIELD from '@salesforce/schema/DH_Ticket__c.StageNamePk__c';
import ID_FIELD from '@salesforce/schema/DH_Ticket__c.Id';
import getTicketETAsWithPriority from '@salesforce/apex/DH_TicketETAService.getTicketETAsWithPriority';
import updateTicketSortOrders from '@salesforce/apex/DH_TicketController.updateTicketSortOrders';
import isMarketingEnabled from '@salesforce/apex/DH_TicketController.isMarketingEnabled';


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
    @track showAllColumns = true;
    @track showCreateModal = false;
    @track nextSortOrder = 1;
    @track overallFilter = 'all';
    @track intentionFilter = 'all';
    ticketsWire;
    @track marketingEnabled = false;


    statusColorMap = {
        'Backlog': '#FAFAFA',
        'Active Scoping': '#FFE082',
        'Quick Estimate': '#FFD54F', // not a status but a column, see below!
        'Pending Client Prioritization': '#FFD54F', // YELLOW
        'Client Clarification (Pre-Dev)': '#FFD54F',
        'Pending Client Approval': '#FFE0B2',
        'Needs Dev Feedback (T-Shirt Sizing)': '#FFD180',
        'Needs Dev Feedback (Proposal)': '#FFD180',
        'Pending Development Approval': '#FFD54F', // now yellow, not blue
        'Ready for Development': '#FFD54F',
        'In Development': '#FF9100', // Orange
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

    // Custom header color logic for Client persona
    columnHeaderStyleMap = {
        // --- Client action columns ---
        'Backlog':                  { bg: '#2196F3', color: '#fff' }, // blue
        'Active Scoping':           { bg: '#2196F3', color: '#fff' }, // blue
        'Pending Client Prioritization': { bg: '#2196F3', color: '#fff' }, // blue
        'Pending Client Approval':  { bg: '#2196F3', color: '#fff' }, // blue
        'Client Clarification (Pre-Dev)':  { bg: '#2196F3', color: '#fff' }, // blue

        // --- Pre-dev/Dev columns (yellow, with black text) ---
        'Quick Estimate':           { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        'Proposal Needed':          { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        'Pending Development Approval': { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        'Client Clarification (In-Dev)': { bg: '#2196F3', color: '#fff' }, // force blue
        'Ready for Development':    { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        'In Development':           { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        'In Review':                { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        // --- Other columns: fallback to blue ---
        'Ready for UAT (Client)':   { bg: '#2196F3', color: '#fff' }, // blue
        'Deployed to Prod':         { bg: '#2196F3', color: '#fff' }, // blue
        'Done':                     { bg: '#607D8B', color: '#fff' },
        
        'Needs Dev Feedback (T-Shirt Sizing)':           { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        'Needs Dev Feedback (Proposal)':           { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        'Dev Complete':           { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        'Back For Development':           { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        'Ready for Scratch Org Test':           { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        'Ready for QA':           { bg: '#FFD54F', color: '#222' }, // yellow, dark text
        'Ready for UAT (Consultant)':           { bg: '#FFD54F', color: '#222' } // yellow, dark text
    };


    /** Who owns each status next **/
    statusOwnerMap = {
        // ── Client ─────────────────────────
        'Backlog': 'Client',
        'Active Scoping': 'Client',
        'Client Clarification (Pre-Dev)': 'Client',
        'Pending Client Prioritization': 'Client',
        'Pending Client Approval': 'Client',
        'Client Clarification (In-Dev)': 'Client',
        'Ready for UAT (Client)': 'Client',
        'Deployed to Prod': 'Client',
        'Done': 'Client',
        'Cancelled': 'Client',

        // ── Consultant / PM ────────────────
        'Pending Development Approval': 'Consultant',
        'Ready for UAT (Consultant)': 'Consultant',
        'Ready for Feature Merge': 'Consultant',
        'Ready for Deployment': 'Consultant',

        // ── Developer ──────────────────────
        'Needs Dev Feedback (T-Shirt Sizing)': 'Developer',
        'Needs Dev Feedback (Proposal)': 'Developer',
        'Ready for Development': 'Developer',
        'In Development': 'Developer',
        'Dev Blocked': 'Developer',
        'Back For Development': 'Developer',
        'Dev Complete': 'Developer',

        // ── QA ─────────────────────────────
        'Ready for Scratch Org Test': 'QA',
        'Ready for QA': 'QA',
        'In QA': 'QA'
    };

    /** Color palette per persona **/
    ownerColorMap = {
        Client:     '#2196F3',   // blue
        Consultant: '#FFD600',   // yellow
        Developer:  '#FF9100',   // orange
        QA:         '#00C853',   // green
        Default:    '#BDBDBD'    // grey fallback
    };

    columnDisplayNames = {
        'Backlog': 'Backlog',
        'Active Scoping': 'Active Scoping',
        'Quick Estimate': 'Ready for Estimate',
        'Pending Client Prioritization': 'Client Prioritization / Feedback', // <-- NEW LABEL!
        'Proposal Needed': 'Approved for Analysis',
        'Pending Client Approval': 'Pending Client Approval',
        'Ready for Development': 'Approved for Development',
        'Client Clarification (In-Dev)': 'Client Clarification (In-Dev)',
        'In Development': 'In Development',
        'In Review': 'In Review',
        'Ready for UAT (Client)': 'Ready for UAT (Client)',
        'Deployed to Prod': 'Deployed to Prod',
        'Done': 'Done'
        // ... (add other columns if you want custom labels)
    };


    personaColumnStatusMap = {
        Client: {
            'Backlog': ['Backlog'],
            'Active Scoping': ['Active Scoping'],
            'Quick Estimate': ['Needs Dev Feedback (T-Shirt Sizing)'],
            'Pending Client Prioritization': [
            'Client Clarification (Pre-Dev)',      // <-- Add here!
            'Pending Client Prioritization'
            ],
            'Proposal Needed': ['Needs Dev Feedback (Proposal)','Pending Development Approval'],
            'Pending Client Approval': ['Pending Client Approval'],
            'Ready for Development': [
                'Ready for Development'
            ],
            'Client Clarification (In-Dev)': ['Client Clarification (In-Dev)'],
            'In Development': [
            'In Development',
            'Dev Blocked',
            'Back For Development',
            'Dev Complete'
            ],
            'In Review': [
            'Ready for Scratch Org Test',
            'Ready for QA',
            'In QA',
            'Ready for UAT (Consultant)',
            'Ready for UAT Approval',
            'Ready for Feature Merge',
            'Ready for Deployment'
            ],
            'Ready for UAT (Client)': ['Ready for UAT (Client)'],
            'Deployed to Prod': ['Deployed to Prod'],
            'Done': ['Done']
        },
        Consultant: {
            'Intake': [
                'Active Scoping',
                'Client Clarification (Pre-Dev)',
                'Pending Client Approval'
            ],
            'Quick Estimate': ['Needs Dev Feedback (T-Shirt Sizing)'],
            'Proposal Needed': ['Needs Dev Feedback (Proposal)'],
            'Dev Approval': ['Pending Development Approval'],
            'Pre-Dev Complete': ['Ready for Development'],
            'In Development': [
                'In Development',
                'Dev Blocked',
                'Back For Development',
                'Dev Complete'
            ],
            'Review & UAT': [
                'Ready for Scratch Org Test',
                'Ready for QA',
                'In QA',
                'Ready for UAT (Consultant)',
                'Ready for UAT Approval'
            ],
            'Feature Merge & Deploy': [
                'Ready for Feature Merge',
                'Ready for Deployment'
            ],
            'Deployed to Prod': ['Deployed to Prod'],
            'Done': ['Done']
        },

        Developer: {
            'Pending Work': [
                'Pending Client Approval',
                'Pending Development Approval',
                'Ready for Development'
            ],
            'Dev In Progress': [
                'In Development'
            ],
            'Dev Blocked': [
                'Dev Blocked'
            ],
            'Dev Complete': [
                'Dev Complete'
            ],
            'Review & Fixes': [
                'Back For Development'
            ],
            'QA & UAT': [
                'Ready for Scratch Org Test',
                'Ready for QA',
                'In QA',
                'Ready for UAT (Consultant)',
                'Ready for UAT (Client)'
            ],
            'Ready for Deploy': [
                'Ready for Feature Merge',
                'Ready for Deployment'
            ],
            'Deployed to Prod': ['Deployed to Prod'],
            'Done': ['Done']
        },

        QA: {
            'Ready for QA': ['Ready for QA'],
            'In QA': ['In QA'],
            'In Dev': [
                'In Development',
                'Dev Blocked',
                'Back For Development',
                'Dev Complete'
            ],
            'Scratch Org Test': ['Ready for Scratch Org Test'],
            'UAT': [
                'Ready for UAT (Consultant)',
                'Ready for UAT (Client)'
            ],
            'Ready for Merge': ['Ready for Feature Merge'],
            'Ready for Deploy': ['Ready for Deployment'],
            'Deployed to Prod': ['Deployed to Prod'],
            'Done': ['Done']
        }
    };

    personaBoardViews = {
        Client: {
            all: [
                'Backlog',
                'Active Scoping',
                'Quick Estimate',
                'Pending Client Prioritization',
                'Proposal Needed',
                'Pending Client Approval',
                'Ready for Development',
                'Client Clarification (In-Dev)',
                'In Development',
                'In Review',
                'Ready for UAT (Client)',
                'Deployed to Prod',
                'Done'
            ],
            predev: [
                'Backlog',
                'Active Scoping',
                'Quick Estimate',
                'Pending Client Prioritization',
                'Proposal Needed',
                'Pending Client Approval',
                'Ready for Development'
            ],
            indev: [
                'Client Clarification (In-Dev)',
                'In Development',
                'In Review',
                'Ready for UAT (Client)'
            ],
            deployed: [
                'Deployed to Prod',
                'Done'
            ]
        },
        Consultant: {
            all: [
                'Intake',
                'Quick Estimate',
                'Proposal Needed',
                'Dev Approval',
                'Pre-Dev Complete',
                'In Development',
                'Review & UAT',
                'Feature Merge & Deploy',
                'Deployed to Prod',
                'Done'
            ],
            predev: [
                'Intake',
                'Quick Estimate',
                'Proposal Needed',
                'Dev Approval',
                'Pre-Dev Complete'
            ],
            indev: [
                'In Development',
                'Review & UAT',
                'Feature Merge & Deploy'
            ],
            deployed: [
                'Deployed to Prod',
                'Done'
            ]
        },
        Developer: {
            all: [
                'Pending Work',
                'Dev In Progress',
                'Dev Blocked',
                'Dev Complete',
                'Review & Fixes',
                'QA & UAT',
                'Ready for Deploy',
                'Deployed to Prod',
                'Done'
            ],
            predev: [
                'Pending Work'
            ],
            indev: [
                'Dev In Progress',
                'Dev Blocked',
                'Dev Complete',
                'Review & Fixes',
                'QA & UAT',
                'Ready for Deploy'
            ],
            deployed: [
                'Deployed to Prod',
                'Done'
            ]
        },
        QA: {
            all: [
                'Ready for QA',
                'In QA',
                'In Dev',
                'Scratch Org Test',
                'UAT',
                'Ready for Merge',
                'Ready for Deploy',
                'Deployed to Prod',
                'Done'
            ],
            predev: [
                'In Dev'
            ],
            indev: [
                'Ready for QA',
                'In QA',
                'Scratch Org Test',
                'UAT',
                'Ready for Merge',
                'Ready for Deploy'
            ],
            deployed: [
                'Deployed to Prod',
                'Done'
            ]
        }
    };

    transitionMap = {
    'Backlog': ['Active Scoping','Needs Dev Feedback (T-Shirt Sizing)','Client Clarification (Pre-Dev)'],
    'Active Scoping': [
        'Client Clarification (Pre-Dev)',
        'Needs Dev Feedback (T-Shirt Sizing)'
    ],
    'Needs Dev Feedback (T-Shirt Sizing)': [
        'Pending Client Prioritization'
    ],
    'Pending Client Prioritization': [
        'Needs Dev Feedback (Proposal)'
    ],
    'Needs Dev Feedback (Proposal)': [
        'Pending Development Approval'
    ],
    'Client Clarification (Pre-Dev)': [
        'Pending Client Approval',
        'Pending Development Approval'
    ],
    'Pending Client Approval': [
        'Ready for Development'
    ],
    'Pending Development Approval': [
        'Pending Client Approval',
        'Ready for Development'
    ],
    'Ready for Development': [
        'In Development'
    ],
    'In Development': [
        'Dev Complete',
        'Dev Blocked'
    ],
    'Dev Blocked': [
        'In Development',
        'Pending Development Approval'
    ],
    // Back For Development is only a forward step from "Client Clarification (In-Dev)"
    'Client Clarification (In-Dev)': [
        'Back For Development'
    ],
    'Back For Development': [
        'In Development'
    ],
    'Dev Complete': [
        'Ready for Scratch Org Test',
        'Ready for QA',
        'Ready for UAT (Consultant)',
        'Ready for UAT (Client)'
    ],
    'Ready for Scratch Org Test': [
        'Ready for QA'
    ],
    'Ready for QA': [
        'In QA'
    ],
    'In QA': [
        'Ready for UAT (Consultant)',
        'Ready for UAT (Client)',
        'Dev Complete'
    ],
    'Ready for UAT (Consultant)': [
        'Ready for UAT (Client)'
    ],
    'Ready for UAT (Client)': [
        'Ready for Feature Merge'
    ],
    'Ready for Feature Merge': [
        'Ready for Deployment'
    ],
    'Ready for Deployment': [
        'Deployed to Prod'
    ],
    'Deployed to Prod': [
        'Done'
    ],
    'Done': [],
    'Cancelled': ['Backlog']
};




backtrackMap = {
    'Active Scoping': [
        'Backlog',
        'Cancelled'
    ],
    'Client Clarification (Pre-Dev)': [
        'Active Scoping',
        'Needs Dev Feedback (T-Shirt Sizing)',
        'Cancelled'
    ],
    'Needs Dev Feedback (T-Shirt Sizing)': [
        'Active Scoping',
        'Backlog',
        'Cancelled'
    ],
    'Pending Client Prioritization': [
        'Needs Dev Feedback (T-Shirt Sizing)',
        'Active Scoping',
        'Backlog',
        'Cancelled'
    ],
    'Needs Dev Feedback (Proposal)': [
        'Pending Client Prioritization',
        'Needs Dev Feedback (T-Shirt Sizing)',
        'Cancelled'
    ],
    'Pending Development Approval': [
        'Needs Dev Feedback (Proposal)',
        'Pending Client Prioritization',
        'Active Scoping',
        'Backlog',
        'Cancelled'
    ],
    'Pending Client Approval': [
        'Needs Dev Feedback (Proposal)',
        'Pending Client Prioritization',
        'Cancelled'
    ],
    'Ready for Development': [
        'Pending Client Approval',
        'Pending Development Approval',
        'Cancelled'
    ],
    'In Development': [
        'Ready for Development',
        'Back For Development',
        'Dev Blocked',
        'Client Clarification (In-Dev)', // <-- now only a backtrack!
        'Cancelled'
    ],
    'Dev Blocked': [
        'Ready for Development',
        'Pending Development Approval',
        'Pending Client Approval',
        'Cancelled'
    ],
    'Client Clarification (In-Dev)': [
        'Pending Client Approval',
        'Cancelled'
    ],
    'Back For Development': [
        'Client Clarification (In-Dev)',
        'Pending Client Approval',
        'Dev Blocked',
        'In Development',
        'Cancelled'
    ],
    'Dev Complete': [
        'In Development',
        'Dev Blocked',
        'Back For Development',
        'Ready for QA',
        'Cancelled'
    ],
    'Ready for Scratch Org Test': [
        'Dev Complete',
        'Cancelled'
    ],
    'Ready for QA': [
        'Ready for Scratch Org Test',
        'Dev Complete',
        'Cancelled'
    ],
    'In QA': [
        'Ready for QA',
        'Ready for Scratch Org Test',
        'Dev Complete',
        'Cancelled'
    ],
    'Ready for UAT (Consultant)': [
        'In QA',
        'Ready for QA',
        'Cancelled'
    ],
    'Ready for UAT (Client)': [
        'Ready for UAT (Consultant)',
        'In QA',
        'Cancelled'
    ],
    'Ready for Feature Merge': [
        'Ready for UAT (Client)',
        'Ready for UAT (Consultant)',
        'Cancelled'
    ],
    'Ready for Deployment': [
        'Ready for Feature Merge',
        'Cancelled'
    ],
    'Deployed to Prod': [
        'Ready for Deployment',
        'Cancelled'
    ],
    'Done': [
        'Deployed to Prod',
        'Ready for Deployment',
        'Cancelled'
    ],
    'Backlog': [
        'Cancelled'
    ],
    'Cancelled': []
};


    intentionColor = {
        'Will Do': '#2196F3',
        'Sizing Only': '#FFD54F'
    };

    personaAdvanceOverrides = {};
    personaBacktrackOverrides = {};
    /*
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
    */
    /** keep a reference so we can refresh it later */
    @wire(getTickets)
    wiredTickets(result) {
        this.ticketsWire = result;              // ⬅️ store the wire

        const { data, error } = result;
        if (data) {
            this.realRecords = [...data];       // reactive copy
            this.loadETAs();                    // refresh ETAs
        } else if (error) {
            // optional: surface the error some other way
            console.error('Ticket wire error', error);
        }
    }

    @wire(isMarketingEnabled)
        wiredMarketingEnabled({ error, data }) {
            if (data !== undefined) {
                this.marketingEnabled = data;
            }
        }


    /* Toolbar button */
    openCreateModal() { this.showCreateModal = true; }

    /* “Cancel” in form */
    handleCreateCancel() { this.showCreateModal = false; }

    /* Called when the record-edit form saves successfully */
    handleCreateSuccess() {
        this.showCreateModal = false;
        // Re-query tickets so the new card appears:
        this.refreshTickets();
    }

    refreshTickets() {
        refreshApex(this.ticketsWire)           // bypass cache & rerun wire
            .then(() => this.loadETAs())        // pull fresh ETAs afterwards
            .catch(err => console.error('Ticket reload error', err));
    }

    openCreateModal() {
        // find current max SortOrderNumber__c and add 1
        const nums = (this.realRecords || [])
            .map(r => r.SortOrderNumber__c)
            .filter(n => n !== null && n !== undefined);
        this.nextSortOrder = nums.length ? Math.max(...nums) + 1 : 1;

        this.showCreateModal = true;
    }

    /* ---------- defaults for the create form ---------- */
    get createDefaults() {
        return {
            StageNamePk__c     : 'Backlog',
            SortOrderNumber__c : this.nextSortOrder,
            PriorityPk__c      : 'Medium',
            IsActiveBool__c    : true
        };
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



    /* ---------- stageColumns ---------- */
    get stageColumns() {
        const persona = this.persona;
        const boardViews = this.personaBoardViews?.[persona] || {};
        let colNames = boardViews?.[this.overallFilter] || [];
        const statusMap = this.personaColumnStatusMap?.[persona] || {};
        const enriched = this.enrichedTickets || [];

        // Filter columns for "Show Internal Columns" toggle
        if (!this.showAllColumns) {
            colNames = colNames.filter(col => this.columnOwner(col) === persona);
        }

        return (colNames || []).map(colName => {
            const statuses = statusMap[colName] || [];
            // Prefer custom style if present, else fallback to persona color logic
            let headerStyle;
            if (this.columnHeaderStyleMap && this.columnHeaderStyleMap[colName]) {
                const { bg, color } = this.columnHeaderStyleMap[colName];
                headerStyle = `background:${bg};color:${color};`;
            } else {
                const owner = this.columnOwner(colName);
                const color = this.ownerColorMap[owner] || this.ownerColorMap.Default;
                headerStyle = `background:${color};color:#fff;`;
            }
            return {
                stage: colName,
                displayName: this.columnDisplayNames[colName] || colName,
                headerStyle,
                tickets: enriched
                    .filter(t => statuses.includes(t.StageNamePk__c))
                    .filter(t => {
                        // Only filter if intention is not "all"
                        if (this.intentionFilter === 'all') return true;
                        // Debug log
                        console.log(
                            `[Intent Filter] Ticket:`, t.Id, 
                            '| Stage:', t.StageNamePk__c, 
                            '| Client_Intention__c:', t.Client_Intention__c, 
                            '| Current Filter:', this.intentionFilter
                        );
                        // Compare picklist value, trimming for safety
                        return (t.Client_Intention__c || '').trim().toLowerCase() === this.intentionFilter.toLowerCase();
                    })
                    .map(t => {
                        // You can add your cardColor logic here if you want
                        let cardColor = this.statusColorMap[t.StageNamePk__c] || '#eee';
                        return { ...t, cardColor };
                    })
            };
        });
    }





    getColumnDisplayName(colKey) {
        return this.columnDisplayNames?.[colKey] || colKey;
    }



    // Helper for client persona column headers
    getClientColumnHeaderColor(colName) {
        // Pre-Dev columns (yellow)
        const yellowCols = [
            'Quick Estimate',
            'Proposal Needed',
            'Pending Development Approval',
            'Ready for Development'
        ];
        // In-Dev/Review columns (orange)
        const orangeCols = [
            'In Development',
            'In Review',
            'Ready for UAT (Client)'
        ];
        // Deployed/Done columns (blue)
        const blueCols = [
            'Deployed to Prod',
            'Done'
        ];
        if (yellowCols.includes(colName)) return '#FFE082';
        if (orangeCols.includes(colName)) return '#FF9100';
        if (blueCols.includes(colName))   return '#90caf9';
        // Backlog/Active Scoping – light gray or light blue
        if (colName === 'Backlog' || colName === 'Active Scoping') return '#bbdefb';
        return '#2196F3'; // Default blue for anything else
    }

    // ...and keep getClientCardColor as previously provided:
    getClientCardColor(status) {
        if (this.persona !== 'Client') {
            return this.statusColorMap[status] || '#eee';
        }
        const predev = [
            'Backlog', 'Active Scoping', 'Quick Estimate', 'Proposal Needed',
            'Pending Development Approval', 'Pending Client Approval', 'Ready for Development'
        ];
        const indev = [
            'In Development', 'Dev Blocked', 'Back For Development', 'Dev Complete',
            'Ready for Scratch Org Test', 'Ready for QA', 'In QA',
            'Ready for UAT (Consultant)', 'Ready for UAT Approval', 'Ready for UAT (Client)',
            'Ready for Feature Merge', 'Ready for Deployment'
        ];
        if (predev.includes(status))   return '#FFE082'; // yellow
        if (indev.includes(status))    return '#FF9100'; // orange
        if (['Deployed to Prod', 'Done', 'Cancelled'].includes(status)) return '#90caf9'; // blue/grey
        return '#eee';
    }







    get advanceOptions() {
        if (!this.selectedRecord) return [];

        const currStage  = this.selectedRecord.StageNamePk__c;
        const persona    = this.persona;
        const nextStages = this.transitionMap[currStage] || [];

        return nextStages
            .filter(tgt => tgt !== currStage)
            .map(tgt => {
                const override = this.personaAdvanceOverrides?.[persona]?.[currStage]?.[tgt] || {};

                // 🔥 Use columnHeaderStyleMap for the target status
                let style = '';
                if (this.columnHeaderStyleMap && this.columnHeaderStyleMap[tgt]) {
                    const { bg, color } = this.columnHeaderStyleMap[tgt];
                    style = `background:${bg};color:${color};`;
                } else {
                    style = 'background:#e0e0e0;color:#222;';
                }

                let icon = override.icon || '➡️';
                if (tgt === 'Active Scoping') icon = '🚀';
                if (tgt === 'Cancelled')      icon = '🛑';

                return {
                    value: tgt,
                    label: override.label || tgt,
                    icon,
                    style,
                    autofocus: override.autofocus || false
                };
            });
    }


    get backtrackOptions() {
        if (!this.selectedRecord) return [];

        const currStage = this.selectedRecord.StageNamePk__c;
        const persona   = this.persona;
        let targets     = [];

        if (this.personaBacktrackOverrides?.[persona]?.[currStage]) {
            const custom = this.personaBacktrackOverrides[persona][currStage];
            targets = Object.keys(custom).map(tgt => {
                const override = custom[tgt];
                // 🔥 Use columnHeaderStyleMap for the target status
                let style = '';
                if (this.columnHeaderStyleMap && this.columnHeaderStyleMap[tgt]) {
                    const { bg, color } = this.columnHeaderStyleMap[tgt];
                    style = `background:${bg};color:${color};`;
                } else {
                    style = 'background:#e0e0e0;color:#222;';
                }
                return {
                    value: tgt,
                    label: override.label || tgt,
                    icon : override.icon  || '🔙',
                    style
                };
            });
        } else {
            const prevStages = this.backtrackMap[currStage] || [];
            targets = prevStages.map(tgt => {
                // 🔥 Use columnHeaderStyleMap for the target status
                let style = '';
                if (this.columnHeaderStyleMap && this.columnHeaderStyleMap[tgt]) {
                    const { bg, color } = this.columnHeaderStyleMap[tgt];
                    style = `background:${bg};color:${color};`;
                } else {
                    style = 'background:#e0e0e0;color:#222;';
                }
                return {
                    value: tgt,
                    label: tgt,
                    icon : '⬅️',
                    style
                };
            });
        }
        return targets;
    }


    get overallFilterOptions() {
        return [
            { label: 'All', value: 'all' },
            { label: 'Pre-Dev', value: 'predev' },
            { label: 'In-Dev & Review', value: 'indev' },
            { label: 'Deployed/Done', value: 'deployed' }
        ];
    }

    get intentionFilterOptions() {
        return [
            { label: 'All', value: 'all' },
            { label: 'Will Do', value: 'Will Do' },
            { label: 'Sizing Only', value: 'Sizing Only' }
        ];
    }
    handleIntentionFilterChange(e) {
        this.intentionFilter = e.detail ? e.detail.value : e.target.value;
    }

    handleOverallFilterChange(e) {
        this.overallFilter = e.detail ? e.detail.value : e.target.value;
    }

    handleToggleColumns(e) {
        this.showAllColumns = e.target.checked;
    }

    columnOwner(colName) {
        // Take first status mapped to that column and look it up
        const statuses = this.personaColumnStatusMap[this.persona]?.[colName] || [];
        const first    = statuses[0];
        return this.statusOwnerMap[first] || 'Default';
    }


    handleNumDevsChange(e) {
        this.numDevs = parseInt(e.target.value, 10) || 1;
        this.loadETAs();
        console.log('here');
    }

    loadETAs() {
        // For now, pass null or [] as prioritizedTicketIds unless you add a "prioritize to top" feature in the UI.
        getTicketETAsWithPriority({ numberOfDevs: this.numDevs, prioritizedTicketIds: null })
            .then(result => {
                this.etaResults = result && result.tickets ? [...result.tickets] : [];
                // If you want to handle warnings:
                if (result && result.pushedBackTicketNumbers && result.pushedBackTicketNumbers.length) {
                    // Show a toast or inline warning
                    console.warn('⚠️ These tickets were pushed back by prioritization:', result.pushedBackTicketNumbers);
                    // Optionally save for UI
                    this.pushedBackTicketNumbers = result.pushedBackTicketNumbers;
                } else {
                    this.pushedBackTicketNumbers = [];
                }
            })
            .catch(err => {
                this.etaResults = [];
                this.pushedBackTicketNumbers = [];
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

    handleArrowClick(e) {
        const ticketId = e.currentTarget.dataset.id;
        const colStage = e.currentTarget.dataset.col;
        const direction = e.currentTarget.dataset.dir; // "up" or "down"

        // Find the column object
        const columns = this.stageColumns;
        const colObj = columns.find(c => c.stage === colStage);
        if (!colObj) return;

        const idx = colObj.tickets.findIndex(t => t.Id === ticketId);
        if (idx === -1) return;

        let targetIdx = direction === 'up' ? idx - 1 : idx + 1;
        if (targetIdx < 0 || targetIdx >= colObj.tickets.length) return; // Out of bounds

        // Swap the two tickets
        const temp = colObj.tickets[idx];
        colObj.tickets[idx] = colObj.tickets[targetIdx];
        colObj.tickets[targetIdx] = temp;

        // Update SortOrderNumber__c in memory
        colObj.tickets.forEach((t, i) => t.SortOrderNumber__c = i + 1);

        // Call Apex to persist the new order (implement this method as needed)
        this.bulkUpdateSortOrders(
            colObj.tickets.map(t => ({
                Id: t.Id,
                SortOrderNumber__c: t.SortOrderNumber__c
            }))
        );

        // Optionally, re-render
        this.refreshTickets();
    }

    bulkUpdateSortOrders(updates) {
        updateTicketSortOrders({ updates })
            .then(() => this.refreshTickets())
            .catch(err => console.error('Bulk sort update error', err));
    }

    get helpMailtoLink() {
        // You can't get the current user's email everywhere
        // so just prompt for it in the body if not available
        const url = window.location.href;
        let subject = `Support Request - ${url}`;
        let body = `Describe your issue here...\n\n---\nURL: ${url}\n`;
        body += `Your email: \n`; // user fills it in

        return 'mailto:support@cloudnimbusllc.com?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}';
    }


}
