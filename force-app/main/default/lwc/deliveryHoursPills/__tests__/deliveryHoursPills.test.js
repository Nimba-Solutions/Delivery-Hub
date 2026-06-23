/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Regression coverage for deliveryHoursPills. Anchors the
 *               divide-by-zero guard: with an estimate set but zero hours
 *               logged, the On-Budget pill must show a neutral "—" placeholder
 *               — NOT the ~8,000,000% ("Infinity"-looking) figure the old
 *               `estimated / (logged || 0.0001)` hack produced on MF prod.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryHoursPills from "c/deliveryHoursPills";
import { getRecord } from "lightning/uiRecordApi";

jest.mock(
    "lightning/uiRecordApi",
    () => {
        const { createTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
        // The component's field tokens may resolve (via the repo's schema mock)
        // to either a bare string ("Obj__c.Field__c") or a { fieldApiName }
        // object. Normalize to the bare field API name so lookups hold either
        // way, then read from a flat map the test supplies.
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

async function mountWith({ estimated, logged, eta, endDev = null, stage = "In Progress" }) {
    const element = createElement("c-delivery-hours-pills", { is: DeliveryHoursPills });
    element.recordId = "a00000000000001AAA";
    document.body.appendChild(element);
    const fields = {
        EstimatedHoursNumber__c: estimated,
        TotalLoggedHoursSum__c: logged,
        CalculatedETADate__c: eta,
        EstimatedEndDevDate__c: endDev,
        StageNamePk__c: stage
    };
    // getRecord (an LDS adapter) delivers a { data, error } envelope.
    getRecord.emit({ data: { fields }, error: undefined });
    await flushPromises();
    return element;
}

function badgeTexts(element) {
    return Array.from(element.shadowRoot.querySelectorAll(".pill-badge")).map((n) =>
        n.textContent.trim()
    );
}

describe("c-delivery-hours-pills", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("shows 0% (not Infinity / a huge %) when hours logged is 0", async () => {
        const element = await mountWith({ estimated: 8, logged: 0, eta: "2099-01-01" });
        const [onBudget] = badgeTexts(element);
        expect(onBudget).toBe("0%"); // 0 logged / 8 estimated = 0% of budget used
        expect(onBudget).not.toMatch(/infinity/i);
        expect(onBudget).not.toMatch(/\d{4,}/); // no runaway 8,000,000% style number
    });

    it("computes On-Budget percent when hours are logged", async () => {
        const element = await mountWith({ estimated: 8, logged: 8, eta: "2099-01-01" });
        const [onBudget] = badgeTexts(element);
        expect(onBudget).toBe("100%");
    });

    it("flags over-budget when logged exceeds estimate", async () => {
        const element = await mountWith({ estimated: 4, logged: 8, eta: "2099-01-01" });
        const [onBudget] = badgeTexts(element);
        expect(onBudget).toBe("200%"); // 8 logged / 4 estimated = 200% of budget used
    });

    it("shows a neutral placeholder when no estimate is set", async () => {
        const element = await mountWith({ estimated: 0, logged: 0, eta: "2099-01-01" });
        const [onBudget] = badgeTexts(element);
        expect(onBudget).toBe("—");
    });

    it("guards an invalid ETA date on the On-Schedule pill", async () => {
        const element = await mountWith({ estimated: 8, logged: 4, eta: "not-a-date" });
        const onSchedule = badgeTexts(element)[1];
        expect(onSchedule).toBe("—");
    });
});
