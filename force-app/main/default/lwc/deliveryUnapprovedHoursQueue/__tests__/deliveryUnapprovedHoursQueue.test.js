/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryUnapprovedHoursQueue: hidden while
 *               the flag is off, total + per-request rows when on, the
 *               per-row and bulk "Approve hours" calls (only approvable rows,
 *               then a refresh), blocked rows showing their reason instead of
 *               a button, buttons hidden for non-approvers, the empty state and
 *               the wire error state.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryUnapprovedHoursQueue from "c/deliveryUnapprovedHoursQueue";
import getUnapprovedHours from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.getUnapprovedHours";
import acknowledgeUnapprovedHours from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTriageController.acknowledgeUnapprovedHours";

const REQ_ONE = "a4B000000000001AAA";
const REQ_TWO = "a4B000000000002AAA";
const REQ_BLOCKED = "a4B000000000003AAA";

function sampleFeed(overrides = {}) {
    return {
        enabled: true,
        canApprove: true,
        cutover: "2026-10-01T00:00:00.000Z",
        totalHours: 9.5,
        rows: [
            {
                requestId: REQ_ONE,
                requestStatus: "Draft",
                workItemId: "a42000000000001AAA",
                workItemName: "T-0401",
                briefDescription: "Borrower portal fix",
                hours: 5,
                logCount: 2,
                firstWorkDate: "2026-10-02",
                lastWorkDate: "2026-10-03",
                canAcknowledge: true,
                blockedReason: null
            },
            {
                requestId: REQ_TWO,
                requestStatus: "Draft",
                workItemId: "a42000000000002AAA",
                workItemName: "T-0402",
                briefDescription: null,
                hours: 3.5,
                logCount: 1,
                firstWorkDate: "2026-10-04",
                lastWorkDate: "2026-10-04",
                canAcknowledge: true,
                blockedReason: null
            },
            {
                requestId: REQ_BLOCKED,
                requestStatus: "Offer Sent",
                workItemId: "a42000000000003AAA",
                workItemName: "T-0403",
                briefDescription: null,
                hours: 1,
                logCount: 1,
                firstWorkDate: "2026-10-05",
                lastWorkDate: "2026-10-05",
                canAcknowledge: false,
                blockedReason: "Awaiting a decision in Pending Work Approvals. Approve it there."
            }
        ],
        ...overrides
    };
}

function createComponent() {
    const element = createElement("c-delivery-unapproved-hours-queue", {
        is: DeliveryUnapprovedHoursQueue
    });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function buttonsByLabel(element, label) {
    return Array.from(element.shadowRoot.querySelectorAll("lightning-button")).filter(
        (b) => b.label === label
    );
}

describe("c-delivery-unapproved-hours-queue", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders nothing while the flag setting is off", async () => {
        const element = createComponent();
        getUnapprovedHours.emit({ enabled: false, canApprove: false, totalHours: 0, rows: [] });
        await flushPromises();

        expect(element.shadowRoot.querySelector(".queue-card")).toBeNull();
    });

    it("renders nothing before the feed loads", async () => {
        const element = createComponent();
        await flushPromises();
        expect(element.shadowRoot.querySelector(".queue-card")).toBeNull();
    });

    it("shows the total and one row per request, with blocked rows explained", async () => {
        const element = createComponent();
        getUnapprovedHours.emit(sampleFeed());
        await flushPromises();

        const text = element.shadowRoot.textContent;
        expect(text).toContain("Hours without approval");
        expect(text).toContain("9.5h");
        expect(text).toContain("across 3 requests");
        expect(element.shadowRoot.querySelectorAll(".queue-row").length).toBe(3);
        expect(text).toContain("T-0401");
        expect(text).toContain("Borrower portal fix");
        expect(text).toContain("2 logs");
        expect(text).toContain("worked 2026-10-02 to 2026-10-03");
        expect(text).toContain("worked 2026-10-04");
        expect(text).toContain("Awaiting a decision in Pending Work Approvals");

        // Two approvable rows get a button; the Offer Sent row does not.
        expect(buttonsByLabel(element, "Approve hours").length).toBe(2);
        expect(buttonsByLabel(element, "Approve all").length).toBe(1);
    });

    it("approves one request from its row, then refreshes", async () => {
        acknowledgeUnapprovedHours.mockResolvedValue({ succeededCount: 1, failedCount: 0, failures: [] });
        const element = createComponent();
        getUnapprovedHours.emit(sampleFeed());
        await flushPromises();

        buttonsByLabel(element, "Approve hours")[0].click();
        await flushPromises();

        expect(acknowledgeUnapprovedHours).toHaveBeenCalledWith({ requestIds: [REQ_ONE] });
    });

    it("Approve all sends only the approvable requests", async () => {
        acknowledgeUnapprovedHours.mockResolvedValue({ succeededCount: 2, failedCount: 0, failures: [] });
        const element = createComponent();
        getUnapprovedHours.emit(sampleFeed());
        await flushPromises();

        buttonsByLabel(element, "Approve all")[0].click();
        await flushPromises();

        expect(acknowledgeUnapprovedHours).toHaveBeenCalledWith({ requestIds: [REQ_ONE, REQ_TWO] });
    });

    it("hides the approve buttons from non-approvers", async () => {
        const element = createComponent();
        getUnapprovedHours.emit(sampleFeed({ canApprove: false }));
        await flushPromises();

        expect(element.shadowRoot.querySelectorAll(".queue-row").length).toBe(3);
        expect(buttonsByLabel(element, "Approve hours").length).toBe(0);
        expect(buttonsByLabel(element, "Approve all").length).toBe(0);
    });

    it("shows the empty state when every hour is on approved work", async () => {
        const element = createComponent();
        getUnapprovedHours.emit(sampleFeed({ totalHours: 0, rows: [] }));
        await flushPromises();

        expect(element.shadowRoot.querySelector(".queue-empty")).toBeTruthy();
        expect(element.shadowRoot.textContent).toContain("Every hour logged is on approved work.");
    });

    it("shows an error when the wire errors", async () => {
        const element = createComponent();
        getUnapprovedHours.error({ message: "boom" });
        await flushPromises();

        const error = element.shadowRoot.querySelector(".queue-error");
        expect(error).toBeTruthy();
        expect(error.textContent).toContain("boom");
    });
});
