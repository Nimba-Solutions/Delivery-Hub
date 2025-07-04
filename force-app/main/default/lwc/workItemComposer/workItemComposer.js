import { LightningElement, track } from 'lwc';
import createTicketFromWorkItem
  from '@salesforce/apex/DH_FileAndTicketService.createTicketFromWorkItem';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WorkItemComposer extends LightningElement {
  // form fields
  @track description = '';
  @track priority    = 'Medium';
  @track type        = 'Feature';
  @track testCases   = [];

  // file wrappers to pass into Apex
  fileData = []; // [{ fileName, base64Data, contentType }, ...]

  // priority picklist
  get priorities() {
    return [
      { label: 'Low',    value: 'Low'    },
      { label: 'Medium', value: 'Medium' },
      { label: 'High',   value: 'High'   }
    ];
  }

  // work type radio-group
  get types() {
    return [
      { label: 'Feature', value: 'Feature' },
      { label: 'Fix',     value: 'Fix'     },
      { label: 'Task',    value: 'Task'    }
    ];
  }

  // field change handlers
  handleDescriptionChange(evt)  { this.description = evt.target.value; }
  handlePriorityChange(evt)     { this.priority    = evt.detail.value; }
  handleTypeChange(evt)         { this.type        = evt.detail.value; }
  handleTestCasesChange(evt)    { this.testCases   = evt.detail; console.log('handleTestCasesChange'); console.log(this.testCases); }

  // read FileReader → base64 wrappers
  handleFilesChange(evt) {
    this.fileData = [];
    const files = Array.from(evt.target.files);
    let count = 0;

    files.forEach(file => {
      const reader = new FileReader();
      reader.onloadend = () => {
        const base64 = reader.result.split(',')[1];
        this.fileData.push({
          fileName:    file.name,
          base64Data:  base64,
          contentType: file.type
        });
        count++;
      };
      reader.readAsDataURL(file);
    });
  }

  // one-click: create ticket and upload files
  handleSaveWorkItem() {
    // guard: wait for all files to be read
    const selected = this.template.querySelector('input[type=file]')?.files.length || 0;
    if (selected > 0 && this.fileData.length < selected) {
      return this.dispatchEvent(new ShowToastEvent({
        title:   'Please wait',
        message: 'Processing file uploads — try again in a moment.',
        variant: 'info'
      }));
    }

    // build the payload
    const workItem = {
      description: this.description,
      priority:    this.priority,
      type:        this.type,
      testCases:   this.testCases
    };
    console.log(this.testCases);
    createTicketFromWorkItem({
      workItemJson: JSON.stringify(workItem),
      files:        this.fileData
    })
    .then(ticketId => {
      this.dispatchEvent(new ShowToastEvent({
        title:   'Success',
        message: `Ticket ${ticketId} created and files attached.`,
        variant: 'success'
      }));
      this._resetForm();
      this.dispatchEvent(new CustomEvent('close'));
    })
    .catch(error => {
      this.dispatchEvent(new ShowToastEvent({
        title:   'Error creating ticket',
        message: error.body?.message || error.message,
        variant: 'error'
      }));
    });
  }

  // clear form
  _resetForm() {
    this.description = '';
    this.priority    = 'Medium';
    this.type        = 'Feature';
    this.testCases   = [];
    this.fileData    = [];
    const fi = this.template.querySelector('input[type=file]');
    if (fi) fi.value = null;
  }
}