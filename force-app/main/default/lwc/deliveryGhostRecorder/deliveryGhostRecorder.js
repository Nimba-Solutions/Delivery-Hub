import { LightningElement, track, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import userId from '@salesforce/user/Id';

// Apex Controllers
// Note: We use the namespaced paths for compilation
import createTicket from '@salesforce/apex/DeliveryGhostController.createQuickRequest'; 
import logActivity from '@salesforce/apex/DeliveryGhostController.logUserActivity';
import linkFilesAndSync from "@salesforce/apex/TicketController.linkFilesAndSync";

export default class DeliveryGhostRecorder extends LightningElement {
    @api enableShortcut = false; 
    @api displayMode = 'Card';   
    
    @track isOpen = false;
    @track description = '';
    @track priority = 'Medium';
    @track isSending = false;
    @track uploadedFileIds = [];
    
    currentPageRef;
    currentUserId = userId; // Used as temporary parent for file uploads

    get isCardMode() { return this.displayMode === 'Card'; }
    get isFloatingMode() { return this.displayMode === 'Floating Button'; }
    
    get priorityOptions() {
        return [
            { label: 'Low', value: 'Low' },
            { label: 'Medium', value: 'Medium' },
            { label: 'High', value: 'High' },
            { label: 'Critical', value: 'Critical' },
        ];
    }

    get uploadedFileCount() {
        return this.uploadedFileIds.length;
    }
    
    // 1. FLIGHT RECORDER LOGIC (Silent Context Capture)
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.currentPageRef = currentPageReference;
            this.handleNavigationLog();
        }
    }

    connectedCallback() {
        if (this.enableShortcut) {
            window.addEventListener('keydown', this.handleShortcut);
        }
    }

    disconnectedCallback() {
        window.removeEventListener('keydown', this.handleShortcut);
    }

    handleShortcut = (event) => {
        // Alt + B shortcut
        if (event.altKey && (event.code === 'KeyB' || event.key === 'b')) {
            this.togglePanel();
        }
    }

    handleNavigationLog() {
        const context = this.gatherContext();
        // Silent log to backend
        logActivity({ 
            actionType: 'Navigation',
            contextData: JSON.stringify(context) 
        }).catch(err => console.error('Ghost log failed', err));
    }

    // 2. UI HANDLERS
    togglePanel() {
        this.isOpen = !this.isOpen;
    }

    handleInputChange(event) {
        this.description = event.target.value;
    }

    handlePriorityChange(event) {
        this.priority = event.detail.value;
    }

    handleUploadFinished(event) {
        const files = event.detail.files;
        this.uploadedFileIds.push(...files.map(f => f.documentId));
    }

    handleSubmit() {
        if (!this.description) return;
        this.isSending = true;

        const context = this.gatherContext();
        // Auto-generate a Subject based on context
        const subjectLine = 'Issue on ' + (context.objectName || 'Home Page');

        createTicket({ 
            subject: subjectLine,
            description: this.description,
            priority: this.priority,
            contextData: JSON.stringify(context)
        })
        .then(ticketId => {
            // Link files if any
            if (this.uploadedFileIds.length > 0) {
                linkFilesAndSync({
                    ticketId: ticketId,
                    contentDocumentIds: this.uploadedFileIds
                }).catch(error => console.error("Error linking files:", error));
            }

            this.dispatchEvent(new ShowToastEvent({
                title: 'Ticket Created',
                message: 'Support has been notified.',
                variant: 'success'
            }));
            
            // Reset Form
            this.description = '';
            this.priority = 'Medium';
            this.uploadedFileIds = [];
            this.isOpen = false;
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        })
        .finally(() => {
            this.isSending = false;
        });
    }

    gatherContext() {
        let objName = this.currentPageRef?.attributes?.objectApiName;
        let recId = this.currentPageRef?.attributes?.recordId;
        
        if (!objName && this.currentPageRef?.attributes?.name) {
            objName = this.currentPageRef.attributes.name;
        }

        return {
            url: window.location.href,
            browser: navigator.userAgent,
            objectName: objName || 'Unknown',
            recordId: recId || ''
        };
    }
}