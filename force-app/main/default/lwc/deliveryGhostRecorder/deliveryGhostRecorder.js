/* eslint-disable new-cap, sort-imports */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LightningElement, api, track, wire } from 'lwc';
import getAttentionCount from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getAttentionCount';
import createWorkItem from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGhostController.createQuickRequest';
import logActivity from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGhostController.logUserActivity';
import linkFilesAndSync from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkItemController.linkFilesAndSync';
import userId from '@salesforce/user/Id';

export default class DeliveryGhostRecorder extends NavigationMixin(LightningElement) {
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
    _sessionId = '';
    _lastLoggedUrl = '';
    _lastLoggedTime = 0;

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

    handleAttentionClick() {
        this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
            attributes: {
                listViewApiName: 'In_Flight',
                objectApiName: '%%%NAMESPACED_ORG%%%WorkItem__c'
            },
            type: 'standard__listView'
        });
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

    get contextDisplayName() {
        try {
            const parsed = this._parseUrlContext();
            return parsed.pageLabel || 'General';
        } catch (e) {
            return 'General';
        }
    }
    
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.currentPageRef = currentPageReference;
            this.handleNavigationLog();
        }
    }

    connectedCallback() {
        this._sessionId = this._generateSessionId();
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
        try {
            const href = window.location.href;
            const now = Date.now();
            if (href === this._lastLoggedUrl && (now - this._lastLoggedTime) < 3000) {
                return;
            }
            this._lastLoggedUrl = href;
            this._lastLoggedTime = now;

            const context = this.gatherContext();
            logActivity({
                actionType: 'Navigation',
                contextData: JSON.stringify(context)
            }).catch(() => { /* silent */ });
        } catch (e) {
            // Never break user experience
        }
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
        
        // Pass workItemType to distinguish intake vs. bug vs. feature
        
        let finalSubject = this.subject;
        if (!finalSubject && this.description) {
            finalSubject = (this.description.length > 95 ? this.description.substring(0, 95) + '...' : this.description);
        }
        if (!finalSubject) {
            finalSubject = (this.isBug ? 'Issue' : 'Feature') + ' on ' + (context.objectName || 'Home Page');
        }

        createWorkItem({ 
            subject: finalSubject,
            description: this.description,
            priority: this.priority,
            contextData: JSON.stringify(context),
            workItemType: this.requestType // NEW PARAMETER
        })
        .then(workItemId => {
            if (this.uploadedFileIds.length > 0) {
                linkFilesAndSync({
                    workItemId: workItemId,
                    contentDocumentIds: this.uploadedFileIds
                }).catch(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'File Attachment Failed',
                        message: 'Work item was created but attached files could not be linked. Please attach them from the work item record.',
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
        try {
            const parsed = this._parseUrlContext();
            return {
                url: window.location.href,
                browser: navigator.userAgent,
                objectName: parsed.objectName,
                recordId: parsed.recordId,
                pageLabel: parsed.pageLabel,
                sessionId: this._sessionId
            };
        } catch (e) {
            return {
                url: window.location.href || '',
                browser: '',
                objectName: 'Unknown',
                recordId: '',
                pageLabel: 'Unknown',
                sessionId: ''
            };
        }
    }

    _parseUrlContext() {
        const href = window.location.href;
        // Pattern: /lightning/r/{objectApiName}/{recordId}/view
        const recordMatch = href.match(/\/lightning\/r\/([^/]+)\/([a-zA-Z0-9]{15,18})\/view/);
        if (recordMatch) {
            return { objectName: recordMatch[1], recordId: recordMatch[2], pageLabel: recordMatch[1] };
        }
        // Pattern: /lightning/o/{objectApiName}/home (list view)
        const listMatch = href.match(/\/lightning\/o\/([^/]+)\/home/);
        if (listMatch) {
            return { objectName: listMatch[1], recordId: '', pageLabel: listMatch[1] + ' List' };
        }
        // Pattern: /lightning/o/{objectApiName}/list
        const listMatch2 = href.match(/\/lightning\/o\/([^/]+)\/list/);
        if (listMatch2) {
            return { objectName: listMatch2[1], recordId: '', pageLabel: listMatch2[1] + ' List' };
        }
        // Pattern: /lightning/page/home
        if (href.includes('/lightning/page/home')) {
            return { objectName: 'Home', recordId: '', pageLabel: 'Home' };
        }
        // Pattern: /lightning/page/chatter
        if (href.includes('/lightning/page/chatter')) {
            return { objectName: 'Chatter', recordId: '', pageLabel: 'Chatter' };
        }
        // Pattern: /lightning/setup/...
        if (href.includes('/lightning/setup/')) {
            return { objectName: 'Setup', recordId: '', pageLabel: 'Setup' };
        }
        // Pattern: /lightning/r/{objectApiName}/{recordId}/related/...
        const relatedMatch = href.match(/\/lightning\/r\/([^/]+)\/([a-zA-Z0-9]{15,18})\/related/);
        if (relatedMatch) {
            return { objectName: relatedMatch[1], recordId: relatedMatch[2], pageLabel: relatedMatch[1] + ' Related' };
        }
        // Fallback: try CurrentPageReference attributes
        const attrs = this.currentPageRef?.attributes || {};
        return {
            objectName: attrs.objectApiName || attrs.name || 'Unknown',
            recordId: attrs.recordId || '',
            pageLabel: attrs.objectApiName || attrs.name || 'Unknown'
        };
    }

    _generateSessionId() {
        try {
            return 'xxxxxxxx-xxxx-4xxx'.replace(/[x]/g, () =>
                (Math.random() * 16 | 0).toString(16)
            );
        } catch (e) {
            return 'unknown';
        }
    }
}