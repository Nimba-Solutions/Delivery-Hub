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
    _pollingInterval; // To store the timer ID

    @wire(getComments, { ticketId: '$recordId' })
    wiredComments(result) {
        this.wiredResult = result;
        if (result.data) {
            this.commentsData = result.data.map(msg => {
                return {
                    ...msg,
                    // Dynamic classes based on who sent it
                    wrapperClass: msg.isOutbound ? 'slds-chat-listitem slds-chat-listitem_outbound' : 'slds-chat-listitem slds-chat-listitem_inbound',
                    bubbleClass: msg.isOutbound ? 'bubble outbound' : 'bubble inbound',
                    metaClass: msg.isOutbound ? 'meta outbound-meta' : 'meta inbound-meta'
                };
            });
            // Only scroll to bottom on initial load or if user sends message
            // You might want smarter logic here to not scroll if user is reading history
            this.scrollToBottom();
        }
    }

    // Start Polling when component loads
    connectedCallback() {
        // Check for new messages every 5 seconds
        this._pollingInterval = setInterval(() => {
            this.refreshChat();
        }, 5000);
    }

    // Stop Polling when component is removed/tab closed
    disconnectedCallback() {
        if (this._pollingInterval) {
            clearInterval(this._pollingInterval);
        }
    }

    refreshChat() {
        return refreshApex(this.wiredResult);
    }

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
                return this.refreshChat(); 
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