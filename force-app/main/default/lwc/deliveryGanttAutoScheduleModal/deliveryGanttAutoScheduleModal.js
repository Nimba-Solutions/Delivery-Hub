/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Two-stage Gantt auto-schedule modal. Stage 1 collects direction
 *               (scope, anchor date, lock policy, working calendar, hours/day,
 *               leveling algo). Stage 2 renders the per-task delta checklist
 *               returned by NimbusGantt.computeSchedule (+ serialLevel /
 *               parallelLevel) and on Apply dispatches per-row PATCHes into the
 *               host gantt's pendingBuffer. The existing audit-pass Submit
 *               (deliveryProFormaTimeline:680-712) drains the buffer via
 *               commitGanttPatches Apex — no new server endpoint.
 *
 *               Assumes window.NimbusGantt is loaded by the parent
 *               deliveryProFormaTimeline (NG 0.190.2 bundle ships AutoSchedulePlugin
 *               + computeSchedule + serialLevel + parallelLevel as pure functions).
 *               Calendar bridge is inline (NG's createCalendarDayBridge isn't
 *               exported in 0.190.2 per agent confirmation).
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track } from 'lwc';

const MS_PER_DAY = 86_400_000;

function parseISO(s) {
    if (!s) return null;
    const parts = String(s).slice(0, 10).split('-').map(Number);
    if (parts.length !== 3 || parts.some(isNaN)) return null;
    return new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]));
}

function fmtISO(d) {
    return d.toISOString().slice(0, 10);
}

function makeCalendarDayBridge() {
    return {
        addDays(start, days) {
            const d = parseISO(start);
            if (!d) return start;
            return fmtISO(new Date(d.getTime() + days * MS_PER_DAY));
        },
        daysBetween(start, end) {
            const a = parseISO(start);
            const b = parseISO(end);
            if (!a || !b) return 0;
            return Math.round((b.getTime() - a.getTime()) / MS_PER_DAY);
        }
    };
}

function makeMondayFridayBridge() {
    // workingDays: 1=Mon ... 5=Fri (UTC). Skip 0=Sun, 6=Sat.
    const isWorkingDay = (date) => {
        const dow = date.getUTCDay();
        return dow >= 1 && dow <= 5;
    };
    return {
        addDays(start, days) {
            const d = parseISO(start);
            if (!d) return start;
            const step = days >= 0 ? 1 : -1;
            let remaining = Math.abs(days);
            const cursor = new Date(d.getTime());
            while (remaining > 0) {
                cursor.setUTCDate(cursor.getUTCDate() + step);
                if (isWorkingDay(cursor)) {
                    remaining -= 1;
                }
            }
            return fmtISO(cursor);
        },
        daysBetween(start, end) {
            const a = parseISO(start);
            const b = parseISO(end);
            if (!a || !b) return 0;
            const step = b.getTime() >= a.getTime() ? 1 : -1;
            let count = 0;
            const cursor = new Date(a.getTime());
            while (cursor.getTime() !== b.getTime()) {
                cursor.setUTCDate(cursor.getUTCDate() + step);
                if (isWorkingDay(cursor)) {
                    count += step;
                }
            }
            return count;
        }
    };
}

export default class DeliveryGanttAutoScheduleModal extends LightningElement {
    /**
     * Parent-supplied snapshot of the Gantt state at modal-open time.
     * tasks: Map<taskId, GanttTask>  — must include id, startDate, endDate.
     *        Strongly recommended to also include name, parentId, criticalPath,
     *        priority, and any field used as the resourceId (DeveloperLookup__c).
     */
    @api tasks;

    /**
     * dependencies: Map<depId, GanttDependency> — source, target, type, lag.
     */
    @api dependencies;

    /**
     * Callback supplied by the parent for committing a single PATCH into the
     * gantt's pendingBuffer. Signature: ({ taskId, changes }) => void.
     * Parent wires this to handle.dispatch({ type: 'PATCH', taskId, changes }).
     */
    @api dispatcher;

    /**
     * Subtree-root WI Id (when scope = 'subtree'). Optional; if absent, the
     * 'subtree' scope falls back to 'visible' (all tasks supplied).
     */
    @api rootTaskId;

    // ── Stage state ─────────────────────────────────────────────────────────
    @track stage = 'settings'; // 'settings' | 'review'

    // ── Settings (Stage 1) ──────────────────────────────────────────────────
    @track scope = 'visible';
    @track projectStart = '';
    @track direction = 'forward';
    @track lockManualStarts = true;
    @track mondayFridayOnly = false;
    @track hoursPerDay = 8;
    @track levelingAlgorithm = 'serial';

    // ── Preview/review state (Stage 2) ──────────────────────────────────────
    @track deltaRows = [];
    @track violations = [];
    @track conflicts = [];
    @track projectStartDateOut = '';
    @track projectEndDateOut = '';
    @track totalDurationOut = 0;
    @track running = false;
    @track errorMessage = '';

    connectedCallback() {
        if (!this.projectStart) {
            const today = new Date();
            const isoDay = `${today.getUTCFullYear()}-${String(today.getUTCMonth() + 1).padStart(2, '0')}-${String(today.getUTCDate()).padStart(2, '0')}`;
            this.projectStart = isoDay;
        }
    }

    // ── Computed getters ────────────────────────────────────────────────────
    get isStageSettings() { return this.stage === 'settings'; }
    get isStageReview() { return this.stage === 'review'; }
    get stageLabel() { return this.isStageSettings ? 'Step 1 of 2 · Settings' : 'Step 2 of 2 · Review'; }

    get scopeOptions() {
        return [
            { label: 'All visible tasks', value: 'visible' },
            { label: 'This project (subtree of root WI)', value: 'subtree' }
        ];
    }
    get directionOptions() {
        return [
            { label: 'Forward (from anchor date)', value: 'forward' },
            { label: 'Backward (toward a deadline)', value: 'backward' }
        ];
    }
    get levelingOptions() {
        return [
            { label: 'Serial (priority-based)', value: 'serial' },
            { label: 'Parallel (forward-pack)', value: 'parallel' },
            { label: 'Skip leveling (CPM only)', value: 'none' }
        ];
    }
    get scopeHelp() {
        return this.scope === 'subtree'
            ? 'Only the descendants of the current root WI are rescheduled.'
            : 'All tasks currently visible on the gantt are rescheduled.';
    }

    get hasDeltas() { return this.deltaRows && this.deltaRows.length > 0; }
    get hasViolations() { return this.violations && this.violations.length > 0; }
    get hasConflicts() { return this.conflicts && this.conflicts.length > 0; }
    get violationCount() { return this.violations.length; }
    get conflictCount() { return this.conflicts.length; }
    get selectedCount() { return this.deltaRows.filter(r => r.selected).length; }
    get applyDisabled() { return this.selectedCount === 0; }
    get applyLabel() {
        const n = this.selectedCount;
        return n === 0 ? 'Apply' : `Apply ${n} change${n === 1 ? '' : 's'}`;
    }

    get reviewHeadline() {
        const range = this.projectStartDateOut && this.projectEndDateOut
            ? `${this.projectStartDateOut} → ${this.projectEndDateOut}`
            : 'Schedule preview';
        const n = this.deltaRows.length;
        const v = this.violations.length;
        return `${range} · ${n} task${n === 1 ? '' : 's'} would move${v ? ` · ${v} violation${v === 1 ? '' : 's'}` : ''}`;
    }

    // ── Handlers (Stage 1) ──────────────────────────────────────────────────
    handleScopeChange(e) { this.scope = e.detail.value; }
    handleProjectStartChange(e) { this.projectStart = e.detail.value; }
    handleDirectionChange(e) { this.direction = e.detail.value; }
    handleLevelingChange(e) { this.levelingAlgorithm = e.detail.value; }
    handleHoursPerDayChange(e) {
        const v = parseFloat(e.detail.value);
        this.hoursPerDay = isFinite(v) && v > 0 ? v : 8;
    }
    handleLockToggle(e) { this.lockManualStarts = e.target.checked; }
    handleCalendarToggle(e) { this.mondayFridayOnly = e.target.checked; }

    // ── Handlers (Stage 2) ──────────────────────────────────────────────────
    handleDeltaToggle(e) {
        const taskId = e.target.dataset.taskId;
        const checked = e.target.checked;
        this.deltaRows = this.deltaRows.map(row =>
            row.taskId === taskId ? { ...row, selected: checked } : row);
    }

    handleBack() {
        this.stage = 'settings';
        this.errorMessage = '';
    }

    // ── Workflow ────────────────────────────────────────────────────────────
    handleBackdropClick(e) {
        // Closes the modal only when the click landed on the backdrop itself.
        if (e.target === e.currentTarget) {
            this.handleCancel();
        }
    }
    stopPropagation(e) { e.stopPropagation(); }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleRunPreview() {
        this.errorMessage = '';
        this.running = true;
        try {
            const result = this.computePreview();
            this.applyPreviewToState(result);
            this.stage = 'review';
        } catch (err) {
            this.errorMessage = 'Could not compute schedule: ' + (err && err.message ? err.message : String(err));
            // eslint-disable-next-line no-console
            console.error('[deliveryGanttAutoScheduleModal] computePreview failed', err);
        } finally {
            this.running = false;
        }
    }

    handleApply() {
        if (!this.dispatcher) {
            this.errorMessage = 'Cannot apply — host did not supply a dispatcher.';
            return;
        }
        const selected = this.deltaRows.filter(r => r.selected);
        for (const row of selected) {
            try {
                this.dispatcher({
                    taskId: row.taskId,
                    changes: { startDate: row.newStart, endDate: row.newEnd }
                });
            } catch (err) {
                // eslint-disable-next-line no-console
                console.error('[deliveryGanttAutoScheduleModal] dispatch failed for', row.taskId, err);
            }
        }
        this.dispatchEvent(new CustomEvent('applied', {
            detail: { appliedCount: selected.length }
        }));
        this.dispatchEvent(new CustomEvent('close'));
    }

    // ── Core: build NG inputs, call computeSchedule + leveling ──────────────
    computePreview() {
        const NG = (typeof window !== 'undefined') ? window.NimbusGantt : null;
        if (!NG || typeof NG.computeSchedule !== 'function') {
            throw new Error('NimbusGantt.computeSchedule is not loaded. Bundle 0.190.2 required.');
        }

        const scopedTasksMap = this.buildScopedTaskMap();
        if (!scopedTasksMap || scopedTasksMap.size === 0) {
            throw new Error('No tasks in scope to schedule.');
        }
        const scopedDepsMap = this.buildScopedDependencyMap(scopedTasksMap);

        const constraints = this.buildConstraintsMap(scopedTasksMap);
        const calendar = this.mondayFridayOnly
            ? makeMondayFridayBridge()
            : makeCalendarDayBridge();

        const scheduleOptions = {
            projectStart: this.projectStart,
            direction: this.direction,
            constraints,
            respectWorkCalendar: this.mondayFridayOnly
        };

        // 1. CPM pass
        const scheduleResult = NG.computeSchedule(
            scopedTasksMap,
            scopedDepsMap,
            scheduleOptions,
            calendar
        );

        // 2. Apply CPM result to working copy for leveling input
        const workingCopy = this.buildWorkingCopy(scopedTasksMap, scheduleResult.scheduledTasks);

        // 3. Optional leveling pass
        let levelingResult = null;
        const leveledMap = new Map();
        if (this.levelingAlgorithm !== 'none' && this.hoursPerDay > 0) {
            const { resources, assignments } = this.buildLevelingInputs(scopedTasksMap);
            if (resources.length > 0 && assignments.length > 0) {
                const fn = this.levelingAlgorithm === 'parallel' ? NG.parallelLevel : NG.serialLevel;
                if (typeof fn === 'function') {
                    levelingResult = fn(workingCopy, assignments, resources);
                    if (levelingResult && levelingResult.adjustedTasks) {
                        levelingResult.adjustedTasks.forEach((dates, taskId) => {
                            leveledMap.set(taskId, dates);
                        });
                    }
                }
            }
        }

        return { scheduleResult, leveledMap, levelingResult, scopedTasksMap };
    }

    buildScopedTaskMap() {
        const out = new Map();
        if (!this.tasks) return out;
        const isMap = typeof this.tasks.forEach === 'function' && typeof this.tasks.get === 'function';
        const iter = isMap
            ? Array.from(this.tasks.values())
            : Array.isArray(this.tasks) ? this.tasks : Object.values(this.tasks || {});

        if (this.scope === 'subtree' && this.rootTaskId) {
            // BFS over parentId
            const wanted = new Set([this.rootTaskId]);
            let frontier = new Set([this.rootTaskId]);
            for (let depth = 0; depth < 10 && frontier.size > 0; depth++) {
                const next = new Set();
                for (const t of iter) {
                    if (t && t.parentId && frontier.has(t.parentId) && !wanted.has(t.id)) {
                        wanted.add(t.id);
                        next.add(t.id);
                    }
                }
                frontier = next;
            }
            for (const t of iter) {
                if (t && wanted.has(t.id)) out.set(t.id, t);
            }
        } else {
            for (const t of iter) {
                if (t && t.id) out.set(t.id, t);
            }
        }
        return out;
    }

    buildScopedDependencyMap(scopedTasksMap) {
        const out = new Map();
        if (!this.dependencies) return out;
        const isMap = typeof this.dependencies.forEach === 'function' && typeof this.dependencies.get === 'function';
        const iter = isMap
            ? Array.from(this.dependencies.values())
            : Array.isArray(this.dependencies) ? this.dependencies : Object.values(this.dependencies || {});
        for (const dep of iter) {
            if (!dep || !dep.id) continue;
            if (scopedTasksMap.has(dep.source) && scopedTasksMap.has(dep.target)) {
                out.set(dep.id, dep);
            }
        }
        return out;
    }

    buildConstraintsMap(scopedTasksMap) {
        const out = new Map();
        if (!this.lockManualStarts) return out;
        // Heuristic: any task with a recorded manualStartFlag or pinned attribute is locked.
        // Fallback: if the parent gantt doesn't surface such a flag, we don't lock anything
        // — let the user re-lock via a future per-row toggle in the review stage.
        scopedTasksMap.forEach((task, id) => {
            if (task && (task.manualStart === true || task.locked === true || task.constraint)) {
                const date = task.startDate;
                if (date) {
                    out.set(id, { type: 'MSO', date });
                }
            }
        });
        return out;
    }

    buildWorkingCopy(scopedTasksMap, scheduledTasks) {
        const out = new Map();
        scopedTasksMap.forEach((task, id) => {
            const sched = scheduledTasks && scheduledTasks.get(id);
            if (sched) {
                out.set(id, { ...task, startDate: sched.startDate, endDate: sched.endDate });
            } else {
                out.set(id, { ...task });
            }
        });
        return out;
    }

    buildLevelingInputs(scopedTasksMap) {
        // Resources = distinct non-null developer ids. maxUnits = hoursPerDay.
        const resourceIds = new Set();
        const assignments = [];
        scopedTasksMap.forEach((task, id) => {
            const devId = task && (task.developerId || task.resourceId || task.assigneeId);
            const hours = task && (task.estimatedHours || task.duration);
            if (devId) {
                resourceIds.add(devId);
                if (hours && hours > 0) {
                    assignments.push({
                        taskId: id,
                        resourceId: devId,
                        units: this.hoursPerDay > 0 ? hours / this.hoursPerDay : hours
                    });
                }
            }
        });
        const resources = Array.from(resourceIds).map(rid => ({
            id: rid,
            maxUnits: this.hoursPerDay
        }));
        return { resources, assignments };
    }

    applyPreviewToState({ scheduleResult, leveledMap, levelingResult, scopedTasksMap }) {
        this.violations = (scheduleResult && scheduleResult.violations) || [];
        this.projectStartDateOut = scheduleResult && scheduleResult.projectStart || this.projectStart;
        this.projectEndDateOut = scheduleResult && scheduleResult.projectEnd || '';
        this.totalDurationOut = scheduleResult && scheduleResult.totalDuration || 0;

        this.conflicts = [];
        if (levelingResult && Array.isArray(levelingResult.conflicts)) {
            this.conflicts = levelingResult.conflicts.map((c, idx) => ({
                id: c.id || `conflict-${idx}`,
                label: c.message || `Resource ${c.resourceId || '?'} over-allocated on ${c.date || 'unknown date'}`
            }));
        }

        // Build delta rows by comparing original dates to final (leveled if present, else scheduled)
        const rows = [];
        const scheduled = scheduleResult && scheduleResult.scheduledTasks;
        scopedTasksMap.forEach((task, id) => {
            const origStart = task.startDate;
            const origEnd = task.endDate;
            const cpm = scheduled && scheduled.get(id);
            const lev = leveledMap && leveledMap.get(id);
            const final = lev || cpm;
            if (!final) return;
            if (final.startDate === origStart && final.endDate === origEnd) return;

            const movedByCpm = cpm && (cpm.startDate !== origStart || cpm.endDate !== origEnd);
            const movedByLeveling = !!lev && cpm && (lev.startDate !== cpm.startDate || lev.endDate !== cpm.endDate);

            let tagLabel = 'Schedule';
            let tagClass = 'as-delta-tag';
            if (movedByLeveling && movedByCpm) {
                tagLabel = 'Both';
                tagClass = 'as-delta-tag is-both';
            } else if (movedByLeveling) {
                tagLabel = 'Leveling';
                tagClass = 'as-delta-tag is-leveling';
            }

            const criticalPath = !!(task && task.criticalPath);
            rows.push({
                taskId: id,
                name: task.name || id,
                oldRange: `${origStart || '?'} → ${origEnd || '?'}`,
                newRange: `${final.startDate} → ${final.endDate}`,
                newStart: final.startDate,
                newEnd: final.endDate,
                tagLabel,
                tagClass,
                criticalPath,
                rowClass: criticalPath ? 'as-delta-row is-critical' : 'as-delta-row',
                selected: true
            });
        });
        this.deltaRows = rows;
    }
}
