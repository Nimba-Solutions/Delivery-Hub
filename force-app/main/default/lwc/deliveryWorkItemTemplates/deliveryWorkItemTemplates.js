/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Template browser and cloner for work item templates.
 * Displays available templates grouped by workflow type and allows
 * creating new work items from templates with optional field overrides.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import getTemplates from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryRecurringItemService.getTemplates";
import cloneFromTemplate from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryRecurringItemService.cloneFromTemplate";

const PRIORITY_VARIANTS = {
    High: "slds-badge slds-theme_error",
    Medium: "slds-badge slds-theme_warning",
    Low: "slds-badge slds-theme_success"
};

export default class DeliveryWorkItemTemplates extends NavigationMixin(LightningElement) {
    @track templates = [];
    @track groupedTemplates = [];
    @track selectedTemplate = null;
    @track showCloneModal = false;
    @track isCloning = false;

    // Override fields for the clone modal
    @track overrideTitle = "";
    @track overridePriority = "";
    @track overrideTags = "";

    @wire(getTemplates)
    wiredTemplates({ data, error }) {
        if (data) {
            this.templates = data.map((t) => ({
                ...t,
                priorityClass: PRIORITY_VARIANTS[t.PriorityPk__c] || "slds-badge",
                descriptionPreview: t.DetailsTxt__c
                    ? t.DetailsTxt__c.replace(/<[^>]*>/g, "").substring(0, 120) +
                      (t.DetailsTxt__c.length > 120 ? "..." : "")
                    : "No description",
                tagList: t.Tags__c
                    ? t.Tags__c.split(",").map((tag) => tag.trim())
                    : [],
                hasEstimate:
                    t.EstimatedHoursNumber__c != null ||
                    t.DeveloperDaysSizeNumber__c != null,
                estimateLabel: this._buildEstimateLabel(t)
            }));
            this._groupByWorkflow();
        } else if (error) {
            console.error("Error loading templates:", error);
        }
    }

    get hasTemplates() {
        return this.groupedTemplates.length > 0;
    }

    get priorityOptions() {
        return [
            { label: "-- Keep Template Default --", value: "" },
            { label: "High", value: "High" },
            { label: "Medium", value: "Medium" },
            { label: "Low", value: "Low" }
        ];
    }

    // ---- Event Handlers ----

    handleUseTemplate(event) {
        const templateId = event.currentTarget.dataset.id;
        this.selectedTemplate = this.templates.find((t) => t.Id === templateId);
        this.overrideTitle = "";
        this.overridePriority = "";
        this.overrideTags = "";
        this.showCloneModal = true;
    }

    handleOverrideTitleChange(event) {
        this.overrideTitle = event.detail.value;
    }

    handleOverridePriorityChange(event) {
        this.overridePriority = event.detail.value;
    }

    handleOverrideTagsChange(event) {
        this.overrideTitle = event.detail.value;
    }

    handleTagsChange(event) {
        this.overrideTags = event.detail.value;
    }

    handleCloneCancel() {
        this.showCloneModal = false;
        this.selectedTemplate = null;
    }

    async handleCloneConfirm() {
        if (!this.selectedTemplate) return;

        this.isCloning = true;
        try {
            const overrides = {};
            if (this.overrideTitle) {
                overrides.BriefDescriptionTxt__c = this.overrideTitle;
            }
            if (this.overridePriority) {
                overrides.PriorityPk__c = this.overridePriority;
            }
            if (this.overrideTags) {
                overrides.Tags__c = this.overrideTags;
            }

            const newId = await cloneFromTemplate({
                templateId: this.selectedTemplate.Id,
                overrides: Object.keys(overrides).length > 0 ? overrides : null
            });

            this.showCloneModal = false;
            this.selectedTemplate = null;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: "Work item created from template.",
                    variant: "success"
                })
            );

            // Navigate to the new record
            this[NavigationMixin.Navigate]({
                type: "standard__recordPage",
                attributes: {
                    recordId: newId,
                    objectApiName: "WorkItem__c",
                    actionName: "view"
                }
            });
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message:
                        error.body?.message ||
                        error.message ||
                        "Failed to create from template.",
                    variant: "error"
                })
            );
        } finally {
            this.isCloning = false;
        }
    }

    // ---- Private Helpers ----

    _buildEstimateLabel(t) {
        const parts = [];
        if (t.EstimatedHoursNumber__c != null) {
            parts.push(t.EstimatedHoursNumber__c + "h");
        }
        if (t.DeveloperDaysSizeNumber__c != null) {
            parts.push(t.DeveloperDaysSizeNumber__c + "d");
        }
        return parts.join(" / ") || "";
    }

    _groupByWorkflow() {
        const groups = {};
        this.templates.forEach((t) => {
            const wf = t.WorkflowTypeTxt__c || "Uncategorized";
            if (!groups[wf]) {
                groups[wf] = { workflowType: wf, label: wf.replace(/_/g, " "), items: [] };
            }
            groups[wf].items.push(t);
        });
        this.groupedTemplates = Object.values(groups);
    }
}
