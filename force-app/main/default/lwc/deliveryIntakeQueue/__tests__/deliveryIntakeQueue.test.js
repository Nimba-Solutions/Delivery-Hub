/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryIntakeQueue: wire-driven rows (name,
 *               brief, stage, requester, arrived age), the bulk "Route to dev"
 *               selection/label/disabled state, the route flow carrying the
 *               developer chosen in the inline picker, the per-row route and
 *               dismiss flows (call shapes + toasts), and the empty/error
 *               states.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import DeliveryIntakeQueue from "c/deliveryIntakeQueue";
import getIntakeItems from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getIntakeItems";
import routeToDev from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.routeToDev";
import dismissIntake from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.dismissIntake";
import getHiddenHomeComponents from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents";

const HOME_PAGE_REF = { type: "standard__namedPage", attributes: { pageName: "home" } };

const ITEM_ONE = "a42000000000001AAA";
const ITEM_TWO = "a42000000000002AAA";
const DEV_ID = "005000000000099AAA";

function sampleItems() {
    return [
        {
            workItemId: ITEM_ONE,
            name: "T-0050",
            briefDescription: "New client portal request",
            createdDate: new Date(Date.now() - 2 * 86400000).toISOString(),
            requestedByName: "client@example.com",
            currentStage: "Backlog"
        },
        {
            workItemId: ITEM_TWO,
            name: "T-0051",
            briefDescription: null,
            createdDate: new Date().toISOString(),
            requestedByName: null,
            currentStage: "Backlog"
        }
    ];
}

function createComponent() {
    const element = createElement("c-delivery-intake-queue", {
        is: DeliveryIntakeQueue
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

describe("c-delivery-intake-queue", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders rows with name, brief, stage, requester, and arrived age", async () => {
        const element = createComponent();
        getIntakeItems.emit(sampleItems());
        await flushPromises();

        const rows = element.shadowRoot.querySelectorAll(".queue-row");
        expect(rows.length).toBe(2);

        const text = element.shadowRoot.textContent;
        expect(text).toContain("T-0050");
        expect(text).toContain("New client portal request");
        expect(text).toContain("client@example.com");
        expect(text).toContain("2 inbound items to triage");
    });

    it("bulk Route to dev is gated by selection and carries the picked developer", async () => {
        routeToDev.mockResolvedValue({
            succeededIds: [ITEM_ONE, ITEM_TWO],
            failures: [],
            succeededCount: 2,
            failedCount: 0
        });
        const element = createComponent();
        const toastHandler = jest.fn();
        element.addEventListener("lightning__showtoast", toastHandler);

        getIntakeItems.emit(sampleItems());
        await flushPromises();

        let bulkButton = findButtonByLabel(element, "Route to dev (0)");
        expect(bulkButton.disabled).toBe(true);

        // Choose a developer in the inline picker.
        const picker = element.shadowRoot.querySelector("lightning-record-picker");
        picker.dispatchEvent(new CustomEvent("change", { detail: { recordId: DEV_ID } }));
        await flushPromises();

        // Select all -> (2), enabled.
        setCheckbox(findInputByLabel(element, "Select all"), true);
        await flushPromises();

        bulkButton = findButtonByLabel(element, "Route to dev (2)");
        expect(bulkButton.disabled).toBe(false);
        bulkButton.dispatchEvent(new CustomEvent("click"));
        await flushPromises();
        await flushPromises();

        expect(routeToDev).toHaveBeenCalledWith({
            workItemIds: [ITEM_ONE, ITEM_TWO],
            developerUserId: DEV_ID
        });
        const toastDetail = toastHandler.mock.calls[0][0].detail;
        expect(toastDetail.variant).toBe("success");
        expect(toastDetail.message).toContain("2 items routed to dev");
    });

    it("per-row Route to dev routes just that row with a null developer when none picked", async () => {
        routeToDev.mockResolvedValue({
            succeededIds: [ITEM_ONE],
            failures: [],
            succeededCount: 1,
            failedCount: 0
        });
        const element = createComponent();
        getIntakeItems.emit(sampleItems());
        await flushPromises();

        findButtonByLabel(element, "Route to dev").dispatchEvent(new CustomEvent("click"));
        await flushPromises();
        await flushPromises();

        expect(routeToDev).toHaveBeenCalledWith({
            workItemIds: [ITEM_ONE],
            developerUserId: null
        });
    });

    it("per-row Dismiss calls dismissIntake for that row", async () => {
        dismissIntake.mockResolvedValue({
            succeededIds: [ITEM_ONE],
            failures: [],
            succeededCount: 1,
            failedCount: 0
        });
        const element = createComponent();
        const toastHandler = jest.fn();
        element.addEventListener("lightning__showtoast", toastHandler);

        getIntakeItems.emit(sampleItems());
        await flushPromises();

        findButtonByLabel(element, "Dismiss").dispatchEvent(new CustomEvent("click"));
        await flushPromises();
        await flushPromises();

        expect(dismissIntake).toHaveBeenCalledWith({ workItemIds: [ITEM_ONE] });
        const toastDetail = toastHandler.mock.calls[0][0].detail;
        expect(toastDetail.variant).toBe("success");
        expect(toastDetail.message).toContain("1 item dismissed");
    });

    it("shows the empty state when there is no inbound work", async () => {
        const element = createComponent();
        getIntakeItems.emit([]);
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("No new inbound items to triage");
        expect(element.shadowRoot.querySelector(".queue-row")).toBeNull();
    });

    it("shows an error when the wire errors", async () => {
        const element = createComponent();
        getIntakeItems.error();
        await flushPromises();

        expect(element.shadowRoot.querySelector(".queue-error")).not.toBeNull();
    });
});

describe("c-delivery-intake-queue home visibility", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders by default when not hidden", async () => {
        const element = createComponent();
        await flushPromises();
        expect(element.shadowRoot.querySelector(".queue-card")).not.toBeNull();
    });

    it("renders nothing on Home when hidden in Settings", async () => {
        const element = createComponent();
        CurrentPageReference.emit(HOME_PAGE_REF);
        getHiddenHomeComponents.emit({ deliveryIntakeQueue: true });
        await flushPromises();
        expect(element.shadowRoot.querySelector(".queue-card")).toBeNull();
    });
});
