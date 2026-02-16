import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
// 1. IMPORT CORRECT CONTROLLER METHODS
import getLiveComments from '@salesforce/apex/DeliveryHubCommentController.getLiveComments';
import postLiveComment from '@salesforce/apex/DeliveryHubCommentController.postLiveComment';
import pollUpdates from '@salesforce/apex/DeliveryHubPoller.pollUpdates'; 
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DeliveryTicketChat extends LightningElement {
    @api recordId;
    @track commentBody = '';
    @track isSending = false;
    @track commentsData = [];
    
    wiredResult; 
    _pollingInterval;

    // 1. Fetch Comments via Wire
    // FIX: Method is getLiveComments, Parameter is requestId (matches Apex)
    @wire(getLiveComments, { requestId: '$recordId' })
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

    // Helper to process SObject data and add CSS classes
    updateComments(data) {
        this.commentsData = data.map(msg => {
            // FIX: Map SObject fields (BodyTxt__c) to JS properties (body)
            // Heuristic: For now, we treat all as outbound styling or you can add logic based on Author
            const isOutbound = true; 

            return {
                Id: msg.Id,
                body: msg.BodyTxt__c,       // SObject Field
                author: msg.AuthorTxt__c,   // SObject Field
                createdDate: msg.CreatedDate,
                
                // Keep existing CSS logic
                wrapperClass: isOutbound ? 'slds-chat-listitem slds-chat-listitem_outbound' : 'slds-chat-listitem slds-chat-listitem_inbound',
                bubbleClass: isOutbound ? 'bubble outbound' : 'bubble inbound',
                metaClass: isOutbound ? 'meta outbound-meta slds-text-align_right' : 'meta inbound-meta slds-text-align_left'
            };
        });
    }

    // 2. Optimized Polling
    connectedCallback() {
        // Poll every 5 seconds
        this._pollingInterval = setInterval(() => {
            
            // A. RUN THE SYNC (The "Mail Carrier")
            pollUpdates()
                .then(() => {
                    // B. REFRESH THE VIEW (Only after sync tries to run)
                    if (this.wiredResult) {
                        return refreshApex(this.wiredResult);
                    }
                })
                .catch(error => {
                    console.error('Error polling mothership:', error);
                });

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
        if (this.isSending) return;
        if (!this.commentBody || this.commentBody.trim() === '') return;

        this.isSending = true;

        // FIX: Call postLiveComment with requestId
        postLiveComment({ requestId: this.recordId, body: this.commentBody })
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