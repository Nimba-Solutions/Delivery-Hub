/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryBillingPreview: the totals header
 *               (billable headline + the ≈ $ figure only when a blended rate
 *               resolves), the per-item Approved vs Logged vs Billable table
 *               with over-cap rows flagged (row class + badge), the month
 *               selector defaulting to the current month with 12 trailing
 *               options, the empty state, and the error state.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryBillingPreview from "c/deliveryBillingPreview";
import getBillingPreview from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryBillingPreviewController.getBillingPreview";

const WI_OK = "a00000000000001AAA";
const WI_OVER = "a00000000000002AAA";

function samplePreview(overrides = {}) {
    return {
        year: 2026,
        month: 6,
        monthLabel: "Jun 2026",
        blendedRate: 90,
        cappedItemCount: 2,
        totalApprovedCap: 30,
        totalMonthLogged: 14,
        totalBillable: 11,
        totalOverCap: 3,
        totalBillableAmount: 990,
        rows: [
            {
                workItemId: WI_OVER,
                label: "Over-cap rock",
                approvedCap: 10,
                loggedBefore: 4,
                monthLogged: 9,
                billable: 6,
                overCap: 3,
                isOverCap: true
            },
            {
                workItemId: WI_OK,
                label: "Healthy item",
                approvedCap: 20,
                loggedBefore: 0,
                monthLogged: 5,
                billable: 5,
                overCap: 0,
                isOverCap: false
            }
        ],
        ...overrides
    };
}

function createComponent() {
    const element = createElement("c-delivery-billing-preview", {
        is: DeliveryBillingPreview
    });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("c-delivery-billing-preview", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders the billable headline with the dollar figure when a rate resolves", async () => {
        const element = createComponent();
        getBillingPreview.emit(samplePreview());
        await flushPromises();

        const billableTile = element.shadowRoot.querySelector(".summary-tile--billable");
        expect(billableTile).not.toBeNull();
        expect(billableTile.textContent).toContain("Billable this month");
        expect(billableTile.textContent).toContain("11.0h");
        expect(billableTile.textContent).toContain("$990");
    });

    it("omits the dollar figure when no blended rate resolves (hours-only)", async () => {
        const element = createComponent();
        getBillingPreview.emit(
            samplePreview({ blendedRate: null, totalBillableAmount: null })
        );
        await flushPromises();

        const billableTile = element.shadowRoot.querySelector(".summary-tile--billable");
        expect(billableTile.textContent).toContain("11.0h");
        expect(billableTile.textContent).not.toContain("$");
        expect(billableTile.querySelector(".summary-money")).toBeNull();
    });

    it("renders one table row per item with the approved/logged/billable/over-cap split", async () => {
        const element = createComponent();
        getBillingPreview.emit(samplePreview());
        await flushPromises();

        const rows = element.shadowRoot.querySelectorAll("tbody tr");
        expect(rows.length).toBe(2);

        const overRow = rows[0];
        expect(overRow.textContent).toContain("Over-cap rock");
        expect(overRow.textContent).toContain("10.0h"); // approved cap
        expect(overRow.textContent).toContain("9.00h"); // month logged
        expect(overRow.textContent).toContain("6.00h"); // billable
        expect(overRow.textContent).toContain("3.00h"); // over cap
    });

    it("flags over-cap rows with the row class and badge; healthy rows stay unflagged", async () => {
        const element = createComponent();
        getBillingPreview.emit(samplePreview());
        await flushPromises();

        const rows = element.shadowRoot.querySelectorAll("tbody tr");
        expect(rows[0].classList.contains("preview-row--over")).toBe(true);
        expect(rows[0].querySelector(".over-badge")).not.toBeNull();
        expect(rows[1].classList.contains("preview-row--over")).toBe(false);
        expect(rows[1].querySelector(".over-badge")).toBeNull();
    });

    it("carries the work item id on the row link for record navigation", async () => {
        const element = createComponent();
        getBillingPreview.emit(samplePreview());
        await flushPromises();

        const links = element.shadowRoot.querySelectorAll(".row-link");
        expect(links[0].dataset.workItemId).toBe(WI_OVER);
        expect(links[1].dataset.workItemId).toBe(WI_OK);
    });

    it("defaults the month selector to the current month with 12 trailing options", async () => {
        const element = createComponent();
        getBillingPreview.emit(samplePreview());
        await flushPromises();

        const combobox = element.shadowRoot.querySelector("lightning-combobox");
        const now = new Date();
        expect(combobox.value).toBe(`${now.getFullYear()}-${now.getMonth() + 1}`);
        expect(combobox.options.length).toBe(12);
        expect(combobox.options[0].value).toBe(combobox.value);
    });

    it("shows the empty state when the month has no billable activity", async () => {
        const element = createComponent();
        getBillingPreview.emit(
            samplePreview({
                rows: [],
                totalApprovedCap: 0,
                totalMonthLogged: 0,
                totalBillable: 0,
                totalOverCap: 0,
                totalBillableAmount: 0
            })
        );
        await flushPromises();

        expect(element.shadowRoot.querySelector(".billing-empty")).not.toBeNull();
        expect(element.shadowRoot.querySelector(".billing-table")).toBeNull();
        expect(element.shadowRoot.textContent).toContain("Jun 2026");
    });

    it("shows an error when the wire errors", async () => {
        const element = createComponent();
        getBillingPreview.error();
        await flushPromises();

        expect(element.shadowRoot.querySelector(".billing-error")).not.toBeNull();
        expect(element.shadowRoot.querySelector(".billing-table")).toBeNull();
    });
});
