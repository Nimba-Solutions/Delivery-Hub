import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getComments from '@salesforce/apex/DeliveryHubCommentController.getComments';
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
                // FIX: Added explicit text alignment to ensure names sit on the correct side
                metaClass: msg.isOutbound ? 'meta outbound-meta slds-text-align_right' : 'meta inbound-meta slds-text-align_left'
            };
        });
    }

    connectedCallback() {
        this._pollingInterval = setInterval(() => {
            getCommentsLive({ ticketId: this.recordId })
                .then(result => {
                    this.updateComments(result);
                    // Silently update cache without triggering a second render cycle if data is same
                    // But we call refreshApex to keep the wire sync
                    refreshApex(this.wiredResult);
                })
                .catch(error => console.error('Error refreshing chat:', error));
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

    // FIX: Enter Key Handler
    handleKeyDown(event) {
        // If Enter is pressed WITHOUT Shift, send.
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault(); // Stop new line
            this.handleSend();
        }
    }

    handleSend() {
        if (!this.commentBody || this.commentBody.trim() === '') return;

        this.isSending = true;

        postComment({ ticketId: this.recordId, body: this.commentBody })
            .then(() => {
                this.commentBody = ''; 
                // FIX: Removed the double-fetch logic. 
                // Just refreshing the wire is enough and prevents the "double typing" visual glitch.
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