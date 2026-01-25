import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, createRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Ticket Fields to Read
import TICKET_HOURS from '@salesforce/schema/Ticket__c.ClientPreApprovedHoursNumber__c';

// Request Object & Fields to Write
import REQUEST_OBJ from '@salesforce/schema/Request__c';
import REQ_TICKET_ID from '@salesforce/schema/Request__c.TicketId__c';
import REQ_PREAPPROVED from '@salesforce/schema/Request__c.PreApprovedHoursNumber__c';
import REQ_STATUS from '@salesforce/schema/Request__c.StatusPk__c';

// Load the Ticket fields so we have the data ready to copy
const FIELDS = [TICKET_HOURS];

export default class TicketRefiner extends NavigationMixin(LightningElement) {
    @api recordId;
    @track isProcessing = false;
    @track isRequestCreated = false;
    @track newRequestId;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    ticket;

    // Called when the "Save Definition" button finishes
    handleTicketSave() {
        this.dispatchEvent(new ShowToastEvent({ 
            title: 'Success', 
            message: 'Ticket Definition Updated', 
            variant: 'success' 
        }));
    }

    // Called when "Create Vendor Request" is clicked
    handleCreateRequest() {
        this.isProcessing = true;
        const fields = {};
        
        // 1. Link to Parent Ticket
        fields[REQ_TICKET_ID.fieldApiName] = this.recordId;
        
        // 2. Set Status (Ensure 'Draft' exists in your Request Status Picklist)
        fields[REQ_STATUS.fieldApiName] = 'Draft'; 

        // 3. COPY THE HOURS (The Broker Logic)
        // We take the hours the Client approved and put them on the Vendor Request.
        // You can edit this on the Request later if you want to keep a "Spread".
        const clientHours = getFieldValue(this.ticket.data, TICKET_HOURS);
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
                objectApiName: 'Request__c',
                actionName: 'view'
            }
        });
    }
}