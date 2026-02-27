/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Record page component for configuring recurring and template settings
 * on a WorkItem__c. Provides toggles for IsRecurringBool__c and IsTemplateBool__c,
 * schedule/day pickers, and read-only next recurrence date display.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue, updateRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import IS_RECURRING_FIELD from "@salesforce/schema/WorkItem__c.IsRecurringBool__c";
import IS_TEMPLATE_FIELD from "@salesforce/schema/WorkItem__c.IsTemplateBool__c";
import RECURRENCE_SCHEDULE_FIELD from "@salesforce/schema/WorkItem__c.RecurrenceScheduleTxt__c";
import RECURRENCE_DAY_FIELD from "@salesforce/schema/WorkItem__c.RecurrenceDayTxt__c";
import NEXT_RECURRENCE_DATE_FIELD from "@salesforce/schema/WorkItem__c.NextRecurrenceDateDt__c";
import TEMPLATE_SOURCE_ID_FIELD from "@salesforce/schema/WorkItem__c.TemplateSourceId__c";
import ID_FIELD from "@salesforce/schema/WorkItem__c.Id";

const FIELDS = [
    IS_RECURRING_FIELD,
    IS_TEMPLATE_FIELD,
    RECURRENCE_SCHEDULE_FIELD,
    RECURRENCE_DAY_FIELD,
    NEXT_RECURRENCE_DATE_FIELD,
    TEMPLATE_SOURCE_ID_FIELD
];

const SCHEDULE_OPTIONS = [
    { label: "Weekly", value: "Weekly" },
    { label: "Biweekly", value: "Biweekly" },
    { label: "Monthly", value: "Monthly" },
    { label: "Quarterly", value: "Quarterly" }
];

const DAY_OF_WEEK_OPTIONS = [
    { label: "Monday", value: "Monday" },
    { label: "Tuesday", value: "Tuesday" },
    { label: "Wednesday", value: "Wednesday" },
    { label: "Thursday", value: "Thursday" },
    { label: "Friday", value: "Friday" },
    { label: "Saturday", value: "Saturday" },
    { label: "Sunday", value: "Sunday" }
];

const DAY_OF_MONTH_OPTIONS = Array.from({ length: 28 }, (_, i) => ({
    label: String(i + 1),
    value: String(i + 1)
}));

export default class DeliveryRecurringConfig extends LightningElement {
    @api recordId;

    isRecurring = false;
    isTemplate = false;
    schedule = "";
    recurrenceDay = "";
    nextRecurrenceDate = null;
    templateSourceId = null;
    isSaving = false;

    scheduleOptions = SCHEDULE_OPTIONS;

    @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            this.isRecurring = getFieldValue(data, IS_RECURRING_FIELD) || false;
            this.isTemplate = getFieldValue(data, IS_TEMPLATE_FIELD) || false;
            this.schedule = getFieldValue(data, RECURRENCE_SCHEDULE_FIELD) || "";
            this.recurrenceDay = getFieldValue(data, RECURRENCE_DAY_FIELD) || "";
            this.nextRecurrenceDate = getFieldValue(data, NEXT_RECURRENCE_DATE_FIELD);
            this.templateSourceId = getFieldValue(data, TEMPLATE_SOURCE_ID_FIELD);
        } else if (error) {
            console.error("Error loading record:", error);
        }
    }

    get showRecurrenceOptions() {
        return this.isRecurring;
    }

    get showDayPicker() {
        return this.isRecurring && this.schedule;
    }

    get dayOptions() {
        if (this.schedule === "Weekly" || this.schedule === "Biweekly") {
            return DAY_OF_WEEK_OPTIONS;
        }
        return DAY_OF_MONTH_OPTIONS;
    }

    get dayPickerLabel() {
        if (this.schedule === "Weekly" || this.schedule === "Biweekly") {
            return "Day of Week";
        }
        return "Day of Month";
    }

    get hasNextRecurrenceDate() {
        return this.nextRecurrenceDate != null;
    }

    get hasTemplateSource() {
        return this.templateSourceId != null && this.templateSourceId !== "";
    }

    get formattedNextDate() {
        if (!this.nextRecurrenceDate) return "";
        return this.nextRecurrenceDate;
    }

    // ---- Event Handlers ----

    handleRecurringToggle(event) {
        this.isRecurring = event.target.checked;
        if (!this.isRecurring) {
            this.schedule = "";
            this.recurrenceDay = "";
        }
    }

    handleTemplateToggle(event) {
        this.isTemplate = event.target.checked;
    }

    handleScheduleChange(event) {
        this.schedule = event.detail.value;
        // Reset day when schedule type changes (day-of-week vs day-of-month)
        this.recurrenceDay = "";
    }

    handleDayChange(event) {
        this.recurrenceDay = event.detail.value;
    }

    async handleSave() {
        this.isSaving = true;
        try {
            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.recordId;
            fields[IS_RECURRING_FIELD.fieldApiName] = this.isRecurring;
            fields[IS_TEMPLATE_FIELD.fieldApiName] = this.isTemplate;
            fields[RECURRENCE_SCHEDULE_FIELD.fieldApiName] = this.schedule || null;
            fields[RECURRENCE_DAY_FIELD.fieldApiName] = this.recurrenceDay || null;

            await updateRecord({ fields });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: "Recurring/template settings saved.",
                    variant: "success"
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: error.body?.message || "Failed to save settings.",
                    variant: "error"
                })
            );
        } finally {
            this.isSaving = false;
        }
    }
}
