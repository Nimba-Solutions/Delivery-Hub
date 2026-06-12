/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Pending work-approval queue card for DH Home (PR2 of the
 *               work-approval queue). Wires
 *               DeliveryWorkApprovalService.getPendingForApprover and renders
 *               each Offer-Sent WorkRequest__c with inline Approve /
 *               Approve-with-change / Decline actions, plus row checkboxes +
 *               select-all feeding a bulk "Approve selected (N)" action
 *               (approveMany — spec §6a) that toasts the approved/failed
 *               counts from BulkApproveResultDTO. After any decision the
 *               wire is refreshed and a toast confirms the outcome using OUR
 *               labels (AuraHandledException messages come back generic inside
 *               the managed package). Clicking the item name navigates to the
 *               WorkItem__c record via NavigationMixin + @salesforce/schema so
 *               the object API name stays namespace-safe. Rows carrying a
 *               latestProposalNote (proposeEstimate's reasoning comment)
 *               expose an expandable "Why this estimate" line under the row
 *               (item 9 — the estimate haggle on the record).
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import WORK_ITEM_OBJECT from "@salesforce/schema/WorkItem__c";
import getPendingForApprover from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkApprovalService.getPendingForApprover";
import approveApex from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkApprovalService.approve";
import approveManyApex from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkApprovalService.approveMany";
import declineApex from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkApprovalService.decline";

const MS_PER_DAY = 86400000;
const MODE_CHANGE = "change";
const MODE_DECLINE = "decline";

export default class DeliveryApprovalQueue extends NavigationMixin(LightningElement) {
    pendingRaw = [];
    errorMessage = "";
    isLoading = true;
    isSaving = false;

    // Bulk selection: request ids ticked for "Approve selected".
    selectedIds = [];

    // One inline panel open at a time: the row + which panel.
    activeRequestId = null;
    activeMode = "";
    draftHours = null;
    draftNote = "";
    draftReason = "";

    // Rows whose "why this estimate" proposal note is expanded.
    expandedNoteIds = [];

    wiredResult;

    @wire(getPendingForApprover, { userId: null })
    wiredPending(result) {
        this.wiredResult = result;
        if (result.data) {
            this.pendingRaw = result.data;
            this.errorMessage = "";
            this.isLoading = false;
        } else if (result.error) {
            this.errorMessage = this._errorText(result.error, "Unable to load the approval queue.");
            this.pendingRaw = [];
            this.isLoading = false;
        }
    }

    // ── Row shaping (templates can't do ternaries — precompute) ──

    get rows() {
        return this.pendingRaw.map((dto) => {
            const isActive = dto.requestId === this.activeRequestId;
            const hasProposalNote = Boolean(dto.latestProposalNote);
            const isProposalOpen = hasProposalNote && this.expandedNoteIds.includes(dto.requestId);
            return {
                key: dto.requestId,
                workItemId: dto.workItemId,
                label: dto.workItemLabel || dto.workItemName || "(unnamed item)",
                quotedDisplay: `${this._formatHours(dto.quotedHours)}h quoted`,
                hasIncrease: dto.requestedIncrease > 0,
                increaseBadge: `increase +${this._formatHours(dto.requestedIncrease)}h`,
                ageDisplay: this._ageDisplay(dto.submittedAt),
                isSelected: this.selectedIds.includes(dto.requestId),
                isChangeOpen: isActive && this.activeMode === MODE_CHANGE,
                isDeclineOpen: isActive && this.activeMode === MODE_DECLINE,
                hasProposalNote,
                isProposalOpen,
                proposalNote: dto.latestProposalNote || "",
                proposalToggleLabel: isProposalOpen
                    ? "Hide why this estimate"
                    : "Why this estimate"
            };
        });
    }

    // ── State flags ──────────────────────────────────────────────

    get hasRows() {
        return !this.isLoading && !this.errorMessage && this.pendingRaw.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && this.pendingRaw.length === 0;
    }

    get hasError() {
        return !this.isLoading && this.errorMessage.length > 0;
    }

    // ── Bulk selection (templates can't do ternaries — getters) ──

    get selectedCount() {
        return this._selectedPendingIds().length;
    }

    get bulkApproveLabel() {
        return `Approve selected (${this.selectedCount})`;
    }

    get isBulkApproveDisabled() {
        return this.isSaving || this.selectedCount === 0;
    }

    get isAllSelected() {
        return this.pendingRaw.length > 0 && this.selectedCount === this.pendingRaw.length;
    }

    // ── Headline numbers ─────────────────────────────────────────

    get pendingCountDisplay() {
        return this.pendingRaw.length;
    }

    get totalQuotedDisplay() {
        let total = 0;
        for (const dto of this.pendingRaw) {
            total += dto.quotedHours || 0;
        }
        return this._formatHours(total);
    }

    // ── Navigation ───────────────────────────────────────────────

    handleItemClick(event) {
        const workItemId = event.currentTarget.dataset.workItemId;
        if (!workItemId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: workItemId,
                objectApiName: WORK_ITEM_OBJECT.objectApiName,
                actionName: "view"
            }
        });
    }

    // ── Bulk selection actions ───────────────────────────────────

    handleRowSelect(event) {
        const requestId = event.target.dataset.requestId;
        if (!requestId) {
            return;
        }
        const next = this.selectedIds.filter((id) => id !== requestId);
        if (event.target.checked) {
            next.push(requestId);
        }
        this.selectedIds = next;
    }

    handleSelectAll(event) {
        this.selectedIds = event.target.checked
            ? this.pendingRaw.map((dto) => dto.requestId)
            : [];
    }

    handleBulkApprove() {
        const ids = this._selectedPendingIds();
        if (ids.length === 0 || this.isSaving) {
            return;
        }
        this.isSaving = true;
        approveManyApex({ workRequestIds: ids, note: null })
            .then((result) => {
                this.isSaving = false;
                this.selectedIds = [];
                this._closeInline();
                this._toastBulkOutcome(result);
                return refreshApex(this.wiredResult);
            })
            .catch((err) => {
                this.isSaving = false;
                this._toast(
                    "Bulk approve failed",
                    this._errorText(err, "The selected requests could not be approved."),
                    "error"
                );
            });
    }

    // ── Decision actions ─────────────────────────────────────────

    handleApprove(event) {
        const requestId = event.currentTarget.dataset.requestId;
        if (!requestId || this.isSaving) {
            return;
        }
        this._decide(
            approveApex({ workRequestId: requestId, approvedHours: null, note: null }),
            "Approved",
            "The request was approved at the quoted hours."
        );
    }

    handleOpenChange(event) {
        this._openInline(event.currentTarget.dataset.requestId, MODE_CHANGE);
    }

    handleOpenDecline(event) {
        this._openInline(event.currentTarget.dataset.requestId, MODE_DECLINE);
    }

    handleCancelInline() {
        this._closeInline();
    }

    handleHoursChange(event) {
        this.draftHours = event.target.value;
    }

    handleNoteChange(event) {
        this.draftNote = event.target.value;
    }

    handleReasonChange(event) {
        this.draftReason = event.target.value;
    }

    handleConfirmChange(event) {
        const requestId = event.currentTarget.dataset.requestId;
        const hours = parseFloat(this.draftHours);
        if (!Number.isFinite(hours) || hours <= 0) {
            this._toast("Enter the approved hours", "Approved hours must be a number greater than zero.", "error");
            return;
        }
        const note = (this.draftNote || "").trim();
        this._decide(
            approveApex({ workRequestId: requestId, approvedHours: hours, note: note.length > 0 ? note : null }),
            "Approved with change",
            `The request was approved at ${this._formatHours(hours)}h.`
        );
    }

    handleConfirmDecline(event) {
        const requestId = event.currentTarget.dataset.requestId;
        const reason = (this.draftReason || "").trim();
        if (reason.length === 0) {
            this._toast("Enter a reason", "A decline reason is required.", "error");
            return;
        }
        this._decide(
            declineApex({ workRequestId: requestId, reason }),
            "Declined",
            "The request was declined."
        );
    }

    handleRefresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    // ── Proposal note ("why this estimate") ──────────────────────

    handleToggleProposalNote(event) {
        const requestId = event.currentTarget.dataset.requestId;
        if (!requestId) {
            return;
        }
        const next = this.expandedNoteIds.filter((id) => id !== requestId);
        if (next.length === this.expandedNoteIds.length) {
            next.push(requestId);
        }
        this.expandedNoteIds = next;
    }

    // ── Internals ────────────────────────────────────────────────

    // Selected ids still present in the pending feed — stale selections
    // (rows decided elsewhere then refreshed away) never reach apex.
    _selectedPendingIds() {
        const pending = new Set(this.pendingRaw.map((dto) => dto.requestId));
        return this.selectedIds.filter((id) => pending.has(id));
    }

    _toastBulkOutcome(result) {
        const approved = result && result.approvedIds ? result.approvedIds.length : 0;
        const failed = result && result.failures ? result.failures.length : 0;
        if (failed === 0) {
            const noun = approved === 1 ? "request" : "requests";
            this._toast(
                "Approved",
                `${approved} ${noun} approved at the quoted hours.`,
                "success"
            );
        } else if (approved === 0) {
            this._toast(
                "Bulk approve failed",
                `0 approved, ${failed} failed.`,
                "error"
            );
        } else {
            this._toast(
                "Partially approved",
                `${approved} approved, ${failed} failed.`,
                "warning"
            );
        }
    }

    _openInline(requestId, mode) {
        if (!requestId) {
            return;
        }
        this.activeRequestId = requestId;
        this.activeMode = mode;
        this.draftHours = null;
        this.draftNote = "";
        this.draftReason = "";
    }

    _closeInline() {
        this.activeRequestId = null;
        this.activeMode = "";
        this.draftHours = null;
        this.draftNote = "";
        this.draftReason = "";
    }

    _decide(apexPromise, successTitle, successMessage) {
        this.isSaving = true;
        apexPromise
            .then(() => {
                this.isSaving = false;
                this._closeInline();
                this._toast(successTitle, successMessage, "success");
                return refreshApex(this.wiredResult);
            })
            .catch((err) => {
                this.isSaving = false;
                this._toast(
                    "Decision failed",
                    this._errorText(err, "The decision could not be recorded."),
                    "error"
                );
            });
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _errorText(err, fallback) {
        // Display-only: managed-package AuraHandledException messages are
        // generic, so never branch on the text — just surface it when present.
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        return fallback;
    }

    _ageDisplay(submittedAt) {
        if (!submittedAt) {
            return "";
        }
        const submitted = new Date(submittedAt).getTime();
        if (!Number.isFinite(submitted)) {
            return "";
        }
        const days = Math.max(0, Math.floor((Date.now() - submitted) / MS_PER_DAY));
        if (days === 0) {
            return "in queue today";
        }
        if (days === 1) {
            return "1 day in queue";
        }
        return `${days} days in queue`;
    }

    _formatHours(value) {
        if (value === null || value === undefined) {
            return "0";
        }
        const num = Number(value);
        if (!Number.isFinite(num)) {
            return "0";
        }
        if (Math.abs(num) >= 100) {
            return num.toFixed(0);
        }
        if (Math.abs(num) >= 10) {
            return num.toFixed(1);
        }
        return num.toFixed(2);
    }
}
