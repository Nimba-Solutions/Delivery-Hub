/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, createRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Work Item Fields to Read
import WORK_ITEM_HOURS from '@salesforce/schema/WorkItem__c.ClientPreApprovedHoursNumber__c';

// Request Object & Fields to Write
import REQUEST_OBJ from '@salesforce/schema/WorkRequest__c';
import REQ_WORK_ITEM_ID from '@salesforce/schema/WorkRequest__c.WorkItemId__c';
import REQ_PREAPPROVED from '@salesforce/schema/WorkRequest__c.PreApprovedHoursNumber__c';
import REQ_STATUS from '@salesforce/schema/WorkRequest__c.StatusPk__c';

import suggestAcceptanceCriteria from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryAiController.suggestAcceptanceCriteria';

// Load the Work Item fields so we have the data ready to copy
const FIELDS = [WORK_ITEM_HOURS];

export default class DeliveryWorkItemRefiner extends NavigationMixin(LightningElement) {
    @api recordId;
    @track isProcessing = false;
    @track isRequestCreated = false;
    @track newRequestId;

    // AI suggestion state
    @track isSuggesting = false;
    @track suggestedCriteria = '';
    @track criteriaError = '';

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    workItem;

    // Called when the "Save Definition" button finishes
    handleWorkItemSave() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Work Item Definition Updated',
            variant: 'success'
        }));
    }

    handleSuggestCriteria() {
        this.isSuggesting = true;
        this.suggestedCriteria = '';
        this.criteriaError = '';
        suggestAcceptanceCriteria({ workItemId: this.recordId })
            .then(result => { this.suggestedCriteria = result; })
            .catch(error => {
                this.criteriaError = error.body ? error.body.message : error.message;
            })
            .finally(() => { this.isSuggesting = false; });
    }

    handleApplyCriteria() {
        const field = this.template.querySelector(
            'lightning-input-field[field-name="AcceptanceCriteriaTxt__c"]'
        );
        if (field) {
            field.value = this.suggestedCriteria;
        }
        this.suggestedCriteria = '';
        this.criteriaError = '';
    }

    // Called when "Create Vendor Request" is clicked
    handleCreateRequest() {
        const clientHoursCheck = getFieldValue(this.workItem.data, WORK_ITEM_HOURS);
        if (!clientHoursCheck) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Missing Client Hours',
                message: 'Please set Client Pre-Approved Hours before creating a Vendor Request.',
                variant: 'error'
            }));
            return;
        }
        this.isProcessing = true;
        const fields = {};

        // 1. Link to Parent Work Item
        fields[REQ_WORK_ITEM_ID.fieldApiName] = this.recordId;

        // 2. Set Status
        fields[REQ_STATUS.fieldApiName] = 'Draft';

        // 3. Copy the client-approved hours onto the vendor request
        const clientHours = getFieldValue(this.workItem.data, WORK_ITEM_HOURS);
        fields[REQ_PREAPPROVED.fieldApiName] = clientHours;

        const recordInput = { apiName: REQUEST_OBJ.objectApiName, fields };

        createRecord(recordInput)
            .then(request => {
                this.newRequestId = request.id;
                this.isRequestCreated = true;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Vendor Request Created',
                    variant: 'success'
                }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error creating request',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }

    navigateToRequest() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.newRequestId,
                objectApiName: 'WorkRequest__c',
                actionName: 'view'
            }
        });
    }
}
