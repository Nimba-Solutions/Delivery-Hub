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

    @wire(getComments, { ticketId: '$recordId' })
    wiredComments(result) {
        this.wiredResult = result;
        if (result.data) {
            this.commentsData = result.data.map(msg => {
                return {
                    ...msg,
                    wrapperClass: msg.isOutbound ? 'slds-chat-listitem slds-chat-listitem_outbound' : 'slds-chat-listitem slds-chat-listitem_inbound',
                    bubbleClass: msg.isOutbound ? 'bubble outbound' : 'bubble inbound',
                    metaClass: msg.isOutbound ? 'meta outbound-meta' : 'meta inbound-meta'
                };
            });
            this.scrollToBottom();
        }
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