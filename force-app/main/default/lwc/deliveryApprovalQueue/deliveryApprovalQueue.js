/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Pending work-approval queue card for DH Home (PR2 of the
 *               work-approval queue). Wires
 *               DeliveryWorkApprovalService.getPendingForApprover and renders
 *               each Offer-Sent WorkRequest__c with inline Approve /
 *               Approve-with-change / Decline actions. After any decision the
 *               wire is refreshed and a toast confirms the outcome using OUR
 *               labels (AuraHandledException messages come back generic inside
 *               the managed package). Clicking the item name navigates to the
 *               WorkItem__c record via NavigationMixin + @salesforce/schema so
 *               the object API name stays namespace-safe.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import WORK_ITEM_OBJECT from "@salesforce/schema/WorkItem__c";
import getPendingForApprover from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkApprovalService.getPendingForApprover";
import approveApex from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkApprovalService.approve";
import declineApex from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkApprovalService.decline";

const MS_PER_DAY = 86400000;
const MODE_CHANGE = "change";
const MODE_DECLINE = "decline";

export default class DeliveryApprovalQueue extends NavigationMixin(LightningElement) {
    pendingRaw = [];
    errorMessage = "";
    isLoading = true;
    isSaving = false;

    // One inline panel open at a time: the row + which panel.
    activeRequestId = null;
    activeMode = "";
    draftHours = null;
    draftNote = "";
    draftReason = "";

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
            return {
                key: dto.requestId,
                workItemId: dto.workItemId,
                label: dto.workItemLabel || dto.workItemName || "(unnamed item)",
                quotedDisplay: `${this._formatHours(dto.quotedHours)}h quoted`,
                hasIncrease: dto.requestedIncrease > 0,
                increaseBadge: `increase +${this._formatHours(dto.requestedIncrease)}h`,
                ageDisplay: this._ageDisplay(dto.submittedAt),
                isChangeOpen: isActive && this.activeMode === MODE_CHANGE,
                isDeclineOpen: isActive && this.activeMode === MODE_DECLINE
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

    // ── Internals ────────────────────────────────────────────────

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
