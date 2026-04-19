/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createWorkItem from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGhostController.createQuickRequest';
import logActivity from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGhostController.logUserActivity';
import getAttentionCount from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getAttentionCount';
import getReportIds from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getReportIds';
import linkFilesAndSync from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkItemController.linkFilesAndSync';
import userId from '@salesforce/user/Id';

const NAV_LOG_DEBOUNCE_MS = 3000;
const SUBJECT_TRUNCATE_LEN = 95;
const HEX_RADIX = 16;
const SESSION_ID_RANDOM_RANGE = 16;

export default class DeliveryGhostRecorder extends NavigationMixin(LightningElement) { // eslint-disable-line new-cap
    @api enableShortcut = false;
    @api displayMode = 'Card';

    @track isOpen = false;
    @track requestType = 'Bug';
    @track subject = '';
    @track description = '';
    @track priority = 'Medium';
    @track isSending = false;
    @track uploadedFileIds = [];

    // Voice capture state
    @track isListening = false;
    @track voiceTranscript = '';
    @track voiceInterim = '';
    @track voiceSupported = false;
    _recognition = null;

    currentPageRef;
    currentUserId = userId;
    sessionIdValue = '';
    lastLoggedUrl = '';
    lastLoggedTime = 0;
    _pageArrivalTime = 0;
    _previousContext = null;

    @wire(getAttentionCount)
    wiredAttentionCount;

    get attentionCount() {
        return this.wiredAttentionCount.data || 0;
    }

    get hasAttentionItems() {
        return this.attentionCount > 0;
    }

    get attentionLabel() {
        const count = this.attentionCount;
        const plural = count === 1 ? '' : 's';
        const verb = count === 1 ? 's' : '';
        return `${count} item${plural} need${verb} your attention`;
    }

    handleAttentionClick() {
        // Try report first, fall back to list view
        getReportIds({ developerNames: ['Attention_Items'] })
            .then(ids => {
                const reportId = ids.Attention_Items;
                if (reportId) {
                    this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
                        attributes: { actionName: 'view', objectApiName: 'Report', recordId: reportId },
                        type: 'standard__recordPage'
                    });
                } else {
                    this.navigateToAttentionListView();
                }
            })
            .catch(() => this.navigateToAttentionListView());
    }

    navigateToAttentionListView() {
        this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
            attributes: { actionName: 'list', objectApiName: '%%%NAMESPACE_DOT%%%WorkItem__c' },
            state: { filterName: 'In_Flight' },
            type: 'standard__objectPage'
        });
    }

    get isCardMode() {
        return this.displayMode === 'Card';
    }

    get isFloatingMode() {
        return this.displayMode === 'Floating Button';
    }

    get typeOptions() {
        return [
            { label: 'Report Issue', value: 'Bug' },
            { label: 'Request Feature', value: 'Feature' }
        ];
    }

    get isBug() {
        return this.requestType === 'Bug';
    }

    get cardTitle() {
        if (this.isBug) {
            return 'Report Issue';
        }
        return 'New Feature Request';
    }

    get cardIcon() {
        if (this.isBug) {
            return 'utility:bug';
        }
        return 'utility:light_bulb';
    }

    get subjectLabel() {
        if (this.isBug) {
            return 'Summary';
        }
        return 'Feature Name';
    }

    get subjectPlaceholder() {
        if (this.isBug) {
            return 'e.g., Sort not working...';
        }
        return 'e.g., Dark Mode for Dashboard...';
    }

    get detailsPlaceholder() {
        if (this.isBug) {
            return 'Steps to reproduce, expected behavior, error messages...';
        }
        return 'What problem does this solve? How should it work?';
    }

    get submitButtonLabel() {
        if (this.isBug) {
            return 'Report Bug';
        }
        return 'Submit Feature';
    }

    get priorityOptions() {
        return [
            { label: 'Low', value: 'Low' },
            { label: 'Medium', value: 'Medium' },
            { label: 'High', value: 'High' }
        ];
    }

    get uploadedFileCount() {
        return this.uploadedFileIds.length;
    }

    get contextDisplayName() {
        try {
            const parsed = this.parseUrlContext();
            return parsed.pageLabel || 'General';
        } catch (err) {
            return 'General';
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.currentPageRef = currentPageReference;
            this.handleNavigationLog();
        }
    }

    connectedCallback() {
        this.sessionIdValue = DeliveryGhostRecorder.generateSessionId();
        this._pageArrivalTime = Date.now();
        if (this.enableShortcut) {
            window.addEventListener('keydown', this.handleShortcut);
        }
        document.addEventListener('visibilitychange', this._handleVisibilityChange);
        this._initVoiceRecognition();
    }

    disconnectedCallback() {
        window.removeEventListener('keydown', this.handleShortcut);
        document.removeEventListener('visibilitychange', this._handleVisibilityChange);
        this._destroyVoiceRecognition();
    }

    _handleVisibilityChange = () => {
        if (document.visibilityState === 'hidden' && this._pageArrivalTime > 0) {
            this._logPageDuration('tab_hidden');
        }
    }

    _logPageDuration(exitType) {
        if (!this._previousContext || this._pageArrivalTime <= 0) {
            return;
        }
        const durationSec = Math.round((Date.now() - this._pageArrivalTime) / 1000);
        if (durationSec < 1) {
            return;
        }
        const ctx = Object.assign({}, this._previousContext, {
            duration: durationSec,
            exitType: exitType
        });
        logActivity({
            actionType: 'Page_Duration',
            contextData: JSON.stringify(ctx)
        }).catch(() => { /* silent */ });
    }

    /* ── Voice Recognition (Web Speech API) ── */

    _initVoiceRecognition() {
        try {
            const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
            if (!SpeechRecognition) {
                return;
            }
            this.voiceSupported = true;

            const recognition = new SpeechRecognition();
            recognition.continuous = true;
            recognition.interimResults = true;
            recognition.lang = 'en-US';

            recognition.onresult = (event) => {
                let finalText = '';
                let interimText = '';
                for (let i = event.resultIndex; i < event.results.length; i++) {
                    if (event.results[i].isFinal) {
                        finalText += event.results[i][0].transcript;
                    } else {
                        interimText += event.results[i][0].transcript;
                    }
                }
                if (finalText) {
                    this.voiceTranscript = this.voiceTranscript
                        ? this.voiceTranscript + ' ' + finalText
                        : finalText;
                }
                this.voiceInterim = interimText;
            };

            recognition.onerror = () => {
                this.isListening = false;
            };

            recognition.onend = () => {
                // Browser may auto-stop; keep state in sync
                if (this.isListening) {
                    this.isListening = false;
                }
            };

            this._recognition = recognition;
        } catch (err) {
            // Voice not available in this context — silent
        }
    }

    _destroyVoiceRecognition() {
        if (this._recognition) {
            try {
                this._recognition.abort();
            } catch (err) {
                // silent
            }
            this._recognition = null;
        }
    }

    handleVoiceToggle() {
        if (this.isListening) {
            this.stopVoice();
        } else {
            this.startVoice();
        }
    }

    startVoice() {
        if (!this._recognition) {
            return;
        }
        this.voiceTranscript = '';
        this.voiceInterim = '';
        try {
            this._recognition.start();
            this.isListening = true;
        } catch (err) {
            // Already started or not permitted
        }
    }

    stopVoice() {
        if (!this._recognition) {
            return;
        }
        this._recognition.stop();
        this.isListening = false;

        // Append captured voice text to description
        const text = this.voiceTranscript.trim();
        if (text) {
            const voiceEntry = '[Voice] ' + text;
            this.description = this.description
                ? this.description + '\n\n' + voiceEntry
                : voiceEntry;
        }
    }

    get hasVoiceContent() {
        return Boolean(this.voiceTranscript || this.voiceInterim);
    }

    get voiceLiveText() {
        let result = '';
        if (this.voiceTranscript) {
            result += this.voiceTranscript;
        }
        if (this.voiceInterim) {
            result += (result ? ' ' : '') + this.voiceInterim;
        }
        return result;
    }

    get voiceButtonTitle() {
        return this.isListening ? 'Stop recording' : 'Dictate feedback';
    }

    get voiceStatusText() {
        return this.isListening ? 'Listening... click to stop' : 'Click mic to dictate feedback';
    }

    get voiceButtonClass() {
        return this.isListening
            ? 'gr-voice-btn gr-voice-btn--active'
            : 'gr-voice-btn';
    }

    get voiceIconName() {
        return this.isListening ? 'utility:stop' : 'utility:mic';
    }

    handleShortcut = (event) => {
        if (event.altKey && (event.code === 'KeyB' || event.key === 'b')) {
            this.togglePanel();
        }
    }

    handleNavigationLog() {
        try {
            const href = window.location.href;
            const now = Date.now();
            if (href === this.lastLoggedUrl && (now - this.lastLoggedTime) < NAV_LOG_DEBOUNCE_MS) {
                return;
            }

            // Log duration of the PREVIOUS page before recording the new one
            this._logPageDuration('navigation');

            this.lastLoggedUrl = href;
            this.lastLoggedTime = now;
            this._pageArrivalTime = now;

            const context = this.gatherContext();
            this._previousContext = context;
            logActivity({
                actionType: 'Navigation',
                contextData: JSON.stringify(context)
            }).catch(() => {
                // Silent — never break user experience for telemetry
            });
        } catch (err) {
            // Never break user experience
        }
    }

    togglePanel() {
        this.isOpen = !this.isOpen;
    }

    handleTypeChange(event) {
        this.requestType = event.detail.value;
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
    }

    handleInputChange(event) {
        this.description = event.target.value;
    }

    handlePriorityChange(event) {
        this.priority = event.detail.value;
    }

    handleUploadFinished(event) {
        const files = event.detail.files;
        this.uploadedFileIds.push(...files.map(file => file.documentId));
    }

    handleSubmit() {
        if (!this.description && !this.subject) {
            return;
        }

        this.isSending = true;
        const context = this.gatherContext();

        // Build a subject from the description if the user only provided a description
        let finalSubject = this.subject;
        if (!finalSubject && this.description) {
            if (this.description.length > SUBJECT_TRUNCATE_LEN) {
                finalSubject = `${this.description.substring(0, SUBJECT_TRUNCATE_LEN)}...`;
            } else {
                finalSubject = this.description;
            }
        }
        if (!finalSubject) {
            const typeLabel = this.isBug ? 'Issue' : 'Feature';
            finalSubject = `${typeLabel} on ${context.objectName || 'Home Page'}`;
        }

        createWorkItem({
            contextData: JSON.stringify(context),
            description: this.description,
            priority: this.priority,
            subject: finalSubject,
            workItemType: this.requestType
        })
        .then(workItemId => {
            if (this.uploadedFileIds.length > 0) {
                linkFilesAndSync({
                    contentDocumentIds: this.uploadedFileIds,
                    workItemId
                }).catch(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        message: 'Work item was created but attached files could not be linked. Please attach them from the work item record.',
                        mode: 'sticky',
                        title: 'File Attachment Failed',
                        variant: 'warning'
                    }));
                });
            }

            this.dispatchEvent(new ShowToastEvent({
                message: 'Thank you for your feedback.',
                title: this.isBug ? 'Bug Reported' : 'Feature Requested',
                variant: 'success'
            }));

            this.resetForm();
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                message: error.body ? error.body.message : error.message,
                title: 'Error',
                variant: 'error'
            }));
        })
        .finally(() => {
            this.isSending = false;
        });
    }

    resetForm() {
        this.subject = '';
        this.description = '';
        this.priority = 'Medium';
        this.uploadedFileIds = [];
        this.isOpen = false;
        this.requestType = 'Bug';
        this.voiceTranscript = '';
        this.voiceInterim = '';
        if (this.isListening) {
            try { this._recognition.stop(); } catch (err) { /* silent */ }
            this.isListening = false;
        }
    }

    gatherContext() {
        try {
            const parsed = this.parseUrlContext();
            return {
                browser: navigator.userAgent,
                objectName: parsed.objectName,
                pageLabel: parsed.pageLabel,
                recordId: parsed.recordId,
                sessionId: this.sessionIdValue,
                url: window.location.href
            };
        } catch (err) {
            return {
                browser: '',
                objectName: 'Unknown',
                pageLabel: 'Unknown',
                recordId: '',
                sessionId: '',
                url: window.location.href || ''
            };
        }
    }

    parseUrlContext() {
        const href = window.location.href;
        // Pattern: /lightning/r/{objectApiName}/{recordId}/view
        const recordMatch = href.match(/\/lightning\/r\/([^/]+)\/([a-zA-Z0-9]{15,18})\/view/u);
        if (recordMatch) {
            return { objectName: recordMatch[1], pageLabel: recordMatch[1], recordId: recordMatch[2] };
        }
        // Pattern: /lightning/o/{objectApiName}/home (list view)
        const listMatch = href.match(/\/lightning\/o\/([^/]+)\/home/u);
        if (listMatch) {
            return { objectName: listMatch[1], pageLabel: `${listMatch[1]} List`, recordId: '' };
        }
        // Pattern: /lightning/o/{objectApiName}/list
        const listAltMatch = href.match(/\/lightning\/o\/([^/]+)\/list/u);
        if (listAltMatch) {
            return { objectName: listAltMatch[1], pageLabel: `${listAltMatch[1]} List`, recordId: '' };
        }
        // Pattern: /lightning/page/home
        if (href.includes('/lightning/page/home')) {
            return { objectName: 'Home', pageLabel: 'Home', recordId: '' };
        }
        // Pattern: /lightning/page/chatter
        if (href.includes('/lightning/page/chatter')) {
            return { objectName: 'Chatter', pageLabel: 'Chatter', recordId: '' };
        }
        // Pattern: /lightning/setup/...
        if (href.includes('/lightning/setup/')) {
            return { objectName: 'Setup', pageLabel: 'Setup', recordId: '' };
        }
        // Pattern: /lightning/r/{objectApiName}/{recordId}/related/...
        const relatedMatch = href.match(/\/lightning\/r\/([^/]+)\/([a-zA-Z0-9]{15,18})\/related/u);
        if (relatedMatch) {
            return { objectName: relatedMatch[1], pageLabel: `${relatedMatch[1]} Related`, recordId: relatedMatch[2] };
        }
        // Fallback: try CurrentPageReference attributes
        const attrs = this.currentPageRef?.attributes || {};
        return {
            objectName: attrs.objectApiName || attrs.name || 'Unknown',
            pageLabel: attrs.objectApiName || attrs.name || 'Unknown',
            recordId: attrs.recordId || ''
        };
    }

    static generateSessionId() {
        try {
            return 'xxxxxxxx-xxxx-4xxx'.replace(/[x]/gu, () =>
                (Math.random() * SESSION_ID_RANDOM_RANGE | 0).toString(HEX_RADIX) // eslint-disable-line no-bitwise
            );
        } catch (err) {
            return 'unknown';
        }
    }
}