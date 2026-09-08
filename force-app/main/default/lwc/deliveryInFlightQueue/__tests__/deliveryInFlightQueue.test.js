/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryInFlightQueue: wire-driven rows in
 *               the order the controller returns them (stage, developer
 *               fallback, approved-hours fallback, time in stage), the
 *               headline count, the "Open full report" button enabled by the
 *               resolved report id, the empty state, and the wire error state. The card is read-only,
 *               so there are no mutation flows to cover.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryInFlightQueue from "c/deliveryInFlightQueue";
import getInFlightItems from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getInFlightItems";
import getInFlightReportId from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getInFlightReportId";

const ITEM_ONE = "a42000000000001AAA";
const ITEM_TWO = "a42000000000002AAA";

function sampleItems() {
    return [
        {
            workItemId: ITEM_ONE,
            name: "T-0363",
            briefDescription: "Risk Portfolio 1: Active Loans Amount",
            stage: "Ready for Development",
            stageRank: 0,
            stageEnteredAt: new Date(Date.now() - 5 * 86400000).toISOString(),
            developerName: "Dana Dev",
            developerId: "005000000000001AAA",
            approvedHours: 40
        },
        {
            workItemId: ITEM_TWO,
            name: "T-0364",
            briefDescription: null,
            stage: "Ready for Deployment",
            stageRank: 18,
            stageEnteredAt: new Date().toISOString(),
            developerName: null,
            developerId: null,
            approvedHours: null
        }
    ];
}

function createComponent() {
    const element = createElement("c-delivery-in-flight-queue", {
        is: DeliveryInFlightQueue
    });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function findButtonByLabel(element, label) {
    return Array.from(element.shadowRoot.querySelectorAll("lightning-button")).find(
        (b) => b.label === label
    );
}

describe("c-delivery-in-flight-queue", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders rows in controller order with stage, developer and hours fallbacks", async () => {
        const element = createComponent();
        getInFlightItems.emit(sampleItems());
        await flushPromises();

        const rows = element.shadowRoot.querySelectorAll(".queue-row");
        expect(rows.length).toBe(2);
        expect(rows[0].textContent).toContain("T-0363");
        expect(rows[1].textContent).toContain("T-0364");

        const text = element.shadowRoot.textContent;
        expect(text).toContain("Risk Portfolio 1: Active Loans Amount");
        expect(text).toContain("Ready for Development");
        expect(text).toContain("Ready for Deployment");
        expect(text).toContain("Dana Dev");
        expect(text).toContain("Unassigned"); // developerName null fallback
        expect(text).toContain("40h approved");
        expect(text).toContain("no approved hours"); // approvedHours null fallback
        expect(text).toContain("in stage 5 days");
        expect(text).toContain("in stage since today");
        expect(text).toContain("2 items in flight");
    });

    it("has no checkboxes or mutation buttons: the card is read-only", async () => {
        const element = createComponent();
        getInFlightItems.emit(sampleItems());
        await flushPromises();

        expect(element.shadowRoot.querySelectorAll("lightning-input").length).toBe(0);
        const labels = Array.from(element.shadowRoot.querySelectorAll("lightning-button")).map((b) => b.label);
        expect(labels).toEqual(["Open full report"]);
    });

    it("disables Open full report until a report id resolves", async () => {
        const element = createComponent();
        getInFlightItems.emit(sampleItems());
        await flushPromises();

        let reportButton = findButtonByLabel(element, "Open full report");
        expect(reportButton).toBeTruthy();
        expect(reportButton.disabled).toBe(true);

        getInFlightReportId.emit("00O000000000001EAA");
        await flushPromises();

        reportButton = findButtonByLabel(element, "Open full report");
        expect(reportButton.disabled).toBe(false);
    });


    it("shows the empty state when nothing is in flight", async () => {
        const element = createComponent();
        getInFlightItems.emit([]);
        await flushPromises();

        expect(element.shadowRoot.querySelector(".queue-empty")).toBeTruthy();
        expect(element.shadowRoot.textContent).toContain("Nothing in flight");
        expect(element.shadowRoot.querySelectorAll(".queue-row").length).toBe(0);
    });

    it("shows an error when the wire errors", async () => {
        const element = createComponent();
        getInFlightItems.error({ message: "boom" });
        await flushPromises();

        const error = element.shadowRoot.querySelector(".queue-error");
        expect(error).toBeTruthy();
        expect(error.textContent).toContain("boom");
    });
});
