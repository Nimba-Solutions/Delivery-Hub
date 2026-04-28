/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, api, track } from 'lwc';
import getLiveComments from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubCommentController.getLiveComments';
import postLiveComment from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubCommentController.postLiveComment';
import getCommentFiles from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubCommentController.getCommentFiles';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

const COMMENT_CHANNEL = '/event/%%%NAMESPACE_DOT%%%DeliveryComment__e';
// Fallback poll cadence — only used if the empApi subscription drops silently.
// Sub-second updates come from the platform-event channel above.
const FALLBACK_POLL_MS = 300000; // 5 minutes

// --- FIELD CONSTANTS ---
const FIELDS = {
    BODY: 'BodyTxt__c',
    AUTHOR: 'AuthorTxt__c',
    SOURCE: 'SourcePk__c',
    CREATED_DATE: 'CreatedDate'
};

export default class DeliveryWorkItemChat extends LightningElement {
    @api recordId;
    @track comments = { data: [] };
    @track commentBody = '';
    @track isSending = false;
    
    wiredResult;
    _hasScrolled = false;
    _pollingInterval;
    _empSubscription;

    // --- LIFECYCLE HOOKS ---

    connectedCallback() {
        // Real-time updates: subscribe to DeliveryComment__e and only refresh
        // when the event's WorkItemIdTxt__c matches this chat's recordId.
        // The 30s polling we used to do is replaced by sub-second platform-event
        // notifications + a 5-min safety-net poll if the subscription drops.
        subscribe(COMMENT_CHANNEL, -1, (message) => {
            const payload = message && message.data && message.data.payload;
            if (!payload) { return; }
            const eventWorkItemId = payload.WorkItemIdTxt__c
                || payload[`${this._nsPrefix()}WorkItemIdTxt__c`];
            if (!this.recordId) { return; }
            if (eventWorkItemId && this._idsMatch(eventWorkItemId, this.recordId)) {
                if (this.wiredResult) {
                    refreshApex(this.wiredResult);
                }
            }
        }).then(response => {
            this._empSubscription = response;
        });
        onError(error => {
            // Stay quiet on the console outside of debug — but log so the
            // health dashboard's empApi check has a breadcrumb.
            console.warn('[DeliveryWorkItemChat] EMP API error:', JSON.stringify(error));
        });

        // Fallback poll every 5 minutes in case empApi disconnects silently.
        this._pollingInterval = setInterval(() => {
            if (this.wiredResult && document.visibilityState === 'visible') {
                refreshApex(this.wiredResult);
            }
        }, FALLBACK_POLL_MS);
    }

    disconnectedCallback() {
        if (this._empSubscription) {
            unsubscribe(this._empSubscription, () => {});
            this._empSubscription = null;
        }
        if (this._pollingInterval) {
            clearInterval(this._pollingInterval);
        }
    }

    /**
     * Match a Salesforce Id ignoring 15- vs 18-char form (event payloads can
     * arrive in either, depending on namespace + serializer).
     */
    _idsMatch(a, b) {
        if (!a || !b) { return false; }
        return a === b || a.substring(0, 15) === b.substring(0, 15);
    }

    /**
     * Resolve the namespace prefix that platform-event field names get when
     * served to a subscriber org. Empty in unmanaged dev; "delivery__" in
     * subscriber orgs after install.
     */
    _nsPrefix() {
        return 'delivery__';
    }

    // Called whenever the component finishes rendering (initial load + updates)
    renderedCallback() {
        if (!this._hasScrolled && this.comments.data.length > 0) {
            this.scrollToBottom();
            this._hasScrolled = true;
        }
    }

    // --- HELPER METHODS ---

    scrollToBottom() {
        // We use a slight delay to ensure the DOM is fully painted
        setTimeout(() => {
            const chatList = this.template.querySelector('[data-id="chatList"]');
            if (chatList) {
                chatList.scrollTop = chatList.scrollHeight;
            }
        }, 100);
    }

    @wire(getLiveComments, { requestId: '$recordId' })
    wiredComments(result) {
        this.wiredResult = result;
        const { data, error } = result;

        if (data) {
            // Check if we actually got NEW data so we can scroll down
            const isNewData = this.comments.data.length !== data.length;

            this.comments.data = data.map(record => {
                // Helper to safely get field value regardless of namespace
                const getValue = (rec, fieldName) => {
                    if (!rec) return null;
                    if (rec[fieldName] !== undefined) return rec[fieldName];
                    
                    // Try un-namespaced version (e.g. BodyTxt__c)
                    let localName = fieldName.replace('delivery__', '');
                    if (rec[localName] !== undefined) return rec[localName];
                    
                    // Try namespaced version (e.g. delivery__BodyTxt__c)
                    let nsName = 'delivery__' + localName;
                    if (rec[nsName] !== undefined) return rec[nsName];
                    
                    return null;
                };

                const body = getValue(record, FIELDS.BODY) || '';
                const author = getValue(record, FIELDS.AUTHOR) || 'Unknown';
                const source = getValue(record, FIELDS.SOURCE) || 'Mothership';
                const createdDate = getValue(record, FIELDS.CREATED_DATE);
                
                // Logic: 'Client' means locally created (Blue/Right). 
                // 'Mothership' means synced in from outside (Grey/Left).
                const isOutbound = (source === 'Client');

                return {
                    Id: record.Id,
                    body: body,
                    author: author,
                    createdDate: createdDate,
                    
                    // Dynamic CSS Classes based on Source
                    wrapperClass: isOutbound 
                        ? 'slds-chat-listitem slds-chat-listitem_outbound' 
                        : 'slds-chat-listitem slds-chat-listitem_inbound',
                    
                    metaClass: isOutbound 
                        ? 'slds-chat-message__meta slds-text-align_right' 
                        : 'slds-chat-message__meta',
                    
                    bubbleClass: isOutbound 
                        ? 'slds-chat-message__text slds-chat-message__text_outbound' 
                        : 'slds-chat-message__text slds-chat-message__text_inbound'
                };
            });

            // If the poll brought in a new message, force a scroll to the bottom
            if (isNewData) {
                this.scrollToBottom();
                // Fetch file attachments for the new comment set
                const ids = data.map(r => r.Id);
                if (ids.length > 0) {
                    getCommentFiles({ commentIds: ids })
                        .then(filesMap => {
                            this.comments.data = this.comments.data.map(msg => ({
                                ...msg,
                                files: filesMap[msg.Id] || []
                            }));
                        })
                        .catch(() => {});
                }
            }

        } else if (error) {
            console.error('Error loading comments', error);
        }
    }

    handleInputChange(event) {
        this.commentBody = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.handleSend();
        }
    }

    handleSend() {
        if (!this.commentBody) return;

        this.isSending = true;
        postLiveComment({ requestId: this.recordId, body: this.commentBody })
            .then(() => {
                this.commentBody = '';
                return refreshApex(this.wiredResult);
            })
            .then(() => {
                // Scroll again after refresh
                this.scrollToBottom();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error posting comment',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isSending = false;
            });
    }
}