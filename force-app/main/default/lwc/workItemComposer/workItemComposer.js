import { LightningElement, track } from 'lwc';
import publishWorkItemEvent from '@salesforce/apex/WorkItemEventPublisher.publishWorkItemEvent';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const PRIORITIES = [
    { label: 'Low', value: 'Low' },
    { label: 'Medium', value: 'Medium' },
    { label: 'High', value: 'High' }
];
const TYPES = [
    { label: 'Feature', value: 'Feature' },
    { label: 'Fix', value: 'Fix' },
    { label: 'Task', value: 'Task' }
];

export default class WorkItemComposer extends LightningElement {
    @track description = '';
    @track priority = 'Medium';
    @track type = 'Feature';
    @track testCases = [];

    get priorities() {
        return PRIORITIES;
    }
    get types() {
        return TYPES;
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }
    handlePriorityChange(event) {
        this.priority = event.detail.value;
    }
    handleTypeChange(event) {
        this.type = event.detail.value;
    }
    handleTestCasesChange(event) {
        this.testCases = event.detail;
    }
    async handleSaveWorkItem() {
        const workItem = {
            description: this.description,
            priority: this.priority,
            type: this.type,
            testCases: this.testCases
        };
        console.log(this.description);
        console.log(this.testCases);
        console.log(this.type);
        try {
            await publishWorkItemEvent({
                operation: 'create',
                body: JSON.stringify(workItem)
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Work item submitted!',
                variant: 'success'
            }));
            this.dispatchEvent(new CustomEvent('close'));
        } catch (e) {
            // Optionally handle error
        }
    }

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
}