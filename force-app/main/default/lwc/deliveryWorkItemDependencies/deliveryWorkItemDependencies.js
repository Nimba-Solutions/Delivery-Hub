/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getDependencies from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkItemDependenciesController.getDependencies';

// Live updates — refresh when a dependency_change PE arrives. The publisher
// (DeliveryDependencyTriggerHandler from PR #732) emits one event per
// affected WorkItem (both endpoints), so we receive an event regardless of
// which side this record is on.
const PE_CHANNEL = '/event/%%%NAMESPACE_DOT%%%DeliveryWorkItemChange__e';
const REFRESH_CHANGE_TYPES = new Set(['dependency_change']);

export default class DeliveryWorkItemDependencies extends NavigationMixin(LightningElement) {
    @api recordId;
    @track blocking = [];
    @track blockedBy = [];
    @track isLoading = true;

    _wiredResult;
    _empSubscription;

    @wire(getDependencies, { workItemId: '$recordId' })
    wiredDeps(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.blocking  = data.blocking  || [];
            this.blockedBy = data.blockedBy || [];
            this.isLoading = false;
        } else if (error) {
            console.error('Error loading dependencies', error);
            this.isLoading = false;
        }
    }

    connectedCallback() {
        if (!this.recordId) return;
        onError((err) => {
            console.warn('[DeliveryWorkItemDependencies] empApi error:', JSON.stringify(err));
        });
        subscribe(PE_CHANNEL, -1, (message) => {
            const payload = message && message.data && message.data.payload;
            if (!payload) return;
            const ns = this._peNs();
            const changeType = payload.ChangeTypeTxt__c || payload[`${ns}ChangeTypeTxt__c`];
            if (!REFRESH_CHANGE_TYPES.has(changeType)) return;
            const eventWiId = payload.WorkItemIdTxt__c || payload[`${ns}WorkItemIdTxt__c`];
            if (!eventWiId) return;
            // Only refresh when the dep-change involves this record.
            if (eventWiId.substring(0, 15) !== this.recordId.substring(0, 15)) return;
            if (this._wiredResult) {
                refreshApex(this._wiredResult);
            }
        }).then((sub) => { this._empSubscription = sub; });
    }

    disconnectedCallback() {
        if (this._empSubscription) {
            try { unsubscribe(this._empSubscription, () => {}); } catch (e) { /* best-effort */ }
            this._empSubscription = null;
        }
    }

    _peNs() {
        if (this.__peNs !== undefined) return this.__peNs;
        const m = PE_CHANNEL.match(/\/event\/(.*?)DeliveryWorkItemChange__e/);
        this.__peNs = (m && m[1]) ? m[1] : '';
        return this.__peNs;
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
