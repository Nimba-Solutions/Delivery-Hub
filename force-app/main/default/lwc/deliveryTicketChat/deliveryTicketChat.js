import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getComments from '@salesforce/apex/DeliveryHubCommentController.getComments';
// 1. IMPORT THE LIVE FETCH METHOD
import getCommentsLive from '@salesforce/apex/DeliveryHubCommentController.getCommentsLive';
import postComment from '@salesforce/apex/DeliveryHubCommentController.postComment';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DeliveryTicketChat extends LightningElement {
    @api recordId;
    @track commentBody = '';
    @track isSending = false;
    @track commentsData = [];
    
    wiredResult; 
    _pollingInterval;

    @wire(getComments, { ticketId: '$recordId' })
    wiredComments(result) {
        this.wiredResult = result;
        if (result.data) {
            this.updateComments(result.data);
            
            // Auto-scroll to bottom only on initial load
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
                metaClass: msg.isOutbound ? 'meta outbound-meta' : 'meta inbound-meta'
            };
        });
    }

    // --- Auto-Refresh Logic (THE FIX) ---
    connectedCallback() {
        this._pollingInterval = setInterval(() => {
            // 2. CALL THE API-FETCHING METHOD, NOT JUST THE DB QUERY
            getCommentsLive({ ticketId: this.recordId })
                .then(result => {
                    // Update the UI with the fresh data from the server
                    this.updateComments(result);
                    // Update the cache so the next wire refresh is accurate
                    return refreshApex(this.wiredResult);
                })
                .catch(error => console.error('Error refreshing chat:', error));
        }, 5000); // Check every 5 seconds
    }

    disconnectedCallback() {
        clearInterval(this._pollingInterval);
    }
    // ----------------------------------

    get comments() {
        return { data: this.commentsData };
    }

    handleInputChange(event) {
        this.commentBody = event.target.value;
    }

    handleSend() {
        if (!this.commentBody || this.commentBody.trim() === '') return;

        this.isSending = true;

        postComment({ ticketId: this.recordId, body: this.commentBody })
            .then(() => {
                this.commentBody = ''; 
                // Force a live pull immediately after sending to ensure sync
                return getCommentsLive({ ticketId: this.recordId });
            })
            .then((result) => {
                this.updateComments(result);
                this.scrollToBottom();
                return refreshApex(this.wiredResult);
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

    scrollToBottom() {
        setTimeout(() => {
            const chatContainer = this.template.querySelector('.chat-container');
            if (chatContainer) {
                chatContainer.scrollTop = chatContainer.scrollHeight;
            }
        }, 100);
    }
}