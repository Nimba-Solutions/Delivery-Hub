import { LightningElement, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";
import { updateRecord } from "lightning/uiRecordApi";
import getTickets from "@salesforce/apex/%%%NAMESPACE_DOT%%%TicketController.getTickets";
import linkFilesAndSync from "@salesforce/apex/%%%NAMESPACE_DOT%%%TicketController.linkFilesAndSync";
import getAiEnhancedTicketDetails from "@salesforce/apex/%%%NAMESPACE_DOT%%%TicketController.getAiEnhancedTicketDetails";
import STAGE_FIELD from "@salesforce/schema/%%%NAMESPACE%%%Ticket__c.%%%NAMESPACE%%%StageNamePk__c";
import ID_FIELD from "@salesforce/schema/%%%NAMESPACE%%%Ticket__c.Id";
import getTicketETAsWithPriority from "@salesforce/apex/%%%NAMESPACE_DOT%%%TicketETAService.getTicketETAsWithPriority";
import updateTicketStage from "@salesforce/apex/%%%NAMESPACE_DOT%%%DragAndDropLwcController.updateTicketStage";
import updateTicketSortOrder from "@salesforce/apex/%%%NAMESPACE_DOT%%%DragAndDropLwcController.updateTicketSortOrder";
import getRequiredFieldsForStage from '@salesforce/apex/%%%NAMESPACE_DOT%%%TicketController.getRequiredFieldsForStage';
import searchForPotentialBlockers from '@salesforce/apex/%%%NAMESPACE_DOT%%%DragAndDropLwcController.searchForPotentialBlockers';
import createDependency from '@salesforce/apex/%%%NAMESPACE_DOT%%%DragAndDropLwcController.createDependency';
import removeDependency from '@salesforce/apex/%%%NAMESPACE_DOT%%%DragAndDropLwcController.removeDependency';
import { ShowToastEvent } from "lightning/platformShowToastEvent";import getSettings from '@salesforce/apex/DeliveryHubSettingsController.getSettings';

export default class DragAndDropLwc extends NavigationMixin(LightningElement) {
  @track persona = "Client";
  @track sizeMode = "equalSized";
  @track displayMode = "kanban";
  @track showModal = false;
  @track selectedRecord = null;
  @track selectedStage = null;
  @track realRecords = [];
  @track moveComment = "";
  @track recentComments = [];
  @track numDevs = 2; // Default to 2 devs, or whatever you want
  @track etaResults = [];
  @track showAllColumns = true;
  @track showCreateModal = false;
  @track nextSortOrder = 1;
  @track overallFilter = "all";
  @track intentionFilter = "all";
  @track uploadedFileIds = [];
  @track showMode = "overall";
  @track draggedItem = {};
  @track isDragging = false;
  @track placeholder = null;
  @track AiEnhancementEnabled = true;
  @track AiEstimation = true;
  // AI Enhancement properties
  @track isAiProcessing = false;
  @track aiSuggestions = null;
  @track createTicketTitle = "";
  @track createTicketDescription = "";
  @track estimatedDaysValue = null;
  @track formFieldValues = {};
  @track showTransitionModal = false;
  @track transitionTicketId = null;
  @track transitionTargetStage = null;
  @track transitionRequiredFields = [];
  ticketsWire;

  @track isModalOpen = false;
    @track selectedTicket = {};
    @track searchTerm = '';
    @track searchResults = [];
    @track isSearching = false;

  statusColorMap = {
    Backlog: "#FAFAFA",
    "Active Scoping": "#FFE082",
    "Quick Estimate": "#FFD54F", // not a status but a column, see below!
    "Pending Client Prioritization": "#FFD54F", // YELLOW
    "Client Clarification (Pre-Dev)": "#FFD54F",
    "Pending Client Approval": "#FFE0B2",
    "Needs Dev Feedback (T-Shirt Sizing)": "#FFD180",
    "Needs Dev Feedback (Proposal)": "#FFD180",
    "Pending Development Approval": "#FFD54F", // now yellow, not blue
    "Ready for Development": "#FFD54F",
    "In Development": "#FF9100", // Orange
    "Dev Blocked": "#FF5252",
    "Back For Development": "#FFD180",
    "Dev Complete": "#A5D6A7",
    "Ready for Scratch Org Test": "#B2DFDB",
    "Ready for QA": "#64B5F6",
    "In QA": "#1976D2",
    "Ready for UAT (Consultant)": "#4FC3F7",
    "Ready for UAT (Client)": "#00BFAE",
    "Ready for Feature Merge": "#00897B",
    "Ready for Deployment": "#43A047",
    "Deployed to Prod": "#388E3C",
    Done: "#263238",
    Cancelled: "#BDBDBD",
  };

  // Custom header color logic for Client persona
  columnHeaderStyleMap = {
    // --- Client Action Columns (Blue Scheme) ---
    Backlog: { bg: "rgba(59, 130, 246, 0.3)", color: "#2563EB" },
    "Active Scoping": { bg: "rgba(59, 130, 246, 0.3)", color: "#2563EB" },
    "Pending Client Prioritization": {
      bg: "rgba(59, 130, 246, 0.3)",
      color: "#2563EB",
    },
    "Pending Client Approval": {
      bg: "rgba(59, 130, 246, 0.3)",
      color: "#2563EB",
    },
    "Client Clarification (Pre-Dev)": {
      bg: "rgba(59, 130, 246, 0.3)",
      color: "#2563EB",
    },
    "Client Clarification (In-Dev)": {
      bg: "rgba(59, 130, 246, 0.3)",
      color: "#2563EB",
    },
    "Ready for UAT (Client)": {
      bg: "rgba(59, 130, 246, 0.3)",
      color: "#2563EB",
    },

    // --- Pre-Dev & Sizing Columns (Amber/Yellow Scheme) ---
    "Quick Estimate": { bg: "rgba(245, 158, 11, 0.3)", color: "#D97706" },
    "Needs Dev Feedback (T-Shirt Sizing)": {
      bg: "rgba(245, 158, 11, 0.3)",
      color: "#D97706",
    },
    "Needs Dev Feedback (Proposal)": {
      bg: "rgba(245, 158, 11, 0.3)",
      color: "#D97706",
    },
    "Proposal Needed": { bg: "rgba(245, 158, 11, 0.3)", color: "#D97706" },
    "Pending Development Approval": {
      bg: "rgba(245, 158, 11, 0.3)",
      color: "#D97706",
    },

    // --- Development Columns (Green Scheme) ---
    "Ready for Development": { bg: "rgba(34, 197, 94, 0.3)", color: "#16A34A" },
    "In Development": { bg: "rgba(34, 197, 94, 0.3)", color: "#16A34A" },
    "Dev Complete": { bg: "rgba(34, 197, 94, 0.3)", color: "#16A34A" },
    "Back For Development": { bg: "rgba(34, 197, 94, 0.3)", color: "#16A34A" },

    // --- QA & Review Columns (Teal/Cyan Scheme) ---
    "In Review": { bg: "rgba(20, 184, 166, 0.3)", color: "#0D9488" },
    "Ready for Scratch Org Test": {
      bg: "rgba(20, 184, 166, 0.3)",
      color: "#0D9488",
    },
    "Ready for QA": { bg: "rgba(20, 184, 166, 0.3)", color: "#0D9488" },
    "In QA": { bg: "rgba(20, 184, 166, 0.3)", color: "#0D9488" },
    "Ready for UAT (Consultant)": {
      bg: "rgba(20, 184, 166, 0.3)",
      color: "#0D9488",
    },

    // --- Deployment Columns (Indigo/Purple Scheme) ---
    "Ready for Feature Merge": {
      bg: "rgba(139, 92, 246, 0.3)",
      color: "#7C3AED",
    },
    "Ready for Deployment": { bg: "rgba(139, 92, 246, 0.3)", color: "#7C3AED" },
    "Deployed to Prod": { bg: "rgba(99, 102, 241, 0.3)", color: "#4F46E5" },

    // --- Final State Columns (Neutral/Special Schemes) ---
    Done: { bg: "rgba(100, 116, 139, 0.3)", color: "#475569" }, // Slate Grey
    "Dev Blocked": { bg: "rgba(239, 68, 68, 0.3)", color: "#DC2626" }, // Red
    Cancelled: { bg: "rgba(156, 163, 175, 0.3)", color: "#6B7280" }, // Light Grey
  };

  /** Who owns each status next **/
  statusOwnerMap = {
    // ── Client ─────────────────────────
    Backlog: "Client",
    "Active Scoping": "Client",
    "Client Clarification (Pre-Dev)": "Client",
    "Pending Client Prioritization": "Client",
    "Pending Client Approval": "Client",
    "Client Clarification (In-Dev)": "Client",
    "Ready for UAT (Client)": "Client",
    "Deployed to Prod": "Client",
    Done: "Client",
    Cancelled: "Client",

    // ── Consultant / PM ────────────────
    "Pending Development Approval": "Consultant",
    "Ready for UAT (Consultant)": "Consultant",
    "Ready for Feature Merge": "Consultant",
    "Ready for Deployment": "Consultant",

    // ── Developer ──────────────────────
    "Needs Dev Feedback (T-Shirt Sizing)": "Developer",
    "Needs Dev Feedback (Proposal)": "Developer",
    "Ready for Development": "Developer",
    "In Development": "Developer",
    "Dev Blocked": "Developer",
    "Back For Development": "Developer",
    "Dev Complete": "Developer",

    // ── QA ─────────────────────────────
    "Ready for Scratch Org Test": "QA",
    "Ready for QA": "QA",
    "In QA": "QA",
  };

  /** Color palette per persona **/
  ownerColorMap = {
    Client: "#2196F3", // blue
    Consultant: "#FFD600", // yellow
    Developer: "#FF9100", // orange
    QA: "#00C853", // green
    Default: "#BDBDBD", // grey fallback
  };

  columnDisplayNames = {
    Backlog: "Backlog",
    "Active Scoping": "Active Scoping",
    "Quick Estimate": "Ready for Estimate",
    "Pending Client Prioritization": "Client Prioritization / Feedback", // <-- NEW LABEL!
    "Proposal Needed": "Approved for Analysis",
    "Pending Client Approval": "Pending Client Approval",
    "Ready for Development": "Approved for Development",
    "Client Clarification (In-Dev)": "Client Clarification (In-Dev)",
    "In Development": "In Development",
    "In Review": "In Review",
    "Ready for UAT (Client)": "Ready for UAT (Client)",
    "Deployed to Prod": "Deployed to Prod",
    Done: "Done",
    // ... (add other columns if you want custom labels)
  };

  personaColumnStatusMap = {
    Client: {
      Backlog: ["Backlog"],
      "Active Scoping": ["Active Scoping"],
      "Quick Estimate": ["Needs Dev Feedback (T-Shirt Sizing)"],
      "Pending Client Prioritization": [
        "Client Clarification (Pre-Dev)", // <-- Add here!
        "Pending Client Prioritization",
      ],
      "Proposal Needed": [
        "Needs Dev Feedback (Proposal)",
        "Pending Development Approval",
      ],
      "Pending Client Approval": ["Pending Client Approval"],
      "Ready for Development": ["Ready for Development"],
      "Client Clarification (In-Dev)": ["Client Clarification (In-Dev)"],
      "In Development": [
        "In Development",
        "Dev Blocked",
        "Back For Development",
        "Dev Complete",
      ],
      "In Review": [
        "Ready for Scratch Org Test",
        "Ready for QA",
        "In QA",
        "Ready for UAT (Consultant)",
        "Ready for UAT Approval",
        "Ready for Feature Merge",
        "Ready for Deployment",
      ],
      "Ready for UAT (Client)": ["Ready for UAT (Client)"],
      "Deployed to Prod": ["Deployed to Prod"],
      Done: ["Done"],
    },
    Consultant: {
      Intake: [
        "Active Scoping",
        "Client Clarification (Pre-Dev)",
        "Pending Client Approval",
      ],
      "Quick Estimate": ["Needs Dev Feedback (T-Shirt Sizing)"],
      "Proposal Needed": ["Needs Dev Feedback (Proposal)"],
      "Dev Approval": ["Pending Development Approval"],
      "Pre-Dev Complete": ["Ready for Development"],
      "In Development": [
        "In Development",
        "Dev Blocked",
        "Back For Development",
        "Dev Complete",
      ],
      "Review & UAT": [
        "Ready for Scratch Org Test",
        "Ready for QA",
        "In QA",
        "Ready for UAT (Consultant)",
        "Ready for UAT Approval",
      ],
      "Feature Merge & Deploy": [
        "Ready for Feature Merge",
        "Ready for Deployment",
      ],
      "Deployed to Prod": ["Deployed to Prod"],
      Done: ["Done"],
    },

    Developer: {
      "Pending Work": [
        "Pending Client Approval",
        "Pending Development Approval",
        "Ready for Development",
      ],
      "Dev In Progress": ["In Development"],
      "Dev Blocked": ["Dev Blocked"],
      "Dev Complete": ["Dev Complete"],
      "Review & Fixes": ["Back For Development"],
      "QA & UAT": [
        "Ready for Scratch Org Test",
        "Ready for QA",
        "In QA",
        "Ready for UAT (Consultant)",
        "Ready for UAT (Client)",
      ],
      "Ready for Deploy": ["Ready for Feature Merge", "Ready for Deployment"],
      "Deployed to Prod": ["Deployed to Prod"],
      Done: ["Done"],
    },

    QA: {
      "Ready for QA": ["Ready for QA"],
      "In QA": ["In QA"],
      "In Dev": [
        "In Development",
        "Dev Blocked",
        "Back For Development",
        "Dev Complete",
      ],
      "Scratch Org Test": ["Ready for Scratch Org Test"],
      UAT: ["Ready for UAT (Consultant)", "Ready for UAT (Client)"],
      "Ready for Merge": ["Ready for Feature Merge"],
      "Ready for Deploy": ["Ready for Deployment"],
      "Deployed to Prod": ["Deployed to Prod"],
      Done: ["Done"],
    },
  };

  personaBoardViews = {
    Client: {
      all: [
        "Backlog",
        "Active Scoping",
        "Quick Estimate",
        "Pending Client Prioritization",
        "Proposal Needed",
        "Pending Client Approval",
        "Ready for Development",
        "Client Clarification (In-Dev)",
        "In Development",
        "In Review",
        "Ready for UAT (Client)",
        "Deployed to Prod",
        "Done",
      ],
      predev: [
        "Backlog",
        "Active Scoping",
        "Quick Estimate",
        "Pending Client Prioritization",
        "Proposal Needed",
        "Pending Client Approval",
        "Ready for Development",
      ],
      indev: [
        "Client Clarification (In-Dev)",
        "In Development",
        "In Review",
        "Ready for UAT (Client)",
      ],
      deployed: ["Deployed to Prod", "Done"],
    },
    Consultant: {
      all: [
        "Intake",
        "Quick Estimate",
        "Proposal Needed",
        "Dev Approval",
        "Pre-Dev Complete",
        "In Development",
        "Review & UAT",
        "Feature Merge & Deploy",
        "Deployed to Prod",
        "Done",
      ],
      predev: [
        "Intake",
        "Quick Estimate",
        "Proposal Needed",
        "Dev Approval",
        "Pre-Dev Complete",
      ],
      indev: ["In Development", "Review & UAT", "Feature Merge & Deploy"],
      deployed: ["Deployed to Prod", "Done"],
    },
    Developer: {
      all: [
        "Pending Work",
        "Dev In Progress",
        "Dev Blocked",
        "Dev Complete",
        "Review & Fixes",
        "QA & UAT",
        "Ready for Deploy",
        "Deployed to Prod",
        "Done",
      ],
      predev: ["Pending Work"],
      indev: [
        "Dev In Progress",
        "Dev Blocked",
        "Dev Complete",
        "Review & Fixes",
        "QA & UAT",
        "Ready for Deploy",
      ],
      deployed: ["Deployed to Prod", "Done"],
    },
    QA: {
      all: [
        "Ready for QA",
        "In QA",
        "In Dev",
        "Scratch Org Test",
        "UAT",
        "Ready for Merge",
        "Ready for Deploy",
        "Deployed to Prod",
        "Done",
      ],
      predev: ["In Dev"],
      indev: [
        "Ready for QA",
        "In QA",
        "Scratch Org Test",
        "UAT",
        "Ready for Merge",
        "Ready for Deploy",
      ],
      deployed: ["Deployed to Prod", "Done"],
    },
  };

  transitionMap = {
    Backlog: [
      "Active Scoping",
      "Needs Dev Feedback (T-Shirt Sizing)",
      "Client Clarification (Pre-Dev)",
    ],
    "Active Scoping": [
      "Client Clarification (Pre-Dev)",
      "Needs Dev Feedback (T-Shirt Sizing)",
    ],
    "Needs Dev Feedback (T-Shirt Sizing)": ["Pending Client Prioritization"],
    "Pending Client Prioritization": ["Needs Dev Feedback (Proposal)"],
    "Needs Dev Feedback (Proposal)": ["Pending Development Approval"],
    "Client Clarification (Pre-Dev)": [
      "Pending Client Approval",
      "Pending Development Approval",
    ],
    "Pending Client Approval": ["Ready for Development"],
    "Pending Development Approval": [
      "Pending Client Approval",
      "Ready for Development",
    ],
    "Ready for Development": ["In Development"],
    "In Development": ["Dev Complete", "Dev Blocked"],
    "Dev Blocked": ["In Development", "Pending Development Approval"],
    // Back For Development is only a forward step from "Client Clarification (In-Dev)"
    "Client Clarification (In-Dev)": ["Back For Development"],
    "Back For Development": ["In Development"],
    "Dev Complete": [
      "Ready for Scratch Org Test",
      "Ready for QA",
      "Ready for UAT (Consultant)",
      "Ready for UAT (Client)",
    ],
    "Ready for Scratch Org Test": ["Ready for QA"],
    "Ready for QA": ["In QA"],
    "In QA": [
      "Ready for UAT (Consultant)",
      "Ready for UAT (Client)",
      "Dev Complete",
    ],
    "Ready for UAT (Consultant)": ["Ready for UAT (Client)"],
    "Ready for UAT (Client)": ["Ready for Feature Merge"],
    "Ready for Feature Merge": ["Ready for Deployment"],
    "Ready for Deployment": ["Deployed to Prod"],
    "Deployed to Prod": ["Done"],
    Done: [],
    Cancelled: ["Backlog"],
  };

  backtrackMap = {
    "Active Scoping": ["Backlog", "Cancelled"],
    "Client Clarification (Pre-Dev)": [
      "Active Scoping",
      "Needs Dev Feedback (T-Shirt Sizing)",
      "Cancelled",
    ],
    "Needs Dev Feedback (T-Shirt Sizing)": [
      "Active Scoping",
      "Backlog",
      "Cancelled",
    ],
    "Pending Client Prioritization": [
      "Needs Dev Feedback (T-Shirt Sizing)",
      "Active Scoping",
      "Backlog",
      "Cancelled",
    ],
    "Needs Dev Feedback (Proposal)": [
      "Pending Client Prioritization",
      "Needs Dev Feedback (T-Shirt Sizing)",
      "Cancelled",
    ],
    "Pending Development Approval": [
      "Needs Dev Feedback (Proposal)",
      "Pending Client Prioritization",
      "Active Scoping",
      "Backlog",
      "Cancelled",
    ],
    "Pending Client Approval": [
      "Needs Dev Feedback (Proposal)",
      "Pending Client Prioritization",
      "Cancelled",
    ],
    "Ready for Development": [
      "Pending Client Approval",
      "Pending Development Approval",
      "Cancelled",
    ],
    "In Development": [
      "Ready for Development",
      "Back For Development",
      "Dev Blocked",
      "Client Clarification (In-Dev)", // <-- now only a backtrack!
      "Cancelled",
    ],
    "Dev Blocked": [
      "Ready for Development",
      "Pending Development Approval",
      "Pending Client Approval",
      "Cancelled",
    ],
    "Client Clarification (In-Dev)": ["Pending Client Approval", "Cancelled"],
    "Back For Development": [
      "Client Clarification (In-Dev)",
      "Pending Client Approval",
      "Dev Blocked",
      "In Development",
      "Cancelled",
    ],
    "Dev Complete": [
      "In Development",
      "Dev Blocked",
      "Back For Development",
      "Ready for QA",
      "Cancelled",
    ],
    "Ready for Scratch Org Test": ["Dev Complete", "Cancelled"],
    "Ready for QA": ["Ready for Scratch Org Test", "Dev Complete", "Cancelled"],
    "In QA": [
      "Ready for QA",
      "Ready for Scratch Org Test",
      "Dev Complete",
      "Cancelled",
    ],
    "Ready for UAT (Consultant)": ["In QA", "Ready for QA", "Cancelled"],
    "Ready for UAT (Client)": [
      "Ready for UAT (Consultant)",
      "In QA",
      "Cancelled",
    ],
    "Ready for Feature Merge": [
      "Ready for UAT (Client)",
      "Ready for UAT (Consultant)",
      "Cancelled",
    ],
    "Ready for Deployment": ["Ready for Feature Merge", "Cancelled"],
    "Deployed to Prod": ["Ready for Deployment", "Cancelled"],
    Done: ["Deployed to Prod", "Ready for Deployment", "Cancelled"],
    Backlog: ["Cancelled"],
    Cancelled: [],
  };

  intentionColor = {
    "Will Do": "#2196F3",
    "Sizing Only": "#FFD54F",
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
    this.ticketsWire = result; // ⬅️ store the wire

    const { data, error } = result;
    if (data) {
      this.realRecords = [...data]; // reactive copy
      this.loadETAs(); // refresh ETAs
    } else if (error) {
      // optional: surface the error some other way
      console.error("Ticket wire error", error);
    }
  }

  @wire(getSettings)
      wiredSettings({ error, data }) {
      
          if (data) {
              this.AiEnhancementEnabled = data.aiSuggestionsEnabled || false;
              this.AiEstimation = data.aiEstimationEnabled || false;
              
              this.hasValidOpenAIKey = data.openAiApiTested || false;
          } else if (error) {
              this.showToast('Error Loading AI Settings', error.body.message, 'error');
          }
      }
  

  /* Toolbar button */
  openCreateModal() {
    this.showCreateModal = true;
  }

  /* “Cancel” in form */
  handleCreateCancel() {
    this.showCreateModal = false;
  }

  /* Called when the record-edit form saves successfully */
  handleCreateSuccess(event) {
    this.showCreateModal = false;
    const newTicketId = event.detail.id;

    // If files were uploaded, link them to the ticket and sync to Jira
    if (this.uploadedFileIds.length > 0) {
      linkFilesAndSync({
        ticketId: newTicketId,
        contentDocumentIds: this.uploadedFileIds,
      }).catch((error) => {
        console.error("Error linking files and syncing to Jira:", error);
      });
      this.uploadedFileIds = []; // Clear the array for the next modal
    }

    // Re-query tickets so the new card appears:
    this.refreshTickets();
  }

  /* Called when files are uploaded */
  handleFileUpload(event) {
    const uploadedFiles = event.detail.files;
    this.uploadedFileIds.push(...uploadedFiles.map((file) => file.documentId));
  }

  handleShowModeChange(event) {
    const selectedMode = event.currentTarget.dataset.mode;
    this.showMode = selectedMode;

    // Optional: Update button styles manually if :active pseudo-class isn't sufficient
    const buttons = this.template.querySelectorAll(".toolbar-button");
    buttons.forEach((button) => {
      if (button.dataset.mode === selectedMode) {
        button.classList.add("active");
      } else {
        button.classList.remove("active");
      }
    });
  }

  refreshTickets() {
    refreshApex(this.ticketsWire) // bypass cache & rerun wire
      .then(() => this.loadETAs()) // pull fresh ETAs afterwards
      .catch((err) => console.error("Ticket reload error", err));
  }

  openCreateModal() {
    // find current max SortOrderNumber__c and add 1
    const nums = (this.realRecords || [])
      .map((r) => r.%%%NAMESPACE%%%SortOrderNumber__c)
      .filter((n) => n !== null && n !== undefined);
    this.nextSortOrder = nums.length ? Math.max(...nums) + 1 : 1;

    this.showCreateModal = true;
  }

  /* ---------- defaults for the create form ---------- */
  get createDefaults() {
    return {
      %%%NAMESPACE%%%StageNamePk__c: "Backlog",
      %%%NAMESPACE%%%SortOrderNumber__c: this.nextSortOrder,
      %%%NAMESPACE%%%PriorityPk__c: "Medium",
      %%%NAMESPACE%%%IsActiveBool__c: true,
    };
  }

  get personaOptions() {
    return Object.keys(this.personaColumnStatusMap).map((p) => ({
      label: p,
      value: p,
    }));
  }
  get sizeModeOptions() {
    return [
      { label: "Equal Sized", value: "equalSized" },
      { label: "Ticket Sized", value: "ticketSize" },
    ];
  }
  get hasRecentComments() {
    return (this.recentComments || []).length > 0;
  }
  get displayModeOptions() {
    return [
      { label: "Kanban", value: "kanban" },
      { label: "Compact", value: "compact" },
      { label: "Table", value: "table" },
    ];
  }
  get mainBoardClass() {
    if (this.displayMode === "table") return "table-board";
    if (this.displayMode === "compact") return "stage-columns compact";
    return "stage-columns";
  }
  get isTableMode() {
    return this.displayMode === "table";
  }

  get enrichedTickets() {
    const norm = (id) => (id || "").substring(0, 15);

    const etaMap = new Map(
      (this.etaResults || [])
        .filter((dto) => !!dto.ticketId)
        .map((dto) => [norm(dto.ticketId), dto])
    );

    return (this.realRecords || []).map((rec) => {
      const etaDto = etaMap.get(norm(rec.Id));

      const isBlockedBy = (rec.Ticket_Dependency1__r || []).map(dep => ({
            id: dep.Blocking_Ticket__c,
            name: dep.Blocking_Ticket__r.Name,
            dependencyId: dep.Id
        }));

        const isBlocking = (rec.Ticket_Dependency__r || []).map(dep => ({
            id: dep.Blocked_Ticket__c,
            name: dep.Blocked_Ticket__r.Name,
            dependencyId: dep.Id
        }));
      // --- START OF NEW ADDITIONS ---

      // Helper to convert status to a CSS-friendly class name
      const getStatusClass = (status) => {
        if (!status) return "border-default";
        // Example: 'Ready for QA' -> 'border-ready-for-qa'
        return (
          "border-" +
          status
            .toLowerCase()
            .replace(/\s+/g, "-")
            .replace(/[^a-z0-9-]/g, "")
        );
      };

      // Helper to create an array from a tag string
      const getTagsArray = (tagsString) => {
        if (!tagsString || typeof tagsString !== "string") return [];
        return tagsString
          .split(",")
          .map((tag) => tag.trim())
          .filter((tag) => tag);
      };

      // --- END OF NEW ADDITIONS ---

      

      return {
        ...rec,
        calculatedETA:
          etaDto && etaDto.calculatedETA
            ? new Date(etaDto.calculatedETA).toLocaleDateString()
            : "—",

        // --- NEW DYNAMIC PROPERTIES FOR THE TEMPLATE ---
        isBlockedBy: isBlockedBy,
        isBlocking: isBlocking,
        isCurrentlyBlocked: isBlockedBy.length > 0,
        OwnerName: rec.Owner?.Name, // Assuming Owner relationship is queried
        isHighPriority: rec.PriorityPk__c?.toLowerCase() === "high",
        tags: getTagsArray(rec.Tags__c),
        cardClasses: `ticket-card`,
        priorityClasses: `priority-badge priority-${rec.PriorityPk__c?.toLowerCase()}`,
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

    if (!this.showAllColumns) {
      colNames = colNames.filter((col) => this.columnOwner(col) === persona);
    }

    let columns = (colNames || []).map((colName) => {
      // Step 1: Get the style config for the column just once.
      const columnStyleConfig = this.columnHeaderStyleMap[colName] || {
        bg: "#ffffff",
        color: "#11182c",
      };
      const headerStyle = `background:${columnStyleConfig.bg};color:${columnStyleConfig.color};`;

      // Step 2: Filter and map the tickets.
      const columnTickets = enriched
        .filter((t) => (statusMap[colName] || []).includes(t.%%%NAMESPACE%%%StageNamePk__c))
        .filter((t) => {
          if (this.intentionFilter === "all") return true;
          return (
            (t.Client_Intention__c || "").trim().toLowerCase() ===
            this.intentionFilter.toLowerCase()
          );
        })
        .map((ticket) => {
          // --- START OF THE FIX ---
          // For each ticket, create a style string that sets the BORDER color
          // to match the column header's main text color for a clean look.
          return {
            ...ticket,
            cardStyle: `border-left-color: ${columnStyleConfig.bg} !important;`,
          };
          // --- END OF THE FIX ---
        });

      const bodyClasses = `kanban-column-body ${
        columnTickets.length > 0 ? "has-tickets" : "is-empty"
      }`;

      return {
        stage: colName,
        displayName: this.columnDisplayNames[colName] || colName,
        headerStyle,
        tickets: columnTickets,
        bodyClasses: bodyClasses,
      };
    });

    if (this.showMode === "active") {
      return columns.filter((col) => col.tickets.length > 0);
    }
    return columns;
  }

  getColumnDisplayName(colKey) {
    return this.columnDisplayNames?.[colKey] || colKey;
  }

  // Helper for client persona column headers
  getClientColumnHeaderColor(colName) {
    // Pre-Dev columns (yellow)
    const yellowCols = [
      "Quick Estimate",
      "Proposal Needed",
      "Pending Development Approval",
      "Ready for Development",
    ];
    // In-Dev/Review columns (orange)
    const orangeCols = [
      "In Development",
      "In Review",
      "Ready for UAT (Client)",
    ];
    // Deployed/Done columns (blue)
    const blueCols = ["Deployed to Prod", "Done"];
    if (yellowCols.includes(colName)) return "#FFE082";
    if (orangeCols.includes(colName)) return "#FF9100";
    if (blueCols.includes(colName)) return "#e3f2fd";
    // Backlog/Active Scoping – light gray or light blue
    if (colName === "Backlog" || colName === "Active Scoping") return "#e3f2fd";
    return "#2196F3"; // Default blue for anything else
  }

  // ...and keep getClientCardColor as previously provided:
  getClientCardColor(status) {
    if (this.persona !== "Client") {
      return this.statusColorMap[status] || "#eee";
    }
    const predev = [
      "Backlog",
      "Active Scoping",
      "Quick Estimate",
      "Proposal Needed",
      "Pending Development Approval",
      "Pending Client Approval",
      "Ready for Development",
    ];
    const indev = [
      "In Development",
      "Dev Blocked",
      "Back For Development",
      "Dev Complete",
      "Ready for Scratch Org Test",
      "Ready for QA",
      "In QA",
      "Ready for UAT (Consultant)",
      "Ready for UAT Approval",
      "Ready for UAT (Client)",
      "Ready for Feature Merge",
      "Ready for Deployment",
    ];
    if (predev.includes(status)) return "#FFE082"; // yellow
    if (indev.includes(status)) return "#FF9100"; // orange
    if (["Deployed to Prod", "Done", "Cancelled"].includes(status))
      return "#90caf9"; // blue/grey
    return "#eee";
  }

  get advanceOptions() {
    if (!this.selectedRecord) return [];

    const currStage = this.selectedRecord.%%%NAMESPACE%%%StageNamePk__c;
    const persona = this.persona;
    const nextStages = this.transitionMap[currStage] || [];

    return nextStages
      .filter((tgt) => tgt !== currStage)
      .map((tgt) => {
        const override =
          this.personaAdvanceOverrides?.[persona]?.[currStage]?.[tgt] || {};

        // 🔥 Use columnHeaderStyleMap for the target status
        let style = "";
        if (this.columnHeaderStyleMap && this.columnHeaderStyleMap[tgt]) {
          const { bg, color } = this.columnHeaderStyleMap[tgt];
          style = `background:${bg};color:${color};`;
        } else {
          style = "background:#e0e0e0;color:#222;";
        }

        let icon = override.icon || "➡️";
        if (tgt === "Active Scoping") icon = "🚀";
        if (tgt === "Cancelled") icon = "🛑";

        return {
          value: tgt,
          label: override.label || tgt,
          icon,
          style,
          autofocus: override.autofocus || false,
        };
      });
  }

  get backtrackOptions() {
    if (!this.selectedRecord) return [];

    const currStage = this.selectedRecord.%%%NAMESPACE%%%StageNamePk__c;
    const persona = this.persona;
    let targets = [];

    if (this.personaBacktrackOverrides?.[persona]?.[currStage]) {
      const custom = this.personaBacktrackOverrides[persona][currStage];
      targets = Object.keys(custom).map((tgt) => {
        const override = custom[tgt];
        // 🔥 Use columnHeaderStyleMap for the target status
        let style = "";
        if (this.columnHeaderStyleMap && this.columnHeaderStyleMap[tgt]) {
          const { bg, color } = this.columnHeaderStyleMap[tgt];
          style = `background:${bg};color:${color};`;
        } else {
          style = "background:#e0e0e0;color:#222;";
        }
        return {
          value: tgt,
          label: override.label || tgt,
          icon: override.icon || "🔙",
          style,
        };
      });
    } else {
      const prevStages = this.backtrackMap[currStage] || [];
      targets = prevStages.map((tgt) => {
        // 🔥 Use columnHeaderStyleMap for the target status
        let style = "";
        if (this.columnHeaderStyleMap && this.columnHeaderStyleMap[tgt]) {
          const { bg, color } = this.columnHeaderStyleMap[tgt];
          style = `background:${bg};color:${color};`;
        } else {
          style = "background:#e0e0e0;color:#222;";
        }
        return {
          value: tgt,
          label: tgt,
          icon: "⬅️",
          style,
        };
      });
    }
    return targets;
  }

  get overallFilterOptions() {
    return [
      { label: "All", value: "all" },
      { label: "Pre-Dev", value: "predev" },
      { label: "In-Dev & Review", value: "indev" },
      { label: "Deployed/Done", value: "deployed" },
    ];
  }

  get intentionFilterOptions() {
    return [
      { label: "All", value: "all" },
      { label: "Will Do", value: "Will Do" },
      { label: "Sizing Only", value: "Sizing Only" },
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
    const first = statuses[0];
    return this.statusOwnerMap[first] || "Default";
  }

  handleNumDevsChange(e) {
    this.numDevs = parseInt(e.target.value, 10) || 1;
    this.loadETAs();
    console.log("here");
  }

  loadETAs() {
    // For now, pass null or [] as prioritizedTicketIds unless you add a "prioritize to top" feature in the UI.
    getTicketETAsWithPriority({
      numberOfDevs: this.numDevs,
      prioritizedTicketIds: null,
    })
      .then((result) => {
        this.etaResults = result && result.tickets ? [...result.tickets] : [];
        // If you want to handle warnings:
        if (
          result &&
          result.pushedBackTicketNumbers &&
          result.pushedBackTicketNumbers.length
        ) {
          // Show a toast or inline warning
          console.warn(
            "⚠️ These tickets were pushed back by prioritization:",
            result.pushedBackTicketNumbers
          );
          // Optionally save for UI
          this.pushedBackTicketNumbers = result.pushedBackTicketNumbers;
        } else {
          this.pushedBackTicketNumbers = [];
        }
      })
      .catch((err) => {
        this.etaResults = [];
        this.pushedBackTicketNumbers = [];
        console.error("ETA error:", err);
      });
  }

  getTicketETA(ticketId) {
    return (this.etaResults || []).find((e) => e.ticketId === ticketId) || {};
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
    // Changed e.target to e.currentTarget
    const id = e.currentTarget.dataset.id;

    if (id) {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: id,
          objectApiName: "%%%NAMESPACE%%%Ticket__c",
          actionName: "view",
        },
      });
    }
  }

  handleCardClick(e) {
    const id = e.currentTarget?.dataset?.id || e.target?.dataset?.id;
    this.selectedRecord = (this.realRecords || []).find((r) => r.Id === id);
    this.selectedStage = null;
    this.showModal = true;
    this.moveComment = "";
  }
  // handleAdvanceOption(e) {
  //   const newStage = e.target.dataset.value;
  //   this.selectedStage = newStage;
  //   this.handleSaveTransition();
  // }

//   async handleAdvanceOption(e) {
//     const newStage = e.target.dataset.value;
//     const ticketId = this.selectedRecord.Id;

//     try {
//         const requiredFields = await getRequiredFieldsForStage({ targetStage: newStage });

//         if (requiredFields && requiredFields.length > 0) {
//             // Fields are required. Close the current modal and open the new one.
//             this.closeModal(); // Close the simple move modal
            
//             this.transitionTicketId = ticketId;
//             this.transitionTargetStage = newStage;
//             this.transitionRequiredFields = requiredFields;
//             this.showTransitionModal = true;
//         } else {
//             // No fields required, proceed with the original save.
//             this.selectedStage = newStage;
//             this.handleSaveTransition();
//         }
//     } catch (error) {
//         this.showToast('Error', 'Could not check for required fields.', 'error');
//         console.error(error);
//     }
// }
//   handleBacktrackOption(e) {
//     const newStage = e.target.dataset.value;
//     this.selectedStage = newStage;
//     this.handleSaveTransition();
//   }

async handleAdvanceOption(e) {
        const newStage = e.target.dataset.value;
        const ticketId = this.selectedRecord.Id;

        try {
            // Call Apex to see if the destination stage has required fields
            const requiredFields = await getRequiredFieldsForStage({ targetStage: newStage });

            if (requiredFields && requiredFields.length > 0) {
                // --- FIELDS ARE REQUIRED ---
                // 1. Close the current selection modal
                this.closeModal(); 
                
                // 2. Set the properties for the new transition modal
                this.transitionTicketId = ticketId;
                this.transitionTargetStage = newStage;
                this.transitionRequiredFields = requiredFields;
                
                // 3. Show the new modal that asks for the fields
                this.showTransitionModal = true;
            } else {
                // --- NO FIELDS REQUIRED ---
                // Proceed with the original, direct move
                this.selectedStage = newStage;
                this.handleSaveTransition();
            }
        } catch (error) {
            this.showToast('Error', 'Could not check for stage requirements.', 'error');
            console.error('Error checking for required fields:', error);
        }
    }

    async handleBacktrackOption(e) {
        const newStage = e.target.dataset.value;
        const ticketId = this.selectedRecord.Id;

        try {
            // Call Apex to see if the destination stage has required fields
            const requiredFields = await getRequiredFieldsForStage({ targetStage: newStage });

            if (requiredFields && requiredFields.length > 0) {
                // --- FIELDS ARE REQUIRED ---
                // 1. Close the current selection modal
                this.closeModal(); 

                // 2. Set the properties for the new transition modal
                this.transitionTicketId = ticketId;
                this.transitionTargetStage = newStage;
                this.transitionRequiredFields = requiredFields;

                // 3. Show the new modal that asks for the fields
                this.showTransitionModal = true;
            } else {
                // --- NO FIELDS REQUIRED ---
                // Proceed with the original, direct move
                this.selectedStage = newStage;
                this.handleSaveTransition();
            }
        } catch (error) {
            this.showToast('Error', 'Could not check for stage requirements.', 'error');
            console.error('Error checking for required fields:', error);
        }
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
          this.realRecords = this.realRecords.map((r) =>
            r.Id === rec.Id ? { ...r, %%%NAMESPACE%%%StageNamePk__c: newStage } : r
          );
        })
        .catch((error) => {
          console.error("Error updating ticket stage:", error);
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
    this.moveComment = "";
    this.isModalOpen = false;
        this.searchResults = [];
        this.searchTerm = '';
  }

  handleDragStart(event) {
    this.isDragging = true;
    const ticketId = event.target.dataset.id;
    event.dataTransfer.setData("text/plain", ticketId);
    event.dataTransfer.effectAllowed = "move";
    this.draggedItem = this.enrichedTickets.find((t) => t.Id === ticketId);

    // Create a placeholder element on the fly
    this.placeholder = document.createElement("div");
    this.placeholder.className = "drag-placeholder";
    // Match the height of the card being dragged for a 1:1 space
    this.placeholder.style.height = `${event.target.offsetHeight}px`;

    const board = this.template.querySelector(".js-kanban-board");
    if (board) {
      board.classList.add("drag-is-active");
    }
    // Add a class to the original element so we can make it look like a "ghost"
    setTimeout(() => {
      event.target.classList.add("is-dragging");
    }, 0);
  }

  handleDragEnd() {
    this.isDragging = false;
    const draggingCard = this.template.querySelector(".is-dragging");
    if (draggingCard) {
      draggingCard.classList.remove("is-dragging");
    }
    // Remove the placeholder from the DOM
    if (this.placeholder && this.placeholder.parentNode) {
      this.placeholder.parentNode.removeChild(this.placeholder);
    }
    this.placeholder = null;

    // Clean up any leftover column highlighting
    this.template
      .querySelectorAll(".kanban-column.drag-over")
      .forEach((col) => {
        col.classList.remove("drag-over");
      });

    const board = this.template.querySelector(".js-kanban-board");
    if (board) {
      board.classList.remove("drag-is-active");
    }
  }

  handleDragOver(event) {
    event.preventDefault();
    const column = event.currentTarget.closest(".kanban-column");
    if (!column) return;

    // Highlight the column
    if (!column.classList.contains("drag-over")) {
      // Debounce adding class to avoid excessive repaints
      this.template
        .querySelectorAll(".kanban-column.drag-over")
        .forEach((col) => col.classList.remove("drag-over"));
      column.classList.add("drag-over");
    }

    // Instead of moving the card, we move the placeholder
    const cardsContainer = column.querySelector(".kanban-column-body");
    const afterElement = this.getDragAfterElement(
      cardsContainer,
      event.clientY
    );

    if (afterElement == null) {
      cardsContainer.appendChild(this.placeholder);
    } else {
      cardsContainer.insertBefore(this.placeholder, afterElement);
    }
  }

  handleDragLeave(event) {
    const column = event.currentTarget.closest(".kanban-column");
    if (column) {
      column.classList.remove("drag-over");
    }
  }

  getDragAfterElement(container, y) {
    const draggableElements = [
      ...container.querySelectorAll(".ticket-card:not(.is-dragging)"),
    ];

    return draggableElements.reduce(
      (closest, child) => {
        const box = child.getBoundingClientRect();
        const offset = y - box.top - box.height / 2;
        if (offset < 0 && offset > closest.offset) {
          return { offset: offset, element: child };
        } else {
          return closest;
        }
      },
      { offset: Number.NEGATIVE_INFINITY }
    ).element;
  }

  

  // async handleDrop(event) {
  //   event.preventDefault();

  //   const ticketId = this.draggedItem.Id;
  //   const sourceColumnStage = this.stageColumns.find((col) =>
  //     col.tickets.some((t) => t.Id === ticketId)
  //   ).stage;

  //   const dropColumnEl = event.target.closest(".kanban-column");
  //   if (!dropColumnEl) {
  //     this.handleDragEnd(); // Abort if dropped outside a valid column
  //     return;
  //   }
  //   const targetColumnStage = dropColumnEl.dataset.stage;

  //   // SCENARIO 1: INTRA-COLUMN DROP (Reordering)
  //   if (sourceColumnStage === targetColumnStage) {
  //     const columnTickets = this.stageColumns.find(
  //       (c) => c.stage === targetColumnStage
  //     ).tickets;
  //     const newSortOrder = this.calculateNewSortOrder(
  //       this.placeholder,
  //       columnTickets
  //     );

  //     try {
  //       await updateTicketSortOrder({
  //         ticketId: ticketId,
  //         newSortOrder: newSortOrder,
  //       });
  //       this.showToast("Success", "Ticket reordered.", "success");
  //     } catch (error) {
  //       this.showToast("Error", "Failed to reorder ticket.", "error");
  //       console.error(error);
  //     }
  //   }
  //   // SCENARIO 2: INTER-COLUMN DROP (Status Change)
  //   else {
  //     const statuses =
  //       this.personaColumnStatusMap[this.persona][targetColumnStage] || [];
  //     const newInternalStage = statuses[0];

  //     if (newInternalStage) {
  //       try {
  //         // When moving to a new column, you might want to set a default sort order,
  //         // e.g., place it at the top. Here we don't pass a sort order and let Apex handle it.
  //         await updateTicketStage({
  //           ticketId: ticketId,
  //           newStage: newInternalStage,
  //         });
  //         this.showToast("Success", "Ticket moved.", "success");
  //       } catch (error) {
  //         this.showToast("Error", "Failed to move ticket.", "error");
  //         console.error(error);
  //       }
  //     }
  //   }

  //   this.refreshTickets();
  //   // DragEnd will handle final cleanup
  // }

  async handleDrop(event) {
    event.preventDefault();
    const ticketId = this.draggedItem.Id;
    const dropColumnEl = event.target.closest('.kanban-column');
    if (!dropColumnEl) {
        this.handleDragEnd(); // Abort if dropped outside a valid column
        return;
    }

    const targetColumnStage = dropColumnEl.dataset.stage;
    const sourceColumnStage = this.stageColumns.find(col => col.tickets.some(t => t.Id === ticketId)).stage;
    
    // Always clean up drag styles
    this.handleDragEnd();

    // SCENARIO 1: INTRA-COLUMN DROP (Reordering - no status change)
    if (sourceColumnStage === targetColumnStage) {
        const columnTickets = this.stageColumns.find(c => c.stage === targetColumnStage).tickets;
        const newSortOrder = this.calculateNewSortOrder(this.placeholder, columnTickets);
        try {
            await updateTicketSortOrder({ ticketId: ticketId, newSortOrder: newSortOrder });
            this.showToast('Success', 'Ticket reordered.', 'success');
            this.refreshTickets();
        } catch (error) {
            this.showToast('Error', 'Failed to reorder ticket.', 'error');
            console.error(error);
        }
        return; // Stop execution here
    }

    // SCENARIO 2: INTER-COLUMN DROP (Status Change)
    const newInternalStage = (this.personaColumnStatusMap[this.persona][targetColumnStage] || [])[0];

    if (newInternalStage) {
        try {
            // Check if this transition requires extra fields
            console.log('stage '+newInternalStage);
            const requiredFields = await getRequiredFieldsForStage({ targetStage: newInternalStage });
            console.log('requiredfields '+requiredFields);
            if (requiredFields && requiredFields.length > 0) {
                // --- FIELDS ARE REQUIRED: Show the modal ---
                console.log('enter required fields if');
                this.transitionTicketId = ticketId;
                this.transitionTargetStage = newInternalStage;
                this.transitionRequiredFields = requiredFields;
                this.showTransitionModal = true;
            } else {
                // --- NO FIELDS REQUIRED: Perform the original direct update ---
                await updateTicketStage({ ticketId: ticketId, newStage: newInternalStage })
                    .then(() => {
                        this.showToast('Success', 'Ticket moved.', 'success');
                        this.refreshTickets();
                    })
                    .catch(error => {
                        // This will now catch the error from your trigger!
                        const errorMessage = error.body.message || 'An unknown error occurred.';
                        this.showToast('Move Failed', errorMessage, 'error');
                        // No need to refresh data, as the move was prevented
                    });
                // this.showToast('Success', 'Ticket moved successfully.', 'success');
                this.refreshTickets();
            }
        } catch (error) {
            this.showToast('Error Moving Ticket', error.body ? error.body.message : error.message, 'error');
            console.error('Error on drop:', error);
        }
    }
}

closeTransitionModal() {
    this.showTransitionModal = false;
    this.transitionTicketId = null;
    this.transitionTargetStage = null;
    this.transitionRequiredFields = [];
}

handleTransitionSuccess(event) {
    this.showToast('Success', 'Ticket has been successfully updated and moved.', 'success');
    // The form automatically saved the record, now we just close the modal and refresh
    this.closeTransitionModal();
    this.refreshTickets();
}

handleTransitionError(event) {
    // The lightning-record-edit-form automatically displays field-level errors.
    // This handler is for more general errors.
    this.showToast('Error Saving Ticket', 'Please review the fields and try again.', 'error');
    console.error('Error on transition save:', JSON.stringify(event.detail));
}


  // 3. ADD this new helper function to calculate sort order
  calculateNewSortOrder(placeholder, columnTickets) {
    const prevSibling = placeholder.previousElementSibling;
    const nextSibling = placeholder.nextElementSibling;

    // Find the corresponding ticket data for the siblings
    const prevTicket = prevSibling
      ? columnTickets.find((t) => t.Id === prevSibling.dataset.id)
      : null;
    const nextTicket = nextSibling
      ? columnTickets.find((t) => t.Id === nextSibling.dataset.id)
      : null;

    const sortBefore = prevTicket ? prevTicket.%%%NAMESPACE%%%SortOrderNumber__c : 0;

    if (nextTicket) {
      // Dropped between two cards
      return (sortBefore + nextTicket.%%%NAMESPACE%%%SortOrderNumber__c) / 2.0;
    } else {
      // Dropped at the end of the list
      return sortBefore + 1; // Or a larger number like 1000 to be safe
    }
  }

  // 4. ADD a handler to open the modal (you may have this already)
  handleCardClick(e) {
    const id = e.currentTarget.dataset.id;
    this.selectedRecord = (this.realRecords || []).find((r) => r.Id === id);
    this.showModal = true;
    this.moveComment = "";
  }

  // handleCardClick(e) {
  //   const id = e.currentTarget.dataset.id;
  //   this.selectedRecord = (this.realRecords || []).find((r) => r.Id === id);
  //   this.showModal = true;
  //   this.moveComment = "";
  // }

  handleManageDependenciesClick(event) {
        const ticketId = event.currentTarget.dataset.id;
        console.log('ticketId '+ticketId);
        // Find the full ticket object from your enriched data
        this.selectedTicket = this.enrichedTickets.find(t => t.Id === ticketId);
        if (this.selectedTicket) {
            this.isModalOpen = true;
        }
    }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title,
      message,
      variant,
    });
    this.dispatchEvent(event);
  }

  // Handle field changes to track current values
  handleFieldChange(event) {
    const fieldName = event.target.fieldName;
    const fieldValue = event.target.value;

    this.formFieldValues[fieldName] = fieldValue;

    // Update specific tracked properties for AI enhancement
    if (fieldName === "BriefDescriptionTxt__c") {
      this.createTicketTitle = fieldValue || "";
    } else if (fieldName === "DetailsTxt__c") {
      this.createTicketDescription = fieldValue || "";
    }
  }

  // --- AI Enhancement Methods ---
  async handleAiEnhance(event) {
    try {
      // 1. Get current field values using multiple approaches
      let titleValue = "";
      let descriptionValue = "";

      // Method 1: Try to get from tracked form field values
      titleValue = this.formFieldValues["BriefDescriptionTxt__c"] || "";
      descriptionValue = this.formFieldValues["%%%NAMESPACE%%%DetailsTxt__c"] || "";

      // Method 2: Try to get directly from input elements if Method 1 fails
      if (!titleValue || !descriptionValue) {
        const titleField = this.template.querySelector(
          'lightning-input-field[field-name="%%%NAMESPACE%%%BriefDescriptionTxt__c"]'
        );
        const descriptionField = this.template.querySelector(
          'lightning-input-field[field-name="%%%NAMESPACE%%%DetailsTxt__c"]'
        );

        if (titleField && !titleValue) {
          const titleInput = titleField.querySelector("input, textarea");
          titleValue = titleInput ? titleInput.value || "" : "";
        }

        if (descriptionField && !descriptionValue) {
          const descInput = descriptionField.querySelector("input, textarea");
          descriptionValue = descInput ? descInput.value || "" : "";
        }
      }

      // Method 3: Fallback to tracked properties
      if (!titleValue) {
        titleValue = this.createTicketTitle || "";
      }
      if (!descriptionValue) {
        descriptionValue = this.createTicketDescription || "";
      }

      // Update tracked properties
      this.createTicketTitle = titleValue;
      this.createTicketDescription = descriptionValue;

      // Debug logging
      console.log("AI Enhancement Debug:", {
        titleValue: titleValue,
        descriptionValue: descriptionValue,
        titleTrimmed: titleValue.trim(),
        descriptionTrimmed: descriptionValue.trim(),
        titleLength: titleValue.length,
        descriptionLength: descriptionValue.length,
        formFieldValues: this.formFieldValues,
      });

      // Validate input requirements - if still no values, try one more time with a delay
      if (!titleValue.trim() && !descriptionValue.trim()) {
        // Wait a bit and try again in case the DOM needs time to update
        await new Promise((resolve) => setTimeout(resolve, 100));

        const titleField = this.template.querySelector(
          'lightning-input-field[field-name="BriefDescriptionTxt__c"]'
        );
        const descriptionField = this.template.querySelector(
          'lightning-input-field[field-name="DetailsTxt__c"]'
        );

        if (titleField) {
          const titleInput = titleField.querySelector("input, textarea");
          titleValue = titleInput ? titleInput.value || "" : "";
        }

        if (descriptionField) {
          const descInput = descriptionField.querySelector("input, textarea");
          descriptionValue = descInput ? descInput.value || "" : "";
        }

        console.log("AI Enhancement Debug (after delay):", {
          titleValue: titleValue,
          descriptionValue: descriptionValue,
        });

        if (!titleValue.trim() && !descriptionValue.trim()) {
          this.showToast(
            "Input Required",
            'Please provide at least a title or description for the AI to enhance. Make sure to enter some text in the form fields before clicking "Enhance with AI".',
            "warning"
          );
          return;
        }
      }

      // Check if already processing
      if (this.isAiProcessing) {
        this.showToast(
          "Processing",
          "AI enhancement is already in progress. Please wait.",
          "info"
        );
        return;
      }

      // 2. Set loading state
      this.isAiProcessing = true;
      this.aiSuggestions = null; // Clear old suggestions

      // 3. Call Apex with timeout handling
      const result = await Promise.race([
        getAiEnhancedTicketDetails({
          currentTitle: this.createTicketTitle,
          currentDescription: this.createTicketDescription,
        }),
        new Promise(
          (_, reject) =>
            setTimeout(() => reject(new Error("Request timeout")), 30000) // 30 second timeout
        ),
      ]);

      // Validate response
      if (!result || typeof result !== "object") {
        throw new Error("Invalid response from AI service");
      }

      if (!result.title && !result.description) {
        throw new Error("AI service returned empty suggestions");
      }

      this.aiSuggestions = result;
      this.showToast(
        "Success",
        "AI suggestions generated successfully!",
        "success"
      );
    } catch (error) {
      // Enhanced error handling with specific messages
      let errorMessage = "Could not retrieve AI suggestions. Please try again.";

      if (error.message === "Request timeout") {
        errorMessage =
          "AI request timed out. Please try again with shorter input.";
      } else if (error.message.includes("Invalid response")) {
        errorMessage =
          "AI service returned invalid data. Please contact support.";
      } else if (error.message.includes("empty suggestions")) {
        errorMessage =
          "AI could not generate suggestions for this input. Try providing more details.";
      } else if (error.body && error.body.message) {
        errorMessage = error.body.message;
      }

      this.showToast("AI Error", errorMessage, "error");
      console.error("AI Enhancement Error:", error);

      // Log additional debug information
      console.debug("AI Enhancement Debug Info:", {
        title: this.createTicketTitle,
        description: this.createTicketDescription,
        error: error,
      });
    } finally {
      // 4. Always reset loading state
      this.isAiProcessing = false;
    }
  }

  applyAiSuggestions() {
    try {
      if (!this.aiSuggestions) {
        this.showToast("Error", "No AI suggestions available to apply.", "error");
        return;
      }

      console.log("Applying AI suggestions:", this.aiSuggestions);

      let appliedFields = [];

      // Update reactive properties - this should automatically update the form fields
      if (this.aiSuggestions.title) {
        this.createTicketTitle = this.aiSuggestions.title;
        this.formFieldValues["BriefDescriptionTxt__c"] = this.aiSuggestions.title;
        appliedFields.push("title");
      }

      if (this.aiSuggestions.description) {
        this.createTicketDescription = this.aiSuggestions.description;
        this.formFieldValues["DetailsTxt__c"] = this.aiSuggestions.description;
        appliedFields.push("description");
      }

      if (this.aiSuggestions.estimatedDays && this.AiEstimation) {
        this.estimatedDaysValue = this.aiSuggestions.estimatedDays;
        this.formFieldValues["DeveloperDaysSizeNumber__c"] = this.aiSuggestions.estimatedDays;
        appliedFields.push("estimated days");
      }

      // Force a re-render by updating the template
      setTimeout(() => {
        // Trigger change events to ensure form validation works
        this.template.querySelectorAll("lightning-input-field").forEach((field) => {
          field.dispatchEvent(new CustomEvent("change", { bubbles: true }));
        });
      }, 100);

      if (appliedFields.length === 0) {
        this.showToast("Warning", "No valid suggestions found to apply.", "warning");
        return;
      }

      // Clear the suggestions
      this.aiSuggestions = null;
      this.showToast("Success", `AI suggestions applied: ${appliedFields.join(", ")}.`, "success");
    } catch (error) {
      console.error("Error applying AI suggestions:", error);
      this.showToast("Error", "Failed to apply AI suggestions. Please try manually copying the values.", "error");
    }
  }

  // Helper method to set field values using multiple approaches
  setFieldValue(fieldName, value) {
    if (!value) return;

    console.log(`Setting field ${fieldName} to:`, value);

    // Method 1: Try to set via lightning-input-field
    const inputField = this.template.querySelector(`lightning-input-field[field-name="${fieldName}"]`);
    if (inputField) {
      // Try to set the value property directly
      try {
        inputField.value = value;
        console.log(`Set ${fieldName} via inputField.value`);
      } catch (e) {
        console.log(`Failed to set ${fieldName} via inputField.value:`, e);
      }

      // Try to find and set the internal input element
      setTimeout(() => {
        const internalInput = inputField.querySelector("input, textarea");
        if (internalInput) {
          internalInput.value = value;
          internalInput.dispatchEvent(new Event("input", { bubbles: true }));
          internalInput.dispatchEvent(new Event("change", { bubbles: true }));
          internalInput.dispatchEvent(new Event("blur", { bubbles: true }));
          console.log(`Set ${fieldName} via internal input element`);
        }
      }, 50);

      // Try to trigger a focus and blur to force update
      setTimeout(() => {
        try {
          inputField.focus();
          inputField.blur();
        } catch (e) {
          console.log(`Failed to focus/blur ${fieldName}:`, e);
        }
      }, 100);
    }

    // Method 2: Try to set via form's setFieldValue if available
    const form = this.template.querySelector("lightning-record-edit-form");
    if (form && typeof form.setFieldValue === "function") {
      try {
        form.setFieldValue(fieldName, value);
        console.log(`Set ${fieldName} via form.setFieldValue`);
      } catch (e) {
        console.log(`Failed to set ${fieldName} via form.setFieldValue:`, e);
      }
    }
  }

  dismissAiSuggestions() {
    this.aiSuggestions = null;
  }

  // --- Update existing modal handlers to reset AI state ---
  handleCreateCancel() {
    this.showCreateModal = false;
    // Reset AI state on cancel
    this.aiSuggestions = null;
    this.isAiProcessing = false;
    this.createTicketTitle = "";
    this.createTicketDescription = "";
    this.formFieldValues = {};
  }

  handleCreateSuccess(event) {
    this.showCreateModal = false;
    const newTicketId = event.detail.id;

    // If files were uploaded, link them to the ticket and sync to Jira
    if (this.uploadedFileIds.length > 0) {
      linkFilesAndSync({
        ticketId: newTicketId,
        contentDocumentIds: this.uploadedFileIds,
      }).catch((error) => {
        console.error("Error linking files and syncing to Jira:", error);
      });
      this.uploadedFileIds = []; // Clear the array for the next modal
    }

    // Reset AI state on success
    this.aiSuggestions = null;
    this.isAiProcessing = false;
    this.createTicketTitle = "";
    this.createTicketDescription = "";
    this.formFieldValues = {};

    // Re-query tickets so the new card appears:
    this.refreshTickets();
  }


    // closeModal() {
    //     this.isModalOpen = false;
    //     this.searchResults = [];
    //     this.searchTerm = '';
    // }

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
    }

    async handleSearch() {
        if (this.searchTerm.length < 3) {
            // Optional: Add a toast message to enter more characters
            return;
        }
        console.log('issearching');
        this.isSearching = true;

        // Create a set of existing dependency IDs to exclude them from the search
        const existingDependencyIds = new Set([
            ...this.selectedTicket.isBlockedBy.map(d => d.id),
            ...this.selectedTicket.isBlocking.map(d => d.id)
        ]);
        
        try {
            this.searchResults = await searchForPotentialBlockers({
                searchTerm: this.searchTerm,
                currentTicketId: this.selectedTicket.Id,
                existingDependencyIds: [...existingDependencyIds]
            });
        } catch (error) {
            // Handle error with a toast message
        } finally {
            this.isSearching = false;
        }
    }

    async handleSelectBlockingTicket(event) {
        const blockingTicketId = event.currentTarget.dataset.blockingId;
        
        try {
            await createDependency({
                blockedTicketId: this.selectedTicket.Id,
                blockingTicketId: blockingTicketId
            });
            // Show success toast
            this.closeModal();
            this.refreshTickets(); // Your method to refresh all board data
        } catch (error) {
            // Handle error with a toast message
        }
    }

    async handleRemoveDependency(event) {
        const dependencyId = event.currentTarget.dataset.dependencyId;
        
        try {
            await removeDependency({ dependencyId: dependencyId });
            // Show success toast
            this.closeModal();
            this.refreshTickets(); // Refresh board data
        } catch (error) {
            // Handle error with a toast message
        }
    }

}

