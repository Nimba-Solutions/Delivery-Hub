/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Portal work item detail component for Experience Cloud.
 * Shows status progress bar, details, comment thread with add-comment input, and file info.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track } from 'lwc';
import getPortalWorkItemDetail from '@salesforce/apex/DeliveryPortalController.getPortalWorkItemDetail';
import addPortalComment from '@salesforce/apex/DeliveryPortalController.addPortalComment';

const STAGE_COLORS = {
    'Backlog': '#6b7280',
    'Scoping In Progress': '#6366f1',
    'Ready for Sizing': '#8b5cf6',
    'Ready for Development': '#3b82f6',
    'In Development': '#0070d2',
    'Ready for QA': '#06b6d4',
    'QA In Progress': '#14b8a6',
    'Ready for Client UAT': '#dd7a01',
    'In Client UAT': '#f59e0b',
    'Ready for Deployment': '#10b981',
    'Deploying': '#059669',
    'Done': '#2e844a'
};

const PRIORITY_COLORS = {
    'Critical': '#ea001e',
    'High': '#dd7a01',
    'Medium': '#0070d2',
    'Low': '#6b7280'
};

export default class DeliveryPortalWorkItemDetail extends LightningElement {
    @api workItemId;
    @api networkEntityId;

    @track detail;
    @track error;
    @track isLoading = true;
    @track newComment = '';
    @track isSubmittingComment = false;
    @track commentSuccess = false;

    connectedCallback() {
        this.loadDetail();
    }

    loadDetail() {
        this.isLoading = true;
        getPortalWorkItemDetail({ workItemId: this.workItemId })
            .then(data => {
                this.detail = data;
                this.error = undefined;
            })
            .catch(err => {
                this.error = this.reduceError(err);
                this.detail = undefined;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasDetail() {
        return this.detail != null;
    }

    get title() { return this.detail ? this.detail.title : ''; }
    get itemName() { return this.detail ? this.detail.name : ''; }
    get stage() { return this.detail ? this.detail.stage : ''; }
    get priority() { return this.detail ? this.detail.priority : ''; }
    get description() { return this.detail ? this.detail.description : ''; }
    get requestType() { return this.detail ? this.detail.requestType : ''; }
    get fileCount() { return this.detail ? this.detail.fileCount : 0; }
    get estimatedDays() { return this.detail ? this.detail.estimatedDays : null; }
    get estimatedHours() { return this.detail ? this.detail.estimatedHours : null; }
    get loggedHours() { return this.detail ? this.detail.loggedHours : null; }

    get hasDescription() { return !!this.description; }
    get hasPriority() { return !!this.priority; }
    get hasRequestType() { return !!this.requestType; }
    get hasFiles() { return this.fileCount > 0; }
    get hasEstimatedDays() { return this.estimatedDays != null && this.estimatedDays > 0; }
    get hasEstimatedHours() { return this.estimatedHours != null && this.estimatedHours > 0; }
    get hasLoggedHours() { return this.loggedHours != null && this.loggedHours > 0; }

    get formattedCreatedDate() {
        if (!this.detail || !this.detail.createdDate) return '';
        return this.formatDate(this.detail.createdDate);
    }

    get formattedLastModified() {
        if (!this.detail || !this.detail.lastModified) return '';
        return this.formatDate(this.detail.lastModified);
    }

    get formattedEta() {
        if (!this.detail || !this.detail.eta) return '';
        const d = new Date(this.detail.eta);
        return d.toLocaleDateString(undefined, { month: 'long', day: 'numeric', year: 'numeric' });
    }

    get hasEta() {
        return this.detail && this.detail.eta;
    }

    get fileCountLabel() {
        const n = this.fileCount;
        return `${n} file${n === 1 ? '' : 's'} attached`;
    }

    get stageBadgeStyle() {
        const color = STAGE_COLORS[this.stage] || '#6b7280';
        return `background-color: ${color}; color: #ffffff; padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.8rem; font-weight: 600; display: inline-block;`;
    }

    get priorityBadgeStyle() {
        const color = PRIORITY_COLORS[this.priority] || '#6b7280';
        return `background-color: ${color}15; color: ${color}; border: 1px solid ${color}40; padding: 0.2rem 0.6rem; border-radius: 12px; font-size: 0.75rem; font-weight: 600; display: inline-block;`;
    }

    // Stage progress pipeline
    get stageSteps() {
        if (!this.detail || !this.detail.stages) return [];
        const currentStage = this.stage;
        const stages = this.detail.stages;
        let currentIndex = stages.indexOf(currentStage);
        // If current stage is not in the simplified list, find the closest match
        if (currentIndex === -1) {
            // Find which stage is closest based on position in the workflow
            currentIndex = -1;
        }

        return stages.map((s, idx) => {
            let stepClass = 'portal-step';
            if (currentIndex >= 0 && idx < currentIndex) {
                stepClass += ' portal-step-completed';
            } else if (idx === currentIndex) {
                stepClass += ' portal-step-current';
            } else {
                stepClass += ' portal-step-upcoming';
            }
            return {
                label: s,
                stepClass,
                isCurrent: idx === currentIndex,
                key: s
            };
        });
    }

    // Comments
    get comments() {
        if (!this.detail || !this.detail.comments) return [];
        return this.detail.comments.map(c => ({
            ...c,
            formattedDate: this.formatDate(c.createdDate),
            isPortalComment: c.source === 'Client',
            avatarInitial: c.author ? c.author.charAt(0).toUpperCase() : '?',
            commentClass: c.source === 'Client' ? 'portal-comment portal-comment-client' : 'portal-comment'
        }));
    }

    get hasComments() {
        return this.comments.length > 0;
    }

    get commentCount() {
        return this.comments.length;
    }

    // Handlers
    handleBackToList() {
        this.dispatchEvent(new CustomEvent('navigateto', {
            detail: { target: 'workItemList', networkEntityId: this.networkEntityId }
        }));
    }

    handleCommentInput(event) {
        this.newComment = event.target.value;
        this.commentSuccess = false;
    }

    handleSubmitComment() {
        if (!this.newComment || !this.newComment.trim()) return;

        this.isSubmittingComment = true;
        this.commentSuccess = false;

        addPortalComment({ workItemId: this.workItemId, commentBody: this.newComment.trim() })
            .then(() => {
                this.newComment = '';
                this.commentSuccess = true;
                // Reload detail to show the new comment
                this.loadDetail();
            })
            .catch(err => {
                this.error = this.reduceError(err);
            })
            .finally(() => {
                this.isSubmittingComment = false;
            });
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        return d.toLocaleDateString(undefined, {
            month: 'short', day: 'numeric', year: 'numeric',
            hour: 'numeric', minute: '2-digit'
        });
    }

    reduceError(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'An unknown error occurred.';
    }
}
