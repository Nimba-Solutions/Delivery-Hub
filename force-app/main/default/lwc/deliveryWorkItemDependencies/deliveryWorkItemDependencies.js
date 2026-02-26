/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDependencies from '@salesforce/apex/DeliveryWorkItemDependenciesController.getDependencies';

export default class DeliveryWorkItemDependencies extends NavigationMixin(LightningElement) {
    @api recordId;
    @track blocking = [];
    @track blockedBy = [];
    @track isLoading = true;

    @wire(getDependencies, { workItemId: '$recordId' })
    wiredDeps({ data, error }) {
        if (data) {
            this.blocking  = data.blocking  || [];
            this.blockedBy = data.blockedBy || [];
            this.isLoading = false;
        } else if (error) {
            console.error('Error loading dependencies', error);
            this.isLoading = false;
        }
    }

    get hasBlocking()  { return this.blocking.length  > 0; }
    get hasBlockedBy() { return this.blockedBy.length > 0; }
    get blockingCount()  { return this.blocking.length; }
    get blockedByCount() { return this.blockedBy.length; }

    handleWorkItemClick(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId:      event.currentTarget.dataset.id,
                objectApiName: 'WorkItem__c',
                actionName:    'view'
            }
        });
    }
}
