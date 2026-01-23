import { LightningElement, api, track } from 'lwc';
import getLiveComments from '@salesforce/apex/DeliveryHubCommentSender.getLiveComments';
import postLiveComment from '@salesforce/apex/DeliveryHubCommentSender.postLiveComment';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DeliveryCommentStream extends LightningElement {
    @api recordId;
    @track comments = [];
    @track commentBody = '';
    isSending = false;

    connectedCallback() {
        this.loadComments();
    }

    loadComments() {
        getLiveComments({ requestId: this.recordId })
            .then(result => {
                this.comments = result;
            })
            .catch(error => {
                console.error('Error loading comments', error);
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
                this.commentBody = ''; // Clear input
                return this.loadComments(); // Refresh list
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
}