import { LightningElement, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";

// Update this line to include createRecord, getRecord, and getFieldValue
import { updateRecord, createRecord, getRecord, getFieldValue } from "lightning/uiRecordApi";

// Add these new imports for the current user
import USER_ID from "@salesforce/user/Id";
import USER_NAME_FIELD from "@salesforce/schema/User.Name";

import { ShowToastEvent } from "lightning/platformShowToastEvent";

// --- Apex Imports ---
import getTickets from "@salesforce/apex/%%%NAMESPACE_DOT%%%TicketController.getTickets";
import linkFilesAndSync from "@salesforce/apex/%%%NAMESPACE_DOT%%%TicketController.linkFilesAndSync";
import getAiEnhancedTicketDetails from "@salesforce/apex/%%%NAMESPACE_DOT%%%TicketController.getAiEnhancedTicketDetails";
import getTicketETAsWithPriority from "@salesforce/apex/%%%NAMESPACE_DOT%%%TicketETAService.getTicketETAsWithPriority";
import updateTicketStage from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.updateTicketStage";
// UPDATED: Using new reorder method instead of updateTicketSortOrder
import reorderTicket from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.reorderTicket";
import createDependency from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.createDependency";
import removeDependency from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.removeDependency";
import searchForPotentialBlockers from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.searchForPotentialBlockers";
import getRequiredFieldsForStage from '@salesforce/apex/%%%NAMESPACE_DOT%%%TicketController.getRequiredFieldsForStage';
import getSettings from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSettingsController.getSettings';

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
    
    // NEW FIELDS FOR CARD UI
    TOTAL_LOGGED_HOURS: `%%%NAMESPACED_ORG%%%TotalLoggedHoursNumber__c`,
    ESTIMATED_HOURS: `%%%NAMESPACED_ORG%%%EstimatedHoursNumber__c`,
    PROJECTED_UAT_READY: `%%%NAMESPACED_ORG%%%ProjectedUATReadyDate__c`,
    
    CREATED_DATE: 'CreatedDate',
    DEVELOPER: `%%%NAMESPACED_ORG%%%Developer__c`,
    // Relationships
    DEP_REL_BLOCKED_BY: `%%%NAMESPACED_ORG%%%Ticket_Dependency1__r`,
    DEP_REL_BLOCKING: `%%%NAMESPACED_ORG%%%Ticket_Dependency__r`,
    BLOCKING_TICKET: `%%%NAMESPACED_ORG%%%Blocking_Ticket__c`,
    BLOCKED_TICKET: `%%%NAMESPACED_ORG%%%Blocked_Ticket__c`
};

export default class DeliveryHubBoard extends NavigationMixin(LightningElement) {
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
    @track showAllColumns = false; 
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
    @track hasValidOpenAIKey = false;

    ticketsWire;

    @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME_FIELD] })
    currentUser;

    get currentUserName() {
        return getFieldValue(this.currentUser.data, USER_NAME_FIELD) || '';
    }

    connectedCallback() {
        this.loadSettings();
    }

    async loadSettings() {
        try {
            const data = await getSettings();
            if (data) {
                this.AiEnhancementEnabled = data.aiSuggestionsEnabled || false;
                this.AiEstimation = data.aiEstimationEnabled || false;
                this.hasValidOpenAIKey = data.openAiApiTested || false;
            }
        } catch (error) {
            console.error('Error loading settings:', error);
        }
    }

    async createStatusComment(ticketId) {
        if (!this.moveComment || this.moveComment.trim() === "") {
            console.log('[createStatusComment] → Skipping empty comment');
            return; 
        }

        const fields = {
            '%%%NAMESPACED_ORG%%%TicketId__c': ticketId,
            '%%%NAMESPACED_ORG%%%BodyTxt__c': this.moveComment,
            '%%%NAMESPACED_ORG%%%SourcePk__c': 'Salesforce',
            '%%%NAMESPACED_ORG%%%AuthorTxt__c': this.currentUserName 
        };

        const recordInput = { 
            // Note: apiName is a string value, so it was already fine, 
            // but the keys inside 'fields' MUST be quoted.
            apiName: '%%%NAMESPACED_ORG%%%Ticket_Comment__c', 
            fields 
        };

        try {
            // Ensure createRecord is imported at the top!
            const result = await createRecord(recordInput);
            console.log('Comment created → ID:', result.id);
        } catch (error) {
            console.error('Failed to create Ticket_Comment__c:', error);
            throw error;
        }
    }

    // --- CONFIGURATION MAPS ---
    statusColorMap = {
        "Backlog": "#F3F4F6", "Scoping In Progress": "#FEF3C7", 
        "Clarification Requested (Pre-Dev)": "#E0F2FE", "Providing Clarification": "#DBEAFE", 
        "Ready for Sizing": "#E0F2FE", "Sizing Underway": "#FFEDD5", 
        "Ready for Prioritization": "#E0F2FE", "Prioritizing": "#DBEAFE", 
        "Proposal Requested": "#E0F2FE", "Drafting Proposal": "#FFEDD5", 
        "Ready for Tech Review": "#E0F2FE", "Tech Reviewing": "#FEF3C7", 
        "Ready for Client Approval": "#E0F2FE", "In Client Approval": "#DBEAFE", 
        "Ready for Development": "#DCFCE7", "In Development": "#FF9100", 
        "Dev Clarification Requested": "#FEE2E2", "Providing Dev Clarification": "#DBEAFE", 
        "Back For Development": "#EF4444", "Dev Blocked": "#EF4444", 
        "Ready for Scratch Test": "#E0F2FE", "Scratch Testing": "#22C55E", 
        "Ready for QA": "#E0F2FE", "QA In Progress": "#22C55E", 
        "Ready for Internal UAT": "#E0F2FE", "Internal UAT": "#1D4ED8", 
        "Ready for Client UAT": "#E0F2FE", "In Client UAT": "#2563EB", 
        "Ready for UAT Sign-off": "#E0F2FE", "Processing Sign-off": "#DBEAFE", 
        "Ready for Merge": "#F3E8FF", "Merging": "#7C3AED", 
        "Ready for Deployment": "#F3E8FF", "Deploying": "#7C3AED", 
        "Deployed to Prod": "#059669", "Done": "#374151", "Cancelled": "#9CA3AF"
    };

    columnHeaderStyleMap = {
        "Backlog": { bg: "rgba(243, 244, 246, 0.8)", color: "#1F2937" },
        "Scoping": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
        "Clarification Requested": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" },
        "Providing Clarification": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" },
        "Clarification": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" },
        "Ready for Sizing": { bg: "rgba(224, 242, 254, 0.5)", color: "#0284C7" },
        "Sizing Underway": { bg: "rgba(255, 237, 213, 0.5)", color: "#EA580C" },
        "Estimation": { bg: "rgba(255, 237, 213, 0.5)", color: "#EA580C" },
        "Ready for Prioritization": { bg: "rgba(224, 242, 254, 0.5)", color: "#0284C7" },
        "Prioritizing": { bg: "rgba(224, 242, 254, 0.5)", color: "#0284C7" },
        "Prioritization": { bg: "rgba(224, 242, 254, 0.5)", color: "#0284C7" },
        "Proposal Requested": { bg: "rgba(255, 237, 213, 0.5)", color: "#EA580C" },
        "Drafting Proposal": { bg: "rgba(255, 237, 213, 0.5)", color: "#EA580C" },
        "Proposal": { bg: "rgba(255, 237, 213, 0.5)", color: "#EA580C" },
        "Ready for Dev Approval": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
        "Dev Approving": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
        "Dev Approval": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
        "Ready for Client Approval": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
        "In Client Approval": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
        "Client Approval": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
        "Approvals": { bg: "rgba(254, 243, 199, 0.5)", color: "#D97706" },
        "Ready for Dev": { bg: "rgba(220, 252, 231, 0.5)", color: "#16A34A" },
        "In Development": { bg: "rgba(255, 145, 0, 0.3)", color: "#C2410C" },
        "Dev Queue": { bg: "rgba(220, 252, 231, 0.5)", color: "#16A34A" },
        "Dev Work": { bg: "rgba(255, 145, 0, 0.3)", color: "#C2410C" },
        "Rework": { bg: "rgba(254, 202, 202, 0.6)", color: "#991B1B" },
        "Blocked": { bg: "rgba(254, 202, 202, 0.6)", color: "#991B1B" },
        "Dev Clarification Requested": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" },
        "Providing Dev Clarification": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" },
        "Dev Clarification": { bg: "rgba(254, 226, 226, 0.5)", color: "#DC2626" },
        "Ready for Scratch Test": { bg: "rgba(219, 234, 254, 0.5)", color: "#1E40AF" },
        "Scratch Testing": { bg: "rgba(219, 234, 254, 0.5)", color: "#1E40AF" },
        "Ready for QA": { bg: "rgba(219, 234, 254, 0.5)", color: "#1E40AF" },
        "QA In Progress": { bg: "rgba(191, 219, 254, 0.5)", color: "#1D4ED8" },
        "Ready for Internal UAT": { bg: "rgba(219, 234, 254, 0.5)", color: "#1E40AF" },
        "Internal UAT": { bg: "rgba(191, 219, 254, 0.5)", color: "#1D4ED8" },
        "QA & Review": { bg: "rgba(219, 234, 254, 0.5)", color: "#1D4ED8" },
        "QA": { bg: "rgba(219, 234, 254, 0.5)", color: "#1E40AF" },
        "Client UAT": { bg: "rgba(191, 219, 254, 0.5)", color: "#2563EB" },
        "UAT": { bg: "rgba(191, 219, 254, 0.5)", color: "#2563EB" },
        "Ready for Client UAT": { bg: "rgba(191, 219, 254, 0.5)", color: "#2563EB" },
        "In Client UAT": { bg: "rgba(191, 219, 254, 0.5)", color: "#2563EB" },
        "Ready for UAT Sign-off": { bg: "rgba(221, 214, 254, 0.5)", color: "#7C3AED" },
        "Processing Sign-off": { bg: "rgba(221, 214, 254, 0.5)", color: "#7C3AED" },
        "Deployment Prep": { bg: "rgba(221, 214, 254, 0.5)", color: "#7C3AED" },
        "Deployment": { bg: "rgba(237, 233, 254, 0.5)", color: "#6D28D9" },
        "Ready for Merge": { bg: "rgba(237, 233, 254, 0.5)", color: "#6D28D9" },
        "Merging": { bg: "rgba(237, 233, 254, 0.5)", color: "#6D28D9" },
        "Ready for Deployment": { bg: "rgba(237, 233, 254, 0.5)", color: "#6D28D9" },
        "Deploying": { bg: "rgba(237, 233, 254, 0.5)", color: "#6D28D9" },
        "Deployed": { bg: "rgba(209, 250, 229, 0.5)", color: "#059669" },
        "Done": { bg: "rgba(229, 231, 235, 0.5)", color: "#374151" },
        "Cancelled": { bg: "rgba(229, 231, 235, 0.5)", color: "#6B7280" }
    };

    statusOwnerMap = {
        "Backlog": "Consultant", "Scoping In Progress": "Consultant",
        "Clarification Requested (Pre-Dev)": "Client", "Providing Clarification": "Client",
        "Ready for Sizing": "Developer", "Sizing Underway": "Developer",
        "Ready for Prioritization": "Client", "Prioritizing": "Client",
        "Proposal Requested": "Developer", "Drafting Proposal": "Developer",
        "Ready for Tech Review": "Consultant", "Tech Reviewing": "Consultant",
        "Ready for Client Approval": "Client", "In Client Approval": "Client",
        "Ready for Development": "Developer", "In Development": "Developer",
        "Dev Clarification Requested": "Client", "Providing Dev Clarification": "Client",
        "Back For Development": "Developer", "Dev Blocked": "Developer",
        "Ready for Scratch Test": "QA", "Scratch Testing": "QA",
        "Ready for QA": "QA", "QA In Progress": "QA",
        "Ready for Internal UAT": "Consultant", "Internal UAT": "Consultant",
        "Ready for Client UAT": "Client", "In Client UAT": "Client",
        "Ready for UAT Sign-off": "Client", "Processing Sign-off": "Client",
        "Ready for Merge": "Consultant", "Merging": "Consultant",
        "Ready for Deployment": "Consultant", "Deploying": "Consultant",
        "Deployed to Prod": "System", "Done": "All", "Cancelled": "All"
    };

    ownerColorMap = { Client: "#2196F3", Consultant: "#FFD600", Developer: "#FF9100", QA: "#00C853", System: "#9E9E9E", Default: "#BDBDBD" };

    columnDisplayNames = {
        "Backlog": "Backlog", "Scoping": "Scoping",
        "Clarification Requested (Pre-Dev)": "Clarification Requested", "Providing Clarification": "Providing Clarification", "Clarification": "Clarification",
        "Estimation": "Estimation", "Ready for Sizing": "Ready for Sizing", "Sizing Underway": "Sizing Underway", "Sizing": "Sizing",
        "Prioritization": "Prioritization", "Ready for Prioritization": "Ready for Prioritization", "Prioritizing": "Prioritizing",
        "Proposal Requested": "Proposal Requested", "Drafting Proposal": "Drafting Proposal", "Proposal": "Proposal",
        "Dev Approval": "Dev Approval", "Ready for Tech Review": "Ready for Tech Review", "Tech Reviewing": "Tech Reviewing",
        "Client Approval": "Client Approval", "Ready for Client Approval": "Ready for Client Approval", "In Client Approval": "In Client Approval", "Approvals": "Approvals",
        "In Development": "In Development", "Dev Queue": "Dev Queue", "Dev Work": "Active Dev", "Rework": "Rework", "Blocked": "⛔ Blocked", "Ready for Dev": "Ready for Dev",
        "Dev Clarification Requested": "Dev Clarification Requested", "Providing Dev Clarification": "Providing Dev Clarification", "Clarification (In-Dev)": "Dev Clarification", "Dev Clarification": "Dev Clarification",
        "QA & Review": "QA & Review", "QA": "QA", "Ready for Scratch Test": "Ready for Scratch Test", "Scratch Testing": "Scratch Testing", "Ready for QA": "Ready for QA",
        "QA In Progress": "QA In Progress", "Ready for Internal UAT": "Ready for Internal UAT", "Internal UAT": "Internal UAT",
        "Client UAT": "Client UAT", "UAT": "UAT", "Ready for Client UAT": "Ready for Client UAT", "In Client UAT": "In Client UAT",
        "Ready for UAT Sign-off": "Ready for UAT Sign-off", "Processing Sign-off": "Processing Sign-off",
        "Deployment Prep": "Deployment Prep", "Deployment": "Deployment", "Ready for Merge": "Ready for Merge", "Merging": "Merging",
        "Ready for Deployment": "Ready for Deployment", "Deploying": "Deploying", "Deployed": "Deployed", "Done": "Done", "Cancelled": "Cancelled",
        "Intake": "Intake Queue", "Scoping In Progress": "Active Scoping", "Ready for Development": "Dev Queue", "Back For Development": "Rework", "Dev Blocked": "Blocked",
        "Pending Tech Approval": "Tech Approval", "Pending Client Approval": "Client Approval"
    };

    personaColumnStatusMap = {
        Client: {
            "Backlog": ["Backlog"], "Scoping": ["Scoping In Progress"],
            "Clarification Requested (Pre-Dev)": ["Clarification Requested (Pre-Dev)"], "Providing Clarification": ["Providing Clarification"],
            "Estimation": ["Ready for Sizing", "Sizing Underway"],
            "Ready for Prioritization": ["Ready for Prioritization"], "Prioritizing": ["Prioritizing"],
            "Proposal": ["Proposal Requested", "Drafting Proposal"], "Dev Approval": ["Ready for Tech Review", "Tech Reviewing"],
            "Ready for Client Approval": ["Ready for Client Approval"], "In Client Approval": ["In Client Approval"],
            "In Development": ["Ready for Development", "In Development", "Back For Development", "Dev Blocked", "Dev Clarification Requested", "Providing Dev Clarification"],
            "QA & Review": ["Ready for Scratch Test", "Scratch Testing", "Ready for QA", "QA In Progress", "Ready for Internal UAT", "Internal UAT"],
            "Ready for Client UAT": ["Ready for Client UAT"], "In Client UAT": ["In Client UAT"],
            "Deployment Prep": ["Ready for UAT Sign-off", "Processing Sign-off", "Ready for Merge", "Merging", "Ready for Deployment", "Deploying"],
            "Deployed": ["Deployed to Prod"], "Done": ["Done", "Cancelled"]
        },
        Consultant: {
            "Backlog": ["Backlog"], "Scoping In Progress": ["Scoping In Progress"],
            "Clarification Requested (Pre-Dev)": ["Clarification Requested (Pre-Dev)"], "Providing Clarification": ["Providing Clarification"],
            "Ready for Sizing": ["Ready for Sizing"], "Sizing Underway": ["Sizing Underway"],
            "Ready for Prioritization": ["Ready for Prioritization"], "Prioritizing": ["Prioritizing"],
            "Proposal Requested": ["Proposal Requested"], "Drafting Proposal": ["Drafting Proposal"],
            "Ready for Tech Review": ["Ready for Tech Review"], "Tech Reviewing": ["Tech Reviewing"],
            "Client Approval": ["Ready for Client Approval", "In Client Approval"],
            "Dev Queue": ["Ready for Development"], "Dev Work": ["In Development"], "Rework": ["Back For Development"],
            "Blocked": ["Dev Blocked"], "Dev Clarification": ["Dev Clarification Requested", "Providing Dev Clarification"],
            "Ready for Scratch Test": ["Ready for Scratch Test"], "Scratch Testing": ["Scratch Testing"],
            "Ready for QA": ["Ready for QA"], "QA In Progress": ["QA In Progress"],
            "Ready for Internal UAT": ["Ready for Internal UAT"], "Internal UAT": ["Internal UAT"],
            "Client UAT": ["Ready for Client UAT", "In Client UAT"],
            "Ready for UAT Sign-off": ["Ready for UAT Sign-off"], "Processing Sign-off": ["Processing Sign-off"],
            "Ready for Merge": ["Ready for Merge"], "Merging": ["Merging"],
            "Ready for Deployment": ["Ready for Deployment"], "Deploying": ["Deploying"],
            "Deployed": ["Deployed to Prod"], "Done": ["Done", "Cancelled"]
        },
        Developer: {
            "Backlog": ["Backlog", "Scoping In Progress"], "Clarification": ["Clarification Requested (Pre-Dev)"], "Providing Clarification": ["Providing Clarification"],
            "Ready for Sizing": ["Ready for Sizing"], "Sizing Underway": ["Sizing Underway"],
            "Prioritization": ["Ready for Prioritization", "Prioritizing"], "Proposal Requested": ["Proposal Requested"], "Drafting Proposal": ["Drafting Proposal"],
            "Ready for Tech Review": ["Ready for Tech Review"], "Tech Reviewing": ["Tech Reviewing"],
            "Client Approval": ["Ready for Client Approval", "In Client Approval"],
            "Dev Queue": ["Ready for Development"], "Dev Work": ["In Development"], "Rework": ["Back For Development"],
            "Blocked": ["Dev Blocked"], "Dev Clarification": ["Dev Clarification Requested", "Providing Dev Clarification"],
            "QA": ["Ready for Scratch Test", "Scratch Testing", "Ready for QA", "QA In Progress", "Ready for Internal UAT", "Internal UAT"],
            "UAT": ["Ready for Client UAT", "In Client UAT", "Ready for UAT Sign-off", "Processing Sign-off"],
            "Deployment": ["Ready for Merge", "Merging", "Ready for Deployment", "Deploying"],
            "Deployed": ["Deployed to Prod"], "Done": ["Done", "Cancelled"]
        },
        QA: {
            "Backlog": ["Backlog", "Scoping In Progress"], "Clarification": ["Clarification Requested (Pre-Dev)", "Providing Clarification"],
            "Sizing": ["Ready for Sizing", "Sizing Underway"], "Prioritization": ["Ready for Prioritization", "Prioritizing", "Proposal Requested", "Drafting Proposal"],
            "Dev Approval": ["Ready for Tech Review", "Tech Reviewing"], "Client Approval": ["Ready for Client Approval", "In Client Approval"],
            "Dev Queue": ["Ready for Development"], "Dev Work": ["In Development", "Back For Development", "Dev Blocked", "Dev Clarification Requested", "Providing Dev Clarification"],
            "Ready for Scratch Test": ["Ready for Scratch Test"], "Scratch Testing": ["Scratch Testing"],
            "Ready for QA": ["Ready for QA"], "QA In Progress": ["QA In Progress"],
            "Ready for Internal UAT": ["Ready for Internal UAT"], "Internal UAT": ["Internal UAT"],
            "UAT": ["Ready for Client UAT", "In Client UAT", "Ready for UAT Sign-off", "Processing Sign-off"],
            "Deployment": ["Ready for Merge", "Merging", "Ready for Deployment", "Deploying"],
            "Deployed": ["Deployed to Prod"], "Done": ["Done", "Cancelled"]
        }
    };

    personaColumnExtensionMap = {
        Client: {
            "Backlog": false, "Scoping": false, "Clarification Requested (Pre-Dev)": false, "Providing Clarification": false,
            "Estimation": true, "Ready for Prioritization": false, "Prioritizing": false, "Proposal": true, "Dev Approval": true,
            "Ready for Client Approval": false, "In Client Approval": false, "In Development": false, "QA & Review": true,
            "Ready for Client UAT": false, "In Client UAT": false, "Deployment Prep": true, "Deployed": false, "Done": true, "Cancelled": true
        },
        Consultant: {
            "Backlog": false, "Scoping In Progress": false, "Clarification Requested (Pre-Dev)": false, "Providing Clarification": false,
            "Ready for Sizing": false, "Sizing Underway": false, "Ready for Prioritization": false, "Prioritizing": false,
            "Proposal Requested": false, "Drafting Proposal": false, "Ready for Tech Review": false, "Tech Reviewing": false,
            "Client Approval": true, "Dev Queue": false, "Dev Work": false, "Rework": false, "Blocked": false, "Dev Clarification": false,
            "Ready for Scratch Test": false, "Scratch Testing": false, "Ready for QA": false, "QA In Progress": false,
            "Ready for Internal UAT": false, "Internal UAT": false, "Client UAT": true, "Ready for UAT Sign-off": true,
            "Processing Sign-off": true, "Ready for Merge": true, "Merging": true, "Ready for Deployment": true, "Deploying": true,
            "Deployed": false, "Done": false
        },
        Developer: {
            "Backlog": true, "Clarification": true, "Ready for Sizing": false, "Sizing Underway": false,
            "Prioritization": true, "Proposal Requested": false, "Drafting Proposal": false, "Ready for Tech Review": false,
            "Tech Reviewing": false, "Client Approval": true, "Dev Queue": false, "Dev Work": false, "Rework": false,
            "Blocked": false, "Dev Clarification": false, "QA": true, "UAT": true, "Deployment": true, "Deployed": true, "Done": true
        },
        QA: {
            "Backlog": true, "Clarification": true, "Sizing": true, "Prioritization": true, "Dev Approval": true,
            "Client Approval": true, "Dev Queue": false, "Dev Work": false, "Ready for Scratch Test": false,
            "Scratch Testing": false, "Ready for QA": false, "QA In Progress": false, "Ready for Internal UAT": false,
            "Internal UAT": false, "UAT": true, "Deployment": true, "Deployed": true, "Done": true
        }
    };

    personaBoardViews = {
        Client: {
            all: ["Backlog", "Scoping", "Clarification Requested (Pre-Dev)", "Providing Clarification", "Estimation", "Ready for Prioritization", "Prioritizing", "Proposal", "Dev Approval", "Ready for Client Approval", "In Client Approval", "In Development", "QA & Review", "Ready for Client UAT", "In Client UAT", "Deployment Prep", "Deployed", "Done"],
            predev: ["Backlog", "Scoping", "Clarification Requested (Pre-Dev)", "Providing Clarification", "Estimation", "Ready for Prioritization", "Prioritizing", "Proposal"],
            indev: ["Dev Approval", "Ready for Client Approval", "In Client Approval", "In Development", "QA & Review"],
            deployed: ["Ready for Client UAT", "In Client UAT", "Deployment Prep", "Deployed", "Done"]
        },
        Consultant: {
            all: ["Backlog", "Scoping In Progress", "Clarification Requested (Pre-Dev)", "Providing Clarification", "Ready for Sizing", "Sizing Underway", "Ready for Prioritization", "Prioritizing", "Proposal Requested", "Drafting Proposal", "Ready for Tech Review", "Tech Reviewing", "Client Approval", "Dev Queue", "Dev Work", "Rework", "Blocked", "Dev Clarification", "Ready for Scratch Test", "Scratch Testing", "Ready for QA", "QA In Progress", "Ready for Internal UAT", "Internal UAT", "Client UAT", "Ready for UAT Sign-off", "Processing Sign-off", "Ready for Merge", "Merging", "Ready for Deployment", "Deploying", "Deployed", "Done"],
            predev: ["Backlog", "Scoping In Progress", "Clarification Requested (Pre-Dev)", "Providing Clarification", "Ready for Sizing", "Sizing Underway", "Ready for Prioritization", "Prioritizing", "Proposal Requested", "Drafting Proposal"],
            indev: ["Ready for Tech Review", "Tech Reviewing", "Client Approval", "Dev Queue", "Dev Work", "Rework", "Blocked", "Dev Clarification", "Ready for Scratch Test", "Scratch Testing", "Ready for QA", "QA In Progress"],
            deployed: ["Ready for Internal UAT", "Internal UAT", "Client UAT", "Ready for UAT Sign-off", "Processing Sign-off", "Ready for Merge", "Merging", "Ready for Deployment", "Deploying", "Deployed", "Done"]
        },
        Developer: {
            all: ["Backlog", "Clarification", "Ready for Sizing", "Sizing Underway", "Prioritization", "Proposal Requested", "Drafting Proposal", "Ready for Tech Review", "Tech Reviewing", "Client Approval", "Dev Queue", "Dev Work", "Rework", "Blocked", "Dev Clarification", "QA", "UAT", "Deployment", "Deployed", "Done"],
            predev: ["Backlog", "Clarification", "Ready for Sizing", "Sizing Underway", "Prioritization", "Proposal Requested", "Drafting Proposal"],
            indev: ["Ready for Tech Review", "Tech Reviewing", "Client Approval", "Dev Queue", "Dev Work", "Rework", "Blocked", "Dev Clarification"],
            deployed: ["QA", "UAT", "Deployment", "Deployed", "Done"]
        },
        QA: {
            all: ["Backlog", "Clarification", "Sizing", "Prioritization", "Dev Approval", "Client Approval", "Dev Queue", "Dev Work", "Ready for Scratch Test", "Scratch Testing", "Ready for QA", "QA In Progress", "Ready for Internal UAT", "Internal UAT", "UAT", "Deployment", "Deployed", "Done"],
            predev: ["Backlog", "Clarification", "Sizing", "Prioritization", "Dev Approval", "Client Approval"],
            indev: ["Dev Queue", "Dev Work", "Ready for Scratch Test", "Scratch Testing", "Ready for QA", "QA In Progress"],
            deployed: ["Ready for Internal UAT", "Internal UAT", "UAT", "Deployment", "Deployed", "Done"]
        }
    };
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
        "Prioritizing":                      [                                                                                                          "Proposal Requested",    "Ready for Tech Review",    "Ready for Client Approval"],
        "Proposal Requested":                ["Drafting Proposal",                                                                                                               "Ready for Tech Review",    "Ready for Client Approval"],
        "Drafting Proposal":                 [                                                                                                                                   "Ready for Tech Review",    "Ready for Client Approval"],

        // --- PHASE 3: TECHNICAL & CLIENT APPROVAL ---
        "Ready for Tech Review":             ["Tech Reviewing",                                                                                                                  "Ready for Client Approval",    "Ready for Development"],
        "Tech Reviewing":                    [                                                                                                                                   "Ready for Client Approval",    "Ready for Development"],
        "Ready for Client Approval":         ["In Client Approval",                                                                                                                                              "Ready for Development"],
        "In Client Approval":                [                                                                                                                                                                   "Ready for Development"],

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
        // --- PHASE 1: DEFINITION & SCOPING ---
        "Scoping In Progress":               ["Backlog",                                                                                                                                                                                                                                                                                                                                                                                                                                                  "Cancelled"],
        "Clarification Requested (Pre-Dev)": ["Scoping In Progress",               "Backlog",                                                                                                                                                                                                                                                                                                                                                                                                                 "Cancelled"],
        "Providing Clarification":           ["Clarification Requested (Pre-Dev)", "Scoping In Progress",               "Backlog",                                                                                                                                                                                                                                                                                                                                                                                "Cancelled"],

        // --- PHASE 2: ESTIMATION & PRIORITIZATION ---
        "Ready for Sizing":                  ["Providing Clarification",           "Clarification Requested (Pre-Dev)", "Scoping In Progress",               "Backlog",                                                                                                                                                                                                                                                                                                                                       "Cancelled"],
        "Sizing Underway":                   ["Ready for Sizing",                                                                                                                                                                                                                                                                                                                                                                                                                                                 "Cancelled"],
        "Ready for Prioritization":          ["Sizing Underway",                   "Ready for Sizing",                  "Providing Clarification",                                                                                                                                                                                                                                                                                                                                                                "Cancelled"],
        "Prioritizing":                      ["Ready for Prioritization",                                                                                                                                                                                                                                                                                                                                                                                                                                         "Cancelled"],
        "Proposal Requested":                ["Prioritizing",                      "Ready for Prioritization",          "Sizing Underway",                                                                                                                                                                                                                                                                                                                                                                        "Cancelled"],
        "Drafting Proposal":                 ["Proposal Requested",                                                                                                                                                                                                                                                                                                                                                                                                                                               "Cancelled"],

        // --- PHASE 3: TECHNICAL & CLIENT APPROVAL ---
        "Ready for Tech Review":             ["Drafting Proposal",                 "Proposal Requested",                "Sizing Underway",                   "Ready for Prioritization",                                                                                                                                                                                                                                                                                                                          "Cancelled"],
        "Tech Reviewing":                    ["Ready for Tech Review",                                                                                                                                                                                                                                                                                                                                                                                                                                            "Cancelled"],
        "Ready for Client Approval":         ["Tech Reviewing",                    "Ready for Tech Review",             "Drafting Proposal",                 "Sizing Underway",                                                                                                                                                                                                                                                                                                                                   "Cancelled"],
        "In Client Approval":                ["Ready for Client Approval",                                                                                                                                                                                                                                                                                                                                                                                                                                        "Cancelled"],

        // --- PHASE 4: DEVELOPMENT ---
        "Ready for Development":             ["In Client Approval",                "Ready for Client Approval",         "Tech Reviewing",                    "Prioritizing",                                                                                                                                                                                                                                                                                                                                      "Cancelled"],
        "In Development":                    ["Ready for Development",                                                                                                                                                                                                                                                                                                                                                                                                                                            "Cancelled"],
        "Dev Clarification Requested":       ["In Development",                                                                                                                                                                                                                                                                                                                                                                                                                                                   "Cancelled"],
        "Providing Dev Clarification":       ["Dev Clarification Requested",                                                                                                                                                                                                                                                                                                                                                                                                                                      "Cancelled"],
        "Dev Blocked":                       ["In Development",                                                                                                                                                                                                                                                                                                                                                                                                                                                   "Cancelled"],
        "Back For Development":              ["Dev Clarification Requested",       "In Development",                                                                                                                                                                                                                                                                                                                                                                                                                  "Cancelled"],

        // --- PHASE 5: TESTING (QA & INTERNAL) ---
        "Ready for Scratch Test":            ["In Development",                                                                                                                                                                                                                                                                                                                                                                                                                                                   "Cancelled"],
        "Scratch Testing":                   ["Ready for Scratch Test",                                                                                                                                                                                                                                                                                                                                                                                                                                           "Cancelled"],
        "Ready for QA":                      ["Scratch Testing",                   "Ready for Scratch Test",            "In Development",                                                                                                                                                                                                                                                                                                                                                                             "Cancelled"],
        "QA In Progress":                    ["Ready for QA",                                                                                                                                                                                                                                                                                                                                                                                                                                                     "Cancelled"],
        "Ready for Internal UAT":            ["QA In Progress",                    "Ready for QA",                                                                                                                                                                                                                                                                                                                                                                                                                    "Cancelled"],
        "Internal UAT":                      ["Ready for Internal UAT",                                                                                                                                                                                                                                                                                                                                                                                                                                           "Cancelled"],

        // --- PHASE 6: CLIENT UAT ---
        "Ready for Client UAT":              ["Internal UAT",                      "Ready for Internal UAT",            "QA In Progress",                                                                                                                                                                                                                                                                                                                                                                             "Cancelled"],
        "In Client UAT":                     ["Ready for Client UAT",                                                                                                                                                                                                                                                                                                                                                                                                                                             "Cancelled"],
        "Ready for UAT Sign-off":            ["In Client UAT",                                                                                                                                                                                                                                                                                                                                                                                                                                                    "Cancelled"],
        "Processing Sign-off":               ["Ready for UAT Sign-off",                                                                                                                                                                                                                                                                                                                                                                                                                                           "Cancelled"],

        // --- PHASE 7: DEPLOYMENT ---
        "Ready for Merge":                   ["Processing Sign-off",               "Ready for UAT Sign-off",            "In Client UAT",                                                                                                                                                                                                                                                                                                                                                                              "Cancelled"],
        "Merging":                           ["Ready for Merge",                                                                                                                                                                                                                                                                                                                                                                                                                                                  "Cancelled"],
        "Ready for Deployment":              ["Merging",                           "Ready for Merge",                   "Processing Sign-off",                                                                                                                                                                                                                                                                                                                                                                        "Cancelled"],
        "Deploying":                         ["Ready for Deployment",                                                                                                                                                                                                                                                                                                                                                                                                                                             "Cancelled"],
        "Deployed to Prod":                  ["Deploying",                         "Ready for Deployment",                                                                                                                                                                                                                                                                                                                                                                                                            "Cancelled"],
        
        // --- PHASE 8: END STATES ---
        "Done":                              ["Deployed to Prod",                                                                                                                                                                                                                                                                                                                                                                                                                                                 "Cancelled"],
        "Backlog":                           [                                                                                                                                                                                                                                                                                                                                                                                                                                                                    "Cancelled"],
        "Cancelled":                         ["Backlog",                           "Ready for Sizing",                  "Ready for Development"] 
    };

    intentionColor = { "Will Do": "#2196F3", "Sizing Only": "#FFD54F" };
    personaAdvanceOverrides = {};
    personaBacktrackOverrides = {};

    @wire(getTickets)
    wiredTickets(result) {
        this.ticketsWire = result; 
        const { data, error } = result;
        if (data) {
            this.realRecords = [...data]; 
            this.loadETAs(); 
        } else if (error) {
            console.error("Ticket wire error", error);
        }
    }

    openCreateModal() {
        const nums = (this.realRecords || [])
            .map((r) => {
                const val = r[FIELDS.SORT_ORDER] || r['delivery__SortOrderNumber__c'] || r['SortOrderNumber__c'];
                return val;
            })
            .filter((n) => n !== null && n !== undefined);
        
        this.nextSortOrder = nums.length ? Math.max(...nums) + 1 : 1;
        this.showCreateModal = true;
    }

    handleFileUpload(event) {
        const uploadedFiles = event.detail.files;
        this.uploadedFileIds.push(...uploadedFiles.map((file) => file.documentId));
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

    handleShowModeChange(event) {
        const selectedMode = event.currentTarget.dataset.mode;
        this.showMode = selectedMode;
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
        refreshApex(this.ticketsWire)
            .then(() => this.loadETAs())
            .catch((err) => console.error("Ticket reload error", err));
    }

    get createDefaults() {
        return {
            [FIELDS.STAGE]: "Backlog",
            [FIELDS.SORT_ORDER]: this.nextSortOrder,
            [FIELDS.PRIORITY]: "Medium",
            [FIELDS.IS_ACTIVE]: true,
        };
    }

    // [Getter options]
    get personaOptions() { return Object.keys(this.personaColumnStatusMap).map((p) => ({ label: p, value: p })); }
    get sizeModeOptions() { return [{ label: "Equal Sized", value: "equalSized" }, { label: "Ticket Sized", value: "ticketSize" }]; }
    get hasRecentComments() { return (this.recentComments || []).length > 0; }
    get displayModeOptions() { return [{ label: "Kanban", value: "kanban" }, { label: "Compact", value: "compact" }, { label: "Table", value: "table" }]; }
    get mainBoardClass() { if (this.displayMode === "table") return "table-board"; if (this.displayMode === "compact") return "stage-columns compact"; return "stage-columns"; }
    get isTableMode() { return this.displayMode === "table"; }

    // --- ENRICHED TICKETS (Namespace Agnostic & Sorted) ---
    get enrichedTickets() {
        const norm = (id) => (id || "").substring(0, 15);

        const etaMap = new Map(
            (this.etaResults || [])
                .filter((dto) => !!dto.ticketId)
                .map((dto) => [norm(dto.ticketId), dto])
        );

        // Helper to safely get field value regardless of namespace presence
        const getValue = (record, fieldName) => {
            if (!record) return null;
            if (record[fieldName] !== undefined) return record[fieldName];
            let localName = fieldName.replace('', '').replace('delivery__', '');
            if (record[localName] !== undefined) return record[localName];
            let nsName = 'delivery__' + localName;
            if (record[nsName] !== undefined) return record[nsName];
            return null;
        };

        // Helper to calculate day difference
        const getDayDiffString = (targetDateStr) => {
            if (!targetDateStr) return "";
            
            const today = new Date();
            today.setHours(0, 0, 0, 0); // Normalize to midnight
            
            const target = new Date(targetDateStr);
            target.setHours(0, 0, 0, 0); // Normalize to midnight
            
            // Calculate difference in milliseconds
            const diffTime = target - today;
            // Convert to days
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)); 

            if (diffDays > 0) return ` (+${diffDays}d)`;
            if (diffDays < 0) return ` (${diffDays}d)`; // Negative sign is automatic
            return " (Today)";
        };

        // 1. Sort Records Client-Side
        const sortedRecords = [...(this.realRecords || [])].sort((a, b) => {
            const orderA = getValue(a, FIELDS.SORT_ORDER) || 0;
            const orderB = getValue(b, FIELDS.SORT_ORDER) || 0;
            return orderA - orderB;
        });

        return sortedRecords.map((rec) => {
            const etaDto = etaMap.get(norm(rec.Id));

            // Extract values safely
            const briefDesc = getValue(rec, FIELDS.BRIEF_DESC);
            const details = getValue(rec, FIELDS.DETAILS);
            const priority = getValue(rec, FIELDS.PRIORITY);
            const tags = getValue(rec, FIELDS.TAGS);
            const stage = getValue(rec, FIELDS.STAGE); 
            const intention = getValue(rec, FIELDS.INTENTION);
            const size = getValue(rec, FIELDS.DEV_DAYS_SIZE);
            
            const actualHours = getValue(rec, FIELDS.TOTAL_LOGGED_HOURS) || 0;
            const estimatedHours = getValue(rec, FIELDS.ESTIMATED_HOURS) || 0;
            const uatDate = getValue(rec, FIELDS.PROJECTED_UAT_READY);
            const createdDate = getValue(rec, FIELDS.CREATED_DATE);
            const recordStoredETA = getValue(rec, FIELDS.CALCULATED_ETA);

            // --- DATE DISPLAY LOGIC ---
            let displayDate = "—";
            let dateLabel = "No Date";
            let rawDateForDiff = null; // Store the raw date to calculate the diff
            
            if (etaDto && etaDto.calculatedETA) {
                // 1. Live Calculation
                rawDateForDiff = etaDto.calculatedETA;
                displayDate = new Date(rawDateForDiff).toLocaleDateString();
                dateLabel = "Est. Completion (Live)";
            } else if (recordStoredETA) {
                // 2. Stored Value (Fallback)
                rawDateForDiff = recordStoredETA;
                // Parse date manually to avoid timezone shifts on simple YYYY-MM-DD strings
                displayDate = new Date(rawDateForDiff).toLocaleDateString(undefined, { timeZone: 'UTC' });
                dateLabel = "Est. Completion";
            } else if (createdDate) {
                // 3. Created Date
                displayDate = new Date(createdDate).toLocaleDateString();
                dateLabel = "Created";
                // We typically don't show (+5d) for created date, so we leave rawDateForDiff null
            }

            // Append day difference if we have a valid ETA date
            if (rawDateForDiff) {
                displayDate += getDayDiffString(rawDateForDiff);
            }

            // UAT Date Display
            let displayUAT = null;
            if (uatDate) {
                displayUAT = new Date(uatDate).toLocaleDateString(undefined, { month: 'short', day: 'numeric', timeZone: 'UTC' });
            }

            const hoursDisplay = `${actualHours} / ${estimatedHours}h`;

            const blockedByRaw = getValue(rec, FIELDS.DEP_REL_BLOCKED_BY) || [];
            const blockingRaw = getValue(rec, FIELDS.DEP_REL_BLOCKING) || [];

            const isBlockedBy = blockedByRaw.map(dep => ({
                id: getValue(dep, FIELDS.BLOCKING_TICKET),
                name: dep['Blocking_Ticket__r']?.Name || dep['Blocking_Ticket__r']?.Name || dep['Blocking_Ticket__c'],
                dependencyId: dep.Id
            }));

            const isBlocking = blockingRaw.map(dep => ({
                id: getValue(dep, FIELDS.BLOCKED_TICKET),
                name: dep['Blocked_Ticket__r']?.Name || dep['Blocked_Ticket__r']?.Name || dep['Blocked_Ticket__c'],
                dependencyId: dep.Id
            }));

            const getTagsArray = (tagsString) => {
                if (!tagsString || typeof tagsString !== "string") return [];
                return tagsString.split(",").map((tag) => tag.trim()).filter((tag) => tag);
            };

            return {
                ...rec,
                uiId: rec.Id,
                uiTitle: briefDesc, 
                uiDescription: details,
                uiSize: size || "--",
                uiHours: hoursDisplay, 
                uiUat: displayUAT,      
                uiStage: stage, 
                uiIntention: intention, 
                uiPriority: priority,
                calculatedETA: displayDate, // Now includes "Jan 21, 2026 (-8d)"
                dateTooltip: dateLabel,
                isBlockedBy: isBlockedBy,
                isBlocking: isBlocking,
                isCurrentlyBlocked: isBlockedBy.length > 0,
                OwnerName: rec.Owner?.Name, 
                isHighPriority: priority?.toLowerCase() === "high",
                tags: getTagsArray(tags),
                cardClasses: `ticket-card`,
                priorityClasses: `priority-badge priority-${priority?.toLowerCase()}`,
            };
        });
    }

    // ... [Getters for columns and other options remain unchanged] ...
    // Paste stageColumns, getClientColumnHeaderColor, etc. here
    get stageColumns() {
        // (Use the version I gave you previously, it works fine)
        const persona = this.persona;
        const boardViews = this.personaBoardViews?.[persona] || {};
        let colNames = boardViews?.[this.overallFilter] || [];
        const statusMap = this.personaColumnStatusMap?.[persona] || {};
        const enriched = this.enrichedTickets || [];
        const extMap = this.personaColumnExtensionMap?.[persona] || {};

        if (!this.showAllColumns) {
            colNames = colNames.filter((col) => {
                const isExtended = extMap[col]; 
                return !isExtended; 
            });
        }

        let columns = colNames.map((colName) => {
            const config = this.columnHeaderStyleMap[colName] || { bg: "#ffffff", color: "#11182c" };
            const headerStyle = `background:${config.bg};color:${config.color};`;

            const columnTickets = enriched
                .filter((t) => (statusMap[colName] || []).includes(t.uiStage)) 
                .filter((t) => {
                    if (this.intentionFilter === "all") return true;
                    const intention = (t.uiIntention || "").trim().toLowerCase();
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
    
    getColumnDisplayName(colKey) { return this.columnDisplayNames?.[colKey] || colKey; }
    
    // [Client Header Colors and Card Colors]
    getClientColumnHeaderColor(colName) {
        const yellowCols = ["Quick Estimate", "Proposal Needed", "Pending Development Approval", "Ready for Development"];
        const orangeCols = ["In Development", "In Review", "Ready for UAT (Client)"];
        const blueCols = ["Deployed to Prod", "Done"];
        if (yellowCols.includes(colName)) return "#FFE082";
        if (orangeCols.includes(colName)) return "#FF9100";
        if (blueCols.includes(colName)) return "#e3f2fd";
        if (colName === "Backlog" || colName === "Active Scoping") return "#e3f2fd";
        return "#2196F3"; 
    }
    getClientCardColor(status) { return this.statusColorMap[status] || "#eee"; }

    get advanceOptions() {
        if (!this.selectedRecord) return [];
        // FIX: Use uiStage which is already normalized
        const currStage = this.enrichedTickets.find(t => t.Id === this.selectedRecord.Id)?.uiStage; 
        if (!currStage) return [];

        const persona = this.persona;
        const nextStages = this.transitionMap[currStage] || [];

        return nextStages.filter((tgt) => tgt !== currStage).map((tgt) => {
            const override = this.personaAdvanceOverrides?.[persona]?.[currStage]?.[tgt] || {};
            let style = "";
            if (this.columnHeaderStyleMap && this.columnHeaderStyleMap[tgt]) {
                const { bg, color } = this.columnHeaderStyleMap[tgt];
                style = `background:${bg};color:${color};`;
            } else { style = "background:#e0e0e0;color:#222;"; }
            let icon = override.icon || "➡️";
            if (tgt === "Active Scoping") icon = "🚀";
            if (tgt === "Cancelled") icon = "🛑";
            return { value: tgt, label: override.label || tgt, icon, style, autofocus: override.autofocus || false };
        });
    }

    get backtrackOptions() {
        if (!this.selectedRecord) return [];
        // FIX: Use uiStage
        const currStage = this.enrichedTickets.find(t => t.Id === this.selectedRecord.Id)?.uiStage;
        if (!currStage) return [];

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
                } else { style = "background:#e0e0e0;color:#222;"; }
                return { value: tgt, label: override.label || tgt, icon: override.icon || "🔙", style };
            });
        } else {
            const prevStages = this.backtrackMap[currStage] || [];
            targets = prevStages.map((tgt) => {
                let style = "";
                if (this.columnHeaderStyleMap && this.columnHeaderStyleMap[tgt]) {
                    const { bg, color } = this.columnHeaderStyleMap[tgt];
                    style = `background:${bg};color:${color};`;
                } else { style = "background:#e0e0e0;color:#222;"; }
                return { value: tgt, label: tgt, icon: "⬅️", style };
            });
        }
        return targets;
    }

    // [Filter Options]
    get overallFilterOptions() { return [{ label: "All", value: "all" }, { label: "Pre-Dev", value: "predev" }, { label: "In-Dev & Review", value: "indev" }, { label: "Deployed/Done", value: "deployed" }]; }
    get intentionFilterOptions() { return [{ label: "All", value: "all" }, { label: "Will Do", value: "Will Do" }, { label: "Sizing Only", value: "Sizing Only" }]; }

    handleIntentionFilterChange(e) { this.intentionFilter = e.detail ? e.detail.value : e.target.value; }
    handleOverallFilterChange(e) { this.overallFilter = e.detail ? e.detail.value : e.target.value; }
    handleToggleColumns(e) { this.showAllColumns = e.target.checked; this.logBoardState(); }
    columnOwner(colName) { const personaMap = this.personaColumnStatusMap[this.persona] || {}; const statuses = personaMap[colName] || []; const firstStatus = statuses[0]; return this.statusOwnerMap[firstStatus] || "Default"; }
    
    // --- LOAD ETAS ---
    handleNumDevsChange(e) { this.numDevs = parseInt(e.target.value, 10) || 1; this.loadETAs(); }
    
    loadETAs() {
        getTicketETAsWithPriority({
            numberOfDevs: this.numDevs,
            prioritizedTicketIds: null,
        })
        .then((result) => {
            this.etaResults = result && result.tickets ? [...result.tickets] : [];
        })
        .catch((err) => {
            this.etaResults = [];
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

    // FIX: Removed debugData which was causing lint error
    logBoardState() {
        setTimeout(() => {
            try {
                // Logic kept simple or removed to satisfy linter
                // const columns = this.stageColumns;
                // console.log('Board State Updated');
            } catch (error) {
                console.error('Error logging board state:', error);
            }
        }, 100);
    }

    handleSizeModeChange(e) { this.sizeMode = e.detail ? e.detail.value : e.target.value; }
    handleDisplayModeChange(e) { this.displayMode = e.detail ? e.detail.value : e.target.value; }
    
    handleTitleClick(e) {
        const id = e.currentTarget.dataset.id;
        if (id) {
            this[NavigationMixin.Navigate]({ type: "standard__recordPage", attributes: { recordId: id, objectApiName: "Ticket__c", actionName: "view" } });
        }
    }

    handleCardClick(e) {
        const id = e.currentTarget?.dataset?.id || e.target?.dataset?.id;
        this.selectedRecord = (this.realRecords || []).find((r) => r.Id === id);
        this.selectedStage = null;
        this.showModal = true;
        this.moveComment = "";
    }

    async handleAdvanceOption(e) {
        const newStage = e.currentTarget.dataset.value; // Use currentTarget
        const ticketId = this.selectedRecord.Id;
        try {
            const requiredFields = await getRequiredFieldsForStage({ targetStage: newStage });
            if (requiredFields && requiredFields.length > 0) {
                this.closeModal(); 
                this.transitionTicketId = ticketId;
                this.transitionTargetStage = newStage;
                this.transitionRequiredFields = requiredFields;
                this.showTransitionModal = true;
            } else {
                this.selectedStage = newStage;
                this.handleSaveTransition();
            }
        } catch (error) {
            console.error('Stage Check Error:', error);
            this.showToast('Error', 'Could not check for stage requirements.', 'error');
        }
    }

    async handleBacktrackOption(e) {
        const newStage = e.target.dataset.value;
        const ticketId = this.selectedRecord.Id;
        try {
            const requiredFields = await getRequiredFieldsForStage({ targetStage: newStage });
            if (requiredFields && requiredFields.length > 0) {
                this.closeModal(); 
                this.transitionTicketId = ticketId;
                this.transitionTargetStage = newStage;
                this.transitionRequiredFields = requiredFields;
                this.showTransitionModal = true;
            } else {
                this.selectedStage = newStage;
                this.handleSaveTransition();
            }
        } catch (error) {
            this.showToast('Error', 'Could not check for stage requirements.', 'error');
        }
    }

    handleStageChange(e) { this.selectedStage = e.detail ? e.detail.value : e.target.value; }
    handleCommentChange(e) { this.moveComment = e.detail ? e.detail.value : e.target.value; }
    
    handleSaveTransition() {
        const rec = this.selectedRecord;
        const newStage = this.selectedStage;
        
        if (!rec || !newStage) {
            this.closeModal();
            return;
        }

        const fields = { 
            Id: rec.Id, 
            '%%%NAMESPACED_ORG%%%StageNamePk__c': newStage 
        };

        updateRecord({ fields })
            .then(async () => {
                let commentCreated = false;

                // this.moveComment is still valid here because we haven't closed the modal yet
                if (this.moveComment && this.moveComment.trim() !== "") {
                    try {
                        await this.createStatusComment(rec.Id);
                        commentCreated = true;
                    } catch (commentErr) {
                        console.warn('Comment creation failed but ticket was updated', commentErr);
                    }
                }

                if (commentCreated) {
                    this.showToast("Success", "Ticket moved and comment added.", "success");
                } else {
                    this.showToast("Success", "Ticket moved to " + newStage + ".", "success");
                }

                this.refreshTickets(); 
                this.closeModal(); // MOVED HERE
            })
            .catch((error) => {
                console.error("Update Error:", error);
                this.showToast("Error", "Failed to update ticket.", "error");
                this.closeModal(); // MOVED HERE
            });
            
        // REMOVED from here
    }

    // FIX: Removed unused event param
    async handleTransitionSuccess(event) {
        const ticketId = event.detail.id;
        let commentCreated = false;

        if (this.moveComment && this.moveComment.trim() !== "") {
            try {
                await this.createStatusComment(ticketId);
                commentCreated = true;
            } catch (err) {
                console.warn('Comment failed but stage transition succeeded', err);
                // Optionally: this.showToast('Warning', 'Comment could not be saved', 'warning');
            }
        }

        if (commentCreated) {
            this.showToast('Success', 'Ticket updated and comment saved.', 'success');
        } else {
            this.showToast('Success', 'Ticket moved successfully.', 'success');
        }

        this.closeTransitionModal();
        this.refreshTickets();
    }

    handleTransitionError(event) {
        this.showToast('Error Saving Ticket', 'Please review the fields and try again.', 'error');
        console.error('Error on transition save:', JSON.stringify(event.detail));
    }

    // [Drag Handlers]
    handleDragStart(event) {
        this.isDragging = true;
        const ticketId = event.target.dataset.id;
        event.dataTransfer.setData("text/plain", ticketId);
        event.dataTransfer.effectAllowed = "move";
        // Enriched tickets is sorted, use it to find the drag item
        this.draggedItem = this.enrichedTickets.find((t) => t.uiId === ticketId);

        this.placeholder = document.createElement("div");
        this.placeholder.className = "drag-placeholder";
        this.placeholder.style.height = `${event.target.offsetHeight}px`;

        const board = this.template.querySelector(".js-kanban-board");
        if (board) {
            board.classList.add("drag-is-active");
        }
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
        if (this.placeholder && this.placeholder.parentNode) {
            this.placeholder.parentNode.removeChild(this.placeholder);
        }
        this.placeholder = null;

        this.template.querySelectorAll(".kanban-column.drag-over").forEach((col) => {
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

        if (!column.classList.contains("drag-over")) {
            this.template.querySelectorAll(".kanban-column.drag-over").forEach((col) => col.classList.remove("drag-over"));
            column.classList.add("drag-over");
        }

        const cardsContainer = column.querySelector(".kanban-column-body");
        const afterElement = this.getDragAfterElement(cardsContainer, event.clientY);

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
        const draggableElements = [...container.querySelectorAll(".ticket-card:not(.is-dragging)")];
        return draggableElements.reduce((closest, child) => {
            const box = child.getBoundingClientRect();
            const offset = y - box.top - box.height / 2;
            if (offset < 0 && offset > closest.offset) {
                return { offset: offset, element: child };
            } else {
                return closest;
            }
        }, { offset: Number.NEGATIVE_INFINITY }).element;
    }

    // --- UPDATED DROP HANDLER ---
    async handleDrop(event) {
        event.preventDefault();
        const ticketId = this.draggedItem.uiId;
        const dropColumnEl = event.target.closest('.kanban-column');
        
        if (!dropColumnEl) {
            this.handleDragEnd();
            return;
        }

        const targetColumnStage = dropColumnEl.dataset.stage;

        // 1. Get the internal Salesforce Picklist value for this column
        const newInternalStage = (this.personaColumnStatusMap[this.persona][targetColumnStage] || [])[0];
        if (!newInternalStage) {
            this.handleDragEnd();
            this.showToast('Error', 'Invalid target stage.', 'error');
            return;
        }

        // 2. Calculate the INTEGER Index where the user dropped the card
        const columnTickets = this.stageColumns.find(c => c.stage === targetColumnStage).tickets || [];
        let dropIndex = columnTickets.length; // Default to end

        // FIX: Calculate position BEFORE calling handleDragEnd (which destroys the placeholder)
        if (this.placeholder && this.placeholder.parentNode) {
            const nextSibling = this.placeholder.nextElementSibling;
            if (nextSibling) {
                const nextId = nextSibling.dataset.id;
                // Find index of that ticket in the data array
                const indexInData = columnTickets.findIndex(t => t.uiId === nextId);
                // If we found the neighbor, put our ticket at that index. 
                if (indexInData !== -1) {
                    dropIndex = indexInData;
                }
            } else {
                // No next sibling means we dropped at the very bottom
                dropIndex = columnTickets.length;
            }
        }

        // 3. NOW it is safe to cleanup the drag visuals
        this.handleDragEnd();

        // 4. Call Apex to Reorder
        try {
            await reorderTicket({ 
                ticketId: ticketId, 
                newStage: newInternalStage, 
                newIndex: dropIndex 
            });
            this.showToast('Success', 'Ticket moved.', 'success');
            this.refreshTickets();
        } catch (error) {
            const errorMessage = error.body?.message || 'An unknown error occurred.';
            this.showToast('Move Failed', errorMessage, 'error');
        }
    }

    // 3. ADD this new helper function to calculate sort order
    calculateNewSortOrder(placeholder, columnTickets) {
        const prevSibling = placeholder.previousElementSibling;
        const nextSibling = placeholder.nextElementSibling;

        // Find the corresponding ticket data for the siblings
        const prevTicket = prevSibling
            ? columnTickets.find((t) => t.uiId === prevSibling.dataset.id)
            : null;
        const nextTicket = nextSibling
            ? columnTickets.find((t) => t.uiId === nextSibling.dataset.id)
            : null;
        
        // FIX: Handle namespace for SortOrder here too using our new safe patterns or direct access
        const getSort = (t) => t[FIELDS.SORT_ORDER] || t['delivery__SortOrderNumber__c'] || t['SortOrderNumber__c'] || 0;

        const sortBefore = prevTicket ? getSort(prevTicket) : 0;

        if (nextTicket) {
            return (sortBefore + getSort(nextTicket)) / 2.0;
        } else {
            return sortBefore + 1; 
        }
    }
    
    // --- NEW: Handle Create Submit to force Defaults ---
    handleCreateSubmit(event) {
        event.preventDefault(); 
        const fields = event.detail.fields;
        
        // Force defaults (namespaced keys)
        fields[FIELDS.IS_ACTIVE] = true;
        if (!fields[FIELDS.PRIORITY]) {
            fields[FIELDS.PRIORITY] = 'Medium';
        }

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }
    
    handleCreateCancel() {
        this.showCreateModal = false;
        this.aiSuggestions = null;
        this.isAiProcessing = false;
        this.createTicketTitle = "";
        this.createTicketDescription = "";
        this.formFieldValues = {};
    }

    handleCreateSuccess(event) {
        this.showCreateModal = false;
        const newTicketId = event.detail.id;

        if (this.uploadedFileIds.length > 0) {
            linkFilesAndSync({
                ticketId: newTicketId,
                contentDocumentIds: this.uploadedFileIds,
            }).catch((error) => {
                console.error("Error linking files and syncing to Jira:", error);
            });
            this.uploadedFileIds = [];
        }

        this.aiSuggestions = null;
        this.isAiProcessing = false;
        this.createTicketTitle = "";
        this.createTicketDescription = "";
        this.formFieldValues = {};

        this.refreshTickets();
    }
    
    // ... [Search Handlers & AI Handlers (handleFieldChange, handleAiEnhance, applyAiSuggestions, setFieldValue, dismissAiSuggestions)] ...
    
    handleFieldChange(event) {
        const fieldName = event.target.fieldName;
        const fieldValue = event.target.value;
    
        this.formFieldValues[fieldName] = fieldValue;
    
        if (fieldName === FIELDS.BRIEF_DESC) {
            this.createTicketTitle = fieldValue || "";
        } else if (fieldName === FIELDS.DETAILS) {
            this.createTicketDescription = fieldValue || "";
        }
    }

    // FIX: Removed unused event param
    async handleAiEnhance() {
        try {
            let titleValue = "";
            let descriptionValue = "";
    
            titleValue = this.formFieldValues[FIELDS.BRIEF_DESC] || "";
            descriptionValue = this.formFieldValues[FIELDS.DETAILS] || "";
    
            if (!titleValue || !descriptionValue) {
                const titleField = this.template.querySelector(
                    `lightning-input-field[field-name="${FIELDS.BRIEF_DESC}"]`
                );
                const descriptionField = this.template.querySelector(
                    `lightning-input-field[field-name="${FIELDS.DETAILS}"]`
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
            
            if (!titleValue) titleValue = this.createTicketTitle || "";
            if (!descriptionValue) descriptionValue = this.createTicketDescription || "";
    
            this.createTicketTitle = titleValue;
            this.createTicketDescription = descriptionValue;

            if (!titleValue.trim() && !descriptionValue.trim()) {
                this.showToast("Input Required", "Please provide a title or description.", "warning");
                return;
            }

            if (this.isAiProcessing) return;

            this.isAiProcessing = true;
            this.aiSuggestions = null; 

            const result = await Promise.race([
                getAiEnhancedTicketDetails({
                    currentTitle: this.createTicketTitle,
                    currentDescription: this.createTicketDescription,
                }),
                new Promise((_, reject) => setTimeout(() => reject(new Error("Request timeout")), 30000))
            ]);

            if (!result || typeof result !== "object" || (!result.title && !result.description)) {
                throw new Error("AI service returned empty/invalid suggestions");
            }

            this.aiSuggestions = result;
            this.showToast("Success", "AI suggestions generated successfully!", "success");

        } catch (error) {
            let errorMessage = "Could not retrieve AI suggestions.";
            if (error.body && error.body.message) errorMessage = error.body.message;
            this.showToast("AI Error", errorMessage, "error");
            console.error("AI Enhancement Error:", error);
        } finally {
            this.isAiProcessing = false;
        }
    }
    
    applyAiSuggestions() {
        try {
            if (!this.aiSuggestions) {
                this.showToast("Error", "No AI suggestions available.", "error");
                return;
            }
            
            if (this.aiSuggestions.title) {
                this.createTicketTitle = this.aiSuggestions.title;
                this.formFieldValues[FIELDS.BRIEF_DESC] = this.aiSuggestions.title;
            }
            if (this.aiSuggestions.description) {
                this.createTicketDescription = this.aiSuggestions.description;
                this.formFieldValues[FIELDS.DETAILS] = this.aiSuggestions.description;
            }
            if (this.aiSuggestions.estimatedDays && this.AiEstimation) {
                this.estimatedDaysValue = this.aiSuggestions.estimatedDays;
                this.formFieldValues[FIELDS.DEV_DAYS_SIZE] = this.aiSuggestions.estimatedDays;
            }
            
            // Re-render inputs to show values
             setTimeout(() => {
                this.template.querySelectorAll("lightning-input-field").forEach((field) => {
                    field.dispatchEvent(new CustomEvent("change", { bubbles: true }));
                });
            }, 100);
            
            this.aiSuggestions = null;
            this.showToast("Success", "AI suggestions applied.", "success");
        } catch (error) {
             this.showToast("Error", "Failed to apply AI suggestions.", "error");
        }
    }
    
    setFieldValue(fieldName, value) {
        if (!value) return;
        const inputField = this.template.querySelector(`lightning-input-field[field-name="${fieldName}"]`);
        if (inputField) {
            inputField.value = value;
        }
    }

    dismissAiSuggestions() { this.aiSuggestions = null; }
    
    handleSearchTermChange(event) { this.searchTerm = event.target.value; }

    // FIX: Added logging to empty catch blocks to satisfy linter
    async handleSearch() {
        if (this.searchTerm.length < 3) return;
        this.isSearching = true;
        const existingDependencyIds = [
            ...this.selectedTicket.isBlockedBy.map(d => d.id),
            ...this.selectedTicket.isBlocking.map(d => d.id)
        ];
        try {
            this.searchResults = await searchForPotentialBlockers({
                searchTerm: this.searchTerm,
                currentTicketId: this.selectedTicket.Id,
                existingDependencyIds: existingDependencyIds
            });
        } catch (error) { 
            console.error('Search error:', error);
        } finally { 
            this.isSearching = false; 
        }
    }

    async handleSelectBlockingTicket(event) {
        const blockingTicketId = event.currentTarget.dataset.blockingId;
        try {
            await createDependency({ blockedTicketId: this.selectedTicket.Id, blockingTicketId: blockingTicketId });
            this.closeModal();
            this.refreshTickets();
        } catch (error) { 
            console.error('Dependency create error:', error);
        }
    }

    async handleRemoveDependency(event) {
        const dependencyId = event.currentTarget.dataset.dependencyId;
        try {
            await removeDependency({ dependencyId: dependencyId });
            this.closeModal();
            this.refreshTickets();
        } catch (error) { 
            console.error('Dependency remove error:', error);
        }
    }

    // [Dependency Management & Search]
    handleManageDependenciesClick(event) {
        const ticketId = event.currentTarget.dataset.id;
        this.selectedTicket = this.enrichedTickets.find(t => t.uiId === ticketId);
        if (this.selectedTicket) {
            this.isModalOpen = true;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    
    // [Modal & Transition Handlers]
    closeTransitionModal() {
        this.showTransitionModal = false;
        this.transitionTicketId = null;
        this.transitionTargetStage = null;
        this.transitionRequiredFields = [];
    }
}