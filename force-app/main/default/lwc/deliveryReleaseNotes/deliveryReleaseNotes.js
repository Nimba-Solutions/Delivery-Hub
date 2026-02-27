/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Release Notes Generator LWC. Queries completed work items within a
 *               configurable date range, displays them grouped by request type, and
 *               supports copy-to-clipboard for sharing.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import generateReleaseNotes from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryReleaseNotesController.generateReleaseNotes';

export default class DeliveryReleaseNotes extends LightningElement {
    @track startDate;
    @track endDate;
    @track isLoading = false;
    @track errorMessage = '';
    @track releaseData = null;
    @track copied = false;

    connectedCallback() {
        this._initDefaultDates();
    }

    /** @description Sets default date range: 30 days ago to today. */
    _initDefaultDates() {
        const today = new Date();
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(today.getDate() - 30);
        this.endDate = this._toIsoDate(today);
        this.startDate = this._toIsoDate(thirtyDaysAgo);
    }

    /** @description Formats a JS Date to YYYY-MM-DD string. */
    _toIsoDate(d) {
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }

    async handleGenerate() {
        this.isLoading = true;
        this.errorMessage = '';
        this.releaseData = null;
        this.copied = false;

        try {
            const result = await generateReleaseNotes({
                startDate: this.startDate,
                endDate: this.endDate,
                workflowTypeName: ''
            });
            this.releaseData = this._enrichSections(result);
        } catch (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
        } finally {
            this.isLoading = false;
        }
    }

    /** @description Adds unique keys to sections and items for template iteration. */
    _enrichSections(data) {
        if (!data || !data.sections) {
            return data;
        }
        const enriched = { ...data };
        enriched.sections = data.sections.map((section, sIdx) => ({
            ...section,
            key: `section-${sIdx}`,
            items: (section.items || []).map((item, iIdx) => ({
                ...item,
                key: `item-${sIdx}-${iIdx}`,
                displayLine: this._buildItemLine(item),
                priorityClass: this._getPriorityClass(item.priority),
                hasPriority: !!item.priority,
                hasDeveloper: !!item.developer
            }))
        }));
        return enriched;
    }

    /** @description Builds display line: "WI-0001 -- Brief description". */
    _buildItemLine(item) {
        const title = item.title || 'Untitled';
        return `${item.name} \u2014 ${title}`;
    }

    /** @description Maps priority to a CSS class for badge styling. */
    _getPriorityClass(priority) {
        const map = {
            'Critical': 'priority-badge priority-critical',
            'High': 'priority-badge priority-high',
            'Medium': 'priority-badge priority-medium',
            'Low': 'priority-badge priority-low'
        };
        return map[priority] || 'priority-badge priority-default';
    }

    handleCopy() {
        const text = this._buildPlainText();
        navigator.clipboard.writeText(text).then(() => {
            this.copied = true;
            setTimeout(() => {
                this.copied = false;
            }, 3000);
        });
    }

    /** @description Builds a plain-text version of release notes for clipboard. */
    _buildPlainText() {
        if (!this.releaseData) {
            return '';
        }
        const lines = [this.releaseData.title, ''];
        lines.push(`${this.releaseData.totalItems} items completed`, '');

        for (const section of this.releaseData.sections) {
            lines.push(`## ${section.category}`);
            for (const item of section.items) {
                const dev = item.developer ? ` (${item.developer})` : '';
                const pri = item.priority ? ` [${item.priority}]` : '';
                lines.push(`  - ${item.name} \u2014 ${item.title || 'Untitled'}${pri}${dev}`);
            }
            lines.push('');
        }
        return lines.join('\n');
    }

    get generateLabel() {
        return this.isLoading ? 'Generating...' : 'Generate';
    }

    get copyLabel() {
        return this.copied ? 'Copied!' : 'Copy to Clipboard';
    }

    get hasResults() {
        return this.releaseData && this.releaseData.totalItems > 0;
    }

    get isEmpty() {
        return this.releaseData && this.releaseData.totalItems === 0;
    }

    get summaryLine() {
        if (!this.releaseData) {
            return '';
        }
        return `${this.releaseData.totalItems} items completed`;
    }
}
