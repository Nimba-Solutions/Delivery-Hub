import { LightningElement, wire, api, track } from 'lwc';
import getLiveComments from '@salesforce/apex/DeliveryHubCommentController.getLiveComments';
import postLiveComment from '@salesforce/apex/DeliveryHubCommentController.postLiveComment';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// --- FIELD CONSTANTS ---
const FIELDS = {
    BODY: 'BodyTxt__c',
    AUTHOR: 'AuthorTxt__c',
    SOURCE: 'SourcePk__c',
    CREATED_DATE: 'CreatedDate'
};

export default class DeliveryTicketChat extends LightningElement {
    @api recordId;
    @track comments = { data: [] };
    @track commentBody = '';
    @track isSending = false;
    
    wiredResult;
    _hasScrolled = false;
    _pollingInterval; // Used to hold the interval ID

    // --- LIFECYCLE HOOKS ---
    
    connectedCallback() {
        // Start polling every 5 seconds (5000 milliseconds)
        // Adjust the time as needed (e.g., 10000 for 10 seconds)
        this._pollingInterval = setInterval(() => {
            if (this.wiredResult) {
                refreshApex(this.wiredResult);
            }
        }, 5000);
    }

    disconnectedCallback() {
        // Prevent memory leaks by destroying the interval when the user leaves the page
        if (this._pollingInterval) {
            clearInterval(this._pollingInterval);
        }
    }

    // Called whenever the component finishes rendering (initial load + updates)
    renderedCallback() {
        if (!this._hasScrolled && this.comments.data.length > 0) {
            this.scrollToBottom();
            this._hasScrolled = true;
        }
    }

    // --- HELPER METHODS ---

    scrollToBottom() {
        // We use a slight delay to ensure the DOM is fully painted
        setTimeout(() => {
            const chatList = this.template.querySelector('[data-id="chatList"]');
            if (chatList) {
                chatList.scrollTop = chatList.scrollHeight;
            }
        }, 100);
    }

    @wire(getLiveComments, { requestId: '$recordId' })
    wiredComments(result) {
        this.wiredResult = result;
        const { data, error } = result;

        if (data) {
            // Check if we actually got NEW data so we can scroll down
            const isNewData = this.comments.data.length !== data.length;

            this.comments.data = data.map(record => {
                // Helper to safely get field value regardless of namespace
                const getValue = (rec, fieldName) => {
                    if (!rec) return null;
                    if (rec[fieldName] !== undefined) return rec[fieldName];
                    
                    // Try un-namespaced version (e.g. BodyTxt__c)
                    let localName = fieldName.replace('delivery__', '');
                    if (rec[localName] !== undefined) return rec[localName];
                    
                    // Try namespaced version (e.g. delivery__BodyTxt__c)
                    let nsName = 'delivery__' + localName;
                    if (rec[nsName] !== undefined) return rec[nsName];
                    
                    return null;
                };

                const body = getValue(record, FIELDS.BODY) || '';
                const author = getValue(record, FIELDS.AUTHOR) || 'Unknown';
                const source = getValue(record, FIELDS.SOURCE) || 'Mothership';
                const createdDate = getValue(record, FIELDS.CREATED_DATE);
                
                // Logic: 'Client' means locally created (Blue/Right). 
                // 'Mothership' means synced in from outside (Grey/Left).
                const isOutbound = (source === 'Client');

                return {
                    Id: record.Id,
                    body: body,
                    author: author,
                    createdDate: createdDate,
                    
                    // Dynamic CSS Classes based on Source
                    wrapperClass: isOutbound 
                        ? 'slds-chat-listitem slds-chat-listitem_outbound' 
                        : 'slds-chat-listitem slds-chat-listitem_inbound',
                    
                    metaClass: isOutbound 
                        ? 'slds-chat-message__meta slds-text-align_right' 
                        : 'slds-chat-message__meta',
                    
                    bubbleClass: isOutbound 
                        ? 'slds-chat-message__text slds-chat-message__text_outbound' 
                        : 'slds-chat-message__text slds-chat-message__text_inbound'
                };
            });

            // If the poll brought in a new message, force a scroll to the bottom
            if (isNewData) {
                this.scrollToBottom();
            }

        } else if (error) {
            console.error('Error loading comments', error);
        }
    }

    handleInputChange(event) {
        this.commentBody = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.handleSend();
        }
    }

    handleSend() {
        if (!this.commentBody) return;

        this.isSending = true;
        postLiveComment({ requestId: this.recordId, body: this.commentBody })
            .then(() => {
                this.commentBody = '';
                return refreshApex(this.wiredResult);
            })
            .then(() => {
                // Scroll again after refresh
                this.scrollToBottom();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error posting comment',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isSending = false;
            });
    }
}