/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryApprovalSummaryCard: the three
 *               agenda tiles from the wire (numbers + hour details), the
 *               report click-through wiring (tile carries the resolved report
 *               id; missing report disables the affordance), and the error
 *               state.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryApprovalSummaryCard from "c/deliveryApprovalSummaryCard";
import getApprovalSummary from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryApprovalSummaryController.getApprovalSummary";

const REPORT_ID_APPROVED = "00O000000000001AAA";
const REPORT_ID_PENDING = "00O000000000002AAA";

function sampleSummary(overrides = {}) {
    return {
        hoursApprovedThisMonth: 42,
        pendingCount: 3,
        pendingQuotedHours: 16,
        inProgressCount: 5,
        inProgressApprovedHours: 120,
        reportIdsByDeveloperName: {
            Hours_Approved_This_Period: REPORT_ID_APPROVED,
            Pending_Approval: REPORT_ID_PENDING
            // Approved_In_Progress intentionally missing — disabled tile case
        },
        ...overrides
    };
}

function createComponent() {
    const element = createElement("c-delivery-approval-summary-card", {
        is: DeliveryApprovalSummaryCard
    });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("c-delivery-approval-summary-card", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders the three agenda tiles with numbers from the wire", async () => {
        const element = createComponent();
        getApprovalSummary.emit(sampleSummary());
        await flushPromises();

        const tiles = element.shadowRoot.querySelectorAll(".agenda-tile");
        expect(tiles.length).toBe(3);

        const text = element.shadowRoot.textContent;
        expect(text).toContain("42.0h"); // hours approved this month
        expect(text).toContain("3"); // pending count
        expect(text).toContain("16.0h quoted awaiting decision");
        expect(text).toContain("5"); // in-progress count
        expect(text).toContain("120h approved in flight");
    });

    it("carries the resolved report id on click-through tiles and disables tiles without a report", async () => {
        const element = createComponent();
        getApprovalSummary.emit(sampleSummary());
        await flushPromises();

        const tiles = Array.from(element.shadowRoot.querySelectorAll(".agenda-tile"));
        const approvedTile = tiles[0];
        const inProgressTile = tiles[2];

        expect(approvedTile.dataset.reportId).toBe(REPORT_ID_APPROVED);
        expect(approvedTile.disabled).toBe(false);
        expect(approvedTile.textContent).toContain("Open report");

        expect(inProgressTile.dataset.reportId).toBe("");
        expect(inProgressTile.disabled).toBe(true);
        expect(inProgressTile.textContent).not.toContain("Open report");
    });

    it("shows an error when the wire errors", async () => {
        const element = createComponent();
        getApprovalSummary.error();
        await flushPromises();

        expect(element.shadowRoot.querySelector(".agenda-error")).not.toBeNull();
        expect(element.shadowRoot.querySelector(".agenda-tile")).toBeNull();
    });
});
