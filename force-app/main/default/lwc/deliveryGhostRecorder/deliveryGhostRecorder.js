import { LightningElement, track, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import createTicket from '@salesforce/apex/DeliveryGhostController.createQuickRequest'; // Points to the same method, just aliased clearly
import logActivity from '@salesforce/apex/DeliveryGhostController.logUserActivity';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DeliveryGhostRecorder extends LightningElement {
    @api enableShortcut = false; 
    @api displayMode = 'Card';   
    
    @track isOpen = false;
    @track description = '';
    @track isSending = false;
    
    currentPageRef;
    
    // 1. FLIGHT RECORDER LOGIC
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.currentPageRef = currentPageReference;
            // Silent Log: User moved to a new page
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
        // Alt + B (for Bug) or Option + B
        if (event.altKey && (event.code === 'KeyB' || event.key === 'b')) {
            this.togglePanel();
        }
    }

    handleNavigationLog() {
        const context = this.gatherContext();
        // Fire and forget - silent logging
        logActivity({ 
            actionType: 'Navigation',
            contextData: context
        }).catch(err => console.error('Ghost log failed', err));
    }

    // 2. UI HANDLERS
    get isCardMode() { return this.displayMode === 'Card'; }
    get isFloatingMode() { return this.displayMode === 'Floating Button'; }

    togglePanel() {
        this.isOpen = !this.isOpen;
    }

    handleInputChange(event) {
        this.description = event.target.value;
    }

    handleSubmit() {
        if (!this.description) return;
        this.isSending = true;

        const context = this.gatherContext();
        
        // We auto-generate a Subject based on where they are (e.g., "Ghost Report: Opportunity")
        const subjectLine = 'Ghost Report: ' + (context.objectName || 'General');

        createTicket({ 
            subject: subjectLine,
            description: this.description,
            contextData: context
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Ticket Created',
                message: 'Support has been notified. Context captured.',
                variant: 'success'
            }));
            this.description = '';
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
        
        // Handle special pages (Home, App Pages) that don't have objectApiName
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