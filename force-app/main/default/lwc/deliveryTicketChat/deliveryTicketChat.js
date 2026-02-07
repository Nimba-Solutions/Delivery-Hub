import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getComments from '@salesforce/apex/DeliveryHubCommentController.getComments';
import postComment from '@salesforce/apex/DeliveryHubCommentController.postComment';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DeliveryTicketChat extends LightningElement {
    @api recordId;
    @track commentBody = '';
    @track isSending = false;
    @track commentsData = [];
    
    wiredResult; 
    _pollingInterval;

    // 1. Fetch Comments via Wire
    @wire(getComments, { ticketId: '$recordId' })
    wiredComments(result) {
        this.wiredResult = result;
        if (result.data) {
            this.updateComments(result.data);
            
            // Auto-scroll to bottom only on initial load (when no interval is set yet)
            if (!this._pollingInterval) {
                 this.scrollToBottom();
            }
        }
    }

    // Helper to process data and add CSS classes
    updateComments(data) {
        this.commentsData = data.map(msg => {
            return {
                ...msg,
                wrapperClass: msg.isOutbound ? 'slds-chat-listitem slds-chat-listitem_outbound' : 'slds-chat-listitem slds-chat-listitem_inbound',
                bubbleClass: msg.isOutbound ? 'bubble outbound' : 'bubble inbound',
                metaClass: msg.isOutbound ? 'meta outbound-meta slds-text-align_right' : 'meta inbound-meta slds-text-align_left'
            };
        });
    }

    // 2. Optimized Polling
    connectedCallback() {
        // Poll every 5 seconds to check for new messages from the Mothership
        this._pollingInterval = setInterval(() => {
            // Only refresh the Wire. 
            // This is efficient and prevents "double rendering" flicker.
            if (this.wiredResult) {
                refreshApex(this.wiredResult)
                    .catch(error => console.error('Error refreshing chat:', error));
            }
        }, 5000); 
    }

    disconnectedCallback() {
        clearInterval(this._pollingInterval);
    }

    get comments() {
        return { data: this.commentsData };
    }

    handleInputChange(event) {
        this.commentBody = event.target.value;
    }

    handleKeyDown(event) {
        // Send on Enter (without Shift)
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault(); 
            this.handleSend();
        }
    }

    // 3. The Duplicate Fix (Locked Sender)
    handleSend() {
        // STOP DOUBLE SUBMITS: If already sending, do nothing.
        if (this.isSending) return;
        
        if (!this.commentBody || this.commentBody.trim() === '') return;

        // Lock
        this.isSending = true;

        postComment({ ticketId: this.recordId, body: this.commentBody })
            .then(() => {
                this.commentBody = ''; // Clear input
                // Force an immediate refresh from server
                return refreshApex(this.wiredResult);
            })
            .then(() => {
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
                // Unlock only when finished
                this.isSending = false;
            });
    }

    scrollToBottom() {
        // Small delay to allow DOM to render new message before scrolling
        setTimeout(() => {
            const chatContainer = this.template.querySelector('.chat-container');
            if (chatContainer) {
                chatContainer.scrollTop = chatContainer.scrollHeight;
            }
        }, 100);
    }
}