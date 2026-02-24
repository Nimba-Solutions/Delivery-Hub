import { LightningElement, api, track } from 'lwc';
import getLiveComments from '@salesforce/apex/DeliveryHubCommentController.getLiveComments';
import postLiveComment from '@salesforce/apex/DeliveryHubCommentController.postLiveComment';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DeliveryCommentStream extends LightningElement {
    @api recordId;
    @track comments = [];
    @track commentBody = '';
    @track isSending = false;

    connectedCallback() {
        this.loadComments();
    }

    loadComments() {
        getLiveComments({ requestId: this.recordId })
            .then(result => {
                this.comments = result.map(record => ({
                    id: record.Id,
                    author: record.AuthorTxt__c || 'Unknown',
                    timestamp: record.CreatedDate,
                    body: record.BodyTxt__c
                }));
            })
            .catch(error => {
                console.error('Error loading comments', error);
                this.showToast('Error', 'Failed to load comments.', 'error');
            });
    }

    handleInputChange(event) {
        this.commentBody = event.target.value;
    }

    handleSend() {
        if (!this.commentBody) return;
        
        this.isSending = true;

        postLiveComment({ requestId: this.recordId, body: this.commentBody })
            .then(() => {
                this.commentBody = ''; // Clear input on success
                return this.loadComments(); // Refresh the list immediately
            })
            .catch(error => {
                const message = error.body ? error.body.message : error.message;
                this.showToast('Error', message, 'error');
            })
            .finally(() => {
                this.isSending = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}