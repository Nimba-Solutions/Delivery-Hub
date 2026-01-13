import { LightningElement, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";
import { updateRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

// --- Namespaced Apex Imports ---
import getTickets from "@salesforce/apex/TicketController.getTickets";
import linkFilesAndSync from "@salesforce/apex/TicketController.linkFilesAndSync";
import getAiEnhancedTicketDetails from "@salesforce/apex/TicketController.getAiEnhancedTicketDetails";
import getTicketETAsWithPriority from "@salesforce/apex/TicketETAService.getTicketETAsWithPriority";
import updateTicketStage from "@salesforce/apex/DragAndDropLwcController.updateTicketStage";
import updateTicketSortOrder from "@salesforce/apex/DragAndDropLwcController.updateTicketSortOrder";
import getRequiredFieldsForStage from '@salesforce/apex/TicketController.getRequiredFieldsForStage';
import searchForPotentialBlockers from '@salesforce/apex/DragAndDropLwcController.searchForPotentialBlockers';
import createDependency from '@salesforce/apex/DragAndDropLwcController.createDependency';
import removeDependency from '@salesforce/apex/DragAndDropLwcController.removeDependency';
import getSettings from '@salesforce/apex/DeliveryHubSettingsController.getSettings';

// --- NAMESPACE BRIDGE ---
const FIELDS = {
    ID: 'Id',
    NAME: 'Name',
    BRIEF_DESC: `%%%NAMESPACED_ORG%%%BriefDescriptionTxt__c`,
    DETAILS: `%%%NAMESPACED_ORG%%%DetailsTxt__c`,
    STAGE: `%%%NAMESPACED_ORG%%%StageNamePk__c`,
    PRIORITY: `%%%NAMESPACED_ORG%%%PriorityPk__c`,
    SORT_ORDER: `%%%NAMESPACED_ORG%%%SortOrderNumber__c`,
    IS_ACTIVE: `%%%NAMESPACED_ORG%%%IsActiveBool__c`,
    TAGS: `%%%NAMESPACED_ORG%%%Tags__c`,
    EPIC: `%%%NAMESPACED_ORG%%%Epic__c`,
    INTENTION: `%%%NAMESPACED_ORG%%%ClientIntentionPk__c`,
    DEV_DAYS_SIZE: `%%%NAMESPACED_ORG%%%DeveloperDaysSizeNumber__c`,
    CALCULATED_ETA: `%%%NAMESPACED_ORG%%%CalculatedETADate__c`,
    PROJECTED_UAT_READY: `%%%NAMESPACED_ORG%%%ProjectedUATReadyDate__c`,
    DEVELOPER: `%%%NAMESPACED_ORG%%%Developer__c`,
    // Relationships
    DEP_REL_BLOCKED_BY: `%%%NAMESPACED_ORG%%%Ticket_Dependency1__r`,
    DEP_REL_BLOCKING: `%%%NAMESPACED_ORG%%%Ticket_Dependency__r`,
    BLOCKING_TICKET: `%%%NAMESPACED_ORG%%%Blocking_Ticket__c`,
    BLOCKED_TICKET: `%%%NAMESPACED_ORG%%%Blocked_Ticket__c`
};

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
    @track numDevs = 2;
    @track etaResults = [];
    @track showAllColumns = false; // Default set to false as requested
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
    @track isModalOpen = false;
    @track selectedTicket = {};
    @track searchTerm = '';
    @track searchResults = [];
    @track isSearching = false;

    ticketsWire;

  // Visual Rules: Queues (Light), Work (Active Colors), Hold (Red)
  statusColorMap = {
    // 1. Intake
    "Backlog": "#F3F4F6", // Light Grey (Queue)
    "Scoping In Progress": "#FEF3C7", // Amber (Work)
    
    // 2. Definition & Sizing
    "Clarification Requested (Pre-Dev)": "#E0F2FE", // Light Blue (Queue)
    "Providing Clarification": "#DBEAFE", // Blue (Work)
    "Ready for Sizing": "#E0F2FE", // Light Blue (Queue)
    "Sizing Underway": "#FFEDD5", // Orange (Work)
    "Ready for Prioritization": "#E0F2FE", // Light Blue (Queue)
    "Prioritizing": "#DBEAFE", // Blue (Work)
    "Proposal Requested": "#E0F2FE", // Light Blue (Queue)
    "Drafting Proposal": "#FFEDD5", // Orange (Work)
    
    // 3. Approval
    "Ready for Tech Review": "#E0F2FE", // Light Blue (Queue)
    "Tech Reviewing": "#FEF3C7", // Amber (Work)
    "Ready for Client Approval": "#E0F2FE", // Light Blue (Queue)
    "In Client Approval": "#DBEAFE", // Blue (Work)
    
    // 4. Development
    "Ready for Development": "#DCFCE7", // Light Green (Queue)
    "In Development": "#FF9100", // Strong Orange (Work)
    "Dev Clarification Requested": "#FEE2E2", // Red (Queue - Issue)
    "Providing Dev Clarification": "#DBEAFE", // Blue (Work)
    "Back For Development": "#EF4444", // Strong Red (Action Required)
    "Dev Blocked": "#EF4444", // Strong Red (Blocked)
    
    // 5. Testing (QA)
    "Ready for Scratch Test": "#E0F2FE", // Light Blue (Queue)
    "Scratch Testing": "#22C55E", // Green (Work)
    "Ready for QA": "#E0F2FE", // Light Blue (Queue)
    "QA In Progress": "#22C55E", // Green (Work)
    "Ready for Internal UAT": "#E0F2FE", // Light Blue (Queue)
    "Internal UAT": "#1D4ED8", // Strong Blue (Work)
    
    // 6. Client UAT
    "Ready for Client UAT": "#E0F2FE", // Light Blue (Queue)
    "In Client UAT": "#2563EB", // Strong Blue (Work)
    "Ready for UAT Sign-off": "#E0F2FE", // Light Blue (Queue)
    "Processing Sign-off": "#DBEAFE", // Blue (Work)
    
    // 7. Deployment
    "Ready for Merge": "#F3E8FF", // Light Purple (Queue)
    "Merging": "#7C3AED", // Purple (Work)
    "Ready for Deployment": "#F3E8FF", // Light Purple (Queue)
    "Deploying": "#7C3AED", // Purple (Work)
    "Deployed to Prod": "#059669", // Dark Green (End)
    
    // End States
    "Done": "#374151", // Dark Grey
    "Cancelled": "#9CA3AF" // Grey
  };

  // Maps Column Keys to Visual Styles (Backgrounds match status groups)
  columnHeaderStyleMap = {
    // --- Client Columns ---
    "Backlog": { bg: "rgba(243, 244, 246, 0.8)", color: "#1F2937" },
    "Scoping": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" }, // Amber
    
    // Split Clarification
    "Clarification Requested (Pre-Dev)": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" }, // Red/Clarification
    "Providing Clarification": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" },
    "Clarification": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" }, // Merged

    // Split Estimation
    "Ready for Sizing": { bg: "rgba(224, 242, 254, 0.5)", color: "#0284C7" }, // Blue
    "Sizing Underway": { bg: "rgba(255, 237, 213, 0.5)", color: "#EA580C" }, // Orange
    "Estimation": { bg: "rgba(255, 237, 213, 0.5)", color: "#EA580C" }, // Merged
    "Sizing": { bg: "rgba(255, 237, 213, 0.5)", color: "#EA580C" }, // Merged

    // Split Prioritization
    "Ready for Prioritization": { bg: "rgba(224, 242, 254, 0.5)", color: "#0284C7" }, 
    "Prioritizing": { bg: "rgba(224, 242, 254, 0.5)", color: "#0284C7" }, 
    "Prioritization": { bg: "rgba(224, 242, 254, 0.5)", color: "#0284C7" }, // Merged

    // Split Proposal
    "Proposal Requested": { bg: "rgba(255, 237, 213, 0.5)", color: "#EA580C" },
    "Drafting Proposal": { bg: "rgba(255, 237, 213, 0.5)", color: "#EA580C" },
    "Proposal": { bg: "rgba(255, 237, 213, 0.5)", color: "#EA580C" }, // Merged
    
    // Split Approvals
    "Ready for Tech Review": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
    "Tech Reviewing": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
    "Dev Approval": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" }, // Merged
    "Ready for Client Approval": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
    "In Client Approval": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
    "Client Approval": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" }, // Merged
    "Approvals": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" }, // Merged both
    
    "Clarification (In-Dev)": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" },
    // Split Dev Clarification
    "Dev Clarification Requested": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" },
    "Providing Dev Clarification": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" },

    "Ready for Dev": { bg: "rgba(220, 252, 231, 0.5)", color: "#16A34A" }, // Green
    "In Development": { bg: "rgba(255, 145, 0, 0.3)", color: "#C2410C" }, // Strong Orange
    "In Review": { bg: "rgba(219, 234, 254, 0.5)", color: "#1D4ED8" }, // Blue
    "Ready for UAT": { bg: "rgba(191, 219, 254, 0.5)", color: "#2563EB" }, // Stronger Blue
    
    // Split Client UAT
    "Ready for Client UAT": { bg: "rgba(191, 219, 254, 0.5)", color: "#2563EB" },
    "In Client UAT": { bg: "rgba(191, 219, 254, 0.5)", color: "#2563EB" },
    "Ready for UAT Sign-off": { bg: "rgba(221, 214, 254, 0.5)", color: "#7C3AED" },
    "Processing Sign-off": { bg: "rgba(221, 214, 254, 0.5)", color: "#7C3AED" },
    "Client UAT": { bg: "rgba(191, 219, 254, 0.5)", color: "#2563EB" }, // Merged
    "UAT": { bg: "rgba(191, 219, 254, 0.5)", color: "#2563EB" }, // Merged

    "Ready For Prod": { bg: "rgba(221, 214, 254, 0.5)", color: "#7C3AED" }, // Purple
    "Deployed": { bg: "rgba(209, 250, 229, 0.5)", color: "#059669" }, // Emerald
    "Done": { bg: "rgba(229, 231, 235, 0.5)", color: "#374151" },
    "Cancelled": { bg: "rgba(229, 231, 235, 0.5)", color: "#6B7280" },

    // --- Consultant / Developer / QA Granular Columns ---
    "Intake": { bg: "rgba(243, 244, 246, 0.8)", color: "#1F2937" },
    "Scoping In Progress": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
    "Dev Queue": { bg: "rgba(220, 252, 231, 0.5)", color: "#16A34A" },
    "Dev Work": { bg: "rgba(255, 145, 0, 0.3)", color: "#C2410C" },
    "QA Queue": { bg: "rgba(219, 234, 254, 0.5)", color: "#1E40AF" },
    "QA Work": { bg: "rgba(191, 219, 254, 0.5)", color: "#1D4ED8" },
    "Merge & Deploy": { bg: "rgba(237, 233, 254, 0.5)", color: "#6D28D9" },
    "Ready for Merge": { bg: "rgba(237, 233, 254, 0.5)", color: "#6D28D9" },
    "Merging": { bg: "rgba(237, 233, 254, 0.5)", color: "#6D28D9" },
    "Ready for Deployment": { bg: "rgba(237, 233, 254, 0.5)", color: "#6D28D9" },
    "Deploying": { bg: "rgba(237, 233, 254, 0.5)", color: "#6D28D9" },
    
    "QA & Review": { bg: "rgba(219, 234, 254, 0.5)", color: "#1D4ED8" }, // Merged
    "QA": { bg: "rgba(219, 234, 254, 0.5)", color: "#1E40AF" }, // Merged
    "Ready for Scratch Test": { bg: "rgba(219, 234, 254, 0.5)", color: "#1E40AF" },
    "Scratch Testing": { bg: "rgba(219, 234, 254, 0.5)", color: "#1E40AF" },
    "Ready for QA": { bg: "rgba(219, 234, 254, 0.5)", color: "#1E40AF" },
    "QA In Progress": { bg: "rgba(191, 219, 254, 0.5)", color: "#1D4ED8" },
    "Ready for Internal UAT": { bg: "rgba(219, 234, 254, 0.5)", color: "#1E40AF" },
    "Internal UAT": { bg: "rgba(191, 219, 254, 0.5)", color: "#1D4ED8" },
    "Deployment Prep": { bg: "rgba(221, 214, 254, 0.5)", color: "#7C3AED" }, // Merged
    "Deployment": { bg: "rgba(237, 233, 254, 0.5)", color: "#6D28D9" }, // Merged

    // Explicit keys for internal views to match Client splits if needed
    "Pending Tech Approval": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" }, 
    "Pending Client Approval": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" }
  };

  /** Who owns each status - Source of Truth **/
  statusOwnerMap = {
    // 1. Intake
    "Backlog": "Consultant",
    "Scoping In Progress": "Consultant",
    
    // 2. Definition & Sizing
    "Clarification Requested (Pre-Dev)": "Client",
    "Providing Clarification": "Client",
    "Ready for Sizing": "Developer",
    "Sizing Underway": "Developer",
    "Ready for Prioritization": "Client",
    "Prioritizing": "Client",
    "Proposal Requested": "Developer",
    "Drafting Proposal": "Developer",
    
    // 3. Approval
    "Ready for Tech Review": "Consultant",
    "Tech Reviewing": "Consultant",
    "Ready for Client Approval": "Client",
    "In Client Approval": "Client",
    
    // 4. Development
    "Ready for Development": "Developer",
    "In Development": "Developer",
    "Dev Clarification Requested": "Client",
    "Providing Dev Clarification": "Client",
    "Back For Development": "Developer",
    "Dev Blocked": "Developer",
    
    // 5. Testing
    "Ready for Scratch Test": "QA",
    "Scratch Testing": "QA",
    "Ready for QA": "QA",
    "QA In Progress": "QA",
    "Ready for Internal UAT": "Consultant",
    "Internal UAT": "Consultant",
    
    // 6. UAT
    "Ready for Client UAT": "Client",
    "In Client UAT": "Client",
    "Ready for UAT Sign-off": "Client",
    "Processing Sign-off": "Client",
    
    // 7. Deployment
    "Ready for Merge": "Consultant",
    "Merging": "Consultant",
    "Ready for Deployment": "Consultant",
    "Deploying": "Consultant",
    
    // End
    "Deployed to Prod": "System",
    "Done": "All",
    "Cancelled": "All"
  };

  /** Color palette per persona **/
  ownerColorMap = {
    Client: "#2196F3", // blue
    Consultant: "#FFD600", // yellow
    Developer: "#FF9100", // orange
    QA: "#00C853", // green
    System: "#9E9E9E", // grey
    Default: "#BDBDBD", 
  };

  columnDisplayNames = {
    // Client Display Names (Full Words, No Shorthands)
    "Backlog": "Backlog",
    "Scoping": "Scoping",
    "Clarification Requested (Pre-Dev)": "Clarification Requested",
    "Providing Clarification": "Providing Clarification",
    "Clarification": "Clarification", // Merged
    
    "Estimation": "Estimation", // Merged
    "Ready for Sizing": "Ready for Sizing",
    "Sizing Underway": "Sizing Underway",
    "Sizing": "Sizing", // Merged
    
    "Prioritization": "Prioritization", // Merged
    "Ready for Prioritization": "Ready for Prioritization",
    "Prioritizing": "Prioritizing",
    "Proposal Requested": "Proposal Requested",
    "Drafting Proposal": "Drafting Proposal",
    "Proposal": "Proposal", // Merged
    
    // Approvals
    "Dev Approval": "Dev Approval", // Merged
    "Ready for Tech Review": "Ready for Tech Review",
    "Tech Reviewing": "Tech Reviewing",
    "Client Approval": "Client Approval", // Merged
    "Ready for Client Approval": "Ready for Client Approval",
    "In Client Approval": "In Client Approval",
    "Approvals": "Approvals", // Merged
    
    // Dev
    "In Development": "In Development", // Merged
    "Dev Queue": "Dev Queue", // Split
    "Dev Work": "Dev Work", // Split
    "Ready for Development": "Ready for Dev",
    
    // Dev Clarification
    "Dev Clarification Requested": "Dev Clarification Requested",
    "Providing Dev Clarification": "Providing Dev Clarification",
    "Clarification (In-Dev)": "Dev Clarification",

    // Testing
    "QA & Review": "QA & Review", // Merged
    "QA": "QA", // Merged
    "Ready for Scratch Test": "Ready for Scratch Test",
    "Scratch Testing": "Scratch Testing",
    "Ready for QA": "Ready for QA",
    "QA In Progress": "QA In Progress",
    "Ready for Internal UAT": "Ready for Internal UAT",
    "Internal UAT": "Internal UAT",
    
    // Client UAT
    "Client UAT": "Client UAT", // Merged
    "UAT": "UAT", // Merged
    "Ready for Client UAT": "Ready for Client UAT",
    "In Client UAT": "In Client UAT",
    "Ready for UAT Sign-off": "Ready for UAT Sign-off",
    "Processing Sign-off": "Processing Sign-off",

    // Deployment
    "Deployment Prep": "Deployment Prep", // Merged
    "Deployment": "Deployment", // Merged
    "Ready for Merge": "Ready for Merge",
    "Merging": "Merging",
    "Ready for Deployment": "Ready for Deployment",
    "Deploying": "Deploying",

    "Deployed": "Deployed",
    "Done": "Done",
    "Cancelled": "Cancelled",
    
    // Granular View Keys (if needed for Consultant/Dev)
    "Intake": "Intake Queue",
    "Scoping In Progress": "Active Scoping",
    "Ready for Development": "Dev Queue",
    "Back For Development": "Rework",
    "Dev Blocked": "Blocked",
    "Ready for Scratch Test": "To Scratch Test",
    "Scratch Testing": "Scratch Testing",
    "Ready for QA": "To QA",
    "QA In Progress": "QA",
    "Ready for Internal UAT": "To Internal UAT",
    "Internal UAT": "Internal UAT",
    "Ready for Merge": "To Merge",
    "Merging": "Merging",
    "Ready for Deployment": "To Deploy",
    "Deploying": "Deploying",
    
    // Explicit keys matching personaColumnStatusMap
    "Pending Tech Approval": "Tech Approval",
    "Pending Client Approval": "Client Approval",
    "QA & Review": "QA & Review",
    "Dev Queue": "Dev Queue",
    "Dev Work": "Dev Work"
  };

  // Maps New 36 Stages into Existing Column Keys (Aggregation Strategy from Table 1)
  personaColumnStatusMap = {
    // Client: Core/Split for [Backlog, Scoping, Clarif, Prio, ClientApp, ClientUAT]
    // Ext/Merge for [Estimation, DevApp, QA/Testing, Deployment]. Core/Merge for [Development].
    Client: {
      "Backlog": ["Backlog"],
      "Scoping": ["Scoping In Progress"],
      
      // Split Clarification (Core)
      "Clarification Requested (Pre-Dev)": ["Clarification Requested (Pre-Dev)"],
      "Providing Clarification": ["Providing Clarification"],
      
      // Merged Estimation (Extended)
      "Estimation": ["Ready for Sizing", "Sizing Underway"], 
      
      // Split Prioritization (Core)
      "Ready for Prioritization": ["Ready for Prioritization"],
      "Prioritizing": ["Prioritizing"],
      // Proposal is part of Prioritization in Table 1, but user JSON separated it.
      "Proposal Requested": ["Proposal Requested"],
      "Drafting Proposal": ["Drafting Proposal"],
      
      // Merged Dev Approval (Extended)
      "Dev Approval": ["Ready for Tech Review", "Tech Reviewing"],
      
      // Split Client Approval (Core)
      "Ready for Client Approval": ["Ready for Client Approval"],
      "In Client Approval": ["In Client Approval"],
      
      // Merged Development (Core)
      "In Development": ["Ready for Development", "In Development", "Back For Development", "Dev Blocked", "Dev Clarification Requested", "Providing Dev Clarification"],
      
      // Merged QA & Review (Extended)
      "QA & Review": [
          "Ready for Scratch Test", "Scratch Testing", 
          "Ready for QA", "QA In Progress", 
          "Ready for Internal UAT", "Internal UAT"
      ],
      
      // Split Client UAT (Core)
      "Ready for Client UAT": ["Ready for Client UAT"],
      "In Client UAT": ["In Client UAT"],
      
      // Merged Deployment Prep (Extended)
      "Deployment Prep": ["Ready for UAT Sign-off", "Processing Sign-off", "Ready for Merge", "Merging", "Ready for Deployment", "Deploying"],
      
      "Deployed": ["Deployed to Prod"],
      "Done": ["Done", "Cancelled"]
    },
    
    // Consultant: Core/Split for [Intake, Clarif, Sizing, Prio, Dev, QA, Deployment].
    // Ext/Merge for [Dev Approval, Client Approval, Client UAT].
    Consultant: {
      "Backlog": ["Backlog"],
      "Scoping In Progress": ["Scoping In Progress"],
      
      // Split Clarification
      "Clarification Requested (Pre-Dev)": ["Clarification Requested (Pre-Dev)"],
      "Providing Clarification": ["Providing Clarification"],
      
      // Split Estimation
      "Ready for Sizing": ["Ready for Sizing"],
      "Sizing Underway": ["Sizing Underway"],
      
      // Split Prioritization
      "Ready for Prioritization": ["Ready for Prioritization"],
      "Prioritizing": ["Prioritizing"],
      "Proposal Requested": ["Proposal Requested"],
      "Drafting Proposal": ["Drafting Proposal"],
      
      // Split Approvals (Core/Split for Dev Approval in Table 1)
      "Ready for Tech Review": ["Ready for Tech Review"], 
      "Tech Reviewing": ["Tech Reviewing"],
      
      // Consultant table says Client Approval is Ext/Merge.
      "Client Approval": ["Ready for Client Approval", "In Client Approval"],
      
      // Split Development
      "Dev Queue": ["Ready for Development"],
      "Dev Work": ["In Development", "Back For Development", "Dev Blocked", "Dev Clarification Requested", "Providing Dev Clarification"],
      
      // Split QA
      "Ready for Scratch Test": ["Ready for Scratch Test"],
      "Scratch Testing": ["Scratch Testing"],
      "Ready for QA": ["Ready for QA"],
      "QA In Progress": ["QA In Progress"],
      "Ready for Internal UAT": ["Ready for Internal UAT"],
      "Internal UAT": ["Internal UAT"],
      
      // Merged Client UAT (Ext/Merge in Table 1)
      "Client UAT": ["Ready for Client UAT", "In Client UAT"],
      
      // Split Deployment (Ext/Split in Table 1)
      "Ready for UAT Sign-off": ["Ready for UAT Sign-off"],
      "Processing Sign-off": ["Processing Sign-off"],
      "Ready for Merge": ["Ready for Merge"],
      "Merging": ["Merging"],
      "Ready for Deployment": ["Ready for Deployment"],
      "Deploying": ["Deploying"],
      
      "Deployed": ["Deployed to Prod"],
      "Done": ["Done", "Cancelled"]
    },
    
    // Developer: Ext/Merge for Intake, Clarif, Prio, ClientApp, QA, UAT, Deploy. Core/Split for Sizing, DevApp, Dev.
    Developer: {
      "Backlog": ["Backlog", "Scoping In Progress"], // Ext/Merge
      "Clarification": ["Clarification Requested (Pre-Dev)", "Providing Clarification"], // Ext/Merge
      
      // Split Estimation (Core/Split)
      "Ready for Sizing": ["Ready for Sizing"],
      "Sizing Underway": ["Sizing Underway"],
      
      "Prioritization": ["Ready for Prioritization", "Prioritizing", "Proposal Requested", "Drafting Proposal"], // Ext/Merge
      
      // Split Dev Approval (Core/Split)
      "Ready for Tech Review": ["Ready for Tech Review"],
      "Tech Reviewing": ["Tech Reviewing"],

      "Client Approval": ["Ready for Client Approval", "In Client Approval"], // Ext/Merge
      
      // Split Development (Core/Split)
      "Dev Queue": ["Ready for Development"],
      "Dev Work": ["In Development", "Back For Development", "Dev Blocked", "Dev Clarification Requested", "Providing Dev Clarification"],
      
      // Merged QA, UAT, Deployment (Ext/Merge)
      "QA": ["Ready for Scratch Test", "Scratch Testing", "Ready for QA", "QA In Progress", "Ready for Internal UAT", "Internal UAT"],
      "UAT": ["Ready for Client UAT", "In Client UAT", "Ready for UAT Sign-off", "Processing Sign-off"],
      "Deployment": ["Ready for Merge", "Merging", "Ready for Deployment", "Deploying"],
      
      "Deployed": ["Deployed to Prod"],
      "Done": ["Done", "Cancelled"]
    },
    
    // QA: Ext/Merge for Intake, Clarif, Sizing, Prio, DevApp, ClientApp, ClientUAT, Deploy. Core/Split for Dev, QA.
    QA: {
      "Backlog": ["Backlog", "Scoping In Progress"], // Ext/Merge
      "Clarification": ["Clarification Requested (Pre-Dev)", "Providing Clarification"], // Ext/Merge
      "Sizing": ["Ready for Sizing", "Sizing Underway"], // Ext/Merge
      "Prioritization": ["Ready for Prioritization", "Prioritizing", "Proposal Requested", "Drafting Proposal"], // Ext/Merge
      "Dev Approval": ["Ready for Tech Review", "Tech Reviewing"], // Ext/Merge
      "Client Approval": ["Ready for Client Approval", "In Client Approval"], // Ext/Merge
      
      // Split Development (Core/Split)
      "Dev Queue": ["Ready for Development"],
      "Dev Work": ["In Development", "Back For Development", "Dev Blocked", "Dev Clarification Requested", "Providing Dev Clarification"],
      
      // Split QA (Core/Split)
      "Ready for Scratch Test": ["Ready for Scratch Test"],
      "Scratch Testing": ["Scratch Testing"],
      "Ready for QA": ["Ready for QA"],
      "QA In Progress": ["QA In Progress"],
      
      // Merged/Ext downstream
      // Table 1 says QA/Testing includes Internal UAT.
      "Ready for Internal UAT": ["Ready for Internal UAT"],
      "Internal UAT": ["Internal UAT"],
      
      "UAT": ["Ready for Client UAT", "In Client UAT", "Ready for UAT Sign-off", "Processing Sign-off"], // Ext/Merge
      "Deployment": ["Ready for Merge", "Merging", "Ready for Deployment", "Deploying"], // Ext/Merge
      
      "Deployed": ["Deployed to Prod"],
      "Done": ["Done", "Cancelled"]
    },
  };

  // false = Core (Always show), true = Extended (Show only if showAllColumns is true)
  personaColumnExtensionMap = {
    Client: {
      "Backlog": false,
      "Scoping": false,
      "Clarification Requested (Pre-Dev)": false,
      "Providing Clarification": false,
      "Estimation": true, // Ext/Merge
      "Ready for Prioritization": false,
      "Prioritizing": false,
      "Proposal Requested": false,
      "Drafting Proposal": false,
      "Dev Approval": true, // Ext/Merge
      "Ready for Client Approval": false, 
      "In Client Approval": false,
      "In Development": false, // Core/Merge
      "QA & Review": true, // Ext/Merge
      "Ready for Client UAT": false,
      "In Client UAT": false,
      "Deployment Prep": true, // Ext/Merge
      "Deployed": false,
      "Done": true, 
      "Cancelled": true
    },
    Consultant: {
      "Backlog": false,
      "Scoping In Progress": false,
      "Clarification Requested (Pre-Dev)": false,
      "Providing Clarification": false,
      "Ready for Sizing": false, 
      "Sizing Underway": false, 
      "Ready for Prioritization": false,
      "Prioritizing": false,
      "Proposal Requested": false, 
      "Drafting Proposal": false, 
      "Ready for Tech Review": false, // Core/Split
      "Tech Reviewing": false, // Core/Split
      "Client Approval": true, // Ext/Merge
      "Dev Queue": false,
      "Dev Work": false,
      "Ready for Scratch Test": false, // Table says Core/Split for QA
      "Scratch Testing": false,
      "Ready for QA": false,
      "QA In Progress": false,
      "Ready for Internal UAT": false,
      "Internal UAT": false,
      "Client UAT": true, // Ext/Merge
      "Ready for UAT Sign-off": true, // Ext/Split
      "Processing Sign-off": true,
      "Ready for Merge": true,
      "Merging": true,
      "Ready for Deployment": true,
      "Deploying": true,
      "Deployed": false,
      "Done": false
    },
    Developer: {
      "Backlog": true, // Ext/Merge
      "Clarification": true, // Ext/Merge
      "Ready for Sizing": false, // Core/Split
      "Sizing Underway": false,
      "Prioritization": true, // Ext/Merge
      "Ready for Tech Review": false, // Core/Split
      "Tech Reviewing": false,
      "Client Approval": true, // Ext/Merge
      "Dev Queue": false,
      "Dev Work": false,
      "QA": true, // Ext/Merge
      "UAT": true, // Ext/Merge
      "Deployment": true, // Ext/Merge
      "Deployed": true,
      "Done": true
    },
    QA: {
      "Backlog": true, // Ext/Merge
      "Clarification": true,
      "Sizing": true,
      "Prioritization": true,
      "Dev Approval": true,
      "Client Approval": true,
      "Dev Queue": false, // Core/Split
      "Dev Work": false, 
      "Ready for Scratch Test": false, // Core/Split
      "Scratch Testing": false,
      "Ready for QA": false,
      "QA In Progress": false,
      "Ready for Internal UAT": false,
      "Internal UAT": false,
      "UAT": true, // Ext/Merge
      "Deployment": true, // Ext/Merge
      "Deployed": true,
      "Done": true
    }
  };

  personaBoardViews = {
    Client: {
      all: [
        "Backlog", "Scoping", 
        "Clarification Requested (Pre-Dev)", "Providing Clarification",
        "Estimation", // Merged
        "Ready for Prioritization", "Prioritizing", "Proposal Requested", "Drafting Proposal",
        "Dev Approval", // Merged
        "Ready for Client Approval", "In Client Approval", 
        "In Development", // Merged
        "QA & Review", // Merged
        "Ready for Client UAT", "In Client UAT", 
        "Deployment Prep", // Merged
        "Deployed", "Done"
      ],
      predev: ["Backlog", "Scoping", "Clarification Requested (Pre-Dev)", "Providing Clarification", "Estimation", "Ready for Prioritization", "Prioritizing", "Proposal Requested", "Drafting Proposal"],
      indev: ["Dev Approval", "Ready for Client Approval", "In Client Approval", "In Development", "QA & Review"],
      deployed: ["Ready for Client UAT", "In Client UAT", "Deployment Prep", "Deployed", "Done"]
    },
    Consultant: {
      all: [
        "Backlog", "Scoping In Progress", 
        "Clarification Requested (Pre-Dev)", "Providing Clarification",
        "Ready for Sizing", "Sizing Underway",
        "Ready for Prioritization", "Prioritizing", "Proposal Requested", "Drafting Proposal", 
        "Ready for Tech Review", "Tech Reviewing",
        "Client Approval", // Merged
        "Dev Queue", "Dev Work", 
        "Ready for Scratch Test", "Scratch Testing", "Ready for QA", "QA In Progress", "Ready for Internal UAT", "Internal UAT",
        "Client UAT", // Merged
        "Ready for UAT Sign-off", "Processing Sign-off", 
        "Ready for Merge", "Merging", "Ready for Deployment", "Deploying", 
        "Deployed", "Done"
      ],
      predev: ["Backlog", "Scoping In Progress", "Clarification Requested (Pre-Dev)", "Providing Clarification", "Ready for Sizing", "Sizing Underway", "Ready for Prioritization", "Prioritizing", "Proposal Requested", "Drafting Proposal"],
      indev: ["Ready for Tech Review", "Tech Reviewing", "Client Approval", "Dev Queue", "Dev Work", "Ready for Scratch Test", "Scratch Testing", "Ready for QA", "QA In Progress"],
      deployed: ["Ready for Internal UAT", "Internal UAT", "Client UAT", "Ready for UAT Sign-off", "Processing Sign-off", "Ready for Merge", "Merging", "Ready for Deployment", "Deploying", "Deployed", "Done"]
    },
    Developer: {
      all: [
        "Backlog", // Merged
        "Clarification", // Merged
        "Ready for Sizing", "Sizing Underway", 
        "Prioritization", // Merged
        "Ready for Tech Review", "Tech Reviewing",
        "Client Approval", // Merged
        "Dev Queue", "Dev Work", 
        "QA", // Merged
        "UAT", // Merged
        "Deployment", // Merged
        "Deployed", "Done"
      ],
      predev: ["Backlog", "Clarification", "Ready for Sizing", "Sizing Underway", "Prioritization"],
      indev: ["Ready for Tech Review", "Tech Reviewing", "Client Approval", "Dev Queue", "Dev Work"],
      deployed: ["QA", "UAT", "Deployment", "Deployed", "Done"]
    },
    QA: {
      all: [
        "Backlog", // Merged
        "Clarification", // Merged
        "Sizing", // Merged
        "Prioritization", // Merged
        "Dev Approval", // Merged
        "Client Approval", // Merged
        "Dev Queue", "Dev Work", 
        "Ready for Scratch Test", "Scratch Testing",
        "Ready for QA", "QA In Progress", 
        "Ready for Internal UAT", "Internal UAT",
        "UAT", // Merged
        "Deployment", // Merged
        "Deployed", "Done"
      ],
      predev: ["Backlog", "Clarification", "Sizing", "Prioritization", "Dev Approval", "Client Approval"],
      indev: ["Dev Queue", "Dev Work", "Ready for Scratch Test", "Scratch Testing", "Ready for QA", "QA In Progress"],
      deployed: ["Ready for Internal UAT", "Internal UAT", "UAT", "Deployment", "Deployed", "Done"]
    },
  };

  // Logic: 
  // 1. Advance: Can move to Next Step OR Jump to a future QUEUE (Waiting) state.
  // 2. Backtrack: Can move to Previous Step OR Jump back to a previous QUEUE (Waiting) state.
  transitionMap = {
    // Sizing Arena
    "Ready for Sizing": ["Sizing Underway", "Ready for Prioritization", "Ready for Tech Review", "Ready for Client Approval"], 
    "Sizing Underway": ["Ready for Prioritization", "Proposal Requested", "Ready for Tech Review", "Ready for Client Approval"], 
    
    // Tech Review Arena
    "Ready for Tech Review": ["Tech Reviewing", "Ready for Client Approval", "Ready for Development"], 
    "Tech Reviewing": ["Ready for Client Approval", "Ready for Development"], 
    
    // Scratch Test Arena
    "Ready for Scratch Test": ["Scratch Testing", "Ready for QA", "Ready for Internal UAT", "Ready for Client UAT"],
    "Scratch Testing": ["Ready for QA", "Ready for Internal UAT", "Ready for Client UAT", "Back For Development"],
    
    // QA Arena
    "Ready for QA": ["QA In Progress", "Ready for Internal UAT", "Ready for Client UAT"],
    "QA In Progress": ["Ready for Internal UAT", "Ready for Client UAT", "Back For Development"],
    
    // Internal UAT Arena
    "Ready for Internal UAT": ["Internal UAT", "Ready for Client UAT"],
    "Internal UAT": ["Ready for Client UAT", "Back For Development"],
    
    // Client UAT Arena
    "Ready for Client UAT": ["In Client UAT", "Ready for UAT Sign-off", "Ready for Merge", "Ready for Deployment"],
    "In Client UAT": ["Ready for UAT Sign-off", "Ready for Merge", "Ready for Deployment", "Back For Development"],
    
    // Sign-off Arena
    "Ready for UAT Sign-off": ["Processing Sign-off", "Ready for Merge", "Ready for Deployment"],
    "Processing Sign-off": ["Ready for Merge", "Ready for Deployment", "Back For Development"],
    
    // Merge Arena
    "Ready for Merge": ["Merging", "Ready for Deployment"],
    "Merging": ["Ready for Deployment"],
    
    // Standard Linear Defaults for others
    "Backlog": ["Scoping In Progress", "Ready for Sizing", "Ready for Prioritization"],
    "Scoping In Progress": ["Clarification Requested (Pre-Dev)", "Ready for Sizing", "Ready for Prioritization"],
    "Clarification Requested (Pre-Dev)": ["Providing Clarification", "Ready for Sizing", "Ready for Tech Review"],
    "Providing Clarification": ["Ready for Sizing", "Ready for Prioritization", "Ready for Tech Review"],
    "Ready for Prioritization": ["Prioritizing", "Ready for Development", "Ready for Tech Review"],
    "Prioritizing": ["Proposal Requested", "Ready for Tech Review", "Ready for Development"],
    "Proposal Requested": ["Drafting Proposal"],
    "Drafting Proposal": ["Ready for Tech Review", "Ready for Prioritization"],
    "Ready for Client Approval": ["In Client Approval", "Ready for Development"],
    "In Client Approval": ["Ready for Development"],
    "Ready for Development": ["In Development"],
    "In Development": ["Dev Clarification Requested", "Dev Blocked", "Ready for Scratch Test", "Ready for QA", "Ready for Deployment"],
    "Dev Clarification Requested": ["Providing Dev Clarification"],
    "Providing Dev Clarification": ["Back For Development"],
    "Back For Development": ["In Development"],
    "Dev Blocked": ["In Development", "Providing Dev Clarification"],
    "Ready for Deployment": ["Deploying"],
    "Deploying": ["Deployed to Prod"],
    "Deployed to Prod": ["Done"],
    "Done": [],
    "Cancelled": ["Backlog", "Ready for Sizing"]
  };

  backtrackMap = {
    // Sizing Arena
    "Ready for Sizing": ["Clarification Requested (Pre-Dev)", "Backlog", "Cancelled"],
    "Sizing Underway": ["Ready for Sizing", "Backlog", "Cancelled"],
    
    // Tech Review Arena
    "Ready for Tech Review": ["Proposal Requested", "Ready for Prioritization", "Cancelled"],
    "Tech Reviewing": ["Ready for Tech Review", "Cancelled"],
    
    // Scratch Test Arena
    "Ready for Scratch Test": ["In Development", "Cancelled"],
    "Scratch Testing": ["Ready for Scratch Test", "Ready for Development", "Cancelled"],
    
    // QA Arena
    "Ready for QA": ["Ready for Scratch Test", "Cancelled"],
    "QA In Progress": ["Ready for QA", "Ready for Scratch Test", "Cancelled"],
    
    // Internal UAT Arena
    "Ready for Internal UAT": ["Ready for QA", "Cancelled"],
    "Internal UAT": ["Ready for Internal UAT", "Ready for QA", "Cancelled"],
    
    // Client UAT Arena
    "Ready for Client UAT": ["Ready for Internal UAT", "Ready for Development", "Cancelled"],
    "In Client UAT": ["Ready for Client UAT", "Ready for Internal UAT", "Cancelled"],
    
    // Sign-off Arena
    "Ready for UAT Sign-off": ["In Client UAT", "Cancelled"],
    "Processing Sign-off": ["Ready for UAT Sign-off", "Ready for Development", "Cancelled"],
    
    // Merge Arena
    "Ready for Merge": ["Processing Sign-off", "Ready for Client UAT", "Ready for Development", "Cancelled"],
    "Merging": ["Ready for Merge", "Cancelled"],
    
    // Others
    "Scoping In Progress": ["Backlog", "Cancelled"],
    "Clarification Requested (Pre-Dev)": ["Backlog", "Cancelled"],
    "Providing Clarification": ["Clarification Requested (Pre-Dev)", "Backlog", "Cancelled"],
    "Ready for Prioritization": ["Ready for Sizing", "Backlog", "Cancelled"],
    "Prioritizing": ["Ready for Prioritization", "Cancelled"],
    "Proposal Requested": ["Ready for Prioritization", "Ready for Sizing", "Cancelled"],
    "Drafting Proposal": ["Proposal Requested", "Cancelled"],
    "Ready for Client Approval": ["Ready for Tech Review", "Cancelled"],
    "In Client Approval": ["Ready for Client Approval", "Cancelled"],
    "Ready for Development": ["In Client Approval", "Ready for Client Approval", "Ready for Tech Review", "Cancelled"],
    "In Development": ["Ready for Development", "Cancelled"],
    "Dev Clarification Requested": ["In Development", "Cancelled"],
    "Providing Dev Clarification": ["Dev Clarification Requested", "Cancelled"],
    "Back For Development": ["Dev Clarification Requested", "Ready for Development", "Cancelled"],
    "Dev Blocked": ["In Development", "Cancelled"],
    "Ready for Deployment": ["Ready for Merge", "Ready for Client UAT", "Cancelled"],
    "Deploying": ["Ready for Deployment", "Cancelled"],
    "Deployed to Prod": ["Ready for Deployment", "Ready for Client UAT", "Cancelled"],
    "Done": ["Deployed to Prod", "Cancelled"],
    "Backlog": ["Cancelled"],
    "Cancelled": ["Backlog", "Ready for Sizing", "Ready for Development"] 
  };

  intentionColor = {
    "Will Do": "#2196F3",
    "Sizing Only": "#FFD54F",
  };

  personaAdvanceOverrides = {};
  personaBacktrackOverrides = {};
 
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

  /** * Refactored Create Modal Logic */
  openCreateModal() {
    // Namespace logic: Use bridge to find max sort order number
    const nums = (this.realRecords || [])
      .map((r) => r[FIELDS.SORT_ORDER])
      .filter((n) => n !== null && n !== undefined);
    
    this.nextSortOrder = nums.length ? Math.max(...nums) + 1 : 1;
    this.showCreateModal = true;
  }

  /* ---------- defaults for the create form ---------- */
  get createDefaults() {
    // Namespace logic: Use computed property names [FIELDS.X]
    return {
      [FIELDS.STAGE]: "Backlog",
      [FIELDS.SORT_ORDER]: this.nextSortOrder,
      [FIELDS.PRIORITY]: "Medium",
      [FIELDS.IS_ACTIVE]: true,
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

          // Refactored Relationships: Accessing arrays and fields via bracket notation
          const isBlockedBy = (rec[FIELDS.DEP_REL_BLOCKED_BY] || []).map(dep => ({
              id: dep[FIELDS.BLOCKING_TICKET],
              // Dynamically building the __r name for the parent Name field
              name: dep[FIELDS.BLOCKING_TICKET.replace('__c', '__r')]?.Name,
              dependencyId: dep.Id
          }));

          const isBlocking = (rec[FIELDS.DEP_REL_BLOCKING] || []).map(dep => ({
              id: dep[FIELDS.BLOCKED_TICKET],
              name: dep[FIELDS.BLOCKED_TICKET.replace('__c', '__r')]?.Name,
              dependencyId: dep.Id
          }));

          // --- KEEPING YOUR ORIGINAL HELPERS ---
          // Helper to create an array from a tag string
          const getTagsArray = (tagsString) => {
              if (!tagsString || typeof tagsString !== "string") return [];
              return tagsString
                  .split(",")
                  .map((tag) => tag.trim())
                  .filter((tag) => tag);
          };

          return {
              ...rec,
              calculatedETA:
                  etaDto && etaDto.calculatedETA
                      ? new Date(etaDto.calculatedETA).toLocaleDateString()
                      : "—",

              // Mapping logic using your original dynamic properties
              isBlockedBy: isBlockedBy,
              isBlocking: isBlocking,
              isCurrentlyBlocked: isBlockedBy.length > 0,
              OwnerName: rec.Owner?.Name, 
              
              // NAMESPACE FIX: Use FIELDS map instead of dot notation
              isHighPriority: rec[FIELDS.PRIORITY]?.toLowerCase() === "high",
              tags: getTagsArray(rec[FIELDS.TAGS]),
              cardClasses: `ticket-card`,
              priorityClasses: `priority-badge priority-${rec[FIELDS.PRIORITY]?.toLowerCase()}`,
          };
      });
  }

  /* ---------- stageColumns (Refactored Phase 3) ---------- */
  get stageColumns() {
    const persona = this.persona;
    const boardViews = this.personaBoardViews?.[persona] || {};
    let colNames = boardViews?.[this.overallFilter] || [];
    const statusMap = this.personaColumnStatusMap?.[persona] || {};
    const enriched = this.enrichedTickets || [];
    const extMap = this.personaColumnExtensionMap?.[persona] || {};

    // Filter columns based on the Extension Map:
    // If showAllColumns is FALSE, we hide any column where isExtended (value in map) is TRUE.
    if (!this.showAllColumns) {
        colNames = colNames.filter((col) => {
            const isExtended = extMap[col]; 
            // If isExtended is true, we hide it when 'Show Internal' is unchecked.
            // So we return true (keep it) only if isExtended is falsy.
            return !isExtended; 
        });
    }

    let columns = colNames.map((colName) => {
        const config = this.columnHeaderStyleMap[colName] || { bg: "#ffffff", color: "#11182c" };
        const headerStyle = `background:${config.bg};color:${config.color};`;

        // Namespace logic: Filter tickets using the FIELDS bridge
        const columnTickets = enriched
            .filter((t) => (statusMap[colName] || []).includes(t[FIELDS.STAGE]))
            .filter((t) => {
                if (this.intentionFilter === "all") return true;
                const intention = (t[FIELDS.INTENTION] || "").trim().toLowerCase();
                return intention === this.intentionFilter.toLowerCase();
            })
            .map((ticket) => ({
                ...ticket,
                cardStyle: `border-left-color: ${config.bg} !important;`,
            }));

        return {
            stage: colName,
            displayName: this.columnDisplayNames[colName] || colName,
            headerStyle,
            tickets: columnTickets,
            bodyClasses: `kanban-column-body ${columnTickets.length > 0 ? "has-tickets" : "is-empty"}`,
        };
    });

    return this.showMode === "active" ? columns.filter((col) => col.tickets.length > 0) : columns;
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
    // Mapping removed for brevity, relying on statusColorMap for new statuses
    return this.statusColorMap[status] || "#eee";
  }

  get advanceOptions() {
    if (!this.selectedRecord) return [];

    // NAMESPACE FIX: Use bridge to get the current stage from the record
    const currStage = this.selectedRecord[FIELDS.STAGE]; 
    const persona = this.persona;
    const nextStages = this.transitionMap[currStage] || [];

    return nextStages
      .filter((tgt) => tgt !== currStage)
      .map((tgt) => {
        const override =
          this.personaAdvanceOverrides?.[persona]?.[currStage]?.[tgt] || {};

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

    // NAMESPACE FIX: Use bridge to get the current stage from the record
    const currStage = this.selectedRecord[FIELDS.STAGE];
    const persona = this.persona;
    let targets = [];

    if (this.personaBacktrackOverrides?.[persona]?.[currStage]) {
      const custom = this.personaBacktrackOverrides[persona][currStage];
      targets = Object.keys(custom).map((tgt) => {
        const override = custom[tgt];
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
    this.logBoardState();
  }

  /** * Refactored Helper to find column owner safely */
    columnOwner(colName) {
      const personaMap = this.personaColumnStatusMap[this.persona] || {};
      const statuses = personaMap[colName] || [];
      const firstStatus = statuses[0];
      return this.statusOwnerMap[firstStatus] || "Default";
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
    this.logBoardState();
  }

  logBoardState() {
    // Timeout ensures we log after the state update has settled in the JS event loop
    setTimeout(() => {
        try {
            const columns = this.stageColumns;
            console.log(`%c[Board Debug] Persona: ${this.persona} | Show Internal: ${this.showAllColumns}`, "color:orange;font-weight:bold;");
            
            const debugData = columns.map(col => ({
                "Display Name": col.displayName,
                "Stage (API Name)": col.stage,
                "Is Extended?": this.personaColumnExtensionMap[this.persona][col.stage],
                "Ticket Count": col.tickets.length
            }));

            console.log(JSON.stringify(debugData, null, 2));
        } catch (error) {
            console.error('Error logging board state:', error);
        }
    }, 100);
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
          objectApiName: "Ticket__c",
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
  //  const newStage = e.target.dataset.value;
  //  this.selectedStage = newStage;
  //  this.handleSaveTransition();
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
  /* ---------- handleSaveTransition (Refactored) ---------- */
handleSaveTransition() {
      const rec = this.selectedRecord;
      const newStage = this.selectedStage;
      if (rec && newStage) {
          // Namespace logic: Use computed property names from the bridge
          const fields = {
              [FIELDS.ID]: rec.Id,
              [FIELDS.STAGE]: newStage
          };

          updateRecord({ fields })
              .then(() => {
                  this.showToast("Success", "Ticket updated.", "success");
                  this.refreshTickets(); 
              })
              .catch((error) => {
                  console.error("Error updating ticket stage:", error);
                  this.showToast("Error", "Failed to update ticket.", "error");
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

  /* ---------- handleDrop (Refactored Phase 4) ---------- */
  async handleDrop(event) {
    event.preventDefault();
    const ticketId = this.draggedItem.Id;
    const dropColumnEl = event.target.closest('.kanban-column');
    if (!dropColumnEl) {
        this.handleDragEnd(); 
        return;
    }

    const targetColumnStage = dropColumnEl.dataset.stage;
    const sourceColumnStage = this.stageColumns.find(col => col.tickets.some(t => t.Id === ticketId)).stage;
    
    this.handleDragEnd();

    // SCENARIO 1: INTRA-COLUMN DROP (Reordering)
    if (sourceColumnStage === targetColumnStage) {
        const columnTickets = this.stageColumns.find(c => c.stage === targetColumnStage).tickets;
        const newSortOrder = this.calculateNewSortOrder(this.placeholder, columnTickets);
        try {
            await updateTicketSortOrder({ ticketId: ticketId, newSortOrder: newSortOrder });
            this.showToast('Success', 'Ticket reordered.', 'success');
            this.refreshTickets();
        } catch (error) {
            this.showToast('Error', 'Failed to reorder ticket.', 'error');
        }
        return; 
    }

    // SCENARIO 2: INTER-COLUMN DROP (Status Change)
    const newInternalStage = (this.personaColumnStatusMap[this.persona][targetColumnStage] || [])[0];

    if (newInternalStage) {
        try {
            const requiredFields = await getRequiredFieldsForStage({ targetStage: newInternalStage });
            if (requiredFields && requiredFields.length > 0) {
                this.transitionTicketId = ticketId;
                this.transitionTargetStage = newInternalStage;
                this.transitionRequiredFields = requiredFields;
                this.showTransitionModal = true;
            } else {
                // Namespace logic: Update stage via Apex
                await updateTicketStage({ ticketId: ticketId, newStage: newInternalStage });
                this.showToast('Success', 'Ticket moved.', 'success');
                this.refreshTickets();
            }
        } catch (error) {
            const errorMessage = error.body?.message || 'An unknown error occurred.';
            this.showToast('Move Failed', errorMessage, 'error');
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
    console.log(event);
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

    const sortBefore = prevTicket ? prevTicket.SortOrderNumber__c : 0;

    if (nextTicket) {
      // Dropped between two cards
      return (sortBefore + nextTicket.SortOrderNumber__c) / 2.0;
    } else {
      // Dropped at the end of the list
      return sortBefore + 1; // Or a larger number like 1000 to be safe
    }
  }

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
      descriptionValue = this.formFieldValues["DetailsTxt__c"] || "";

      // Method 2: Try to get directly from input elements if Method 1 fails
      if (!titleValue || !descriptionValue) {
        const titleField = this.template.querySelector(
          'lightning-input-field[field-name="BriefDescriptionTxt__c"]'
        );
        const descriptionField = this.template.querySelector(
          'lightning-input-field[field-name="DetailsTxt__c"]'
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
      console.log(event);
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

        // NAMESPACE FIX: Use FIELDS map for the formFieldValues keys
        if (this.aiSuggestions.title) {
            this.createTicketTitle = this.aiSuggestions.title;
            this.formFieldValues[FIELDS.BRIEF_DESC] = this.aiSuggestions.title;
            appliedFields.push("title");
        }

        if (this.aiSuggestions.description) {
            this.createTicketDescription = this.aiSuggestions.description;
            this.formFieldValues[FIELDS.DETAILS] = this.aiSuggestions.description;
            appliedFields.push("description");
        }

        if (this.aiSuggestions.estimatedDays && this.AiEstimation) {
            this.estimatedDaysValue = this.aiSuggestions.estimatedDays;
            this.formFieldValues[FIELDS.DEV_DAYS_SIZE] = this.aiSuggestions.estimatedDays;
            appliedFields.push("estimated days");
        }

        // Force a re-render and trigger standard LWC form validation
        setTimeout(() => {
            this.template.querySelectorAll("lightning-input-field").forEach((field) => {
                field.dispatchEvent(new CustomEvent("change", { bubbles: true }));
            });
        }, 100);

        if (appliedFields.length === 0) {
            this.showToast("Warning", "No valid suggestions found to apply.", "warning");
            return;
        }

        // Clear suggestions and notify success
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
    //      this.isModalOpen = false;
    //      this.searchResults = [];
    //      this.searchTerm = '';
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