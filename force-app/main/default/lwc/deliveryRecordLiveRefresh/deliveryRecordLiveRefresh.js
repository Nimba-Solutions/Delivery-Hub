/**
 * @name         Delivery Hub — deliveryRecordLiveRefresh
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Headless LWC dropped onto the WorkItem__c record page
 *               Lightning App Builder layout. Subscribes to
 *               DeliveryWorkItemChange__e and, on a task_upsert event whose
 *               WorkItemIdTxt__c matches @api recordId, calls
 *               getRecordNotifyChange — Lightning Data Service then
 *               auto-refreshes any LDS-backed UI on the page (the stock
 *               detail panel, related lists wired via LDS, etc).
 *
 *               Renders nothing visible. Drop on any record page where
 *               WorkItem__c fields are surfaced; the standard SF detail UI
 *               picks up the LDS notification without further wiring.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

const CHANNEL = '/event/%%%NAMESPACE_DOT%%%DeliveryWorkItemChange__e';
// Change types we care about for record-page refresh. stage_change + comment_*
// already drive their own LWCs (board, chat) via the same channel — getting
// the LDS notification on those is harmless but not the primary goal.
const REFRESH_CHANGE_TYPES = new Set(['task_upsert', 'stage_change', 'dependency_change']);

export default class DeliveryRecordLiveRefresh extends LightningElement {
    @api recordId;

    _subscription;

    connectedCallback() {
        if (!this.recordId) {
            return;
        }
        onError((err) => {
            // eslint-disable-next-line no-console
            console.warn('[deliveryRecordLiveRefresh] empApi error:', JSON.stringify(err));
        });
        subscribe(CHANNEL, -1, (message) => {
            try {
                this._handle(message);
            } catch (e) {
                // eslint-disable-next-line no-console
                console.warn('[deliveryRecordLiveRefresh] handler failed:', e && e.message);
            }
        }).then((sub) => { this._subscription = sub; });
    }

    disconnectedCallback() {
        if (this._subscription) {
            try { unsubscribe(this._subscription, () => {}); } catch (e) { /* best-effort */ }
            this._subscription = null;
        }
    }

    _handle(message) {
        const payload = message && message.data && message.data.payload;
        if (!payload) {
            return;
        }
        const ns = this._nsPrefix();
        const changeType = payload.ChangeTypeTxt__c || payload[`${ns}ChangeTypeTxt__c`];
        if (!REFRESH_CHANGE_TYPES.has(changeType)) {
            return;
        }
        const eventWorkItemId = payload.WorkItemIdTxt__c || payload[`${ns}WorkItemIdTxt__c`];
        if (eventWorkItemId && this._idsMatch(eventWorkItemId, this.recordId)) {
            getRecordNotifyChange([{ recordId: this.recordId }]);
        }
    }

    /** 15-char IDs from PE payload may compare against 18-char @api recordId. */
    _idsMatch(a, b) {
        if (!a || !b) return false;
        const a15 = a.substring(0, 15);
        const b15 = b.substring(0, 15);
        return a15 === b15;
    }

    _nsPrefix() {
        if (this.__nsPrefix !== undefined) return this.__nsPrefix;
        try {
            const m = CHANNEL.match(/\/event\/(.*?)DeliveryWorkItemChange__e/);
            this.__nsPrefix = (m && m[1]) ? m[1] : '';
        } catch (e) {
            this.__nsPrefix = '';
        }
        return this.__nsPrefix;
    }
}
