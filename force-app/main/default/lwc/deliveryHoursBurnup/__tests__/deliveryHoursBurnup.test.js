/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Mount coverage for deliveryHoursBurnup: empty state when no ceiling,
 *               a rendered bar with a ceiling line when hours exist, and the red
 *               over-cap band surfacing when logged exceeds the approved cap. The
 *               geometry math itself is covered in burnupModel.test.js.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryHoursBurnup from "c/deliveryHoursBurnup";
import { getRecord } from "lightning/uiRecordApi";

jest.mock(
    "lightning/uiRecordApi",
    () => {
        const { createTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
        const bareName = (field) => {
            if (typeof field === "string") {
                const parts = field.split(".");
                return parts[parts.length - 1];
            }
            return field && field.fieldApiName;
        };
        return {
            getRecord: createTestWireAdapter(jest.fn()),
            getFieldValue: (record, field) =>
                record && record.fields ? record.fields[bareName(field)] : undefined
        };
    },
    { virtual: true }
);

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

async function mountWith({ estimated, approved, logged }) {
    const element = createElement("c-delivery-hours-burnup", { is: DeliveryHoursBurnup });
    element.recordId = "a00000000000001AAA";
    document.body.appendChild(element);
    getRecord.emit({
        data: {
            fields: {
                EstimatedHoursNumber__c: estimated,
                ClientPreApprovedHoursNumber__c: approved,
                TotalLoggedHoursSum__c: logged
            }
        },
        error: undefined
    });
    await flushPromises();
    return element;
}

describe("c-delivery-hours-burnup", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("shows the empty state when no ceiling is set", async () => {
        const element = await mountWith({ estimated: 0, approved: 0, logged: 0 });
        expect(element.shadowRoot.querySelector(".bu-track")).toBeNull();
        expect(element.shadowRoot.textContent).toMatch(/No ceiling set yet/i);
    });

    it("renders a bar with a ceiling line when hours exist", async () => {
        const element = await mountWith({ estimated: 8, approved: 10, logged: 4 });
        expect(element.shadowRoot.querySelector(".bu-track")).not.toBeNull();
        expect(element.shadowRoot.querySelector(".bu-ceiling")).not.toBeNull();
        expect(element.shadowRoot.querySelector(".burnup--healthy")).not.toBeNull();
    });

    it("surfaces the red over-cap band and over-cap state when logged exceeds the cap", async () => {
        const element = await mountWith({ estimated: 4, approved: 4, logged: 8 });
        expect(element.shadowRoot.querySelector(".burnup--over")).not.toBeNull();
        const over = element.shadowRoot.querySelector(".bu-fill_over");
        expect(over.style.width).not.toBe("0%");
    });
});
