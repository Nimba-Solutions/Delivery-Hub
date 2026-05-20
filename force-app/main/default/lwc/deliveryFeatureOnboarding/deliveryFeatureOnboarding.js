/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Checkr-style gated onboarding LWC (Layer 5 of the DH cockpit).
 *               Renders a 3-section stepper (Lessons → Quiz → Checklist) for
 *               the configured OnboardingTrack__mdt, writes per-user runtime
 *               state to OnboardingProgress__c via DeliveryOnboardingService.
 *
 *               PR 3 ships the reader + quiz + manual-attest checklist. PR 4
 *               wires the gate that refuses non-admin feature flips until the
 *               track's CompletedDateTime__c is populated and replaces the
 *               manual-attest fallback with real SoqlQuery / RestCall /
 *               WebhookReceived evaluators.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTrack from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryOnboardingService.getTrack';
import getProgress from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryOnboardingService.getProgress';
import markLessonComplete from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryOnboardingService.markLessonComplete';
import submitQuiz from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryOnboardingService.submitQuiz';
import verifyChecklistItem from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryOnboardingService.verifyChecklistItem';

const SECTION_LESSONS = 'lessons';
const SECTION_QUIZ = 'quiz';
const SECTION_CHECKLIST = 'checklist';
const EMPTY = 0;

export default class DeliveryFeatureOnboarding extends LightningElement {
    /** @description Optional override for the track DeveloperName. PR 4 will
     *               auto-resolve from Feature__c.FeatureDefinitionTxt__c when blank. */
    @api trackDeveloperName = '';

    @track activeSection = SECTION_LESSONS;
    @track currentLessonIndex = 0;
    @track quizAnswers = {};
    @track quizSubmitted = false;
    @track quizPassed = false;
    @track quizError = '';
    @track errorMessage = '';
    @track isWorking = false;

    wiredTrackResult;
    wiredProgressResult;
    bundle;
    progress;
    parsedQuestions = [];

    @wire(getTrack, { trackDeveloperName: '$trackDeveloperName' })
    wiredTrack(result) {
        this.wiredTrackResult = result;
        if (result.data) {
            this.bundle = result.data;
            this.parsedQuestions = this.parseQuestions(
                result.data.quiz ? result.data.quiz.questionsJson : ''
            );
            this.errorMessage = '';
        } else if (result.error) {
            this.errorMessage = this.extractError(result.error) || 'Unable to load onboarding track.';
        }
    }

    @wire(getProgress, { trackDeveloperName: '$trackDeveloperName' })
    wiredProgress(result) {
        this.wiredProgressResult = result;
        if (result.data) {
            this.progress = result.data;
        } else if (result.error) {
            this.errorMessage = this.extractError(result.error) || 'Unable to load onboarding progress.';
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // Derived state (getters, not template ternaries)
    // ────────────────────────────────────────────────────────────────────

    get hasTrack() {
        return !!(this.bundle && this.bundle.track);
    }

    get trackLabel() {
        return this.hasTrack ? this.bundle.track.label : '';
    }

    get trackEstimatedDuration() {
        return this.hasTrack ? this.bundle.track.estimatedDuration : null;
    }

    get hasLessons() {
        return !!(this.bundle && this.bundle.lessons && this.bundle.lessons.length > EMPTY);
    }

    get currentLesson() {
        if (!this.hasLessons) {
            return null;
        }
        const idx = Math.min(this.currentLessonIndex, this.bundle.lessons.length - 1);
        return this.bundle.lessons[idx];
    }

    get isLastLesson() {
        return this.hasLessons && this.currentLessonIndex >= this.bundle.lessons.length - 1;
    }

    get completedLessonNames() {
        if (!this.progress || !this.progress.lessonsCompletedJson) {
            return new Set();
        }
        try {
            const arr = JSON.parse(this.progress.lessonsCompletedJson);
            const out = new Set();
            (arr || []).forEach((e) => {
                if (e && e.lesson) {
                    out.add(e.lesson);
                }
            });
            return out;
        } catch (e) {
            return new Set();
        }
    }

    get lessonCompletionCount() {
        return this.completedLessonNames.size;
    }

    get lessonTotal() {
        return this.hasLessons ? this.bundle.lessons.length : 0;
    }

    get isCurrentLessonCompleted() {
        const lesson = this.currentLesson;
        if (!lesson) {
            return false;
        }
        return this.completedLessonNames.has(lesson.developerName);
    }

    get currentLessonHasUrl() {
        const lesson = this.currentLesson;
        return !!(lesson && lesson.lessonUrl);
    }

    get hasQuiz() {
        return !!(this.bundle && this.bundle.quiz && this.parsedQuestions.length > EMPTY);
    }

    get quizPassThreshold() {
        return this.hasQuiz ? this.bundle.quiz.passThreshold : 0;
    }

    get quizAllowsRetry() {
        return !!(this.bundle && this.bundle.quiz && this.bundle.quiz.allowRetry);
    }

    get quizPriorAttempts() {
        return this.progress && this.progress.quizAttempts != null ? this.progress.quizAttempts : 0;
    }

    get quizPriorScore() {
        return this.progress && this.progress.quizScore != null ? this.progress.quizScore : null;
    }

    get quizSubmitButtonDisabled() {
        if (this.isWorking) {
            return true;
        }
        // Cannot submit if quiz already submitted in this session and retries disabled
        if (this.quizSubmitted && !this.quizAllowsRetry) {
            return true;
        }
        return Object.keys(this.quizAnswers).length < this.parsedQuestions.length;
    }

    get displayQuestions() {
        return this.parsedQuestions.map((q, idx) => {
            const id = `q_${idx}`;
            const options = (q.options || []).map((opt, optIdx) => ({
                key: `${id}_${optIdx}`,
                value: String(optIdx),
                label: opt,
                checked: this.quizAnswers[id] === String(optIdx)
            }));
            return {
                key: id,
                index: idx + 1,
                question: q.q || '',
                options,
                explanation: q.explanation || '',
                showExplanation: this.quizSubmitted && q.explanation
            };
        });
    }

    get hasChecklist() {
        return !!(this.bundle && this.bundle.checklist && this.bundle.checklist.length > EMPTY);
    }

    get checklistState() {
        if (!this.progress || !this.progress.checklistStateJson) {
            return {};
        }
        try {
            return JSON.parse(this.progress.checklistStateJson) || {};
        } catch (e) {
            return {};
        }
    }

    get displayChecklist() {
        const state = this.checklistState;
        return (this.bundle.checklist || []).map((item) => {
            const stateEntry = state[item.developerName] || {};
            const completed = stateEntry.completed === true;
            const requiredLabel = item.required ? 'Required' : 'Optional';
            const badgeClass = item.required
                ? 'slds-badge slds-theme_warning'
                : 'slds-badge slds-badge_lightest';
            const buttonLabel = completed ? 'Verified' : 'Attest';
            const buttonVariant = completed ? 'success' : 'brand';
            return {
                key: item.developerName,
                developerName: item.developerName,
                label: item.label,
                description: item.description,
                verificationMethod: item.verificationMethod,
                required: item.required,
                requiredLabel,
                badgeClass,
                completed,
                buttonLabel,
                buttonVariant,
                buttonDisabled: completed || this.isWorking
            };
        });
    }

    get isTrackComplete() {
        return !!(this.progress && this.progress.isComplete === true);
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get isLessonsActive() {
        return this.activeSection === SECTION_LESSONS;
    }

    get isQuizActive() {
        return this.activeSection === SECTION_QUIZ;
    }

    get isChecklistActive() {
        return this.activeSection === SECTION_CHECKLIST;
    }

    get lessonsTabClass() {
        return this.tabClass(SECTION_LESSONS);
    }

    get quizTabClass() {
        return this.tabClass(SECTION_QUIZ);
    }

    get checklistTabClass() {
        return this.tabClass(SECTION_CHECKLIST);
    }

    get markLessonButtonLabel() {
        return this.isCurrentLessonCompleted ? 'Completed — Next Lesson' : 'Mark Complete';
    }

    get markLessonButtonDisabled() {
        return this.isWorking;
    }

    get quizResultMessage() {
        if (!this.quizSubmitted) {
            return '';
        }
        if (this.quizPassed) {
            return `Passed — score ${this.quizPriorScore} of ${this.parsedQuestions.length}.`;
        }
        return `Did not pass — score ${this.quizPriorScore} of ${this.parsedQuestions.length} (need ${this.quizPassThreshold}).`;
    }

    get quizResultClass() {
        if (!this.quizSubmitted) {
            return '';
        }
        return this.quizPassed
            ? 'slds-notify slds-notify_alert slds-theme_success'
            : 'slds-notify slds-notify_alert slds-theme_warning';
    }

    // ────────────────────────────────────────────────────────────────────
    // Handlers
    // ────────────────────────────────────────────────────────────────────

    handleSectionClick(event) {
        const section = event.currentTarget.dataset.section;
        if (section) {
            this.activeSection = section;
        }
    }

    handlePreviousLesson() {
        if (this.currentLessonIndex > 0) {
            this.currentLessonIndex -= 1;
        }
    }

    handleMarkLessonComplete() {
        const lesson = this.currentLesson;
        if (!lesson || this.isWorking) {
            return;
        }
        this.isWorking = true;
        markLessonComplete({
            trackDeveloperName: this.trackDeveloperName,
            lessonDeveloperName: lesson.developerName
        })
            .then(() => {
                if (!this.isLastLesson) {
                    this.currentLessonIndex += 1;
                }
                return refreshApex(this.wiredProgressResult);
            })
            .catch((error) => {
                this.errorMessage = this.extractError(error) || 'Unable to mark lesson complete.';
            })
            .finally(() => {
                this.isWorking = false;
            });
    }

    handleAnswerChange(event) {
        const questionId = event.target.dataset.question;
        const value = event.target.value;
        // Use a fresh object so reactive tracking sees the change.
        this.quizAnswers = { ...this.quizAnswers, [questionId]: value };
    }

    handleSubmitQuiz() {
        if (this.quizSubmitButtonDisabled) {
            return;
        }
        let score = 0;
        this.parsedQuestions.forEach((q, idx) => {
            const id = `q_${idx}`;
            const answered = this.quizAnswers[id];
            if (answered !== undefined && Number(answered) === Number(q.correct)) {
                score += 1;
            }
        });
        this.isWorking = true;
        this.quizError = '';
        submitQuiz({
            trackDeveloperName: this.trackDeveloperName,
            score
        })
            .then(() => {
                this.quizSubmitted = true;
                this.quizPassed = score >= this.quizPassThreshold;
                return refreshApex(this.wiredProgressResult);
            })
            .catch((error) => {
                this.quizError = this.extractError(error) || 'Unable to submit quiz.';
            })
            .finally(() => {
                this.isWorking = false;
            });
    }

    handleAttestChecklistItem(event) {
        const itemName = event.currentTarget.dataset.item;
        if (!itemName || this.isWorking) {
            return;
        }
        this.isWorking = true;
        verifyChecklistItem({
            trackDeveloperName: this.trackDeveloperName,
            itemDeveloperName: itemName
        })
            .then(() => refreshApex(this.wiredProgressResult))
            .catch((error) => {
                this.errorMessage = this.extractError(error) || 'Unable to attest checklist item.';
            })
            .finally(() => {
                this.isWorking = false;
            });
    }

    // ────────────────────────────────────────────────────────────────────
    // Internal helpers
    // ────────────────────────────────────────────────────────────────────

    tabClass(section) {
        const base = 'slds-tabs_default__item';
        return this.activeSection === section ? `${base} slds-is-active` : base;
    }

    parseQuestions(raw) {
        if (!raw) {
            return [];
        }
        try {
            const parsed = JSON.parse(raw);
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            return [];
        }
    }

    extractError(error) {
        if (!error) {
            return '';
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (typeof error === 'string') {
            return error;
        }
        return error.message || '';
    }
}
