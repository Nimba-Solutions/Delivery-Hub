/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Swipe gesture wrapper for work item cards on mobile.
 *               Swipe right to advance (forward transition), swipe left to backtrack.
 *               Fires a 'swipetransition' custom event with workItemId and targetStage.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api } from 'lwc';

// Minimum horizontal distance (px) to qualify as a completed swipe
const SWIPE_THRESHOLD = 80;
// Maximum vertical distance to distinguish from scroll
const VERTICAL_TOLERANCE_RATIO = 0.75;
// Maximum swipe duration in ms — fast gesture vs slow drag
const MAX_SWIPE_DURATION = 600;
// Maximum card translation (px) for visual cap
const MAX_TRANSLATE = 160;

export default class DeliverySwipeCard extends LightningElement {
    /**
     * The Id of the work item this card represents.
     */
    @api workItemId;

    /**
     * The display name of the next forward stage (first in forwardTransitions).
     * Null or empty if no forward transition exists.
     */
    @api forwardStageName = '';

    /**
     * The API value of the forward stage target.
     */
    @api forwardStageValue = '';

    /**
     * The display name of the backtrack stage (first in backtrackTransitions).
     * Null or empty if no backtrack transition exists.
     */
    @api backtrackStageName = '';

    /**
     * The API value of the backtrack stage target.
     */
    @api backtrackStageValue = '';

    /**
     * Whether this stage is terminal (no forward transitions).
     */
    @api isTerminal = false;

    // Internal touch state — not reactive (no need for @track)
    _startX = 0;
    _startY = 0;
    _startTime = 0;
    _currentDeltaX = 0;
    _isSwiping = false;
    _isVerticalScroll = false;

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------

    renderedCallback() {
        // Bind touch events once the card container is in the DOM
        const card = this.template.querySelector('.swipe-card-wrapper');
        if (card && !card._touchBound) {
            card.addEventListener('touchstart', this._handleTouchStart.bind(this), { passive: true });
            card.addEventListener('touchmove', this._handleTouchMove.bind(this), { passive: false });
            card.addEventListener('touchend', this._handleTouchEnd.bind(this), { passive: true });
            card.addEventListener('touchcancel', this._handleTouchCancel.bind(this), { passive: true });
            card._touchBound = true;
        }
    }

    // -----------------------------------------------------------------------
    // Computed getters
    // -----------------------------------------------------------------------

    get hasForward() {
        return !!this.forwardStageValue && !this.isTerminal;
    }

    get hasBacktrack() {
        return !!this.backtrackStageValue;
    }

    get forwardLabel() {
        return this.forwardStageName || this.forwardStageValue || '';
    }

    get backtrackLabel() {
        return this.backtrackStageName || this.backtrackStageValue || '';
    }

    // -----------------------------------------------------------------------
    // Touch handlers
    // -----------------------------------------------------------------------

    _handleTouchStart(event) {
        if (!event.touches || event.touches.length !== 1) return;
        const touch = event.touches[0];
        this._startX = touch.clientX;
        this._startY = touch.clientY;
        this._startTime = Date.now();
        this._currentDeltaX = 0;
        this._isSwiping = false;
        this._isVerticalScroll = false;

        // Remove transition for immediate finger-follow
        const inner = this.template.querySelector('.swipe-card-inner');
        if (inner) {
            inner.style.transition = 'none';
        }
    }

    _handleTouchMove(event) {
        if (this._isVerticalScroll) return;
        if (!event.touches || event.touches.length !== 1) return;

        const touch = event.touches[0];
        const deltaX = touch.clientX - this._startX;
        const deltaY = touch.clientY - this._startY;
        const absDeltaX = Math.abs(deltaX);
        const absDeltaY = Math.abs(deltaY);

        // First significant move — determine direction intent
        if (!this._isSwiping && (absDeltaX > 10 || absDeltaY > 10)) {
            if (absDeltaY > absDeltaX * VERTICAL_TOLERANCE_RATIO) {
                // Vertical gesture — let it scroll naturally
                this._isVerticalScroll = true;
                this._resetCardPosition();
                return;
            }
            this._isSwiping = true;
        }

        if (!this._isSwiping) return;

        // Prevent page scrolling during horizontal swipe
        event.preventDefault();

        // Clamp to max translation
        const clampedDelta = Math.max(-MAX_TRANSLATE, Math.min(MAX_TRANSLATE, deltaX));
        this._currentDeltaX = clampedDelta;

        // Apply visual transform
        const inner = this.template.querySelector('.swipe-card-inner');
        if (inner) {
            inner.style.transform = `translateX(${clampedDelta}px)`;
        }

        // Update action indicators
        this._updateIndicators(clampedDelta);
    }

    _handleTouchEnd() {
        if (!this._isSwiping) {
            this._resetCardPosition();
            return;
        }

        const deltaX = this._currentDeltaX;
        const absDeltaX = Math.abs(deltaX);
        const elapsed = Date.now() - this._startTime;
        const isQuickEnough = elapsed <= MAX_SWIPE_DURATION;
        const isPastThreshold = absDeltaX >= SWIPE_THRESHOLD;

        if (isPastThreshold && isQuickEnough) {
            if (deltaX > 0 && this.hasForward) {
                // Swipe right — advance
                this._animateOffScreen('right');
                this._fireTransition(this.forwardStageValue);
                return;
            } else if (deltaX < 0 && this.hasBacktrack) {
                // Swipe left — backtrack
                this._animateOffScreen('left');
                this._fireTransition(this.backtrackStageValue);
                return;
            }
        }

        // Snap back — threshold not met or no valid transition
        this._animateSnapBack();
    }

    _handleTouchCancel() {
        this._animateSnapBack();
    }

    // -----------------------------------------------------------------------
    // Visual feedback
    // -----------------------------------------------------------------------

    _updateIndicators(deltaX) {
        const absDelta = Math.abs(deltaX);
        const progress = Math.min(absDelta / SWIPE_THRESHOLD, 1);

        const forwardIndicator = this.template.querySelector('.swipe-indicator-forward');
        const backtrackIndicator = this.template.querySelector('.swipe-indicator-backtrack');

        if (forwardIndicator) {
            if (deltaX > 0 && this.hasForward) {
                forwardIndicator.style.opacity = String(progress * 0.9 + 0.1);
                forwardIndicator.classList.toggle('past-threshold', progress >= 1);
            } else {
                forwardIndicator.style.opacity = '0';
                forwardIndicator.classList.remove('past-threshold');
            }
        }

        if (backtrackIndicator) {
            if (deltaX < 0 && this.hasBacktrack) {
                backtrackIndicator.style.opacity = String(progress * 0.9 + 0.1);
                backtrackIndicator.classList.toggle('past-threshold', progress >= 1);
            } else {
                backtrackIndicator.style.opacity = '0';
                backtrackIndicator.classList.remove('past-threshold');
            }
        }
    }

    _animateSnapBack() {
        const inner = this.template.querySelector('.swipe-card-inner');
        if (inner) {
            inner.style.transition = 'transform 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94)';
            inner.style.transform = 'translateX(0)';
        }
        this._hideIndicators();
        this._isSwiping = false;
        this._currentDeltaX = 0;
    }

    _animateOffScreen(direction) {
        const inner = this.template.querySelector('.swipe-card-inner');
        if (inner) {
            const distance = direction === 'right' ? '120%' : '-120%';
            inner.style.transition = 'transform 0.35s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.35s ease-out';
            inner.style.transform = `translateX(${distance})`;
            inner.style.opacity = '0';
        }
        this._isSwiping = false;
        this._currentDeltaX = 0;
    }

    _resetCardPosition() {
        const inner = this.template.querySelector('.swipe-card-inner');
        if (inner) {
            inner.style.transition = '';
            inner.style.transform = '';
            inner.style.opacity = '';
        }
        this._hideIndicators();
        this._isSwiping = false;
        this._currentDeltaX = 0;
    }

    _hideIndicators() {
        const forwardIndicator = this.template.querySelector('.swipe-indicator-forward');
        const backtrackIndicator = this.template.querySelector('.swipe-indicator-backtrack');
        if (forwardIndicator) {
            forwardIndicator.style.opacity = '0';
            forwardIndicator.classList.remove('past-threshold');
        }
        if (backtrackIndicator) {
            backtrackIndicator.style.opacity = '0';
            backtrackIndicator.classList.remove('past-threshold');
        }
    }

    // -----------------------------------------------------------------------
    // Event dispatch
    // -----------------------------------------------------------------------

    _fireTransition(targetStage) {
        this.dispatchEvent(new CustomEvent('swipetransition', {
            detail: {
                workItemId: this.workItemId,
                targetStage: targetStage
            },
            bubbles: true,
            composed: true
        }));
    }
}