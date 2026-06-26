/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryCloseOutQueue: wire-driven rows
 *               (name, brief, waiting age, developer fallback), the headline
 *               count, the "Open full report" button enabled/disabled by the
 *               resolved report id, the bulk + per-row Mark Done flows
 *               (markDone call shape, success + partial-failure toasts), and
 *               the caught-up empty state.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryCloseOutQueue from "c/deliveryCloseOutQueue";
import getCloseOutItems from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getCloseOutItems";
import getCloseOutReportId from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getCloseOutReportId";
import markDone from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.markDone";

const ITEM_ONE = "a42000000000001AAA";
const ITEM_TWO = "a42000000000002AAA";

function sampleItems() {
    return [
        {
            workItemId: ITEM_ONE,
            name: "T-0041",
            briefDescription: "Stripe webhook close-out",
            stageEnteredAt: new Date(Date.now() - 5 * 86400000).toISOString(),
            developerName: "Dana Dev",
            developerId: "005000000000001AAA"
        },
        {
            workItemId: ITEM_TWO,
            name: "T-0042",
            briefDescription: null,
            stageEnteredAt: new Date().toISOString(),
            developerName: null,
            developerId: null
        }
    ];
}

function createComponent() {
    const element = createElement("c-delivery-close-out-queue", {
        is: DeliveryCloseOutQueue
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

function findInputByLabel(element, label) {
    return Array.from(element.shadowRoot.querySelectorAll("lightning-input")).find(
        (i) => i.label === label
    );
}

function setCheckbox(input, checked) {
    input.checked = checked;
    input.dispatchEvent(new CustomEvent("change"));
}

describe("c-delivery-close-out-queue", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders rows with name, brief, developer fallback, and headline", async () => {
        const element = createComponent();
        getCloseOutItems.emit(sampleItems());
        await flushPromises();

        const rows = element.shadowRoot.querySelectorAll(".queue-row");
        expect(rows.length).toBe(2);

        const text = element.shadowRoot.textContent;
        expect(text).toContain("T-0041");
        expect(text).toContain("Stripe webhook close-out");
        expect(text).toContain("Dana Dev");
        expect(text).toContain("Unassigned"); // developerName null fallback
        expect(text).toContain("2 deployed items, awaiting your verification");
    });

    it("disables Open full report until a report id resolves", async () => {
        const element = createComponent();
        getCloseOutItems.emit(sampleItems());
        await flushPromises();

        let reportButton = findButtonByLabel(element, "Open full report");
        expect(reportButton).toBeTruthy();
        expect(reportButton.disabled).toBe(true);

        getCloseOutReportId.emit("00O000000000001EAA");
        await flushPromises();

        reportButton = findButtonByLabel(element, "Open full report");
        expect(reportButton.disabled).toBe(false);
    });

    it("selection toggles drive the bulk button label and disabled state", async () => {
        const element = createComponent();
        getCloseOutItems.emit(sampleItems());
        await flushPromises();

        let bulkButton = findButtonByLabel(element, "Mark Done (0)");
        expect(bulkButton).toBeTruthy();
        expect(bulkButton.disabled).toBe(true);

        setCheckbox(findInputByLabel(element, "Select item"), true);
        await flushPromises();

        bulkButton = findButtonByLabel(element, "Mark Done (1)");
        expect(bulkButton).toBeTruthy();
        expect(bulkButton.disabled).toBe(false);

        setCheckbox(findInputByLabel(element, "Select all"), true);
        await flushPromises();
        expect(findButtonByLabel(element, "Mark Done (2)")).toBeTruthy();
    });

    it("bulk Mark Done calls apex with the selected ids and toasts the success count", async () => {
        markDone.mockResolvedValue({
            succeededIds: [ITEM_ONE, ITEM_TWO],
            failures: [],
            succeededCount: 2,
            failedCount: 0
        });
        const element = createComponent();
        const toastHandler = jest.fn();
        element.addEventListener("lightning__showtoast", toastHandler);

        getCloseOutItems.emit(sampleItems());
        await flushPromises();

        setCheckbox(findInputByLabel(element, "Select all"), true);
        await flushPromises();

        findButtonByLabel(element, "Mark Done (2)").dispatchEvent(new CustomEvent("click"));
        await flushPromises();
        await flushPromises();

        expect(markDone).toHaveBeenCalledWith({ workItemIds: [ITEM_ONE, ITEM_TWO] });
        const toastDetail = toastHandler.mock.calls[0][0].detail;
        expect(toastDetail.variant).toBe("success");
        expect(toastDetail.message).toContain("2 items closed out");
    });

    it("per-row Mark Done calls apex with just that row and warns on partial failure", async () => {
        markDone.mockResolvedValue({
            succeededIds: [ITEM_ONE],
            failures: [{ workItemId: ITEM_TWO, error: "x" }],
            succeededCount: 1,
            failedCount: 1
        });
        const element = createComponent();
        const toastHandler = jest.fn();
        element.addEventListener("lightning__showtoast", toastHandler);

        getCloseOutItems.emit(sampleItems());
        await flushPromises();

        findButtonByLabel(element, "Mark Done").dispatchEvent(new CustomEvent("click"));
        await flushPromises();
        await flushPromises();

        expect(markDone).toHaveBeenCalledWith({ workItemIds: [ITEM_ONE] });
        const toastDetail = toastHandler.mock.calls[0][0].detail;
        expect(toastDetail.variant).toBe("warning");
        expect(toastDetail.message).toContain("1 closed out, 1 failed");
    });

    it("shows the caught-up empty state when nothing is awaiting close-out", async () => {
        const element = createComponent();
        getCloseOutItems.emit([]);
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("Nothing awaiting close-out");
        expect(element.shadowRoot.querySelector(".queue-row")).toBeNull();
    });

    it("shows an error when the wire errors", async () => {
        const element = createComponent();
        getCloseOutItems.error();
        await flushPromises();

        expect(element.shadowRoot.querySelector(".queue-error")).not.toBeNull();
    });
});
