/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryCapacityForecast: the client-side
 *               staffing-ramp packer (greenlit drains first, build-out packs,
 *               terminal / zero-remaining items dropped), the per-month vs
 *               cumulative toggle (cumulative totals never decrease), the live
 *               "lands by" readout, and the empty / error states. Mirrors the
 *               prototype buildSchedule the slider productizes. getForecastItems
 *               is called IMPERATIVELY (the Apex is non-cacheable by design, so
 *               it cannot be @wired) — the mock is a jest.fn resolved/rejected
 *               per case before the component mounts.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryCapacityForecast from "c/deliveryCapacityForecast";
import getForecastItems from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHoursAnalyticsController.getForecastItems";
import getTeamCapacity from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCapacityService.getTeamCapacity";

// A configured CMT-derived TeamCapacity (the MF-Prod seed shape: one team-pool
// row of 1000 h/mo → 6 dev-equivalents of ~166.67 h/mo each).
function configuredCapacity(overrides = {}) {
    return {
        monthlyCapacityHours: 1000,
        weeklyCapacityHours: 230.77,
        developerEquivalents: 6,
        perDeveloperMonthlyHours: 166.67,
        isConfigured: true,
        sourceLabel: "DeveloperCapacity__mdt (1 record)",
        ...overrides
    };
}

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
    beforeEach(() => {
        // Default = unconfigured org: the slider must exercise its documented
        // explicit fallback (3 developers × 160 h/mo). jest.clearAllMocks does
        // not reset implementations, so re-pin the default per test.
        getTeamCapacity.mockImplementation(() => Promise.resolve(null));
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders staffing-ramped stacked bars from the apex data", async () => {
        getForecastItems.mockResolvedValue([
            item({ id: "a01", remaining: 300, tier: "predicted" }),
            item({ id: "a02", remaining: 200, tier: "greenlit" })
        ]);
        const element = createComponent();
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
        getForecastItems.mockResolvedValue([
            item({ id: "a01", remaining: 100, isTerminal: true }),
            item({ id: "a02", remaining: 0 })
        ]);
        const element = createComponent();
        await flushPromises();

        // Nothing forward to pack → empty state, not a chart.
        expect(element.shadowRoot.querySelector(".chart")).toBeNull();
        expect(element.shadowRoot.textContent).toContain("No active work in scope");
    });

    it("shows a live 'lands by' readout", async () => {
        getForecastItems.mockResolvedValue([item({ id: "a01", remaining: 120, tier: "predicted" })]);
        const element = createComponent();
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("Everything lands by");
    });

    it("cumulative toggle makes per-column totals non-decreasing", async () => {
        getForecastItems.mockResolvedValue([
            item({ id: "a01", remaining: 600, tier: "predicted" }),
            item({ id: "a02", remaining: 300, tier: "greenlit" })
        ]);
        const element = createComponent();
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
        getForecastItems.mockResolvedValue([item({ id: "a01", remaining: 800, tier: "predicted" })]);
        const element = createComponent();
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
        getForecastItems.mockResolvedValue([]);
        const element = createComponent();
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("No active work in scope");
        expect(element.shadowRoot.querySelector(".chart")).toBeNull();
    });

    it("shows an error when the apex call fails", async () => {
        getForecastItems.mockRejectedValue({ body: { message: "boom" } });
        const element = createComponent();
        await flushPromises();

        expect(element.shadowRoot.querySelector(".slds-text-color_error")).not.toBeNull();
        expect(element.shadowRoot.querySelector(".chart")).toBeNull();
    });

    // ── W5.2 / DECISION-G3 — CMT-driven pace ceiling ────────────────────────

    it("calibrates the ceiling and slider from configured DeveloperCapacity metadata", async () => {
        getTeamCapacity.mockResolvedValue(configuredCapacity());
        getForecastItems.mockResolvedValue([item({ id: "a01", remaining: 500 })]);
        const element = createComponent();
        await flushPromises();

        // 1000 h/mo team ÷ 166.67 per dev-equivalent → defaults to 6 devs · ~1000 h/mo.
        const text = element.shadowRoot.textContent;
        expect(text).toContain("6 developers · ~1000 h/mo");
        expect(text).toContain("≈ today’s pace");
        expect(text).toContain("configured team capacity");
        // Slider range grows to devEquivalents + 2.
        const slider = element.shadowRoot.querySelector(".dev-slider");
        expect(slider.getAttribute("max")).toBe("8");
    });

    it("falls back to the explicit 3×160 model when the CMT is unconfigured", async () => {
        // Default getTeamCapacity mock resolves null (unconfigured org).
        getForecastItems.mockResolvedValue([item({ id: "a01", remaining: 300 })]);
        const element = createComponent();
        await flushPromises();

        const text = element.shadowRoot.textContent;
        // Exact historical behavior: 3 devs × 160 h/mo = 480 — explicit, not near-zero.
        expect(text).toContain("3 developers · ~480 h/mo");
        expect(text).toContain("default model (3 developers × 160 h/mo)");
        const slider = element.shadowRoot.querySelector(".dev-slider");
        expect(slider.getAttribute("max")).toBe("6");
    });

    it("degrades to the fallback when the capacity read fails, without killing the card", async () => {
        getTeamCapacity.mockRejectedValue(new Error("capacity boom"));
        getForecastItems.mockResolvedValue([item({ id: "a01", remaining: 300 })]);
        const element = createComponent();
        await flushPromises();

        expect(element.shadowRoot.querySelector(".chart")).not.toBeNull();
        expect(element.shadowRoot.textContent).toContain("default model (3 developers × 160 h/mo)");
    });
});
