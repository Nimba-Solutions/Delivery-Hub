/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createWorkItemFromVoice from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryVoiceNotesController.createWorkItemFromVoice';
import createBatchWorkItems from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryVoiceNotesController.createBatchWorkItems';
import getEntityNames from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryVoiceNotesController.getEntityNames';

const BRIEF_MAX = 100;
const DATE_PATTERN = /\b(\d{4}-\d{2}-\d{2})\b/u;
const NATURAL_DATE_PATTERNS = [
    { regex: /\b(?:next\s+)?monday\b/iu, offset: day => nextWeekday(day, 1) },
    { regex: /\b(?:next\s+)?tuesday\b/iu, offset: day => nextWeekday(day, 2) },
    { regex: /\b(?:next\s+)?wednesday\b/iu, offset: day => nextWeekday(day, 3) },
    { regex: /\b(?:next\s+)?thursday\b/iu, offset: day => nextWeekday(day, 4) },
    { regex: /\b(?:next\s+)?friday\b/iu, offset: day => nextWeekday(day, 5) },
    { regex: /\btomorrow\b/iu, offset: () => 1 },
    { regex: /\bnext\s+week\b/iu, offset: () => 7 },
    { regex: /\bend\s+of\s+(?:the\s+)?week\b/iu, offset: day => nextWeekday(day, 5) },
    { regex: /\bend\s+of\s+(?:the\s+)?month\b/iu, offset: day => {
        const d = new Date(day);
        const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0);
        return Math.ceil((lastDay - d) / 86400000);
    }},
    { regex: /\bin\s+(\d+)\s+days?\b/iu, offset: (day, match) => parseInt(match[1], 10) },
    { regex: /\bin\s+(\d+)\s+weeks?\b/iu, offset: (day, match) => parseInt(match[1], 10) * 7 }
];

const PRIORITY_HIGH = /\b(?:urgent|critical|asap|high\s+priority|emergency|immediately|right\s+away)\b/iu;
const PRIORITY_LOW = /\b(?:low\s+priority|not\s+urgent|whenever|no\s+rush|backlog)\b/iu;

const ACTION_TYPE_MAP = [
    { regex: /\b(?:bug|fix|broken|issue|error|defect|crash)\b/iu, type: 'Bug Fix' },
    { regex: /\b(?:meeting|call|sync|standup|check[- ]?in|discuss)\b/iu, type: 'Meeting' },
    { regex: /\b(?:deploy|release|push|ship|launch|go[- ]?live)\b/iu, type: 'Deployment' },
    { regex: /\b(?:test|qa|verify|validate|regression)\b/iu, type: 'Testing' },
    { regex: /\b(?:doc|document|write[- ]?up|readme|wiki)\b/iu, type: 'Documentation' }
];

function extractPriority(text) {
    if (PRIORITY_HIGH.test(text)) { return 'High'; }
    if (PRIORITY_LOW.test(text)) { return 'Low'; }
    return 'Medium';
}

function extractActionType(text) {
    for (const entry of ACTION_TYPE_MAP) {
        if (entry.regex.test(text)) {
            return entry.type;
        }
    }
    return null;
}

function extractEntityName(text, entities) {
    if (!entities || entities.length === 0) { return null; }
    const lower = text.toLowerCase();
    let bestMatch = null;
    let bestLen = 0;
    for (const entity of entities) {
        const name = entity.name.toLowerCase();
        if (lower.includes(name) && name.length > bestLen) {
            bestMatch = entity;
            bestLen = name.length;
        }
    }
    return bestMatch;
}

function nextWeekday(today, targetDay) {
    const currentDay = today.getDay();
    let diff = targetDay - currentDay;
    if (diff <= 0) {
        diff += 7;
    }
    return diff;
}

function parseDateFromText(text) {
    // Try ISO date first (YYYY-MM-DD)
    const isoMatch = text.match(DATE_PATTERN);
    if (isoMatch) {
        return isoMatch[1];
    }

    // Try natural language dates
    const today = new Date();
    for (const pattern of NATURAL_DATE_PATTERNS) {
        const match = text.match(pattern.regex);
        if (match) {
            const offsetDays = pattern.offset(today, match);
            const target = new Date(today);
            target.setDate(target.getDate() + offsetDays);
            return target.toISOString().split('T')[0];
        }
    }

    return null;
}

function splitIntoSegments(text) {
    // Split on sentence boundaries (period, exclamation, question mark followed by space)
    // or on "also" / "and then" / "next" at the start of a clause
    const sentences = text.split(/(?<=[.!?])\s+/u).filter(s => s.trim().length > 0);

    // If we only got one segment, return it as-is
    if (sentences.length <= 1) {
        return [{ text: text.trim(), startDate: parseDateFromText(text) }];
    }

    return sentences.map(s => ({
        text: s.trim(),
        startDate: parseDateFromText(s)
    }));
}

export default class DeliveryVoiceNotes extends NavigationMixin(LightningElement) { // eslint-disable-line new-cap
    // Voice recognition state
    @track voiceSupported = false;
    @track isListening = false;
    @track voiceTranscript = '';
    @track voiceInterim = '';
    _recognition = null;

    // Entity data
    _entities = [];

    @wire(getEntityNames)
    wiredEntities({ data }) {
        if (data) {
            this._entities = data;
        }
    }

    // Form state
    @track showReview = false;
    @track editableTitle = '';
    @track editableTranscript = '';
    @track priority = 'Medium';
    @track startDate = '';
    @track detectedEntityId = '';
    @track detectedEntityName = '';
    @track detectedActionType = '';
    @track isSaving = false;
    @track createMode = 'single'; // 'single' or 'batch'
    @track segments = [];
    @track createdItems = [];
    @track showSuccess = false;

    // ── Getters ──

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
        return this.isListening ? 'Stop recording' : 'Start recording';
    }

    get voiceStatusText() {
        if (!this.voiceSupported) {
            return 'Voice recognition is not supported in this browser';
        }
        return this.isListening
            ? 'Listening... tap to stop'
            : 'Tap the microphone to start dictating';
    }

    get voiceButtonClass() {
        let cls = 'vn-mic-btn';
        if (this.isListening) {
            cls += ' vn-mic-btn--active';
        }
        if (!this.voiceSupported) {
            cls += ' vn-mic-btn--disabled';
        }
        return cls;
    }

    get voiceIconName() {
        return this.isListening ? 'utility:stop' : 'utility:mic';
    }

    get priorityOptions() {
        return [
            { label: 'Low', value: 'Low' },
            { label: 'Medium', value: 'Medium' },
            { label: 'High', value: 'High' }
        ];
    }

    get voiceNotSupported() {
        return !this.voiceSupported;
    }

    get isRecordingView() {
        return !this.showReview && !this.showSuccess;
    }

    get isSingleMode() {
        return this.createMode === 'single';
    }

    get isBatchMode() {
        return this.createMode === 'batch';
    }

    get createButtonLabel() {
        return this.isBatchMode ? 'Create All Work Items' : 'Create Work Item';
    }

    get segmentCount() {
        return this.segments.length;
    }

    get hasSegments() {
        return this.segments.length > 0;
    }

    get hasCreatedItems() {
        return this.createdItems.length > 0;
    }

    get reviewTitle() {
        return this.isBatchMode
            ? `Review ${this.segments.length} Work Item(s)`
            : 'Review Work Item';
    }

    get titlePreview() {
        const src = this.editableTitle || this.editableTranscript || '';
        return src.length > BRIEF_MAX ? src.substring(0, BRIEF_MAX) + '...' : src;
    }

    get hasDetectedEntity() {
        return Boolean(this.detectedEntityId);
    }

    get hasDetectedActionType() {
        return Boolean(this.detectedActionType);
    }

    get canCreate() {
        if (this.isBatchMode) {
            return this.segments.some(s => s.text && s.text.trim().length > 0);
        }
        return Boolean(this.editableTranscript && this.editableTranscript.trim());
    }

    // ── Lifecycle ──

    connectedCallback() {
        this._initVoiceRecognition();
    }

    disconnectedCallback() {
        this._destroyVoiceRecognition();
    }

    // ── Voice Recognition ──

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
                if (this.isListening) {
                    // Auto-restart if user hasn't explicitly stopped
                    try {
                        recognition.start();
                    } catch (err) {
                        this.isListening = false;
                    }
                }
            };

            this._recognition = recognition;
        } catch (err) {
            // Voice not available
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

    // ── Event Handlers ──

    handleVoiceToggle() {
        if (!this.voiceSupported) {
            return;
        }
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
        // Reset only if starting fresh (no existing transcript)
        if (!this.voiceTranscript) {
            this.voiceInterim = '';
        }
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
        this.isListening = false;
        try {
            this._recognition.stop();
        } catch (err) {
            // silent
        }

        // Transition to review mode if we have content
        const transcript = (this.voiceTranscript || '').trim();
        if (transcript) {
            this.editableTranscript = transcript;
            this.editableTitle = '';

            // Smart parsing — extract structured data from transcript
            const detectedDate = parseDateFromText(transcript);
            if (detectedDate) {
                this.startDate = detectedDate;
            }
            this.priority = extractPriority(transcript);

            const actionType = extractActionType(transcript);
            this.detectedActionType = actionType || '';

            const matchedEntity = extractEntityName(transcript, this._entities);
            if (matchedEntity) {
                this.detectedEntityId = matchedEntity.id;
                this.detectedEntityName = matchedEntity.name;
            } else {
                this.detectedEntityId = '';
                this.detectedEntityName = '';
            }

            // Auto-split into segments for batch mode preview
            this.segments = splitIntoSegments(transcript).map((s, idx) => ({
                ...s,
                id: 'seg-' + idx,
                preview: s.text.length > BRIEF_MAX
                    ? s.text.substring(0, BRIEF_MAX) + '...'
                    : s.text
            }));

            this.showReview = true;
        }
    }

    handleTitleChange(event) {
        this.editableTitle = event.target.value;
    }

    handleTranscriptChange(event) {
        this.editableTranscript = event.target.value;
    }

    handlePriorityChange(event) {
        this.priority = event.detail.value;
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }

    handleModeChange(event) {
        this.createMode = event.detail.value;
    }

    handleSegmentTextChange(event) {
        const segId = event.target.dataset.segmentId;
        const newText = event.target.value;
        this.segments = this.segments.map(s =>
            s.id === segId ? { ...s, text: newText } : s
        );
    }

    handleRemoveSegment(event) {
        const segId = event.target.dataset.segmentId || event.currentTarget.dataset.segmentId;
        this.segments = this.segments.filter(s => s.id !== segId);
    }

    handleClearEntity() {
        this.detectedEntityId = '';
        this.detectedEntityName = '';
    }

    handleClearActionType() {
        this.detectedActionType = '';
    }

    handleBackToRecording() {
        this.showReview = false;
        this.showSuccess = false;
        this.createdItems = [];
    }

    handleNewRecording() {
        this.voiceTranscript = '';
        this.voiceInterim = '';
        this.editableTitle = '';
        this.editableTranscript = '';
        this.startDate = '';
        this.priority = 'Medium';
        this.detectedEntityId = '';
        this.detectedEntityName = '';
        this.detectedActionType = '';
        this.segments = [];
        this.createdItems = [];
        this.showReview = false;
        this.showSuccess = false;
        this.createMode = 'single';
    }

    handleCreateWorkItem() {
        if (this.isBatchMode) {
            this._createBatch();
        } else {
            this._createSingle();
        }
    }

    handleNavigateToItem(event) {
        const recordId = event.currentTarget.dataset.recordId;
        if (recordId) {
            this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
                attributes: {
                    actionName: 'view',
                    objectApiName: '%%%NAMESPACED_ORG%%%WorkItem__c',
                    recordId: recordId
                },
                type: 'standard__recordPage'
            });
        }
    }

    // ── Private Methods ──

    _createSingle() {
        this.isSaving = true;
        createWorkItemFromVoice({
            transcript: this.editableTranscript,
            briefTitle: this.editableTitle || null,
            priority: this.priority,
            startDateStr: this.startDate || null,
            entityId: this.detectedEntityId || null,
            actionType: this.detectedActionType || null
        })
        .then(result => {
            this.createdItems = [{
                recordId: result.recordId,
                recordName: result.recordName,
                title: this.editableTitle || this.editableTranscript.substring(0, BRIEF_MAX)
            }];
            this.showSuccess = true;
            this.showReview = false;
            this.dispatchEvent(new ShowToastEvent({
                message: `Work item ${result.recordName} created from voice note.`,
                title: 'Voice Note Saved',
                variant: 'success'
            }));
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                message: error.body ? error.body.message : error.message,
                title: 'Error Creating Work Item',
                variant: 'error'
            }));
        })
        .finally(() => {
            this.isSaving = false;
        });
    }

    _createBatch() {
        const validSegments = this.segments
            .filter(s => s.text && s.text.trim().length > 0)
            .map(s => ({ text: s.text.trim(), startDate: s.startDate || '' }));

        if (validSegments.length === 0) {
            this.dispatchEvent(new ShowToastEvent({
                message: 'Please add at least one non-empty note.',
                title: 'No Content',
                variant: 'warning'
            }));
            return;
        }

        this.isSaving = true;
        createBatchWorkItems({
            segments: JSON.stringify(validSegments),
            priority: this.priority
        })
        .then(results => {
            this.createdItems = results.map((r, idx) => ({
                recordId: r.recordId,
                recordName: r.recordName,
                title: validSegments[idx]
                    ? validSegments[idx].text.substring(0, BRIEF_MAX)
                    : r.recordName
            }));
            this.showSuccess = true;
            this.showReview = false;
            this.dispatchEvent(new ShowToastEvent({
                message: `${results.length} work item(s) created from voice notes.`,
                title: 'Voice Notes Saved',
                variant: 'success'
            }));
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                message: error.body ? error.body.message : error.message,
                title: 'Error Creating Work Items',
                variant: 'error'
            }));
        })
        .finally(() => {
            this.isSaving = false;
        });
    }

    get modeOptions() {
        return [
            { label: 'Single Work Item', value: 'single' },
            { label: 'Multiple Work Items (one per sentence)', value: 'batch' }
        ];
    }
}
