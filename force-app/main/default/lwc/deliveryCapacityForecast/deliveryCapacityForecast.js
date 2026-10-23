import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getForecastItems from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHoursAnalyticsController.getForecastItems';
import getTeamCapacity from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCapacityService.getTeamCapacity';

// ── Scheduler constants (synthesized bands; no DH data home yet — pass two may
//    model maintenance/run-point as real fields). Ported 1:1 from the prototype
//    cloudnimbusllc.com/src/app/glen/mf-forecast-stack-0607/MfForecastStack0607.tsx.
const MAINT = 90; // measured maintenance run-rate, h/mo, reserved off the top
const HOURS_PER_DEV = 160; // ~1 developer-month — the dev-equivalent modeling UNIT only
const ORCH_START = 0.35; // run-point load as a fraction of output during spin-up
const ORCH_FLOOR = 0.1; // steady-state run-point fraction once the team absorbs it
const HORIZON = 18; // months drawn

// ── Capacity source (DECISION-G3 / W5.2) ────────────────────────────────────
// The pace ceiling is CMT-driven: DeliveryCapacityService.getTeamCapacity reads
// DeveloperCapacity__mdt (the single capacity source of truth) and returns the
// team's monthly hours + developer-equivalents. When the subscriber org has no
// CMT rows (or the call fails), this EXPLICIT fallback reproduces the slider's
// historical hardcoded model — 3 developers × 160 h/mo = 480 h/mo — and the card
// labels the number as a default. Never a silent near-zero.
const FALLBACK_DEV_EQUIVALENTS = 3;
const FALLBACK_CAPACITY = {
    monthlyCapacityHours: HOURS_PER_DEV * FALLBACK_DEV_EQUIVALENTS,
    perDeveloperMonthlyHours: HOURS_PER_DEV,
    developerEquivalents: FALLBACK_DEV_EQUIVALENTS,
    isConfigured: false
};
const MIN_SLIDER_MAX = 6; // never shrink the historical 1–6 dev range

const GREENLIT = 'greenlit';

// Stacked bands, drawn bottom→top. committed + conditional are REAL DH items
// (split by tier); maintenance + run-point are synthesized constants.
const LAYERS = [
    { key: 'committed', label: 'Greenlit / in-motion', color: '#10b981' },
    { key: 'maintenance', label: 'Predictable maintenance', color: '#6366f1' },
    { key: 'conditional', label: 'Build-out (scoped, pending)', color: '#f59e0b' },
    { key: 'orchestration', label: 'Run-point (tapering)', color: '#475569' }
];

const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export default class DeliveryCapacityForecast extends NavigationMixin(LightningElement) {
    @track items = [];
    @track capacity = FALLBACK_CAPACITY;
    devs = FALLBACK_DEV_EQUIVALENTS;
    cumulative = false;
    error;
    loading = true;

    // getForecastItems is non-cacheable by design (it must reflect reorder
    // writes on the next read, never a stale LDS cache), so it cannot be @wired
    // — a wired Apex method must be @AuraEnabled(cacheable=true), and wiring a
    // plain @AuraEnabled method throws "Apex methods that are to be cached must
    // be marked as @AuraEnabled(cacheable=true)" at render. Call it imperatively
    // on mount instead; the slider then reflows client-side with no further hops.
    // getTeamCapacity loads alongside it: the CMT-derived ceiling calibrates the
    // slider before first paint, and a failed capacity read degrades to the
    // documented fallback model without killing the card.
    connectedCallback() {
        this.loadItems();
    }

    loadItems() {
        this.loading = true;
        const capacityPromise = getTeamCapacity({ workflowType: null }).catch(() => null);
        Promise.all([getForecastItems(), capacityPromise])
            .then(([data, capacity]) => {
                this.capacity = capacity || FALLBACK_CAPACITY;
                this.devs = this.defaultDevs;
                // Only forward work packs: drop terminal-stage items and anything
                // with no remaining hours — they are history, not future schedule.
                this.items = (data || [])
                    .filter((d) => !d.isTerminal && (d.remaining || 0) > 0)
                    .map((d) => ({
                        id: d.id,
                        name: d.name,
                        tier: d.tier,
                        remaining: d.remaining || 0,
                        startDate: d.startDate
                    }));
                this.error = undefined;
            })
            .catch((error) => {
                this.error = (error && error.body && error.body.message) || 'Unable to load forecast items.';
                this.items = [];
            })
            .finally(() => {
                this.loading = false;
            });
    }

    // ── Slider / toggle handlers ────────────────────────────────────────────
    handleDevs(event) {
        this.devs = parseInt(event.target.value, 10);
    }

    toggleCumulative() {
        this.cumulative = !this.cumulative;
    }

    // ── Capacity-derived slider model (W5.2) ────────────────────────────────

    get isFallbackCapacity() {
        return !(this.capacity && this.capacity.isConfigured);
    }

    get perDevHours() {
        const cap = this.capacity;
        if (cap && cap.perDeveloperMonthlyHours > 0) {
            return cap.perDeveloperMonthlyHours;
        }
        return HOURS_PER_DEV;
    }

    get devEquivalents() {
        const cap = this.capacity;
        if (cap && cap.developerEquivalents > 0) {
            return cap.developerEquivalents;
        }
        return FALLBACK_DEV_EQUIVALENTS;
    }

    /** The slider position that equals the org's real (or fallback) capacity. */
    get defaultDevs() {
        return Math.min(Math.max(1, this.devEquivalents), this.maxDevs);
    }

    get maxDevs() {
        return Math.max(MIN_SLIDER_MAX, this.devEquivalents + 2);
    }

    get maxDevsLabel() {
        return `${this.maxDevs} devs`;
    }

    get ceiling() {
        return this.devs * this.perDevHours;
    }

    get devLabel() {
        return `${this.devs} developer${this.devs > 1 ? 's' : ''} · ~${Math.round(this.ceiling)} h/mo`;
    }

    get capacitySourceNote() {
        if (this.isFallbackCapacity) {
            return `Capacity source: default model (${FALLBACK_DEV_EQUIVALENTS} developers × ${HOURS_PER_DEV} h/mo) — add Developer Capacity records to calibrate.`;
        }
        return 'Capacity source: your configured team capacity (Developer Capacity settings).';
    }

    get cumulativeLabel() {
        return this.cumulative ? 'Cumulative' : 'Per month';
    }

    get hasItems() {
        return !this.loading && !this.error && this.items.length > 0;
    }

    get isEmpty() {
        return !this.loading && !this.error && this.items.length === 0;
    }

    // ── Greedy scheduler with a staffing ramp ───────────────────────────────
    // Ported from buildSchedule(ceiling, devs): effective ceiling climbs over the
    // first ~2 months (you can't hire instantly), committed work drains first,
    // build-out packs into what's left, run-point rides on top as a declining
    // fraction of output. Runs client-side so the slider reflows with no Apex hop.
    get schedule() {
        const ceiling = this.ceiling;
        const devs = this.devs;
        const declinePerMonth = 0.02 + (devs - 1) * 0.012;

        // committed (greenlit) drains first as one pool; build-out items pack in
        // order (start date, then largest first) — pass two wires drag-reorder.
        let committedLeft = 0;
        const build = [];
        for (const it of this.items) {
            if (it.tier === GREENLIT) {
                committedLeft += it.remaining;
            } else {
                build.push({ ...it, left: it.remaining });
            }
        }
        build.sort((a, b) => {
            const ad = a.startDate || '9999-12-31';
            const bd = b.startDate || '9999-12-31';
            if (ad !== bd) return ad < bd ? -1 : 1;
            return b.left - a.left;
        });

        const months = [];
        let ip = 0;
        let mi = 0;
        let landsIndex = -1;
        while ((committedLeft > 0.01 || ip < build.length) && mi < HORIZON) {
            const rampFactor = Math.min(1, 0.45 + mi * 0.275);
            const effCeiling = ceiling * rampFactor;
            let a = Math.max(20, effCeiling - MAINT);

            const cAlloc = Math.min(committedLeft, a);
            committedLeft -= cAlloc;
            a -= cAlloc;

            let bAlloc = 0;
            const allocs = [];
            while (ip < build.length && a > 0.01) {
                const it = build[ip];
                const take = Math.min(it.left, a);
                it.left -= take;
                a -= take;
                bAlloc += take;
                if (take > 0.01) allocs.push({ id: it.id, name: it.name, hours: Math.round(take) });
                if (it.left <= 0.01) {
                    landsIndex = mi;
                    ip++;
                }
            }
            if (cAlloc > 0.01 && landsIndex < mi && committedLeft <= 0.01) landsIndex = mi;

            const output = cAlloc + MAINT + bAlloc;
            const glenRate = Math.max(ORCH_FLOOR, ORCH_START - mi * declinePerMonth);
            months.push({
                index: mi,
                committed: Math.round(cAlloc),
                maintenance: MAINT,
                conditional: Math.round(bAlloc),
                orchestration: Math.round(glenRate * output),
                allocs
            });
            mi++;
        }
        const overflow = committedLeft > 0.01 || ip < build.length;
        return { months, overflow, landsIndex };
    }

    // ── Render model: per-month (or cumulative) stacked bars scaled to peak ──
    get chartMonths() {
        const sched = this.schedule;
        const running = { committed: 0, maintenance: 0, conditional: 0, orchestration: 0 };

        const rows = sched.months.map((mo) => {
            const vals = {};
            let total = 0;
            for (const l of LAYERS) {
                let v = mo[l.key];
                if (this.cumulative) {
                    running[l.key] += v;
                    v = running[l.key];
                }
                vals[l.key] = v;
                total += v;
            }
            return { ...mo, vals, total };
        });

        const peak = Math.max(1, ...rows.map((r) => r.total));
        return rows.map((r) => ({
            key: `m${r.index}`,
            label: this.monthLabel(r.index),
            total: r.total,
            segments: LAYERS.filter((l) => r.vals[l.key] > 0).map((l) => ({
                key: l.key,
                color: l.color,
                style: `height:${((r.vals[l.key] / r.total) * 100).toFixed(2)}%;background:${l.color};`,
                title: `${l.label}: ${r.vals[l.key]}h`
            })),
            barStyle: `height:${((r.total / peak) * 230).toFixed(0)}px;`
        }));
    }

    get legend() {
        return LAYERS.map((l) => ({ key: l.key, label: l.label, swatch: `background:${l.color};` }));
    }

    get landsBy() {
        const sched = this.schedule;
        if (sched.overflow || sched.landsIndex < 0) return `beyond ${HORIZON} mo`;
        return this.monthLabel(sched.landsIndex);
    }

    get paceHint() {
        // Anchored on the CMT-derived (or fallback) capacity position, not a
        // hardcoded "3": the default slider position IS today's real pace.
        const base = this.defaultDevs;
        if (this.devs < base) return 'Conservative — protect cash, slower build';
        if (this.devs === base) return '≈ today’s pace';
        if (this.devs === base + 1) return 'Leaning in — important work pulls forward';
        return 'Full throttle — fastest path to the milestones';
    }

    // Month label N months from the current month. Watermark/last-worklog anchoring
    // is a pass-two refinement; pass one anchors on the current month.
    monthLabel(offset) {
        const base = new Date();
        const m = base.getMonth() + offset;
        const year = base.getFullYear() + Math.floor(m / 12);
        const name = MONTH_NAMES[((m % 12) + 12) % 12];
        const yy = String(year).slice(2);
        return year === base.getFullYear() ? name : `${name} ’${yy}`;
    }
}
