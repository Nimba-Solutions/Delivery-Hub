/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Pure burn-up model for the WorkItem hours card. Given estimated /
 *               approved / logged hours, returns the bar geometry (segment widths,
 *               ceiling position), an adaptive block unit, and a health band — all
 *               as plain numbers so it unit-tests without a DOM mount. No LWC, no
 *               platform APIs here; the component is a thin SLDS shell over this.
 *
 *               Model: the ceiling is the hours you set (approved if present, else
 *               the estimate). Work fills toward it as three nested shades —
 *               shipped ⊆ approved ⊆ estimated — with logged hours past the cap
 *               drawn red. Headroom (dashed) only renders when nothing exceeds the
 *               ceiling, so the cap line sits mid-bar exactly when it's been broken.
 * @author       Cloud Nimbus LLC
 */

const NICE_UNITS = [1, 2, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000];
const TARGET_BLOCKS = 30; // pick the smallest nice unit that keeps us at/under this

function num(v) {
    const n = Number(v);
    return Number.isFinite(n) && n > 0 ? n : 0;
}

function clampPct(h, scaleMax) {
    if (scaleMax <= 0) return 0;
    const p = (h / scaleMax) * 100;
    if (p < 0) return 0;
    if (p > 100) return 100;
    return p;
}

function pickBlockUnit(scaleMax) {
    if (scaleMax <= TARGET_BLOCKS) return 1;
    for (let i = 0; i < NICE_UNITS.length; i++) {
        if (scaleMax / NICE_UNITS[i] <= TARGET_BLOCKS) return NICE_UNITS[i];
    }
    return NICE_UNITS[NICE_UNITS.length - 1];
}

/**
 * @param {{estimated:number, approved:number, logged:number}} input
 * @returns burn-up model (see file header)
 */
export function computeBurnup(input) {
    const estimated = num(input && input.estimated);
    const approved = num(input && input.approved);
    const logged = num(input && input.logged);

    const ceiling = approved > 0 ? approved : estimated > 0 ? estimated : 0;
    const ceilingSource =
        approved > 0 ? "approved" : estimated > 0 ? "estimated" : "none";

    if (ceiling <= 0) {
        return {
            empty: true,
            health: "empty",
            ceiling: 0,
            ceilingSource,
            scaleMax: 0,
            blockUnit: 1,
            ceilingPct: 0,
            segments: {
                shippedPct: 0,
                overCapPct: 0,
                approvedRemainingPct: 0,
                estimatedBeyondPct: 0,
                headroomPct: 0
            },
            estimated,
            approved,
            logged
        };
    }

    const cap = ceiling;
    const fillMax = Math.max(approved, estimated, logged);
    // Only pad in headroom when nothing has exceeded the ceiling; otherwise the
    // overflow defines the right edge and the cap line sits mid-bar.
    const scaleMax = fillMax <= cap ? cap * 1.2 : fillMax;

    const shippedWithinCap = Math.min(logged, cap);
    const overCap = Math.max(0, logged - cap);
    const approvedRemaining = Math.max(0, cap - logged);
    const estimatedBeyond = Math.max(0, estimated - Math.max(cap, logged));
    const headroom = Math.max(0, scaleMax - Math.max(cap, logged, estimated));

    let health;
    if (overCap > 0) {
        health = "over";
    } else if (estimated > cap || logged >= cap * 0.85) {
        health = "approaching";
    } else {
        health = "healthy";
    }

    return {
        empty: false,
        health,
        ceiling,
        ceilingSource,
        scaleMax,
        blockUnit: pickBlockUnit(scaleMax),
        ceilingPct: clampPct(cap, scaleMax),
        segments: {
            shippedPct: clampPct(shippedWithinCap, scaleMax),
            overCapPct: clampPct(overCap, scaleMax),
            approvedRemainingPct: clampPct(approvedRemaining, scaleMax),
            estimatedBeyondPct: clampPct(estimatedBeyond, scaleMax),
            headroomPct: clampPct(headroom, scaleMax)
        },
        estimated,
        approved,
        logged
    };
}
