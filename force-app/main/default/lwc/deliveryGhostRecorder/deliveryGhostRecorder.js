/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import userId from '@salesforce/user/Id';

import createTicket from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGhostController.createQuickRequest';
import logActivity from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGhostController.logUserActivity';
import linkFilesAndSync from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkItemController.linkFilesAndSync";
import getAttentionCount from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getAttentionCount';

export default class DeliveryGhostRecorder extends LightningElement {
    @api enableShortcut = false; 
    @api displayMode = 'Card';   
    
    @track isOpen = false;
    @track requestType = 'Bug'; // Default to Bug
    @track subject = ''; 
    @track description = '';
    @track priority = 'Medium';
    @track isSending = false;
    @track uploadedFileIds = [];
    
    currentPageRef;
    currentUserId = userId;

    @wire(getAttentionCount)
    wiredAttentionCount;

    get attentionCount() {
        return this.wiredAttentionCount.data || 0;
    }

    get hasAttentionItems() {
        return this.attentionCount > 0;
    }

    get attentionLabel() {
        const n = this.attentionCount;
        return `${n} item${n === 1 ? '' : 's'} need${n === 1 ? 's' : ''} your attention`;
    }

    // --- GETTERS FOR DYNAMIC UI ---
    get isCardMode() { return this.displayMode === 'Card'; }
    get isFloatingMode() { return this.displayMode === 'Floating Button'; }
    
    get typeOptions() {
        return [
            { label: 'Report Issue', value: 'Bug' },
            { label: 'Request Feature', value: 'Feature' }
        ];
    }

    get isBug() { return this.requestType === 'Bug'; }

    get cardTitle() { return this.isBug ? 'Report Issue' : 'New Feature Request'; }
    get cardIcon() { return this.isBug ? 'utility:bug' : 'utility:light_bulb'; }
    
    get subjectLabel() { return this.isBug ? 'Summary' : 'Feature Name'; }
    get subjectPlaceholder() { return this.isBug ? 'e.g., Sort not working...' : 'e.g., Dark Mode for Dashboard...'; }
    
    get detailsPlaceholder() { 
        return this.isBug 
            ? 'Steps to reproduce, expected behavior, error messages...' 
            : 'What problem does this solve? How should it work?'; 
    }

    get submitButtonLabel() { return this.isBug ? 'Report Bug' : 'Submit Feature'; }

    get priorityOptions() {
        return [
            { label: 'Low',    value: 'Low' },
            { label: 'Medium', value: 'Medium' },
            { label: 'High',   value: 'High' },
        ];
    }

    get uploadedFileCount() {
        return this.uploadedFileIds.length;
    }

    // ... (Keep Context gathering Logic same as before) ...
    get contextDisplayName() {
        if (!this.currentPageRef) return 'General';
        const attrs = this.currentPageRef.attributes;
        if (attrs.objectApiName) return attrs.objectApiName;
        if (attrs.name) return attrs.name; 
        if (this.currentPageRef.type === 'standard__namedPage') return 'Page: ' + attrs.pageName;
        return 'General Context';
    }
    
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
        if (event.altKey && (event.code === 'KeyB' || event.key === 'b')) {
            this.togglePanel();
        }
    }

    handleNavigationLog() {
        const context = this.gatherContext();
        logActivity({ 
            actionType: 'Navigation',
            contextData: JSON.stringify(context) 
        }).catch(err => console.error('Ghost log failed', err));
    }

    togglePanel() {
        this.isOpen = !this.isOpen;
    }

    // --- HANDLERS ---
    handleTypeChange(event) {
        this.requestType = event.detail.value;
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
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
        if (!this.description && !this.subject) return;
        
        this.isSending = true;
        const context = this.gatherContext();
        
        // Add Type to the context so Apex knows what it is
        // Or better yet, send it as a dedicated param if the controller supports it
        // For now, we prepend it to the description or subject if we don't want to change Apex params
        // But the best way is to update Apex to accept 'type'.
        // Assuming current Apex is rigid, we pass it in context or modify subject slightly.
        
        // Let's modify the Apex controller to accept 'ticketType' (See Step 3 below)
        
        let finalSubject = this.subject;
        if (!finalSubject && this.description) {
            finalSubject = (this.description.length > 95 ? this.description.substring(0, 95) + '...' : this.description);
        }
        if (!finalSubject) {
            finalSubject = (this.isBug ? 'Issue' : 'Feature') + ' on ' + (context.objectName || 'Home Page');
        }

        createTicket({ 
            subject: finalSubject,
            description: this.description,
            priority: this.priority,
            contextData: JSON.stringify(context),
            ticketType: this.requestType // NEW PARAMETER
        })
        .then(ticketId => {
            if (this.uploadedFileIds.length > 0) {
                linkFilesAndSync({
                    ticketId: ticketId,
                    contentDocumentIds: this.uploadedFileIds
                }).catch(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'File Attachment Failed',
                        message: 'Ticket was created but attached files could not be linked. Please attach them from the ticket record.',
                        variant: 'warning',
                        mode: 'sticky'
                    }));
                });
            }

            this.dispatchEvent(new ShowToastEvent({
                title: this.isBug ? 'Bug Reported' : 'Feature Requested',
                message: 'Thank you for your feedback.',
                variant: 'success'
            }));
            
            this.resetForm();
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

    resetForm() {
        this.subject = '';
        this.description = '';
        this.priority = 'Medium';
        this.uploadedFileIds = [];
        this.isOpen = false;
        this.requestType = 'Bug'; // Reset to default
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