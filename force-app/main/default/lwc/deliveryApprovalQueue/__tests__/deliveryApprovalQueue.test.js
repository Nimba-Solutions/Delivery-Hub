/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryApprovalQueue: wire-driven rows
 *               (label fallback, increase badge, headline totals), the
 *               imperative approve flow (apex call + success toast + wire
 *               refresh), the bulk "Approve selected" flow (selection
 *               toggles, approveMany call shape, outcome toasts), the inline
 *               decline flow, and the caught-up empty state.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryApprovalQueue from "c/deliveryApprovalQueue";
import getPendingForApprover from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkApprovalService.getPendingForApprover";
import approve from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkApprovalService.approve";
import approveMany from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkApprovalService.approveMany";
import decline from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkApprovalService.decline";

const REQUEST_ONE = "a0G000000000001AAA";
const REQUEST_TWO = "a0G000000000002AAA";

function samplePending() {
    return [
        {
            requestId: REQUEST_ONE,
            workItemId: "a42000000000001AAA",
            workItemName: "T-1001",
            workItemLabel: "Build the approval queue",
            quotedHours: 12,
            requestedIncrease: null,
            requestStatus: "Offer Sent",
            submittedAt: new Date().toISOString(),
            approverUserId: "005000000000001AAA"
        },
        {
            requestId: REQUEST_TWO,
            workItemId: "a42000000000002AAA",
            workItemName: "T-1002",
            workItemLabel: null,
            quotedHours: 4,
            requestedIncrease: 4,
            requestStatus: "Offer Sent",
            submittedAt: new Date(Date.now() - 3 * 86400000).toISOString(),
            approverUserId: null
        }
    ];
}

function createComponent() {
    const element = createElement("c-delivery-approval-queue", {
        is: DeliveryApprovalQueue
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

describe("c-delivery-approval-queue", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders rows from the wire with label fallback and increase badge", async () => {
        const element = createComponent();
        getPendingForApprover.emit(samplePending());
        await flushPromises();

        const rows = element.shadowRoot.querySelectorAll(".queue-row");
        expect(rows.length).toBe(2);

        const text = element.shadowRoot.textContent;
        expect(text).toContain("Build the approval queue"); // workItemLabel
        expect(text).toContain("T-1002"); // workItemName fallback when label null

        const badges = element.shadowRoot.querySelectorAll(".queue-increase-badge");
        expect(badges.length).toBe(1);
        expect(badges[0].textContent).toContain("increase +4");

        // Headline: 2 pending, 16h quoted total.
        expect(text).toContain("16.0h");
    });

    it("approve button calls apex with the request id and refreshes via a success toast", async () => {
        approve.mockResolvedValue(undefined);
        const element = createComponent();

        const toastHandler = jest.fn();
        element.addEventListener("lightning__showtoast", toastHandler);

        getPendingForApprover.emit(samplePending());
        await flushPromises();

        const approveButton = findButtonByLabel(element, "Approve");
        approveButton.dispatchEvent(new CustomEvent("click"));
        await flushPromises();
        await flushPromises();

        expect(approve).toHaveBeenCalledWith({
            workRequestId: REQUEST_ONE,
            approvedHours: null,
            note: null
        });
        expect(toastHandler).toHaveBeenCalled();
        const toastDetail = toastHandler.mock.calls[0][0].detail;
        expect(toastDetail.variant).toBe("success");
    });

    it("selection toggles drive the bulk button label and disabled state", async () => {
        const element = createComponent();
        getPendingForApprover.emit(samplePending());
        await flushPromises();

        let bulkButton = findButtonByLabel(element, "Approve selected (0)");
        expect(bulkButton).toBeTruthy();
        expect(bulkButton.disabled).toBe(true);

        // Tick the first row checkbox -> (1), enabled.
        const rowCheckbox = findInputByLabel(element, "Select request");
        setCheckbox(rowCheckbox, true);
        await flushPromises();

        bulkButton = findButtonByLabel(element, "Approve selected (1)");
        expect(bulkButton).toBeTruthy();
        expect(bulkButton.disabled).toBe(false);

        // Select all -> (2).
        setCheckbox(findInputByLabel(element, "Select all"), true);
        await flushPromises();
        expect(findButtonByLabel(element, "Approve selected (2)")).toBeTruthy();

        // Clear via select-all -> back to (0), disabled.
        setCheckbox(findInputByLabel(element, "Select all"), false);
        await flushPromises();
        bulkButton = findButtonByLabel(element, "Approve selected (0)");
        expect(bulkButton).toBeTruthy();
        expect(bulkButton.disabled).toBe(true);
    });

    it("bulk approve calls apex with the selected ids and toasts the success count", async () => {
        approveMany.mockResolvedValue({
            approvedIds: [REQUEST_ONE, REQUEST_TWO],
            failures: []
        });
        const element = createComponent();
        const toastHandler = jest.fn();
        element.addEventListener("lightning__showtoast", toastHandler);

        getPendingForApprover.emit(samplePending());
        await flushPromises();

        setCheckbox(findInputByLabel(element, "Select all"), true);
        await flushPromises();

        findButtonByLabel(element, "Approve selected (2)").dispatchEvent(
            new CustomEvent("click")
        );
        await flushPromises();
        await flushPromises();

        expect(approveMany).toHaveBeenCalledWith({
            workRequestIds: [REQUEST_ONE, REQUEST_TWO],
            note: null
        });
        expect(toastHandler).toHaveBeenCalled();
        const toastDetail = toastHandler.mock.calls[0][0].detail;
        expect(toastDetail.variant).toBe("success");
        expect(toastDetail.message).toContain("2 requests approved");
    });

    it("bulk approve toasts a warning summarizing partial failures", async () => {
        approveMany.mockResolvedValue({
            approvedIds: [REQUEST_ONE],
            failures: [`${REQUEST_TWO}: not awaiting a decision`]
        });
        const element = createComponent();
        const toastHandler = jest.fn();
        element.addEventListener("lightning__showtoast", toastHandler);

        getPendingForApprover.emit(samplePending());
        await flushPromises();

        setCheckbox(findInputByLabel(element, "Select all"), true);
        await flushPromises();

        findButtonByLabel(element, "Approve selected (2)").dispatchEvent(
            new CustomEvent("click")
        );
        await flushPromises();
        await flushPromises();

        expect(approveMany).toHaveBeenCalledWith({
            workRequestIds: [REQUEST_ONE, REQUEST_TWO],
            note: null
        });
        const toastDetail = toastHandler.mock.calls[0][0].detail;
        expect(toastDetail.variant).toBe("warning");
        expect(toastDetail.message).toContain("1 approved, 1 failed");
    });

    it("decline requires a reason then calls apex", async () => {
        decline.mockResolvedValue(undefined);
        const element = createComponent();
        getPendingForApprover.emit(samplePending());
        await flushPromises();

        findButtonByLabel(element, "Decline").dispatchEvent(new CustomEvent("click"));
        await flushPromises();

        const reasonInput = Array.from(
            element.shadowRoot.querySelectorAll("lightning-input")
        ).find((i) => i.label === "Decline reason");
        expect(reasonInput).toBeTruthy();
        reasonInput.value = "Budget exhausted for this quarter";
        reasonInput.dispatchEvent(new CustomEvent("change"));
        await flushPromises();

        findButtonByLabel(element, "Confirm decline").dispatchEvent(new CustomEvent("click"));
        await flushPromises();
        await flushPromises();

        expect(decline).toHaveBeenCalledWith({
            workRequestId: REQUEST_ONE,
            reason: "Budget exhausted for this quarter"
        });
    });

    it("shows the caught-up empty state when nothing is pending", async () => {
        const element = createComponent();
        getPendingForApprover.emit([]);
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("Nothing pending");
        expect(element.shadowRoot.querySelector(".queue-row")).toBeNull();
    });

    it("shows an error when the wire errors", async () => {
        const element = createComponent();
        getPendingForApprover.error();
        await flushPromises();

        expect(element.shadowRoot.querySelector(".queue-error")).not.toBeNull();
    });
});
