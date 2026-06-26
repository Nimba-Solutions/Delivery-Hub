/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Close-out queue card for the workspace "Close Outs" tab — the
 *               back of the pipeline. Wires
 *               DeliveryTriageController.getCloseOutItems and renders each
 *               WorkItem sitting in 'Deployed to Prod' awaiting the triager's
 *               verification, with row checkboxes + select-all feeding a bulk
 *               "Mark Done (N)" action and a per-row "Mark Done", both calling
 *               DeliveryTriageController.markDone imperatively (mutations are
 *               non-cacheable, never @wired). After any decision the wire is
 *               refreshed and a toast confirms the outcome using OUR labels
 *               (AuraHandledException messages come back generic inside the
 *               managed package). A header "Open full report" button links to
 *               the Deployed-to-Prod-Awaiting-Verification report via the id
 *               the controller resolves by DeveloperName (namespace-safe); the
 *               button is disabled when the report is absent in the org.
 *               Clicking an item name navigates to the WorkItem__c record via
 *               NavigationMixin + @salesforce/schema so the object API name
 *               stays namespace-safe.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import WORK_ITEM_OBJECT from "@salesforce/schema/WorkItem__c";
import getCloseOutItems from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getCloseOutItems";
import getCloseOutReportId from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getCloseOutReportId";
import markDoneApex from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.markDone";

const MS_PER_DAY = 86400000;

export default class DeliveryCloseOutQueue extends NavigationMixin(LightningElement) {
    itemsRaw = [];
    errorMessage = "";
    isLoading = true;
    isSaving = false;
    reportId = "";

    // Work item ids ticked for "Mark Done".
    selectedIds = [];

    wiredResult;

    @wire(getCloseOutItems)
    wiredItems(result) {
        this.wiredResult = result;
        if (result.data) {
            this.itemsRaw = result.data;
            this.errorMessage = "";
            this.isLoading = false;
        } else if (result.error) {
            this.errorMessage = this._errorText(result.error, "Unable to load the close-out queue.");
            this.itemsRaw = [];
            this.isLoading = false;
        }
    }

    @wire(getCloseOutReportId)
    wiredReportId({ data }) {
        if (data) {
            this.reportId = data;
        }
    }

    // ── Row shaping (templates can't do ternaries — precompute) ──

    get rows() {
        return this.itemsRaw.map((dto) => ({
            key: dto.workItemId,
            workItemId: dto.workItemId,
            name: dto.name || "(unnamed item)",
            briefDescription: dto.briefDescription || "",
            hasBrief: Boolean(dto.briefDescription),
            waitingDisplay: this._ageDisplay(dto.stageEnteredAt),
            developerDisplay: dto.developerName || "Unassigned",
            isSelected: this.selectedIds.includes(dto.workItemId)
        }));
    }

    // ── State flags ──────────────────────────────────────────────

    get hasRows() {
        return !this.isLoading && !this.errorMessage && this.itemsRaw.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && this.itemsRaw.length === 0;
    }

    get hasError() {
        return !this.isLoading && this.errorMessage.length > 0;
    }

    get hasReport() {
        return Boolean(this.reportId);
    }

    get hasNoReport() {
        return !this.reportId;
    }

    // ── Headline + bulk state ────────────────────────────────────

    get headlineDisplay() {
        const n = this.itemsRaw.length;
        const noun = n === 1 ? "item" : "items";
        return `${n} deployed ${noun}, awaiting your verification`;
    }

    get selectedCount() {
        return this._selectedPresentIds().length;
    }

    get bulkDoneLabel() {
        return `Mark Done (${this.selectedCount})`;
    }

    get isBulkDoneDisabled() {
        return this.isSaving || this.selectedCount === 0;
    }

    get isAllSelected() {
        return this.itemsRaw.length > 0 && this.selectedCount === this.itemsRaw.length;
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

    handleOpenReport() {
        if (!this.reportId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.reportId,
                objectApiName: "Report",
                actionName: "view"
            }
        });
    }

    // ── Selection ────────────────────────────────────────────────

    handleRowSelect(event) {
        const workItemId = event.target.dataset.workItemId;
        if (!workItemId) {
            return;
        }
        const next = this.selectedIds.filter((id) => id !== workItemId);
        if (event.target.checked) {
            next.push(workItemId);
        }
        this.selectedIds = next;
    }

    handleSelectAll(event) {
        this.selectedIds = event.target.checked
            ? this.itemsRaw.map((dto) => dto.workItemId)
            : [];
    }

    // ── Mark Done ────────────────────────────────────────────────

    handleBulkDone() {
        this._markDoneIds(this._selectedPresentIds());
    }

    handleRowDone(event) {
        const workItemId = event.currentTarget.dataset.workItemId;
        if (!workItemId) {
            return;
        }
        this._markDoneIds([workItemId]);
    }

    handleRefresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    _markDoneIds(ids) {
        if (ids.length === 0 || this.isSaving) {
            return;
        }
        this.isSaving = true;
        markDoneApex({ workItemIds: ids })
            .then((result) => {
                this.isSaving = false;
                this.selectedIds = [];
                this._toastBulkOutcome(result, "closed out", "Marked done");
                return refreshApex(this.wiredResult);
            })
            .catch((err) => {
                this.isSaving = false;
                this._toast(
                    "Mark done failed",
                    this._errorText(err, "The selected items could not be closed out."),
                    "error"
                );
            });
    }

    // ── Internals ────────────────────────────────────────────────

    _selectedPresentIds() {
        const present = new Set(this.itemsRaw.map((dto) => dto.workItemId));
        return this.selectedIds.filter((id) => present.has(id));
    }

    _toastBulkOutcome(result, verb, successTitle) {
        const succeeded = result && result.succeededCount ? result.succeededCount : 0;
        const failed = result && result.failedCount ? result.failedCount : 0;
        if (failed === 0) {
            const noun = succeeded === 1 ? "item" : "items";
            this._toast(successTitle, `${succeeded} ${noun} ${verb}.`, "success");
        } else if (succeeded === 0) {
            this._toast(`${successTitle} failed`, `0 ${verb}, ${failed} failed.`, "error");
        } else {
            this._toast("Partially complete", `${succeeded} ${verb}, ${failed} failed.`, "warning");
        }
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _errorText(err, fallback) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        return fallback;
    }

    _ageDisplay(stageEnteredAt) {
        if (!stageEnteredAt) {
            return "waiting";
        }
        const entered = new Date(stageEnteredAt).getTime();
        if (!Number.isFinite(entered)) {
            return "waiting";
        }
        const days = Math.max(0, Math.floor((Date.now() - entered) / MS_PER_DAY));
        if (days === 0) {
            return "waiting since today";
        }
        if (days === 1) {
            return "waiting 1 day";
        }
        return `waiting ${days} days`;
    }
}
