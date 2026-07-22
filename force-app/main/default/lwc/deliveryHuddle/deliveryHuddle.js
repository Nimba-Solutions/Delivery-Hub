/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Huddle — the meeting-prep surface. Open WorkItems grouped by
 *               epic, each row carrying status, owner, due date, the latest
 *               comment (with age) and an optional link-out to the external
 *               page that holds its context. Filter chips slice the same list
 *               four ways (overdue / due soon / changed recently / stale) so a
 *               standup can open on "what changed" instead of on memory, and a
 *               quick-add row captures a new item mid-meeting in seconds.
 *               Sectioning is computed client-side from getHuddleItems()'s
 *               dates — the Apex stays one cacheable query.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getHuddleItems from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHuddleController.getHuddleItems';
import quickAddItem from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHuddleController.quickAddItem';

const MS_PER_DAY = 24 * 60 * 60 * 1000;
const DUE_SOON_DAYS = 7;
const RECENT_DAYS = 7;
const STALE_DAYS = 14;
const UNGROUPED = 'Ungrouped';

const FILTERS = [
    { key: 'all', label: 'All open' },
    { key: 'overdue', label: 'Overdue' },
    { key: 'duesoon', label: 'Due soon' },
    { key: 'recent', label: 'Changed recently' },
    { key: 'stale', label: 'Stale' }
];

export default class DeliveryHuddle extends NavigationMixin(LightningElement) {
    items = [];
    error;
    activeFilter = 'all';
    saving = false;
    _wiredResult;

    // Quick-add form state
    draftTitle = '';
    draftDue = null;
    draftEpic = '';

    @wire(getHuddleItems)
    wiredItems(result) {
        this._wiredResult = result;
        if (result.data) {
            this.items = result.data.map((row) => this.decorate(row));
            this.error = undefined;
        } else if (result.error) {
            this.error = 'Could not load huddle items.';
            this.items = [];
        }
    }

    // ── View models ────────────────────────────────────────────────────

    /** Adds derived, template-ready fields to one Apex DTO row. */
    decorate(row) {
        const now = Date.now();
        // dueDate arrives as 'YYYY-MM-DD'; anchor at local midnight for day math.
        const due = row.dueDate ? new Date(row.dueDate + 'T00:00:00') : null;
        // LastModifiedDate is polluted by scheduled jobs (the hourly ETA service
        // re-stamps ~a third of open items), so staleness/recency key off human
        // signals only: latest comment, stage transition, or creation.
        const touched = Math.max(
            row.lastCommentDate ? new Date(row.lastCommentDate).getTime() : 0,
            row.stageEntered ? new Date(row.stageEntered).getTime() : 0,
            row.createdDate ? new Date(row.createdDate).getTime() : 0
        ) || now;
        const daysUntilDue = due === null ? null : Math.floor((due.getTime() - now) / MS_PER_DAY) + 1;
        const daysSinceTouch = Math.floor((now - touched) / MS_PER_DAY);

        const isOverdue = daysUntilDue !== null && daysUntilDue < 0;
        const isDueSoon = daysUntilDue !== null && daysUntilDue >= 0 && daysUntilDue <= DUE_SOON_DAYS;
        const isRecent = daysSinceTouch <= RECENT_DAYS;
        const isStale = daysSinceTouch >= STALE_DAYS;

        let dueText = '';
        if (isOverdue) {
            dueText = `Overdue ${Math.abs(daysUntilDue)}d`;
        } else if (daysUntilDue === 0) {
            dueText = 'Due today';
        } else if (daysUntilDue !== null) {
            dueText = `Due in ${daysUntilDue}d`;
        }

        let commentText = 'No comments yet';
        if (row.lastCommentBody) {
            const age = this.ageText(row.lastCommentDate);
            const author = row.lastCommentAuthor ? `${row.lastCommentAuthor} · ` : '';
            commentText = `${author}${age}: ${row.lastCommentBody}`;
        }

        let dueClass = 'slds-badge';
        if (isOverdue) {
            dueClass = 'slds-badge slds-theme_error';
        } else if (isDueSoon) {
            dueClass = 'slds-badge slds-theme_warning';
        }

        return {
            ...row,
            epicKey: row.epic || UNGROUPED,
            humanTouch: touched,
            metaText: this.metaText(row),
            touchedText: `activity ${this.ageText(touched)}`,
            hasDue: dueText !== '',
            dueText,
            dueClass,
            hasUrl: Boolean(row.externalPageUrl),
            commentText,
            isOverdue,
            isDueSoon,
            isRecent,
            isStale,
            showStaleBadge: isStale
        };
    }

    metaText(row) {
        const parts = [];
        if (row.stage) {
            parts.push(row.stage);
        } else if (row.status) {
            parts.push(row.status);
        }
        if (row.ownerName) {
            parts.push(row.ownerName);
        }
        return parts.join(' · ');
    }

    ageText(dateTimeValue) {
        if (!dateTimeValue) {
            return '';
        }
        const days = Math.floor((Date.now() - new Date(dateTimeValue).getTime()) / MS_PER_DAY);
        if (days <= 0) {
            return 'today';
        }
        if (days === 1) {
            return '1d ago';
        }
        return `${days}d ago`;
    }

    matchesFilter(item, filterKey) {
        if (filterKey === 'overdue') {
            return item.isOverdue;
        }
        if (filterKey === 'duesoon') {
            return item.isDueSoon;
        }
        if (filterKey === 'recent') {
            return item.isRecent;
        }
        if (filterKey === 'stale') {
            return item.isStale;
        }
        return true;
    }

    get filterChips() {
        return FILTERS.map((f) => {
            const count = this.items.filter((i) => this.matchesFilter(i, f.key)).length;
            return {
                ...f,
                labelWithCount: `${f.label} (${count})`,
                variant: f.key === this.activeFilter ? 'brand' : 'neutral'
            };
        });
    }

    /** Items passing the active filter, grouped by epic (Ungrouped last),
     *  freshest human activity first within each group. */
    get groups() {
        const visible = this.items
            .filter((i) => this.matchesFilter(i, this.activeFilter))
            .sort((a, b) => b.humanTouch - a.humanTouch);
        const byEpic = new Map();
        visible.forEach((item) => {
            if (!byEpic.has(item.epicKey)) {
                byEpic.set(item.epicKey, []);
            }
            byEpic.get(item.epicKey).push(item);
        });
        const names = [...byEpic.keys()].sort((a, b) => {
            if (a === UNGROUPED) {
                return 1;
            }
            if (b === UNGROUPED) {
                return -1;
            }
            return a.localeCompare(b);
        });
        return names.map((name) => ({
            name,
            countText: `${byEpic.get(name).length} item(s)`,
            items: byEpic.get(name)
        }));
    }

    get hasItems() {
        return this.groups.length > 0;
    }

    get showEmpty() {
        return !this.error && !this.hasItems;
    }

    get addDisabled() {
        return this.saving || !this.draftTitle || this.draftTitle.trim() === '';
    }

    // ── Handlers ───────────────────────────────────────────────────────

    handleFilterClick(event) {
        this.activeFilter = event.target.dataset.filter;
    }

    handleTitleChange(event) {
        this.draftTitle = event.target.value;
    }

    handleDueChange(event) {
        this.draftDue = event.target.value || null;
    }

    handleEpicChange(event) {
        this.draftEpic = event.target.value;
    }

    handleOpenRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    async handleQuickAdd() {
        if (this.addDisabled) {
            return;
        }
        this.saving = true;
        try {
            await quickAddItem({
                title: this.draftTitle,
                dueDate: this.draftDue,
                epic: this.draftEpic,
                externalPageUrl: null
            });
            this.draftTitle = '';
            this.draftDue = null;
            this.draftEpic = '';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Captured',
                    message: 'Work item added to intake.',
                    variant: 'success'
                })
            );
            await refreshApex(this._wiredResult);
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Could not add item',
                    message: e && e.body && e.body.message ? e.body.message : 'Unexpected error',
                    variant: 'error'
                })
            );
        } finally {
            this.saving = false;
        }
    }
}
