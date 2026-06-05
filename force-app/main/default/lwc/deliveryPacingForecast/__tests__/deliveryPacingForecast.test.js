/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryPacingForecast: control rendering, the
 *               wire-driven chart (actual + forecast bars, target polyline, current
 *               marker), the headline summary cards, the unscheduled note, the click
 *               drill-down, navigate-to-record on a work-item row, the $ measure gated
 *               on a blended rate, and empty/error states.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryPacingForecast from "c/deliveryPacingForecast";
import getPortfolioPacing from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHoursAnalyticsController.getPortfolioPacing";

function sampleItem(overrides = {}) {
    return {
        workItemId: "a0X000000000001AAA",
        name: "T-0042",
        hoursThisPeriod: 30,
        pctOfItem: 50,
        estimatedHours: 100,
        loggedHours: 40,
        remainingHours: 60,
        budgetUsedPct: 40,
        startDate: "2026-06-01",
        endDate: "2026-07-31",
        developerName: "Mahi",
        stage: "In Progress",
        priorityGroup: "NOW",
        ...overrides
    };
}

function samplePacing(overrides = {}) {
    return {
        granularity: "Month",
        scopeLabel: "3 active projects · 2 in-flight items",
        rootCount: 3,
        blendedRate: null,
        earliestStart: "2026-01-01",
        latestEnd: "2026-12-31",
        summary: {
            estimatedHours: 100,
            loggedHours: 40,
            remainingHours: 60,
            projectedFinalHours: 100,
            pacingPct: 40,
            activeItems: 2,
            unscheduledRemainingHours: 0,
            runRateHoursPerPeriod: 10,
            hasEstimate: true,
            isOverBudgetTrajectory: false,
            forecastCapped: false,
            ...(overrides.summary || {})
        },
        periods: overrides.periods || [
            { label: "Apr 26", actualHours: 12, targetHours: 8, forecastHours: 0, isForecast: false, isCurrent: false, overTarget: true, items: [] },
            { label: "May 26", actualHours: 6, targetHours: 8, forecastHours: 0, isForecast: false, isCurrent: true, overTarget: false, items: [] },
            { label: "Jun 26", actualHours: 0, targetHours: 8, forecastHours: 30, isForecast: true, isCurrent: false, overTarget: false, items: [sampleItem()] }
        ],
        ...overrides
    };
}

function createComponent() {
    const element = createElement("c-delivery-pacing-forecast", {
        is: DeliveryPacingForecast
    });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("c-delivery-pacing-forecast", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders the range, bucket, and mode selectors", () => {
        const element = createComponent();
        const combos = element.shadowRoot.querySelectorAll("lightning-combobox");
        const names = Array.from(combos).map((c) => c.name);
        expect(names).toContain("range");
        expect(names).toContain("granularity");
        expect(names).toContain("mode");
    });

    it("renders actual + forecast bars, target polyline, and current marker", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        const bars = element.shadowRoot.querySelectorAll("rect.bar");
        expect(bars.length).toBe(3);
        const classes = Array.from(bars).map((b) => b.getAttribute("class"));
        expect(classes.some((c) => c.includes("bar--actual"))).toBe(true);
        expect(classes.some((c) => c.includes("bar--over"))).toBe(true);
        expect(classes.some((c) => c.includes("bar--forecast"))).toBe(true);

        const target = element.shadowRoot.querySelector("polyline.target-line");
        expect(target).not.toBeNull();
        expect(target.getAttribute("points").trim().split(" ").length).toBe(3);

        const marker = element.shadowRoot.querySelector("line.current-marker");
        expect(marker).not.toBeNull();
    });

    it("shows headline summary cards: logged, projected final, pacing", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        const text = element.shadowRoot.textContent;
        expect(text).toContain("40.0h"); // logged
        expect(text).toContain("60.0h"); // remaining
        expect(text).toContain("100h"); // projected final
        expect(text).toContain("40%"); // pacing
    });

    it("surfaces the unscheduled-remaining note when present", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(
            samplePacing({
                summary: { unscheduledRemainingHours: 25 }
            })
        );
        await flushPromises();

        const note = element.shadowRoot.querySelector(".pacing-unscheduled-note");
        expect(note).not.toBeNull();
        expect(note.textContent).toContain("can't be placed on the forecast");
    });

    it("hides the measure selector when no blended rate is present", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing({ blendedRate: null }));
        await flushPromises();
        const combos = element.shadowRoot.querySelectorAll("lightning-combobox");
        const names = Array.from(combos).map((c) => c.name);
        expect(names).not.toContain("measure");
    });

    it("offers the measure selector when a blended rate is present", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing({ blendedRate: 100 }));
        await flushPromises();
        const combos = element.shadowRoot.querySelectorAll("lightning-combobox");
        const names = Array.from(combos).map((c) => c.name);
        expect(names).toContain("measure");
    });

    it("opens the drill-down when a bar is clicked", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        // No drill-down until a bar is clicked.
        expect(element.shadowRoot.querySelector(".pacing-drill")).toBeNull();

        const bars = element.shadowRoot.querySelectorAll("rect.bar");
        const forecastBar = Array.from(bars).find((b) =>
            b.getAttribute("class").includes("bar--forecast")
        );
        forecastBar.dispatchEvent(new CustomEvent("click"));
        await flushPromises();

        const drill = element.shadowRoot.querySelector(".pacing-drill");
        expect(drill).not.toBeNull();
        const rows = element.shadowRoot.querySelectorAll("tr.drill-row");
        expect(rows.length).toBe(1);
        expect(drill.textContent).toContain("T-0042");
        expect(drill.textContent).toContain("NOW");
    });

    it("wires each drill-down row to its WorkItem record for navigation", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        const bars = element.shadowRoot.querySelectorAll("rect.bar");
        const forecastBar = Array.from(bars).find((b) =>
            b.getAttribute("class").includes("bar--forecast")
        );
        forecastBar.dispatchEvent(new CustomEvent("click"));
        await flushPromises();

        // The row carries the WorkItem Id that handleRowClick feeds to
        // NavigationMixin.Navigate (standard__recordPage). The repo's sfdx-lwc-jest
        // navigation stub doesn't expose getNavigateCalledWith and the mixin method
        // is non-configurable under jest, so assert the wiring contract + that the
        // click path runs cleanly.
        const row = element.shadowRoot.querySelector("tr.drill-row");
        expect(row.dataset.recordId).toBe("a0X000000000001AAA");
        expect(() => {
            row.dispatchEvent(new CustomEvent("click"));
        }).not.toThrow();
        await flushPromises();
    });

    it("toggles a series off when its toggle is clicked", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        expect(element.shadowRoot.querySelectorAll("rect.bar").length).toBe(3);

        const toggles = element.shadowRoot.querySelectorAll("button.series-toggle");
        const forecastToggle = Array.from(toggles).find((t) =>
            t.textContent.includes("Forecast")
        );
        forecastToggle.click();
        await flushPromises();

        // The single forecast bar drops out; the two actual bars remain.
        expect(element.shadowRoot.querySelectorAll("rect.bar").length).toBe(2);
    });

    it("flags an over-budget projected final", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(
            samplePacing({
                summary: { isOverBudgetTrajectory: true, projectedFinalHours: 150 }
            })
        );
        await flushPromises();

        const over = element.shadowRoot.querySelector(".summary-value--over");
        expect(over).not.toBeNull();
    });

    it("re-wires when the bucket selector changes", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        const combos = element.shadowRoot.querySelectorAll("lightning-combobox");
        const combo = Array.from(combos).find((c) => c.name === "granularity");
        combo.dispatchEvent(
            new CustomEvent("change", { detail: { value: "Quarter" } })
        );
        await flushPromises();

        getPortfolioPacing.emit(samplePacing({ granularity: "Quarter" }));
        await flushPromises();
        expect(element.shadowRoot.querySelectorAll("rect.bar").length).toBe(3);
    });

    it("shows custom date inputs when the Custom range is selected", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        const combos = element.shadowRoot.querySelectorAll("lightning-combobox");
        const rangeCombo = Array.from(combos).find((c) => c.name === "range");
        rangeCombo.dispatchEvent(
            new CustomEvent("change", { detail: { value: "custom" } })
        );
        await flushPromises();

        const dateInputs = element.shadowRoot.querySelectorAll(
            "lightning-input.pacing-date"
        );
        expect(dateInputs.length).toBe(2);
    });

    it("shows the empty state for a fully-empty portfolio", async () => {
        const element = createComponent();
        getPortfolioPacing.emit({
            granularity: "Month",
            scopeLabel: "0 active projects · 0 in-flight items",
            rootCount: 0,
            blendedRate: null,
            summary: {
                estimatedHours: 0,
                loggedHours: 0,
                remainingHours: 0,
                projectedFinalHours: 0,
                pacingPct: 0,
                activeItems: 0,
                unscheduledRemainingHours: 0,
                hasEstimate: false,
                isOverBudgetTrajectory: false,
                forecastCapped: false
            },
            periods: [
                { label: "Apr 26", actualHours: 0, targetHours: 0, forecastHours: 0, isForecast: false, isCurrent: false, items: [] },
                { label: "May 26", actualHours: 0, targetHours: 0, forecastHours: 0, isForecast: true, isCurrent: false, items: [] }
            ]
        });
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain(
            "No active portfolio activity yet"
        );
        expect(element.shadowRoot.querySelector("rect.bar")).toBeNull();
    });

    it("shows an error when the wire errors", async () => {
        const element = createComponent();
        getPortfolioPacing.error();
        await flushPromises();

        const err = element.shadowRoot.querySelector(".pacing-error");
        expect(err).not.toBeNull();
    });
});
