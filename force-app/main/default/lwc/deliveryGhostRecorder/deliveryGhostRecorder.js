/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Universal "Ghost Recorder" utility — logs user navigation activity in the
 *               background (debounced) and exposes a one-click Quick Request form with
 *               automatic context capture (current URL, record ID, browser) plus voice-to-text
 *               via the Web Speech API. Mounts on UtilityBar / HomePage / AppPage / RecordPage.
 *               Optional Alt+B keyboard shortcut. Feeds DeliveryActivityDashboard analytics
 *               via DeliveryGhostController.logUserActivity. The logging itself
 *               lives in the shared c/deliveryGhostTracker module, which the
 *               background-only recorder (deliveryGhostRecorderBackground) also uses.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import WORK_ITEM_OBJECT from '@salesforce/schema/WorkItem__c';
import createWorkItem from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGhostController.createQuickRequest';
import getAttentionCount from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getAttentionCount';
import getReportIds from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getReportIds';
import linkFilesAndSync from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkItemController.linkFilesAndSync';
import userId from '@salesforce/user/Id';
import { attach, detach, gatherContext, parseUrlContext, recordNavigation } from 'c/deliveryGhostTracker';

const SUBJECT_TRUNCATE_LEN = 95;

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
            attributes: { actionName: 'list', objectApiName: WORK_ITEM_OBJECT.objectApiName },
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
        attach(this);
        if (this.enableShortcut) {
            window.addEventListener('keydown', this.handleShortcut);
        }
        this._initVoiceRecognition();
    }

    disconnectedCallback() {
        window.removeEventListener('keydown', this.handleShortcut);
        detach(this);
        this._destroyVoiceRecognition();
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
        recordNavigation(this, this.currentPageRef);
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
        return gatherContext();
    }

    parseUrlContext() {
        return parseUrlContext(this.currentPageRef);
    }
}