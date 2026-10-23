/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryPacingForecast: control rendering, the
 *               wire-driven chart (bars, target polyline, forecast boundary),
 *               headline numbers, the $-secondary gated on a blended rate, and
 *               empty/error states.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import DeliveryPacingForecast from "c/deliveryPacingForecast";
import getPortfolioPacing from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHoursAnalyticsController.getPortfolioPacing";
import getHiddenHomeComponents from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents";

const HOME_PAGE_REF = { type: "standard__namedPage", attributes: { pageName: "home" } };

function samplePacing(overrides = {}) {
    return {
        granularity: "Month",
        rootCount: 3,
        totalEstimatedHours: 100,
        totalLoggedHours: 40,
        projectedFinalHours: 90,
        runRateHoursPerPeriod: 10,
        blendedRate: null,
        hasEstimate: true,
        isOverBudgetTrajectory: false,
        earliestStart: "2026-01-01",
        latestEnd: "2026-12-31",
        periods: [
            { label: "Apr 26", loggedHours: 12, targetHours: 8, forecastHours: 0, isForecast: false, overTarget: true },
            { label: "May 26", loggedHours: 6, targetHours: 8, forecastHours: 0, isForecast: false, overTarget: false },
            { label: "Jun 26", loggedHours: 0, targetHours: 8, forecastHours: 10, isForecast: true, overTarget: false }
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

    it("renders the granularity and horizon selectors", () => {
        const element = createComponent();
        const combos = element.shadowRoot.querySelectorAll("lightning-combobox");
        expect(combos.length).toBe(2);
        const names = Array.from(combos).map((c) => c.name);
        expect(names).toContain("granularity");
        expect(names).toContain("horizon");
    });

    it("renders bars, target polyline, and forecast boundary from the wire", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        const bars = element.shadowRoot.querySelectorAll("rect.bar");
        expect(bars.length).toBe(3);
        // The over-target history bar and the forecast bar each get a distinct class.
        const classes = Array.from(bars).map((b) => b.getAttribute("class"));
        expect(classes.some((c) => c.includes("bar--over"))).toBe(true);
        expect(classes.some((c) => c.includes("bar--forecast"))).toBe(true);

        const target = element.shadowRoot.querySelector("polyline.target-line");
        expect(target).not.toBeNull();
        expect(target.getAttribute("points").trim().split(" ").length).toBe(3);

        const boundary = element.shadowRoot.querySelector("line.forecast-boundary");
        expect(boundary).not.toBeNull();
    });

    it("shows headline hours and pacing percent", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        const text = element.shadowRoot.textContent;
        expect(text).toContain("40.0h"); // logged
        expect(text).toContain("90.0h"); // projected final
        expect(text).toContain("90%"); // pacing
        expect(text).toContain("On track at current pace");
    });

    it("hides $ figures when no blended rate is present", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing({ blendedRate: null }));
        await flushPromises();
        expect(element.shadowRoot.querySelector(".summary-money")).toBeNull();
    });

    it("shows $ secondary figures when a blended rate is present", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing({ blendedRate: 100 }));
        await flushPromises();

        const money = element.shadowRoot.querySelectorAll(".summary-money");
        expect(money.length).toBeGreaterThan(0);
        const moneyText = Array.from(money).map((m) => m.textContent).join(" ");
        expect(moneyText).toContain("$4,000"); // 40h * 100
        expect(moneyText).toContain("$9,000"); // 90h * 100
    });

    it("flags an over-budget trajectory", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing({ isOverBudgetTrajectory: true }));
        await flushPromises();

        const variance = element.shadowRoot.querySelector(".summary-variance--over");
        expect(variance).not.toBeNull();
        expect(element.shadowRoot.textContent).toContain("Over budget at current pace");
    });

    it("re-wires when the granularity selector changes", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        const combos = element.shadowRoot.querySelectorAll("lightning-combobox");
        const combo = Array.from(combos).find((c) => c.name === "granularity");
        combo.dispatchEvent(new CustomEvent("change", { detail: { value: "Quarter" } }));
        await flushPromises();

        // The wire config recomputes against the new granularity; emitting fresh
        // data keeps the component rendering without error.
        getPortfolioPacing.emit(samplePacing({ granularity: "Quarter" }));
        await flushPromises();
        expect(element.shadowRoot.querySelectorAll("rect.bar").length).toBe(3);
    });

    it("shows the empty state for a fully-empty portfolio", async () => {
        const element = createComponent();
        getPortfolioPacing.emit({
            granularity: "Month",
            rootCount: 0,
            totalEstimatedHours: 0,
            totalLoggedHours: 0,
            projectedFinalHours: 0,
            hasEstimate: false,
            isOverBudgetTrajectory: false,
            periods: [
                { label: "Apr 26", loggedHours: 0, targetHours: 0, forecastHours: 0, isForecast: false },
                { label: "May 26", loggedHours: 0, targetHours: 0, forecastHours: 0, isForecast: true }
            ]
        });
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("No active portfolio activity yet");
        expect(element.shadowRoot.querySelector("rect.bar")).toBeNull();
    });

    it("shows an error when the wire errors", async () => {
        const element = createComponent();
        getPortfolioPacing.error();
        await flushPromises();

        const err = element.shadowRoot.querySelector(".pacing-error");
        expect(err).not.toBeNull();
    });

    // ── W5.3 (T6.1) — stacked commitment-tier forecast bars ──────
    it("renders stacked per-tier rects for forecast periods that carry segments", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(
            samplePacing({
                segmentDefs: [
                    { id: "greenlit", label: "Committed", color: "#059669", style: "solid" },
                    { id: "ready", label: "Ready to approve", color: "#d97706", style: "dotted" }
                ],
                periods: [
                    { label: "Apr 26", loggedHours: 12, targetHours: 8, forecastHours: 0, isForecast: false, overTarget: true },
                    { label: "May 26", loggedHours: 6, targetHours: 8, forecastHours: 0, isForecast: false, overTarget: false },
                    {
                        label: "Jun 26",
                        loggedHours: 0,
                        targetHours: 8,
                        forecastHours: 10,
                        isForecast: true,
                        overTarget: false,
                        segments: { greenlit: 6, ready: 4 }
                    }
                ]
            })
        );
        await flushPromises();

        // The forecast period renders one rect per tier — no flat dashed bar.
        const segmentRects = element.shadowRoot.querySelectorAll("rect.bar--segment");
        expect(segmentRects.length).toBe(2);
        const fills = Array.from(segmentRects).map((r) => r.getAttribute("fill"));
        expect(fills).toContain("#059669");
        expect(fills).toContain("#d97706");
        expect(element.shadowRoot.querySelector("rect.bar--forecast")).toBeNull();

        // Stack height equals the flat bar it replaces: Σ segments (6+4) = forecast (10).
        const stackHeight = Array.from(segmentRects).reduce(
            (total, r) => total + parseFloat(r.getAttribute("height")),
            0
        );
        const historyBar = Array.from(element.shadowRoot.querySelectorAll("rect.bar")).find((r) =>
            r.getAttribute("class").includes("bar--over")
        );
        // Logged 12 vs stacked 10 → stacked height ≈ (10/12) of the logged bar.
        const expected = (parseFloat(historyBar.getAttribute("height")) * 10) / 12;
        expect(Math.abs(stackHeight - expected)).toBeLessThan(1.5);

        // The tier legend advertises the tiers in play.
        const legendText = element.shadowRoot.textContent;
        expect(legendText).toContain("Committed (forecast)");
        expect(legendText).toContain("Ready to approve (forecast)");
    });

    it("keeps flat forecast bars for periods without segments (backward compat)", async () => {
        const element = createComponent();
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        expect(element.shadowRoot.querySelectorAll("rect.bar--segment").length).toBe(0);
        const forecastBar = element.shadowRoot.querySelector("rect.bar--forecast");
        expect(forecastBar).not.toBeNull();
        // Legacy "Forecast" legend swatch still shows for flat bars.
        expect(element.shadowRoot.textContent).toContain("Forecast");
    });

    // ── W5.4 (F15) — 100% pacing is AT budget, not over ──────────
    it("pairs a 100% pacing readout with the on-track label, never over-budget", async () => {
        const element = createComponent();
        // Apex now rounds to displayed precision before flagging: projected 247.2 of
        // 247 estimated displays 100% and arrives with isOverBudgetTrajectory=false.
        getPortfolioPacing.emit(
            samplePacing({
                totalEstimatedHours: 247,
                projectedFinalHours: 247.2,
                isOverBudgetTrajectory: false
            })
        );
        await flushPromises();

        const text = element.shadowRoot.textContent;
        expect(text).toContain("100%");
        expect(text).toContain("On track at current pace");
        expect(text).not.toContain("Over budget at current pace");
        expect(element.shadowRoot.querySelector(".summary-variance--over")).toBeNull();
    });

    // ── Home-page visibility ─────────────────────────────────────
    it("renders the card on Home when not hidden in Settings", async () => {
        const element = createComponent();
        CurrentPageReference.emit(HOME_PAGE_REF);
        getHiddenHomeComponents.emit({ deliveryPacingForecast: false });
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        expect(element.shadowRoot.querySelector(".pacing-card")).not.toBeNull();
    });

    it("renders nothing on Home when hidden in Settings", async () => {
        const element = createComponent();
        CurrentPageReference.emit(HOME_PAGE_REF);
        getHiddenHomeComponents.emit({ deliveryPacingForecast: true });
        getPortfolioPacing.emit(samplePacing());
        await flushPromises();

        expect(element.shadowRoot.querySelector(".pacing-card")).toBeNull();
    });
});
