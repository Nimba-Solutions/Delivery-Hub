/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryCapacityForecast: the client-side
 *               staffing-ramp packer (greenlit drains first, build-out packs,
 *               terminal / zero-remaining items dropped), the per-month vs
 *               cumulative toggle (cumulative totals never decrease), the live
 *               "lands by" readout, and the empty / error states. Mirrors the
 *               prototype buildSchedule the slider productizes.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryCapacityForecast from "c/deliveryCapacityForecast";
import getForecastItems from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHoursAnalyticsController.getForecastItems";

function item(overrides = {}) {
    return {
        id: overrides.id || "a00000000000001AAA",
        name: overrides.name || "Item",
        tier: overrides.tier || "predicted",
        remaining: overrides.remaining != null ? overrides.remaining : 40,
        startDate: overrides.startDate || "2026-06-01",
        isTerminal: overrides.isTerminal || false
    };
}

function createComponent() {
    const element = createElement("c-delivery-capacity-forecast", {
        is: DeliveryCapacityForecast
    });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function columnTotals(element) {
    return Array.from(element.shadowRoot.querySelectorAll(".chart .col .total")).map(
        (n) => parseInt(n.textContent, 10)
    );
}

describe("c-delivery-capacity-forecast", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders staffing-ramped stacked bars from the wire data", async () => {
        const element = createComponent();
        getForecastItems.emit([
            item({ id: "a01", remaining: 300, tier: "predicted" }),
            item({ id: "a02", remaining: 200, tier: "greenlit" })
        ]);
        await flushPromises();

        const cols = element.shadowRoot.querySelectorAll(".chart .col");
        expect(cols.length).toBeGreaterThan(0);
        // The greenlit pool produces a committed band somewhere in the stack.
        const committed = element.shadowRoot.querySelector('.seg[title^="Greenlit"]');
        expect(committed).not.toBeNull();
        // Ramp: month one total is below the full 3-dev ceiling (480h) — it climbs.
        const totals = columnTotals(element);
        expect(totals[0]).toBeLessThan(480);
        expect(totals.every((t) => Number.isFinite(t))).toBe(true);
    });

    it("drops terminal and zero-remaining items from the schedule", async () => {
        const element = createComponent();
        getForecastItems.emit([
            item({ id: "a01", remaining: 100, isTerminal: true }),
            item({ id: "a02", remaining: 0 })
        ]);
        await flushPromises();

        // Nothing forward to pack → empty state, not a chart.
        expect(element.shadowRoot.querySelector(".chart")).toBeNull();
        expect(element.shadowRoot.textContent).toContain("No active work in scope");
    });

    it("shows a live 'lands by' readout", async () => {
        const element = createComponent();
        getForecastItems.emit([item({ id: "a01", remaining: 120, tier: "predicted" })]);
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("Everything lands by");
    });

    it("cumulative toggle makes per-column totals non-decreasing", async () => {
        const element = createComponent();
        getForecastItems.emit([
            item({ id: "a01", remaining: 600, tier: "predicted" }),
            item({ id: "a02", remaining: 300, tier: "greenlit" })
        ]);
        await flushPromises();

        const toggle = element.shadowRoot.querySelector("lightning-button");
        toggle.dispatchEvent(new CustomEvent("click"));
        await flushPromises();

        const totals = columnTotals(element);
        for (let i = 1; i < totals.length; i++) {
            expect(totals[i]).toBeGreaterThanOrEqual(totals[i - 1]);
        }
    });

    it("reflows when the dev-count slider changes", async () => {
        const element = createComponent();
        getForecastItems.emit([item({ id: "a01", remaining: 800, tier: "predicted" })]);
        await flushPromises();

        // Month 0 always exists; raising the dev ceiling lifts its packed total.
        const before = columnTotals(element)[0];
        const slider = element.shadowRoot.querySelector(".dev-slider");
        slider.value = 6;
        slider.dispatchEvent(new CustomEvent("change"));
        await flushPromises();

        const after = columnTotals(element)[0];
        // More devs → a taller stack in the first month (steeper ramp ceiling).
        expect(after).toBeGreaterThan(before);
    });

    it("shows the empty state when no items are in scope", async () => {
        const element = createComponent();
        getForecastItems.emit([]);
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("No active work in scope");
        expect(element.shadowRoot.querySelector(".chart")).toBeNull();
    });

    it("shows an error when the wire errors", async () => {
        const element = createComponent();
        getForecastItems.error();
        await flushPromises();

        expect(element.shadowRoot.querySelector(".slds-text-color_error")).not.toBeNull();
        expect(element.shadowRoot.querySelector(".chart")).toBeNull();
    });
});
