/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Unit spec for the pure burn-up model (no DOM mount). Anchors the
 *               adaptive-block math, the nested shipped⊆approved⊆estimated bands,
 *               health thresholds, the over-cap (red) overflow, and the empty
 *               state. The component is a thin SLDS shell over this function.
 * @author       Cloud Nimbus LLC
 */
import { computeBurnup } from "../burnupModel";

const sumSegments = (s) =>
    s.shippedPct +
    s.overCapPct +
    s.approvedRemainingPct +
    s.estimatedBeyondPct +
    s.headroomPct;

describe("computeBurnup", () => {
    it("is empty when no approved and no estimated ceiling exists", () => {
        const m = computeBurnup({ estimated: 0, approved: 0, logged: 0 });
        expect(m.empty).toBe(true);
        expect(m.health).toBe("empty");
    });

    it("uses approved hours as the ceiling and leaves visible headroom when nothing exceeds it", () => {
        const m = computeBurnup({ estimated: 8, approved: 10, logged: 4 });
        expect(m.empty).toBe(false);
        expect(m.ceiling).toBe(10);
        expect(m.ceilingSource).toBe("approved");
        expect(m.health).toBe("healthy");
        // ceiling sits below the right edge so headroom shows
        expect(m.ceilingPct).toBeGreaterThan(0);
        expect(m.ceilingPct).toBeLessThan(100);
        expect(m.segments.headroomPct).toBeGreaterThan(0);
        expect(m.segments.overCapPct).toBe(0);
        expect(Math.round(sumSegments(m.segments))).toBe(100);
    });

    it("falls back to the estimate as the ceiling when nothing is approved", () => {
        const m = computeBurnup({ estimated: 10, approved: 0, logged: 3 });
        expect(m.ceiling).toBe(10);
        expect(m.ceilingSource).toBe("estimated");
    });

    it("renders logged hours past the cap as a red over-cap band and flags health=over", () => {
        const m = computeBurnup({ estimated: 4, approved: 4, logged: 8 });
        expect(m.health).toBe("over");
        expect(m.segments.overCapPct).toBeGreaterThan(0);
        expect(m.segments.approvedRemainingPct).toBe(0);
        // bar fills to the overflow edge → no headroom
        expect(m.segments.headroomPct).toBe(0);
        expect(Math.round(sumSegments(m.segments))).toBe(100);
    });

    it("flags health=approaching when scope (estimate) exceeds the approved cap", () => {
        const m = computeBurnup({ estimated: 20, approved: 10, logged: 2 });
        expect(m.health).toBe("approaching");
        expect(m.segments.estimatedBeyondPct).toBeGreaterThan(0);
    });

    it("flags health=approaching when logged is within 15% of the cap", () => {
        const m = computeBurnup({ estimated: 10, approved: 10, logged: 9 });
        expect(m.health).toBe("approaching");
    });

    it("keeps blocks literal (1h) for small items", () => {
        const m = computeBurnup({ estimated: 8, approved: 12, logged: 4 });
        expect(m.blockUnit).toBe(1);
    });

    it("rescales the block unit so a large item stays ~20-30 blocks", () => {
        const m = computeBurnup({ estimated: 0, approved: 400, logged: 200 });
        expect(m.blockUnit).toBeGreaterThan(1);
        expect(m.scaleMax / m.blockUnit).toBeLessThanOrEqual(30);
        expect(m.scaleMax / m.blockUnit).toBeGreaterThan(8);
    });

    it("coerces null/garbage inputs to zero rather than NaN", () => {
        const m = computeBurnup({ estimated: null, approved: undefined, logged: "x" });
        expect(m.empty).toBe(true);
        expect(Number.isNaN(m.scaleMax)).toBe(false);
    });
});
