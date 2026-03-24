/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Stage History LWC. Displays a vertical timeline of stage
 *               transitions for a Work Item, showing old/new stage, who made
 *               the change, duration in the prior stage, and relative time.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire } from 'lwc';
import getStageHistory from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryStageHistoryController.getStageHistory';

const MS_PER_MINUTE = 60000;
const MS_PER_HOUR   = 3600000;
const MS_PER_DAY    = 86400000;

export default class DeliveryStageHistory extends LightningElement {
    @api workItemId;
    @api recordId; // auto-populated on record pages

    _wiredResult;
    _entries = [];
    error;

    /** @description Resolved Id — prefers explicit workItemId, falls back to recordId. */
    get resolvedId() {
        return this.workItemId || this.recordId;
    }

    // ── Wire ────────────────────────────────────────────────────────────

    @wire(getStageHistory, { workItemId: '$resolvedId' })
    wiredHistory(result) {
        this._wiredResult = result;
        const { data, error: err } = result;
        if (data) {
            this._entries = data;
            this.error = undefined;
        } else if (err) {
            this.error = err;
            this._entries = [];
        }
    }

    // ── Getters ─────────────────────────────────────────────────────────

    get isLoading() {
        return !this._wiredResult || (!this._wiredResult.data && !this._wiredResult.error);
    }

    get hasEntries() {
        return this._entries.length > 0;
    }

    get showEmpty() {
        return !this.isLoading && !this.hasEntries && !this.error;
    }

    get timelineEntries() {
        return this._entries.map(entry => {
            const ts = new Date(entry.timestamp);
            const oldStage = entry.oldStage || '(none)';
            const newStage = entry.newStage || '(none)';

            let durationLabel = '';
            if (entry.durationHours != null) {
                const hours = Number(entry.durationHours);
                if (hours < 1) {
                    const mins = Math.round(hours * 60);
                    durationLabel = 'Duration in previous stage: ' + mins + (mins === 1 ? ' minute' : ' minutes');
                } else if (hours < 24) {
                    durationLabel = 'Duration in previous stage: ' + hours.toFixed(1) + (hours === 1 ? ' hour' : ' hours');
                } else {
                    const days = (hours / 24).toFixed(1);
                    durationLabel = 'Duration in previous stage: ' + days + ' days';
                }
            }

            return {
                id: entry.id,
                heading: oldStage + ' \u2192 ' + newStage,
                subtitle: 'by ' + (entry.userName || 'System') + ' \u2022 ' + this._relativeTime(ts),
                durationLabel,
                hasDuration: !!durationLabel,
                formattedTime: ts.toLocaleString()
            };
        });
    }

    get totalTimeLabel() {
        if (this._entries.length === 0) {
            return '';
        }
        // Oldest entry is last (results are DESC)
        const oldest = new Date(this._entries[this._entries.length - 1].timestamp);
        const now = Date.now();
        const diff = now - oldest.getTime();
        if (diff < MS_PER_HOUR) {
            const mins = Math.floor(diff / MS_PER_MINUTE);
            return 'Total time tracked: ' + mins + (mins === 1 ? ' minute' : ' minutes');
        }
        if (diff < MS_PER_DAY) {
            const hrs = Math.floor(diff / MS_PER_HOUR);
            return 'Total time tracked: ' + hrs + (hrs === 1 ? ' hour' : ' hours');
        }
        const days = Math.floor(diff / MS_PER_DAY);
        return 'Total time tracked: ' + days + (days === 1 ? ' day' : ' days');
    }

    get transitionCount() {
        const count = this._entries.length;
        return count + (count === 1 ? ' transition' : ' transitions');
    }

    // ── Relative Time Helper ────────────────────────────────────────────

    _relativeTime(date) {
        const diff = Date.now() - date.getTime();

        if (diff < MS_PER_MINUTE) {
            return 'just now';
        }
        if (diff < MS_PER_HOUR) {
            const mins = Math.floor(diff / MS_PER_MINUTE);
            return mins + (mins === 1 ? ' minute ago' : ' minutes ago');
        }
        if (diff < MS_PER_DAY) {
            const hrs = Math.floor(diff / MS_PER_HOUR);
            return hrs + (hrs === 1 ? ' hour ago' : ' hours ago');
        }
        const days = Math.floor(diff / MS_PER_DAY);
        if (days < 30) {
            return days + (days === 1 ? ' day ago' : ' days ago');
        }
        return date.toLocaleDateString();
    }
}
