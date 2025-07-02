import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { createRecord } from 'lightning/uiRecordApi';
import SFDC_DEV_TICKET_OBJECT from '@salesforce/schema/SFDC_Dev_Ticket__c';
import TYPE_FIELD from '@salesforce/schema/SFDC_Dev_Ticket__c.TypePk__c';
import CLIENT_NOTES_FIELD from '@salesforce/schema/SFDC_Dev_Ticket__c.ClientNotesTxt__c';

export default class DeliveryHubTicketLauncher extends LightningElement {
  @track type = '';
  @track notes = '';
  @track steps = '';
  @track criteria = '';
  @track uploadedFiles = [];

  get typeOptions() {
    return [
      { label: 'Feature', value: 'Feature' },
      { label: 'Bug', value: 'Bug' },
      { label: 'Question', value: 'Question' }
    ];
  }

  handleChange(event) {
    const field = event.target.name;
    this[field] = event.target.value;
  }

  handleUploadFinished(event) {
    this.uploadedFiles = event.detail.files;
    this.showToast('Success', `${this.uploadedFiles.length} file(s) uploaded`, 'success');
  }

  handleSubmit() {
    const fields = {};
    fields[TYPE_FIELD.fieldApiName] = this.type;
    fields[CLIENT_NOTES_FIELD.fieldApiName] = this.notes;

    const recordInput = { apiName: SFDC_DEV_TICKET_OBJECT.objectApiName, fields };

    createRecord(recordInput)
      .then((record) => {
        this.showToast('Success', `Ticket created: ${record.id}`, 'success');
        this.type = '';
        this.notes = '';
        this.steps = '';
        this.criteria = '';
        this.uploadedFiles = [];
      })
      .catch((error) => {
        this.showToast('Error creating record', error.body.message, 'error');
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}
