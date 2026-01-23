import { LightningElement, api, wire, track } from 'lwc';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendFileToBroker from '@salesforce/apex/DeliveryHubFileSender.sendFileToBroker';

export default class DeliveryFileSender extends LightningElement {
    @api recordId;
    @track files = [];
    isLoading = false;

    // Fetch Files attached to this Request
    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'ContentDocumentLinks',
        fields: ['ContentDocumentLink.ContentDocumentId', 'ContentDocumentLink.ContentDocument.Title']
    })
    wiredFiles({ data }) { // FIX: Removed 'error' parameter since it wasn't used
        if (data) {
            this.files = data.records.map(record => ({
                Id: record.fields.ContentDocumentId.value,
                Title: record.fields.ContentDocument.value.fields.Title.value
            }));
        }
    }

    handleUploadFinished() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'File Attached',
            message: 'Now click "Send to Dev" to transfer it.',
            variant: 'success'
        }));
    }

    handleSend(event) {
        const fileId = event.target.dataset.id;
        this.isLoading = true;

        sendFileToBroker({ requestId: this.recordId, contentDocumentId: fileId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'File sent to Developer successfully!',
                    variant: 'success'
                }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error sending file',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}