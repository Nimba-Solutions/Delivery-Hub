var NimbusGanttApp = (function(exports) {
  "use strict";
  const GROUP_BAR = {
    "top-priority": "#f87171",
    "active": "#fbbf24",
    "follow-on": "#34d399",
    "proposed": "#60a5fa",
    "deferred": "#cbd5e1"
  };
  const OVER_BUDGET_COLOR = "#f59e0b";
  const STAGE_COLORS = {
    "Backlog": "#64748b",
    "Scoping In Progress": "#64748b",
    "Ready for Sizing": "#3b82f6",
    "Ready for Development": "#22c55e",
    "In Development": "#22c55e",
    "Ready for QA": "#a855f7",
    "QA In Progress": "#a855f7",
    "Ready for Client UAT": "#14b8a6",
    "In Client UAT": "#14b8a6",
    "Ready for UAT Sign-off": "#14b8a6",
    "Ready for Deployment": "#f97316",
    "Deploying": "#f97316",
    "Done": "#9ca3af",
    "Deployed to Prod": "#9ca3af",
    "Cancelled": "#cbd5e1",
    "Paused": "#94a3b8",
    "On Hold": "#94a3b8",
    "Blocked": "#ef4444"
  };
  const DONE_STAGES = {
    "Done": true,
    "Deployed to Prod": true,
    "Cancelled": true
  };
  const STAGE_TO_CATEGORY_COLOR = {
    // In Flight — active development (green)
    "In Development": "#10b981",
    "QA In Progress": "#10b981",
    "In Client UAT": "#10b981",
    "Deploying": "#10b981",
    // Next Up — ready/queued (blue)
    "Ready for Development": "#3b82f6",
    "Ready for QA": "#3b82f6",
    "Ready for Client UAT": "#3b82f6",
    "Ready for UAT Sign-off": "#3b82f6",
    "Ready for Deployment": "#3b82f6",
    "Ready for Sizing": "#3b82f6",
    "Scoping In Progress": "#3b82f6",
    // Backlog (amber)
    "Backlog": "#f59e0b",
    // Paused / Blocked
    "Paused": "#94a3b8",
    "On Hold": "#94a3b8",
    "Blocked": "#ef4444",
    // Done (muted slate)
    "Done": "#cbd5e1",
    "Deployed to Prod": "#cbd5e1",
    "Cancelled": "#cbd5e1"
  };
  function pad(n) {
    return n < 10 ? "0" + n : String(n);
  }
  function todayISO() {
    const d = /* @__PURE__ */ new Date();
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  }
  function addDays(iso, n) {
    const d = /* @__PURE__ */ new Date(iso + "T00:00:00");
    d.setDate(d.getDate() + n);
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  }
  function addMonths(iso, n) {
    const d = /* @__PURE__ */ new Date(iso + "T00:00:00");
    d.setMonth(d.getMonth() + n);
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  }
  function darkenColor(hex, f) {
    let h = hex.replace("#", "");
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    const ch = (s) => Math.max(0, Math.round(parseInt(h.substring(s, s + 2), 16) * (1 - f)));
    const x2 = (n) => {
      const s = n.toString(16);
      return s.length < 2 ? "0" + s : s;
    };
    return "#" + x2(ch(0)) + x2(ch(2)) + x2(ch(4));
  }
  function isBucketId(id) {
    return !!(id && (id.indexOf("__bucket_header__") === 0 || id.indexOf("group-") === 0));
  }
  function buildDepthMap(tasks) {
    const byId = {};
    const dm = {};
    tasks.forEach((t) => {
      byId[t.id] = t;
    });
    function depth(id) {
      if (dm[id] !== void 0) return dm[id];
      const t = byId[id];
      if (!t || !t.parentWorkItemId || !byId[t.parentWorkItemId]) {
        dm[id] = 0;
        return 0;
      }
      dm[id] = 1 + depth(t.parentWorkItemId);
      return dm[id];
    }
    tasks.forEach((t) => {
      depth(t.id);
    });
    return dm;
  }
  function buildTasks(tasks) {
    const today = todayISO();
    const fallback = addMonths(today, -1);
    const byId = {};
    tasks.forEach((t) => {
      byId[t.id] = t;
    });
    function resolveRootGroup(id, visited = {}) {
      if (visited[id]) return null;
      visited[id] = true;
      const t = byId[id];
      if (!t) return null;
      if (!t.parentWorkItemId || !byId[t.parentWorkItemId]) return t.priorityGroup || null;
      return resolveRootGroup(t.parentWorkItemId, visited);
    }
    const mapped = tasks.map((t) => {
      const hrs = t.estimatedHours ? Math.round(Number(t.estimatedHours)) : 0;
      const logged = t.loggedHours ? Number(t.loggedHours) : 0;
      const pct = hrs > 0 ? Math.round(logged / hrs * 100) : 0;
      const hLabel = hrs > 0 ? logged > 0 ? hrs + "h (" + pct + "% budget)" : hrs + "h" : "";
      const gid = t.parentWorkItemId ? null : t.priorityGroup || null;
      const overBudget = hrs > 0 && logged >= hrs;
      const baseCol = gid ? GROUP_BAR[gid] || "#94a3b8" : STAGE_TO_CATEGORY_COLOR[t.stage || ""] || STAGE_COLORS[t.stage || ""] || "#94a3b8";
      const col = overBudget ? OVER_BUDGET_COLOR : baseCol;
      const start = t.startDate || fallback;
      const end = t.endDate || addDays(start, 14);
      return {
        id: t.id,
        title: t.title || t.name || t.id,
        name: hrs > 0 ? logged > 0 ? hrs + "h (" + pct + "% budget)" : hrs + "h" : "",
        hoursLabel: hLabel,
        // DM-3 (0.183) — split fields for surfaces that opt into the separate
        // Hours + Budget Used columns. When zero, empty string so the cell
        // renders blank rather than "0h" / "0%".
        hours: hrs > 0 ? hrs + "h" : "",
        budgetUsedPct: hrs > 0 && logged > 0 ? pct + "%" : "",
        startDate: start,
        endDate: end,
        progress: hrs > 0 ? Math.min(logged / hrs, 1) : 0,
        status: t.stage || "",
        color: col,
        groupId: gid,
        parentId: t.parentWorkItemId || void 0,
        sortOrder: Number(t.sortOrder) || 0,
        isInactive: !!t.isInactive,
        metadata: { hoursHigh: hrs, hoursLogged: logged }
      };
    });
    const parentIds = {};
    const childCounts = {};
    mapped.forEach((t) => {
      if (t.parentId) {
        parentIds[t.parentId] = true;
        childCounts[t.parentId] = (childCounts[t.parentId] || 0) + 1;
      }
    });
    function descDates(pid, vis = {}) {
      if (vis[pid]) return { s: [], e: [] };
      vis[pid] = true;
      const r = { s: [], e: [] };
      mapped.forEach((t) => {
        if (t.parentId !== pid) return;
        if (t.startDate) r.s.push(t.startDate);
        if (t.endDate) r.e.push(t.endDate);
        if (parentIds[t.id]) {
          const sub = descDates(t.id, vis);
          r.s = r.s.concat(sub.s);
          r.e = r.e.concat(sub.e);
        }
      });
      return r;
    }
    return mapped.map((t) => {
      if (!parentIds[t.id]) return t;
      const count = childCounts[t.id] || 0;
      const dd = descDates(t.id);
      const allS = [t.startDate].concat(dd.s).filter(Boolean).sort();
      const allE = [t.endDate].concat(dd.e).filter(Boolean).sort();
      const rootGroup = resolveRootGroup(t.id);
      const parentBaseColor = rootGroup ? GROUP_BAR[rootGroup] || "#94a3b8" : t.color || "#64748b";
      const pHrs = t.metadata.hoursHigh;
      const pLogged = t.metadata.hoursLogged;
      const parentOverBudget = pHrs > 0 && pLogged >= pHrs;
      const parentPaint = parentOverBudget ? OVER_BUDGET_COLOR : parentBaseColor;
      return {
        id: t.id,
        title: t.title,
        name: t.name + (count > 0 ? " · " + count + " items" : ""),
        hoursLabel: t.hoursLabel,
        // DM-3: propagate through parent mapping so conditional columns
        // render on parent rows too (typically blank since parents often
        // carry zero direct estimates — rollup math is DM-6, future).
        hours: t.hours,
        budgetUsedPct: t.budgetUsedPct,
        startDate: allS.length ? allS[0] : t.startDate,
        endDate: allE.length ? allE[allE.length - 1] : t.endDate,
        progress: t.progress,
        status: t.status,
        // Darken the root bucket's bar color — all parent bars share the same hue family
        color: darkenColor(parentPaint, 0.25),
        groupId: t.groupId,
        parentId: t.parentId,
        sortOrder: t.sortOrder,
        isInactive: t.isInactive,
        metadata: t.metadata,
        isParent: true
      };
    });
  }
  function buildTasksEpic(tasks) {
    const epicIds = {};
    tasks.forEach((t) => {
      if (!t.parentWorkItemId) epicIds[t.id] = true;
    });
    const taskById = {};
    tasks.forEach((t) => {
      taskById[t.id] = t;
    });
    function getEpic(id, visited = {}) {
      if (visited[id]) return id;
      visited[id] = true;
      if (epicIds[id]) return id;
      const t = taskById[id];
      if (!t || !t.parentWorkItemId) return id;
      return getEpic(t.parentWorkItemId, visited);
    }
    return tasks.map((t) => {
      const epic = getEpic(t.id);
      return {
        ...t,
        parentWorkItemId: t.id === epic ? null : t.parentWorkItemId,
        _epicGroupId: epicIds[t.id] ? t.id : null
      };
    });
  }
  const PROPOSAL_STAGES$1 = {
    "Backlog": true,
    "Scoping In Progress": true,
    "Ready for Sizing": true,
    "Ready for Development": true
  };
  const BACKLOG_OR_EXPANSION_STAGES = {
    "Backlog": true,
    "Scoping In Progress": true
  };
  function applyFilter(tasks, filter, q) {
    let r = tasks;
    if (filter === "active") {
      const cutoff = addDays(todayISO(), -30);
      r = r.filter((t) => {
        if (t.isInactive) return false;
        const stage = t.stage || "";
        if (BACKLOG_OR_EXPANSION_STAGES[stage]) return false;
        if (DONE_STAGES[stage]) {
          return !!(t.endDate && t.endDate >= cutoff);
        }
        if (t.endDate && t.endDate < cutoff) return false;
        return true;
      });
    } else if (filter === "proposal") {
      r = r.filter((t) => PROPOSAL_STAGES$1[t.stage || ""] || t.priorityGroup === "proposed");
    } else if (filter === "done") {
      r = r.filter((t) => !!DONE_STAGES[t.stage || ""]);
    } else if (filter === "real") {
      r = r.filter((t) => !!(t.id && t.id.indexOf("T-") === 0));
    } else if (filter === "workstreams") {
      r = r.filter((t) => !!(t.id && t.id.indexOf("WS-") === 0));
    }
    if (q) {
      const ql = q.toLowerCase();
      r = r.filter((t) => t.title && t.title.toLowerCase().indexOf(ql) !== -1);
    }
    return r;
  }
  function stageToCategory$1(stage) {
    const s = stage || "";
    if (STAGE_TO_CATEGORY_COLOR[s] === "#10b981") return "In Flight";
    if (STAGE_TO_CATEGORY_COLOR[s] === "#3b82f6") return "Next Up";
    if (STAGE_TO_CATEGORY_COLOR[s] === "#f59e0b") return "Backlog";
    if (STAGE_TO_CATEGORY_COLOR[s] === "#ef4444") return "Blocked";
    if (STAGE_TO_CATEGORY_COLOR[s] === "#cbd5e1") return "Done";
    if (STAGE_TO_CATEGORY_COLOR[s] === "#94a3b8") return "Paused";
    return "Paused";
  }
  function computeStats(tasks) {
    const active = tasks.filter((t) => !t.isInactive);
    const est = active.reduce((s, t) => s + (Number(t.estimatedHours) || 0), 0);
    const estLow = active.reduce((s, t) => s + (Number(t.estimatedHoursLow ?? t.estimatedHours) || 0), 0);
    const logged = active.reduce((s, t) => s + (Number(t.loggedHours) || 0), 0);
    const sched = active.filter((t) => t.startDate && t.endDate).length;
    const needDates = active.filter((t) => !t.startDate || !t.endDate).length;
    const counts = {
      "top-priority": 0,
      "active": 0,
      "follow-on": 0,
      "proposed": 0,
      "deferred": 0
    };
    const categoryCounts = {
      "In Flight": 0,
      "Next Up": 0,
      "Backlog": 0,
      "Paused": 0,
      "Blocked": 0,
      "Done": 0
    };
    active.forEach((t) => {
      if (t.priorityGroup && Object.prototype.hasOwnProperty.call(counts, t.priorityGroup)) {
        counts[t.priorityGroup]++;
      }
      const cat = stageToCategory$1(t.stage || "");
      categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;
    });
    return { total: active.length, scheduled: sched, needDates, est: Math.round(est), estLow: Math.round(estLow), logged: Math.round(logged * 10) / 10, counts, categoryCounts };
  }
  function startDepthShading(ganttContainer, depthMap) {
    const applied = [];
    let lastGrad = "";
    let isApplying = false;
    let timer = null;
    function parseRgb(s) {
      const m = s && s.match(/(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/);
      return m ? { r: +m[1], g: +m[2], b: +m[3] } : null;
    }
    function run() {
      if (isApplying) return;
      isApplying = true;
      const scrollContent = ganttContainer.querySelector(".ng-scroll-content");
      if (scrollContent) {
        const existing = scrollContent.querySelector("[data-depth-stripes]");
        if (existing) existing.remove();
      }
      const rows = ganttContainer.querySelectorAll(".ng-grid-row");
      let bucketRgb = null;
      const stripes = [];
      for (let ri = 0; ri < rows.length; ri++) {
        const el2 = rows[ri];
        if (el2.classList.contains("ng-group-row")) {
          const bgRgb = parseRgb(el2.style.background || "");
          if (bgRgb) stripes.push({ top: el2.offsetTop, height: el2.offsetHeight, color: `rgba(${bgRgb.r},${bgRgb.g},${bgRgb.b},0.18)` });
          bucketRgb = bgRgb;
          continue;
        }
        const tid = el2.getAttribute("data-task-id") || "";
        const d = depthMap[tid] !== void 0 ? depthMap[tid] : 0;
        let target = "";
        if (bucketRgb) {
          const alpha = Math.max(0.03, 0.12 - d * 0.04);
          target = `rgba(${bucketRgb.r},${bucketRgb.g},${bucketRgb.b},${alpha})`;
          stripes.push({ top: el2.offsetTop, height: el2.offsetHeight, color: target });
        }
        let found = false;
        for (let ai = 0; ai < applied.length; ai++) {
          if (applied[ai].el === el2) {
            found = true;
            if (applied[ai].val !== target) {
              applied[ai].val = target;
              if (target) el2.style.setProperty("background", target, "important");
              else el2.style.removeProperty("background");
            }
            break;
          }
        }
        if (!found) {
          applied.push({ el: el2, val: target });
          if (target) el2.style.setProperty("background", target, "important");
        }
      }
      if (scrollContent && stripes.length) {
        const liveCanvas = scrollContent.querySelector("canvas");
        if (liveCanvas) {
          const cw = liveCanvas.offsetWidth || liveCanvas.width;
          if (cw > 0) {
            scrollContent.style.backgroundSize = cw + "px 100%";
            scrollContent.style.backgroundRepeat = "no-repeat";
          }
        }
        const totalH = scrollContent.scrollHeight || 2e3;
        const stops = [];
        let lastEnd = 0;
        for (let si = 0; si < stripes.length; si++) {
          const st = stripes[si];
          if (st.top > lastEnd) {
            stops.push("transparent " + lastEnd + "px", "transparent " + st.top + "px");
          }
          stops.push(st.color + " " + st.top + "px", st.color + " " + (st.top + st.height) + "px");
          lastEnd = st.top + st.height;
        }
        if (lastEnd < totalH) stops.push("transparent " + lastEnd + "px", "transparent " + totalH + "px");
        const grad = "linear-gradient(to bottom," + stops.join(",") + ")";
        if (grad !== lastGrad) {
          lastGrad = grad;
          scrollContent.style.backgroundImage = grad;
        }
      }
      isApplying = false;
    }
    const raf = requestAnimationFrame(run);
    const observer = new MutationObserver(() => {
      if (isApplying) return;
      if (timer) clearTimeout(timer);
      timer = setTimeout(run, 50);
    });
    observer.observe(ganttContainer, { childList: true, subtree: true });
    return function cleanup() {
      cancelAnimationFrame(raf);
      if (timer) clearTimeout(timer);
      observer.disconnect();
      const sc = ganttContainer.querySelector(".ng-scroll-content");
      if (sc) {
        sc.style.backgroundImage = "";
        sc.style.backgroundSize = "";
        sc.style.backgroundRepeat = "";
      }
    };
  }
  function startDragReparent(ganttContainer, allTasks, depthMap, onPatch) {
    const DRAG_THRESHOLD = 6;
    const LEAF_STEP = 10;
    const INDENT_BASE = 6;
    const taskById = {};
    allTasks.forEach((t) => {
      taskById[t.id] = t;
    });
    let dragTaskId = null;
    let dragSourceGroup = null;
    let dragRow = null;
    let startY = 0, startX = 0, dragStartX = 0, dragStartDepth = 0;
    let hasMoved = false;
    let ghost = null;
    let spacer = null;
    let pendingIP = null;
    let autoScrollVel = 0;
    let autoScrollRAF = null;
    function getSortOrder(id) {
      const t = taskById[id];
      return t ? Number(t.sortOrder) || 0 : 0;
    }
    function getGroup(id) {
      const t = taskById[id];
      return t ? t.priorityGroup || null : null;
    }
    function getGroupAtY(clientY) {
      const gRows = Array.prototype.slice.call(ganttContainer.querySelectorAll(".ng-group-row"));
      let cur = null;
      gRows.forEach((row) => {
        const rect = row.getBoundingClientRect();
        if (rect.top <= clientY) {
          const tid = row.getAttribute("data-task-id");
          if (tid) {
            if (tid.indexOf("__bucket_header__") === 0) cur = tid.slice("__bucket_header__".length);
            else if (tid.indexOf("group-") === 0) cur = tid.slice(6);
          }
        }
      });
      return cur;
    }
    function getInsertionPoint(clientY, clientX) {
      const allRows = Array.prototype.slice.call(
        ganttContainer.querySelectorAll(".ng-grid-row:not(.ng-group-row)")
      );
      const vis = allRows.filter((r) => r !== dragRow && r !== spacer);
      const groupRows = Array.prototype.slice.call(
        ganttContainer.querySelectorAll(".ng-group-row")
      );
      let overGroupRow = null;
      for (const gr of groupRows) {
        const rect = gr.getBoundingClientRect();
        if (clientY >= rect.top && clientY <= rect.bottom) {
          overGroupRow = gr;
          break;
        }
      }
      if (overGroupRow) {
        const tid = overGroupRow.getAttribute("data-task-id") || "";
        let bucket = "";
        if (tid.indexOf("__bucket_header__") === 0) bucket = tid.slice("__bucket_header__".length);
        else if (tid.indexOf("group-") === 0) bucket = tid.slice(6);
        const bucketFinal = bucket || dragSourceGroup || "";
        return {
          parentId: null,
          depth: 0,
          targetBucket: bucketFinal,
          // Put the deparented task at the top of the bucket (before any
          // existing root-level tasks). Index-based value matches the
          // sparse-int convention used elsewhere.
          targetSortOrder: 500,
          insertBeforeRow: null,
          nestIntoRow: null,
          deparent: true
        };
      }
      let nestIntoRow = null;
      for (const row of vis) {
        const rect = row.getBoundingClientRect();
        const nestTop = rect.top + rect.height * 0.25;
        const nestBottom = rect.top + rect.height * 0.75;
        if (clientY >= nestTop && clientY <= nestBottom) {
          nestIntoRow = row;
          break;
        }
      }
      const targetBucket = getGroupAtY(clientY) || dragSourceGroup || "";
      if (nestIntoRow) {
        const targetId = nestIntoRow.getAttribute("data-task-id");
        let cycleDetected = false;
        if (targetId && dragTaskId) {
          let cur = targetId;
          while (cur) {
            if (cur === dragTaskId) {
              cycleDetected = true;
              break;
            }
            const t = taskById[cur];
            cur = t ? t.parentWorkItemId || null : null;
          }
        }
        if (!cycleDetected && targetId) {
          let maxChildSort = 0;
          Object.keys(depthMap).forEach((id) => {
            const t = taskById[id];
            if (t && t.parentWorkItemId === targetId) {
              const s = getSortOrder(id);
              if (s > maxChildSort) maxChildSort = s;
            }
          });
          const nestDepth = (depthMap[targetId] || 0) + 1;
          return {
            parentId: targetId,
            depth: nestDepth,
            targetBucket,
            targetSortOrder: maxChildSort + 1e3,
            insertBeforeRow: null,
            nestIntoRow,
            deparent: false
          };
        }
      }
      let rowAbove = null;
      let rowBelow = null;
      for (let i = 0; i < vis.length; i++) {
        const rect = vis[i].getBoundingClientRect();
        if (clientY < rect.top + rect.height / 2) {
          rowBelow = vis[i];
          break;
        }
        rowAbove = vis[i];
      }
      const aboveId = rowAbove ? rowAbove.getAttribute("data-task-id") : null;
      const belowId = rowBelow ? rowBelow.getAttribute("data-task-id") : null;
      const aboveDepth = aboveId != null ? depthMap[aboveId] || 0 : -1;
      const aboveHasExpand = !!(rowAbove && rowAbove.querySelector(".ng-expand-icon"));
      const maxDepth = rowAbove == null ? 0 : aboveHasExpand ? aboveDepth + 1 : aboveDepth;
      const depthDelta = Math.round((clientX - dragStartX) / 25);
      const desiredDepth = Math.max(0, Math.min(maxDepth, dragStartDepth + depthDelta));
      let parentId = null;
      if (desiredDepth > 0) {
        let curId = aboveId;
        while (curId) {
          const d = depthMap[curId] || 0;
          if (d === desiredDepth - 1) {
            parentId = curId;
            break;
          }
          const it = taskById[curId];
          curId = it ? it.parentWorkItemId : null;
        }
      }
      const sortAbove = aboveId ? getSortOrder(aboveId) : 0;
      const sortBelow = belowId ? getSortOrder(belowId) : sortAbove + 2;
      const aboveIdx = rowAbove ? vis.indexOf(rowAbove) : -1;
      const targetSort = sortAbove !== sortBelow ? (sortAbove + sortBelow) / 2 : aboveIdx >= 0 ? (aboveIdx + 1) * 1e3 : 500;
      return { parentId, depth: desiredDepth, targetBucket, targetSortOrder: targetSort, insertBeforeRow: rowBelow, nestIntoRow: null, deparent: false };
    }
    function cleanupDrag() {
      if (ghost) {
        ghost.remove();
        ghost = null;
      }
      if (spacer) {
        spacer.remove();
        spacer = null;
      }
      if (dragRow) {
        dragRow.style.opacity = "";
        dragRow.style.outline = "";
      }
      document.body.style.cursor = "";
      ganttContainer.querySelectorAll(".ng-group-row.ng-drop-target").forEach((row) => {
        row.classList.remove("ng-drop-target");
        row.style.boxShadow = "";
      });
      ganttContainer.querySelectorAll(".ng-nest-target").forEach((row) => {
        row.classList.remove("ng-nest-target");
        row.style.boxShadow = "";
        row.style.background = "";
      });
      ganttContainer.querySelectorAll(".ng-deparent-target").forEach((row) => {
        row.classList.remove("ng-deparent-target");
        row.style.boxShadow = "";
      });
      dragTaskId = null;
      dragSourceGroup = null;
      dragRow = null;
      hasMoved = false;
      pendingIP = null;
    }
    function findScrollEl() {
      return ganttContainer.querySelector(".ng-scroll-wrapper");
    }
    function tickAutoScroll() {
      const el2 = findScrollEl();
      if (!el2 || !dragTaskId || autoScrollVel === 0) {
        autoScrollRAF = null;
        return;
      }
      el2.scrollTop = Math.max(0, Math.min(el2.scrollHeight - el2.clientHeight, el2.scrollTop + autoScrollVel));
      autoScrollRAF = requestAnimationFrame(tickAutoScroll);
    }
    function onMouseDown(e) {
      const row = e.target.closest(".ng-grid-row:not(.ng-group-row)");
      if (!row) return;
      const tag = e.target.tagName.toLowerCase();
      if (tag === "input" || tag === "button" || tag === "select" || tag === "textarea") return;
      const taskId = row.getAttribute("data-task-id");
      if (!taskId) return;
      const grp = getGroup(taskId) || getGroupAtY(e.clientY) || "";
      e.preventDefault();
      e.stopPropagation();
      e.stopImmediatePropagation();
      dragTaskId = taskId;
      dragSourceGroup = grp;
      dragRow = row;
      startY = e.clientY;
      startX = e.clientX;
      dragStartX = e.clientX;
      dragStartDepth = depthMap[taskId] || 0;
      hasMoved = false;
      pendingIP = null;
      document.body.style.cursor = "grabbing";
      row.style.outline = "2px solid #3b82f6";
    }
    function onMouseMove(e) {
      if (!dragTaskId || !dragRow) return;
      const dx = e.clientX - startX, dy = e.clientY - startY;
      if (!hasMoved && (Math.abs(dy) > DRAG_THRESHOLD || Math.abs(dx) > DRAG_THRESHOLD)) {
        hasMoved = true;
        const firstCell = dragRow.querySelector("td");
        ghost = document.createElement("div");
        ghost.style.cssText = "position:fixed;z-index:10000;pointer-events:none;left:" + (e.clientX - 16) + "px;top:" + (e.clientY - 18) + "px;background:#dbeafe;border:2px solid #2563eb;border-radius:8px;box-shadow:0 16px 40px rgba(37,99,235,0.4);padding:6px 12px;font-size:12px;font-weight:700;color:#1d4ed8;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;cursor:grabbing;transform:rotate(-1.5deg) scale(1.04);display:flex;align-items:center;gap:8px;max-width:320px";
        ghost.innerHTML = '<span style="opacity:.6;font-size:14px">⠇</span><span style="overflow:hidden;text-overflow:ellipsis">' + (firstCell ? firstCell.innerText.replace(/\s+/g, " ").slice(0, 60) : "") + "</span>";
        document.body.appendChild(ghost);
        const tbody = dragRow.parentElement;
        if (tbody) {
          spacer = document.createElement("tr");
          spacer.setAttribute("data-drag-spacer", "1");
          spacer.style.pointerEvents = "none";
          const numCols = dragRow.querySelectorAll("td").length || 6;
          const td = document.createElement("td");
          td.setAttribute("colspan", String(numCols));
          td.style.cssText = "padding:0;height:34px;background:rgba(59,130,246,0.07);border-top:2px solid #3b82f6;border-bottom:2px solid rgba(59,130,246,0.3)";
          const span = document.createElement("span");
          span.style.cssText = "display:flex;align-items:center;height:100%;padding-left:10px;font-size:10px;font-weight:700;color:#3b82f6;letter-spacing:.05em;opacity:.7";
          span.textContent = "↓ drop here";
          td.appendChild(span);
          spacer.appendChild(td);
          tbody.insertBefore(spacer, dragRow.nextSibling);
        }
        dragRow.style.opacity = "0.25";
        dragRow.style.outline = "";
      }
      if (!hasMoved) return;
      if (ghost) {
        ghost.style.left = e.clientX - 12 + "px";
        ghost.style.top = e.clientY - 14 + "px";
      }
      const scrollEl = findScrollEl();
      if (scrollEl) {
        const sr = scrollEl.getBoundingClientRect(), EDGE = 60, MAX = 18;
        let v = 0;
        if (e.clientY < sr.top + EDGE) v = -Math.ceil(MAX * Math.min(1, (sr.top + EDGE - e.clientY) / EDGE));
        else if (e.clientY > sr.bottom - EDGE) v = Math.ceil(MAX * Math.min(1, (e.clientY - (sr.bottom - EDGE)) / EDGE));
        autoScrollVel = v;
        if (v !== 0 && autoScrollRAF == null) autoScrollRAF = requestAnimationFrame(tickAutoScroll);
      }
      const ip = getInsertionPoint(e.clientY, e.clientX);
      pendingIP = ip;
      if (spacer) {
        const tb = dragRow ? dragRow.parentElement : null;
        if (ip.nestIntoRow || ip.deparent) {
          if (tb && spacer.parentElement === tb) spacer.remove();
        } else if (tb) {
          if (ip.insertBeforeRow && ip.insertBeforeRow !== spacer) tb.insertBefore(spacer, ip.insertBeforeRow);
          else if (!ip.insertBeforeRow) tb.appendChild(spacer);
          const indent = INDENT_BASE + ip.depth * LEAF_STEP;
          const lbl = spacer.querySelector("td span");
          if (lbl) lbl.style.paddingLeft = indent + 8 + "px";
        }
      }
      updateBucketHighlight(ip.deparent ? null : ip.targetBucket);
      updateNestHighlight(ip.nestIntoRow);
      updateDeparentHighlight(ip.deparent ? getGroupRowForBucket(ip.targetBucket) : null);
    }
    function getGroupRowForBucket(bucket) {
      if (!bucket) return null;
      const rows = ganttContainer.querySelectorAll(".ng-group-row");
      for (const row of Array.from(rows)) {
        const tid = row.getAttribute("data-task-id") || "";
        if (tid === `__bucket_header__${bucket}` || tid === `group-${bucket}`) return row;
      }
      return null;
    }
    function updateDeparentHighlight(target) {
      ganttContainer.querySelectorAll(".ng-deparent-target").forEach((row) => {
        row.classList.remove("ng-deparent-target");
        row.style.boxShadow = "";
      });
      if (!target) return;
      target.classList.add("ng-deparent-target");
      target.style.boxShadow = "inset 0 0 0 3px #f59e0b";
    }
    function updateNestHighlight(target) {
      const prev = ganttContainer.querySelectorAll(".ng-nest-target");
      prev.forEach((row) => {
        row.classList.remove("ng-nest-target");
        row.style.boxShadow = "";
        row.style.background = "";
      });
      if (!target) return;
      target.classList.add("ng-nest-target");
      target.style.boxShadow = "inset 0 0 0 2px #10b981";
      target.style.background = "rgba(16,185,129,0.08)";
    }
    function updateBucketHighlight(targetBucket) {
      const allGroupRows = ganttContainer.querySelectorAll(".ng-group-row");
      allGroupRows.forEach((row) => {
        row.classList.remove("ng-drop-target");
        row.style.boxShadow = "";
      });
      if (!targetBucket || targetBucket === dragSourceGroup) return;
      const target = Array.from(allGroupRows).find((row) => {
        const tid = row.getAttribute("data-task-id") || "";
        if (tid === `__bucket_header__${targetBucket}`) return true;
        if (tid === `group-${targetBucket}`) return true;
        return false;
      });
      if (target) {
        target.classList.add("ng-drop-target");
        target.style.boxShadow = "inset 0 0 0 2px #3b82f6";
      }
    }
    function onMouseUp(e) {
      autoScrollVel = 0;
      if (autoScrollRAF != null) {
        cancelAnimationFrame(autoScrollRAF);
        autoScrollRAF = null;
      }
      const savedId = dragTaskId, savedGroup = dragSourceGroup, savedMoved = hasMoved, ip = pendingIP;
      cleanupDrag();
      if (!savedId) return;
      if (!savedMoved) return;
      if (!ip) return;
      if (ip.targetBucket && ip.targetBucket !== savedGroup) {
        onPatch({ id: savedId, priorityGroup: ip.targetBucket });
      }
      const currentParent = taskById[savedId] ? taskById[savedId].parentWorkItemId : void 0;
      if (ip.parentId !== currentParent) {
        onPatch({ id: savedId, parentId: ip.parentId || null });
      }
      onPatch({ id: savedId, sortOrder: ip.targetSortOrder });
    }
    ganttContainer.addEventListener("mousedown", onMouseDown, true);
    window.addEventListener("mousemove", onMouseMove, true);
    window.addEventListener("mouseup", onMouseUp, true);
    return function cleanup() {
      ganttContainer.removeEventListener("mousedown", onMouseDown, true);
      window.removeEventListener("mousemove", onMouseMove, true);
      window.removeEventListener("mouseup", onMouseUp, true);
      cleanupDrag();
    };
  }
  function el$1(tag, className, styleText) {
    const e = document.createElement(tag);
    if (className) e.className = className;
    return e;
  }
  function clear(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
  }
  const GROUP_ORDER = ["top-priority", "active", "follow-on", "proposed", "deferred"];
  const GROUP_LABELS = {
    "top-priority": "NOW",
    "active": "NEXT",
    "follow-on": "PLANNED",
    "proposed": "PROPOSED",
    "deferred": "HOLD"
  };
  const GROUP_COLORS = {
    "top-priority": "#dc2626",
    "active": "#d97706",
    "follow-on": "#059669",
    "proposed": "#2563eb",
    "deferred": "#94a3b8"
  };
  const GROUP_BG = {
    "top-priority": "#fef2f2",
    "active": "#fffbeb",
    "follow-on": "#ecfdf5",
    "proposed": "#eff6ff",
    "deferred": "#f8fafc"
  };
  const FILTER_LABELS = {
    "all": "All",
    "needs-attention": "Needs attention",
    "dupes": "Dupe candidates",
    "no-mf-ref": "No mfRef",
    "no-mf-page": "No docs page",
    "no-owner": "No owner",
    "no-dates": "No dates",
    "no-hours": "Not sized"
  };
  const SORT_LABELS = {
    "default": "Sort: default",
    "hours-desc": "Hours: high → low",
    "hours-asc": "Hours: low → high",
    "owner": "Owner",
    "last-activity": "Last activity",
    "audit-score": "Audit score"
  };
  function auditTask(task) {
    const hasOwner = !!task.developerName;
    const hasDates = !!(task.startDate && task.endDate);
    const hasHours = !!(task.estimatedHours && task.estimatedHours > 0);
    const issues = [];
    if (!hasOwner) issues.push({ severity: "warning", message: "No owner assigned" });
    if (!hasDates) issues.push({ severity: "warning", message: "No start/end dates" });
    if (!hasHours) issues.push({ severity: "warning", message: "Not sized (no hours estimate)" });
    return {
      flags: {
        hasMfRef: false,
        // NormalizedTask has no mfRef field
        hasMfPage: false,
        // No docs-page lookup in v0
        hasOwner,
        hasDates,
        hasHours
      },
      issues,
      score: hasOwner && hasDates && hasHours ? 100 : 50
    };
  }
  function computeKpis(tasks, audits) {
    let totalSizedHours = 0;
    let needsAttention = 0;
    let proposalReady = 0;
    let proposalTotal = 0;
    for (const t of tasks) {
      const h = t.estimatedHours || 0;
      totalSizedHours += h;
      const a = audits.get(t.id);
      if (a && a.issues.some((i) => i.severity === "error" || i.severity === "warning")) {
        needsAttention++;
      }
      if (t.priorityGroup === "proposed") {
        proposalTotal++;
        if (a && a.flags.hasOwner && a.flags.hasHours && a.flags.hasDates) {
          proposalReady++;
        }
      }
    }
    return {
      totalItems: tasks.length,
      totalSizedHours: Math.round(totalSizedHours),
      needsAttention,
      dupeCount: 0,
      proposalReady,
      proposalTotal
    };
  }
  function bucketOf(task) {
    const g = task.priorityGroup;
    if (g && GROUP_ORDER.indexOf(g) >= 0) return g;
    return "deferred";
  }
  function fmtDate(iso) {
    if (!iso) return "";
    const m = iso.match(/^(\d{4})-(\d{2})-(\d{2})/);
    return m ? m[2] + "-" + m[3] : iso;
  }
  function fmtDateRange(start, end) {
    if (!start && !end) return "";
    return fmtDate(start) + " → " + fmtDate(end);
  }
  function progressOf(task) {
    const high = task.estimatedHours || 0;
    const logged = task.loggedHours || 0;
    if (DONE_STAGES[task.stage || ""]) return 100;
    if (!high) return null;
    return Math.min(100, Math.round(logged / high * 100));
  }
  const KPI_TONES = {
    slate: { bg: "#f1f5f9", text: "#475569" },
    emerald: { bg: "#d1fae5", text: "#047857" },
    amber: { bg: "#fef3c7", text: "#b45309" },
    rose: { bg: "#ffe4e6", text: "#be123c" }
  };
  function kpiPill(label, value, tone) {
    const t = KPI_TONES[tone];
    const wrap = el$1("span", "");
    wrap.style.cssText = [
      "display:inline-flex",
      "align-items:center",
      "gap:6px",
      "padding:3px 10px",
      "border-radius:9999px",
      "background:" + t.bg,
      "color:" + t.text,
      "font-size:11px",
      "font-weight:600",
      "white-space:nowrap"
    ].join(";");
    const v = el$1("span", "");
    v.style.cssText = "font-weight:700";
    v.textContent = value;
    const l = el$1("span", "");
    l.style.cssText = "opacity:0.85;font-weight:500";
    l.textContent = label;
    wrap.appendChild(v);
    wrap.appendChild(l);
    return wrap;
  }
  function auditIcons(audit) {
    const wrap = el$1("span", "");
    wrap.style.cssText = "display:inline-flex;gap:4px;font-size:11px;opacity:0.75;";
    function icon(glyph, ok, title) {
      const s = el$1("span", "");
      s.style.cssText = "color:" + (ok ? "#10b981" : "#94a3b8");
      s.textContent = glyph;
      s.title = title;
      return s;
    }
    wrap.appendChild(icon("👤", audit.flags.hasOwner, "Owner"));
    wrap.appendChild(icon("📅", audit.flags.hasDates, "Dates"));
    wrap.appendChild(icon("⌛", audit.flags.hasHours, "Hours estimated"));
    return wrap;
  }
  function renderAuditListView(host, tasks, options) {
    let search = "";
    let filterChip = "all";
    let sortKey = "default";
    const collapsedBuckets = /* @__PURE__ */ new Set();
    const expandedIds = /* @__PURE__ */ new Set();
    const progressLabel = (options == null ? void 0 : options.progressLabel) ?? "Budget Used";
    const hideRecordIds = (options == null ? void 0 : options.hideRecordIds) ?? true;
    const onReorder = options == null ? void 0 : options.onReorder;
    const audits = /* @__PURE__ */ new Map();
    for (const t of tasks) audits.set(t.id, auditTask(t));
    const dupeIds = /* @__PURE__ */ new Set();
    function getFilteredTasks() {
      let result = tasks;
      if (search.trim()) {
        const q = search.toLowerCase();
        result = result.filter((t) => {
          const hay = [
            t.title || "",
            t.name || "",
            t.developerName || "",
            t.stage || ""
            // mfRef + notes have no equivalent on NormalizedTask; skip.
          ].join(" ").toLowerCase();
          return hay.indexOf(q) >= 0;
        });
      }
      if (filterChip !== "all") {
        result = result.filter((t) => {
          const a = audits.get(t.id);
          if (!a) return false;
          switch (filterChip) {
            case "needs-attention":
              return a.issues.some((i) => i.severity === "error" || i.severity === "warning");
            case "no-mf-ref":
              return !a.flags.hasMfRef;
            case "no-mf-page":
              return !a.flags.hasMfPage;
            case "no-owner":
              return !a.flags.hasOwner;
            case "no-dates":
              return !a.flags.hasDates;
            case "no-hours":
              return !a.flags.hasHours;
            case "dupes":
              return dupeIds.has(t.id);
            default:
              return true;
          }
        });
      }
      return result;
    }
    function sortTasks(arr) {
      if (sortKey === "default") {
        return arr.slice().sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));
      }
      const out = arr.slice();
      if (sortKey === "hours-desc") {
        out.sort((a, b) => (b.estimatedHours || 0) - (a.estimatedHours || 0));
      } else if (sortKey === "hours-asc") {
        out.sort((a, b) => (a.estimatedHours || 0) - (b.estimatedHours || 0));
      } else if (sortKey === "owner") {
        out.sort((a, b) => (a.developerName || "").localeCompare(b.developerName || ""));
      } else if (sortKey === "last-activity") {
        out.sort((a, b) => (b.endDate || "").localeCompare(a.endDate || ""));
      } else if (sortKey === "audit-score") {
        out.sort((a, b) => {
          var _a, _b;
          return (((_a = audits.get(a.id)) == null ? void 0 : _a.score) || 0) - (((_b = audits.get(b.id)) == null ? void 0 : _b.score) || 0);
        });
      }
      return out;
    }
    function groupByBucket(filtered) {
      const m = /* @__PURE__ */ new Map();
      for (const g of GROUP_ORDER) m.set(g, []);
      for (const t of filtered) {
        const b = bucketOf(t);
        m.get(b).push(t);
      }
      for (const g of GROUP_ORDER) {
        m.set(g, sortTasks(m.get(g)));
      }
      return m;
    }
    function bucketStats(bucketTasks) {
      let hours = 0, logged = 0, issues = 0;
      for (const t of bucketTasks) {
        hours += t.estimatedHours || 0;
        logged += t.loggedHours || 0;
        const a = audits.get(t.id);
        if (a && a.issues.some((i) => i.severity === "error" || i.severity === "warning")) {
          issues++;
        }
      }
      return { count: bucketTasks.length, hours: Math.round(hours), logged: Math.round(logged), issues };
    }
    function filterCounts() {
      const counts = {
        "all": tasks.length,
        "needs-attention": 0,
        "no-mf-ref": 0,
        "no-mf-page": 0,
        "no-owner": 0,
        "no-dates": 0,
        "no-hours": 0,
        "dupes": 0
      };
      for (const t of tasks) {
        const a = audits.get(t.id);
        if (!a) continue;
        if (a.issues.some((i) => i.severity === "error" || i.severity === "warning")) counts["needs-attention"]++;
        if (!a.flags.hasMfRef) counts["no-mf-ref"]++;
        if (!a.flags.hasMfPage) counts["no-mf-page"]++;
        if (!a.flags.hasOwner) counts["no-owner"]++;
        if (!a.flags.hasDates) counts["no-dates"]++;
        if (!a.flags.hasHours) counts["no-hours"]++;
        if (dupeIds.has(t.id)) counts["dupes"]++;
      }
      return counts;
    }
    let bodyEl = null;
    let clearLink = null;
    const filterPillBtns = /* @__PURE__ */ new Map();
    const filterPillCnts = /* @__PURE__ */ new Map();
    function applyFilterPillStyles(chip) {
      const btn = filterPillBtns.get(chip);
      const cnt = filterPillCnts.get(chip);
      if (!btn || !cnt) return;
      const isActive = chip === filterChip;
      btn.style.cssText = [
        "padding:4px 10px",
        "border-radius:9999px",
        "border:1px solid " + (isActive ? "#3b82f6" : "#e2e8f0"),
        "background:" + (isActive ? "#3b82f6" : "#ffffff"),
        "color:" + (isActive ? "#ffffff" : "#475569"),
        "font-size:11px",
        "font-weight:600",
        "cursor:pointer",
        "display:inline-flex",
        "align-items:center",
        "gap:5px"
      ].join(";");
      cnt.style.cssText = [
        "padding:0 6px",
        "border-radius:9999px",
        "background:" + (isActive ? "rgba(255,255,255,0.25)" : "#f1f5f9"),
        "color:" + (isActive ? "#ffffff" : "#64748b"),
        "font-size:10px",
        "font-weight:700"
      ].join(";");
    }
    function updateFilterPillStyles() {
      Object.keys(FILTER_LABELS).forEach((chip) => {
        applyFilterPillStyles(chip);
      });
    }
    function updateClearLinkVisibility() {
      if (!clearLink) return;
      const anyFilter = filterChip !== "all" || search.trim() !== "" || sortKey !== "default";
      clearLink.style.display = anyFilter ? "" : "none";
    }
    let drgTaskId = null;
    let drgGhost = null;
    let drgLine = null;
    let drgInsertAfter = null;
    let drgInsertBefore = null;
    function cleanupReorderDrag() {
      if (drgGhost) {
        drgGhost.remove();
        drgGhost = null;
      }
      if (drgLine) {
        drgLine.remove();
        drgLine = null;
      }
      drgTaskId = null;
      drgInsertAfter = null;
      drgInsertBefore = null;
      document.body.style.cursor = "";
    }
    function startReorderDrag(e, task) {
      if (!onReorder) return;
      e.preventDefault();
      e.stopPropagation();
      drgTaskId = task.id;
      document.body.style.cursor = "grabbing";
      drgGhost = document.createElement("div");
      drgGhost.style.cssText = [
        "position:fixed",
        "z-index:10000",
        "pointer-events:none",
        `left:${e.clientX - 12}px`,
        `top:${e.clientY - 14}px`,
        "background:#dbeafe",
        "border:2px solid #2563eb",
        "border-radius:8px",
        "padding:6px 12px",
        "font-size:12px",
        "font-weight:700",
        "color:#1d4ed8",
        "white-space:nowrap",
        "max-width:320px",
        "overflow:hidden",
        "text-overflow:ellipsis",
        "box-shadow:0 16px 40px rgba(37,99,235,0.4)",
        "transform:rotate(-1.5deg) scale(1.04)"
      ].join(";");
      drgGhost.textContent = (task.title || task.name || task.id).slice(0, 60);
      document.body.appendChild(drgGhost);
      drgLine = document.createElement("div");
      drgLine.style.cssText = [
        "position:fixed",
        "z-index:9999",
        "pointer-events:none",
        "height:2px",
        "background:#3b82f6",
        "box-shadow:0 0 4px rgba(59,130,246,0.5)",
        "display:none"
      ].join(";");
      document.body.appendChild(drgLine);
      window.addEventListener("mousemove", onReorderMove, true);
      window.addEventListener("mouseup", onReorderUp, true);
    }
    function onReorderMove(e) {
      if (!drgTaskId || !drgGhost) return;
      drgGhost.style.left = e.clientX - 12 + "px";
      drgGhost.style.top = e.clientY - 14 + "px";
      const rows = Array.from(host.querySelectorAll('[data-list-row="1"]'));
      let above = null;
      let below = null;
      for (const r of rows) {
        const rect = r.getBoundingClientRect();
        const mid = rect.top + rect.height / 2;
        if (e.clientY < mid) {
          below = r;
          break;
        }
        above = r;
      }
      const aboveId = (above == null ? void 0 : above.getAttribute("data-task-id")) || null;
      const belowId = (below == null ? void 0 : below.getAttribute("data-task-id")) || null;
      drgInsertAfter = aboveId ? tasks.find((t) => t.id === aboveId) || null : null;
      drgInsertBefore = belowId ? tasks.find((t) => t.id === belowId) || null : null;
      if (drgLine) {
        if (below) {
          const rect = below.getBoundingClientRect();
          drgLine.style.display = "block";
          drgLine.style.left = rect.left + "px";
          drgLine.style.top = rect.top - 1 + "px";
          drgLine.style.width = rect.width + "px";
        } else if (above) {
          const rect = above.getBoundingClientRect();
          drgLine.style.display = "block";
          drgLine.style.left = rect.left + "px";
          drgLine.style.top = rect.bottom - 1 + "px";
          drgLine.style.width = rect.width + "px";
        } else {
          drgLine.style.display = "none";
        }
      }
    }
    function onReorderUp() {
      window.removeEventListener("mousemove", onReorderMove, true);
      window.removeEventListener("mouseup", onReorderUp, true);
      const taskId = drgTaskId;
      const after = drgInsertAfter;
      const before = drgInsertBefore;
      cleanupReorderDrag();
      if (!taskId || !onReorder) return;
      if (!after && !before) return;
      const afterSort = after ? Number(after.sortOrder) || 0 : 0;
      const beforeSort = before ? Number(before.sortOrder) || 0 : 0;
      let newIndex;
      if (after && before && afterSort !== beforeSort) {
        newIndex = (afterSort + beforeSort) / 2;
      } else if (after && !before) {
        newIndex = afterSort + 1e3;
      } else if (!after && before) {
        newIndex = beforeSort - 1e3;
      } else {
        newIndex = afterSort + 500;
      }
      onReorder(taskId, { newIndex });
    }
    function resetAllFilters() {
      search = "";
      filterChip = "all";
      sortKey = "default";
      const searchInput = host.querySelector('input[type="search"]');
      if (searchInput) searchInput.value = "";
      const sortSel = host.querySelector("select[data-nga-audit-sort]");
      if (sortSel) sortSel.value = "default";
      updateFilterPillStyles();
      updateClearLinkVisibility();
      renderBody();
    }
    function renderBody() {
      if (!bodyEl) return;
      clear(bodyEl);
      const grouped = groupByBucket(getFilteredTasks());
      for (const g of GROUP_ORDER) {
        const bucketTasks = grouped.get(g);
        if (bucketTasks.length === 0) continue;
        const stats = bucketStats(bucketTasks);
        const isCollapsed = collapsedBuckets.has(g);
        const section = el$1("section", "");
        section.style.cssText = [
          "border-radius:12px",
          "border:2px solid " + GROUP_COLORS[g] + "40",
          "background:" + GROUP_BG[g],
          "overflow:hidden"
        ].join(";");
        const bucketHdr = el$1("div", "");
        bucketHdr.style.cssText = [
          "display:flex",
          "align-items:center",
          "gap:10px",
          "padding:10px 14px",
          "background:#ffffff",
          "border-bottom:1px solid " + GROUP_COLORS[g] + "30",
          "cursor:pointer",
          "user-select:none"
        ].join(";");
        const chevron = el$1("span", "");
        chevron.style.cssText = "font-size:12px;color:" + GROUP_COLORS[g];
        chevron.textContent = isCollapsed ? "▶" : "▼";
        bucketHdr.appendChild(chevron);
        const bucketLabel = el$1("span", "");
        bucketLabel.style.cssText = [
          "font-size:13px",
          "font-weight:700",
          "letter-spacing:0.05em",
          "color:" + GROUP_COLORS[g],
          "text-transform:uppercase"
        ].join(";");
        bucketLabel.textContent = GROUP_LABELS[g];
        bucketHdr.appendChild(bucketLabel);
        const bucketStatsEl = el$1("span", "");
        bucketStatsEl.style.cssText = "font-size:11px;color:#64748b;font-weight:500";
        const statsParts = [
          stats.count + " item" + (stats.count === 1 ? "" : "s"),
          stats.hours + "h sized"
        ];
        if (stats.logged > 0) statsParts.push(stats.logged + "h logged");
        if (stats.issues > 0) statsParts.push(stats.issues + " needs attention");
        bucketStatsEl.textContent = statsParts.join(" · ");
        bucketHdr.appendChild(bucketStatsEl);
        bucketHdr.addEventListener("click", () => {
          if (isCollapsed) collapsedBuckets.delete(g);
          else collapsedBuckets.add(g);
          renderBody();
        });
        section.appendChild(bucketHdr);
        if (!isCollapsed) {
          const body = el$1("div", "");
          body.style.cssText = "background:#ffffff";
          for (const t of bucketTasks) {
            body.appendChild(renderRow(t));
          }
          section.appendChild(body);
        }
        bodyEl.appendChild(section);
      }
      if (Array.from(grouped.values()).every((arr) => arr.length === 0)) {
        const empty = el$1("div", "");
        empty.style.cssText = [
          "padding:48px 24px",
          "text-align:center",
          "color:#64748b",
          "font-size:13px"
        ].join(";");
        const emptyTitle = el$1("div", "");
        emptyTitle.style.cssText = "font-size:16px;font-weight:600;color:#475569;margin-bottom:8px";
        emptyTitle.textContent = tasks.length === 0 ? "No tasks to audit" : "No tasks match the current filter";
        empty.appendChild(emptyTitle);
        if (tasks.length > 0 && (filterChip !== "all" || search.trim() !== "")) {
          const clearBtn = el$1("button", "");
          clearBtn.style.cssText = [
            "margin-top:12px",
            "padding:6px 14px",
            "background:#3b82f6",
            "color:#ffffff",
            "border:none",
            "border-radius:8px",
            "font-size:12px",
            "font-weight:600",
            "cursor:pointer"
          ].join(";");
          clearBtn.textContent = "Clear filters";
          clearBtn.addEventListener("click", () => resetAllFilters());
          empty.appendChild(clearBtn);
        }
        bodyEl.appendChild(empty);
      }
    }
    function mountShell() {
      clear(host);
      host.style.cssText = [
        "height:100%",
        "width:100%",
        "overflow:auto",
        "background:#f8fafc",
        "color:#0f172a",
        "font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif"
      ].join(";");
      const kpis = computeKpis(tasks, audits);
      const header = el$1("div", "");
      header.style.cssText = [
        "background:#ffffff",
        "border-bottom:1px solid #e2e8f0",
        "box-shadow:0 1px 2px rgba(0,0,0,0.04)"
      ].join(";");
      const headerInner = el$1("div", "");
      headerInner.style.cssText = [
        "padding:12px 16px",
        "display:flex",
        "flex-wrap:wrap",
        "align-items:center",
        "gap:12px"
      ].join(";");
      const labelWrap = el$1("div", "");
      labelWrap.style.cssText = "display:flex;align-items:center;gap:8px;margin-right:8px";
      const label = el$1("span", "");
      label.style.cssText = "font-size:14px;font-weight:700;color:#0f172a";
      label.textContent = "Audit view";
      const sep = el$1("span", "");
      sep.style.cssText = "color:#94a3b8;font-size:12px";
      sep.textContent = "·";
      labelWrap.appendChild(label);
      labelWrap.appendChild(sep);
      headerInner.appendChild(labelWrap);
      const kpiWrap = el$1("div", "");
      kpiWrap.style.cssText = "display:flex;flex-wrap:wrap;gap:8px;align-items:center";
      kpiWrap.appendChild(kpiPill("items", String(kpis.totalItems), "slate"));
      kpiWrap.appendChild(kpiPill("h sized", String(kpis.totalSizedHours), "slate"));
      kpiWrap.appendChild(kpiPill(
        "needs attention",
        String(kpis.needsAttention),
        kpis.needsAttention > 0 ? "amber" : "emerald"
      ));
      kpiWrap.appendChild(kpiPill(
        "dupes",
        String(kpis.dupeCount),
        "emerald"
      ));
      if (kpis.proposalTotal > 0) {
        const ready = kpis.proposalReady;
        const total = kpis.proposalTotal;
        const tone = ready === total ? "emerald" : ready > total / 2 ? "amber" : "rose";
        kpiWrap.appendChild(kpiPill("ready / " + total, String(ready), tone));
      }
      headerInner.appendChild(kpiWrap);
      const spacer = el$1("div", "");
      spacer.style.cssText = "flex:1;min-width:8px";
      headerInner.appendChild(spacer);
      const searchInput = el$1("input", "");
      searchInput.type = "search";
      searchInput.placeholder = "Search title / owner / stage…";
      searchInput.value = search;
      searchInput.style.cssText = [
        "min-width:200px",
        "max-width:320px",
        "padding:6px 12px",
        "border-radius:8px",
        "border:1px solid #cbd5e1",
        "font-size:13px",
        "background:#ffffff",
        "outline:none"
      ].join(";");
      searchInput.addEventListener("input", (e) => {
        search = e.target.value;
        renderBody();
        updateClearLinkVisibility();
      });
      headerInner.appendChild(searchInput);
      const sortSel = el$1("select", "");
      sortSel.setAttribute("data-nga-audit-sort", "1");
      sortSel.style.cssText = [
        "padding:6px 10px",
        "border-radius:8px",
        "border:1px solid #cbd5e1",
        "font-size:12px",
        "background:#ffffff",
        "outline:none"
      ].join(";");
      Object.keys(SORT_LABELS).forEach((k) => {
        const opt = el$1("option", "");
        opt.value = k;
        opt.textContent = SORT_LABELS[k];
        if (k === sortKey) opt.selected = true;
        sortSel.appendChild(opt);
      });
      sortSel.addEventListener("change", (e) => {
        sortKey = e.target.value;
        renderBody();
        updateClearLinkVisibility();
      });
      headerInner.appendChild(sortSel);
      header.appendChild(headerInner);
      const filterRow = el$1("div", "");
      filterRow.style.cssText = [
        "display:flex",
        "flex-wrap:wrap",
        "gap:6px",
        "padding:10px 16px",
        "border-bottom:1px solid #f1f5f9",
        "background:#ffffff"
      ].join(";");
      const counts = filterCounts();
      Object.keys(FILTER_LABELS).forEach((chip) => {
        const btn = el$1("button", "");
        const lbl = el$1("span", "");
        lbl.textContent = FILTER_LABELS[chip];
        btn.appendChild(lbl);
        const cnt = el$1("span", "");
        cnt.textContent = String(counts[chip]);
        btn.appendChild(cnt);
        btn.addEventListener("click", () => {
          filterChip = chip;
          updateFilterPillStyles();
          updateClearLinkVisibility();
          renderBody();
        });
        filterRow.appendChild(btn);
        filterPillBtns.set(chip, btn);
        filterPillCnts.set(chip, cnt);
        applyFilterPillStyles(chip);
      });
      clearLink = el$1("button", "");
      clearLink.style.cssText = [
        "padding:4px 10px",
        "background:transparent",
        "border:none",
        "color:#dc2626",
        "font-size:11px",
        "font-weight:600",
        "cursor:pointer",
        "text-decoration:underline",
        "text-decoration-style:dotted"
      ].join(";");
      clearLink.textContent = "Clear filters";
      clearLink.addEventListener("click", () => resetAllFilters());
      filterRow.appendChild(clearLink);
      updateClearLinkVisibility();
      header.appendChild(filterRow);
      host.appendChild(header);
      bodyEl = el$1("div", "");
      bodyEl.style.cssText = "padding:16px;display:flex;flex-direction:column;gap:14px";
      host.appendChild(bodyEl);
    }
    function renderRow(task) {
      const audit = audits.get(task.id);
      const isExpanded = expandedIds.has(task.id);
      const hasErrors = audit.issues.some((i) => i.severity === "error");
      const hasWarnings = audit.issues.some((i) => i.severity === "warning");
      const row = el$1("div", "");
      row.style.cssText = [
        "display:flex",
        "flex-direction:column",
        "border-bottom:1px solid #f1f5f9",
        "background:#ffffff",
        "transition:background-color 0.1s"
      ].join(";");
      row.addEventListener("mouseenter", () => {
        row.style.backgroundColor = hasErrors ? "rgba(244,63,94,0.04)" : hasWarnings ? "rgba(245,158,11,0.04)" : "rgba(59,130,246,0.04)";
      });
      row.addEventListener("mouseleave", () => {
        row.style.backgroundColor = "#ffffff";
      });
      const top = el$1("div", "");
      top.style.cssText = [
        "display:flex",
        "align-items:center",
        "gap:10px",
        "padding:8px 14px",
        "cursor:pointer"
      ].join(";");
      const drag = el$1("span", "");
      drag.style.cssText = [
        "color:#cbd5e1",
        "font-size:14px",
        "cursor:" + (onReorder ? "grab" : "default"),
        "user-select:none",
        "flex-shrink:0",
        "padding:0 4px"
      ].join(";");
      drag.textContent = "⠇";
      drag.title = onReorder ? "Drag to reorder" : "Drag to reorder (disabled)";
      drag.setAttribute("data-reorder-handle", "1");
      drag.setAttribute("data-task-id", task.id);
      if (onReorder) {
        drag.addEventListener("mousedown", (e) => startReorderDrag(e, task));
      }
      top.appendChild(drag);
      row.setAttribute("data-list-row", "1");
      row.setAttribute("data-task-id", task.id);
      const chev = el$1("span", "");
      chev.style.cssText = "color:#64748b;font-size:11px;flex-shrink:0;width:12px;text-align:center";
      chev.textContent = isExpanded ? "▼" : "▶";
      top.appendChild(chev);
      if (!hideRecordIds) {
        const name = el$1("code", "");
        name.style.cssText = [
          "font-family:SF Mono,Cascadia Code,Consolas,monospace",
          "font-size:11px",
          "color:#64748b",
          "flex-shrink:0",
          "min-width:80px",
          "max-width:140px",
          "overflow:hidden",
          "text-overflow:ellipsis",
          "white-space:nowrap"
        ].join(";");
        name.textContent = task.name || task.id;
        top.appendChild(name);
      }
      const title = el$1("span", "");
      title.style.cssText = [
        "flex:1",
        "min-width:0",
        "font-size:13px",
        "color:#0f172a",
        "overflow:hidden",
        "text-overflow:ellipsis",
        "white-space:nowrap"
      ].join(";");
      title.textContent = task.title;
      if (options == null ? void 0 : options.onTaskClick) {
        title.style.cursor = "pointer";
        title.style.textDecoration = "underline";
        title.style.textDecorationStyle = "dotted";
        title.style.textDecorationColor = "#94a3b8";
        title.addEventListener("click", (e) => {
          e.stopPropagation();
          options.onTaskClick(task.id);
        });
      }
      top.appendChild(title);
      const pct = progressOf(task);
      if (pct !== null) {
        const pctWrap = el$1("span", "");
        pctWrap.style.cssText = [
          "flex-shrink:0",
          "font-size:11px",
          "color:" + (pct === 100 ? "#10b981" : pct > 50 ? "#d97706" : "#64748b"),
          "font-weight:600",
          "text-align:right",
          "white-space:nowrap"
        ].join(";");
        const prefixLabel = progressLabel.trim();
        pctWrap.textContent = prefixLabel ? prefixLabel + " " + pct + "%" : pct + "%";
        pctWrap.title = "Budget Used — hours logged / hours estimated";
        top.appendChild(pctWrap);
      }
      const hoursTxt = el$1("span", "");
      hoursTxt.style.cssText = [
        "font-family:SF Mono,Cascadia Code,Consolas,monospace",
        "font-size:11px",
        "color:" + (audit.flags.hasHours ? "#475569" : "#dc2626"),
        "flex-shrink:0",
        "min-width:64px",
        "text-align:right"
      ].join(";");
      if (audit.flags.hasHours) {
        const high = task.estimatedHours || 0;
        const logged = task.loggedHours || 0;
        hoursTxt.textContent = logged > 0 ? logged + "h / " + high + "h" : high + "h";
      } else {
        hoursTxt.textContent = "— h";
      }
      top.appendChild(hoursTxt);
      const dates = el$1("span", "");
      dates.style.cssText = [
        "font-family:SF Mono,Cascadia Code,Consolas,monospace",
        "font-size:11px",
        "color:" + (audit.flags.hasDates ? "#475569" : "#dc2626"),
        "flex-shrink:0",
        "min-width:104px",
        "text-align:right"
      ].join(";");
      dates.textContent = audit.flags.hasDates ? fmtDateRange(task.startDate, task.endDate) : "— → —";
      top.appendChild(dates);
      top.appendChild(auditIcons(audit));
      top.addEventListener("click", () => {
        if (isExpanded) expandedIds.delete(task.id);
        else expandedIds.add(task.id);
        renderBody();
      });
      row.appendChild(top);
      if (isExpanded) {
        let field = function(label, value) {
          const f = el$1("div", "");
          f.style.cssText = "display:flex;flex-direction:column;gap:2px";
          const l = el$1("span", "");
          l.style.cssText = "font-size:10px;color:#94a3b8;text-transform:uppercase;letter-spacing:0.05em;font-weight:600";
          l.textContent = label;
          const v = el$1("span", "");
          v.style.cssText = "font-size:12px;color:#0f172a";
          v.textContent = value || "—";
          f.appendChild(l);
          f.appendChild(v);
          grid.appendChild(f);
        };
        const detail = el$1("div", "");
        detail.style.cssText = [
          "padding:12px 14px 14px 50px",
          "background:#f8fafc",
          "border-top:1px solid #f1f5f9",
          "font-size:12px",
          "color:#475569"
        ].join(";");
        const grid = el$1("div", "");
        grid.style.cssText = [
          "display:grid",
          "grid-template-columns:repeat(auto-fit,minmax(180px,1fr))",
          "gap:8px 16px"
        ].join(";");
        field("Stage", task.stage || "");
        field("Owner", task.developerName || "");
        field("Priority group", task.priorityGroup || "");
        field("Start", task.startDate || "");
        field("End", task.endDate || "");
        field("Estimated", String(task.estimatedHours || 0) + " h");
        field("Logged", String(task.loggedHours || 0) + " h");
        if (task.entityName) field("Entity", task.entityName);
        detail.appendChild(grid);
        if (audit.issues.length > 0) {
          const issuesWrap = el$1("div", "");
          issuesWrap.style.cssText = [
            "margin-top:10px",
            "padding:8px 10px",
            "background:#ffffff",
            "border:1px solid #e2e8f0",
            "border-radius:6px",
            "display:flex",
            "flex-direction:column",
            "gap:4px"
          ].join(";");
          const issuesTitle = el$1("div", "");
          issuesTitle.style.cssText = "font-size:10px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:0.05em;margin-bottom:2px";
          issuesTitle.textContent = "Audit issues";
          issuesWrap.appendChild(issuesTitle);
          for (const issue of audit.issues) {
            const issueRow = el$1("div", "");
            issueRow.style.cssText = [
              "display:flex",
              "align-items:center",
              "gap:6px",
              "font-size:11px",
              "color:" + (issue.severity === "error" ? "#dc2626" : issue.severity === "warning" ? "#d97706" : "#64748b")
            ].join(";");
            const dot = el$1("span", "");
            dot.style.cssText = "flex-shrink:0;width:6px;height:6px;border-radius:50%;background:currentColor";
            issueRow.appendChild(dot);
            const msg = el$1("span", "");
            msg.textContent = issue.message;
            issueRow.appendChild(msg);
            issuesWrap.appendChild(issueRow);
          }
          detail.appendChild(issuesWrap);
        }
        row.appendChild(detail);
      }
      return row;
    }
    mountShell();
    renderBody();
    return function cleanup() {
    };
  }
  function squarify(items, rect) {
    items = items.filter((i) => i.area > 0);
    if (items.length === 0) return [];
    const total = items.reduce((s, i) => s + i.area, 0);
    if (total <= 0) return [];
    const rects = [];
    let { x, y, w, h } = rect;
    for (const item of items) {
      const ratio = item.area / total;
      if (w >= h) {
        const iw = w * ratio;
        rects.push({ x, y, w: iw, h, task: item.task, label: item.label });
        x += iw;
        w -= iw;
      } else {
        const ih = h * ratio;
        rects.push({ x, y, w, h: ih, task: item.task, label: item.label });
        y += ih;
        h -= ih;
      }
    }
    return rects;
  }
  function roundRect(ctx, x, y, w, h, r) {
    if (w <= 0 || h <= 0) return;
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.arcTo(x + w, y, x + w, y + r, r);
    ctx.lineTo(x + w, y + h - r);
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
    ctx.lineTo(x + r, y + h);
    ctx.arcTo(x, y + h, x, y + h - r, r);
    ctx.lineTo(x, y + r);
    ctx.arcTo(x, y, x + r, y, r);
    ctx.closePath();
  }
  function renderTreemap(ctx, w, h, tasks, opts) {
    const { theme, colorMap, hoveredId } = opts;
    const pad2 = 16;
    const titleH = 40;
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = theme.text;
    ctx.font = `bold 16px ${theme.font}`;
    ctx.textAlign = "center";
    ctx.fillText("Task Treemap — Area by Hours", w / 2, titleH / 2 + 6);
    const areaX = pad2, areaY = titleH + pad2 / 2;
    const areaW = w - pad2 * 2, areaH = h - titleH - pad2;
    const validTasks = tasks.filter(
      (t) => !t.isInactive && (t.estimatedHours || 0) > 0 && t.startDate && t.endDate
    );
    if (validTasks.length === 0) return;
    const groups = /* @__PURE__ */ new Map();
    for (const t of validTasks) {
      const key = t.priorityGroup || t.stage || "Other";
      const arr = groups.get(key) || [];
      arr.push(t);
      groups.set(key, arr);
    }
    const groupItems = Array.from(groups.entries()).map(([name, ts]) => ({
      area: ts.reduce((s, t) => s + (Number(t.estimatedHours) || 0), 0),
      label: name,
      tasks: ts
    }));
    groupItems.sort((a, b) => b.area - a.area);
    const groupRects = squarify(
      groupItems.map((g) => ({ area: g.area, label: g.label })),
      { x: areaX, y: areaY, w: areaW, h: areaH }
    );
    for (let gi = 0; gi < groupRects.length; gi++) {
      const gr = groupRects[gi];
      const gData = groupItems[gi];
      const inset = 3;
      ctx.fillStyle = theme.altRowBg;
      roundRect(ctx, gr.x + inset, gr.y + inset, gr.w - inset * 2, gr.h - inset * 2, 8);
      ctx.fill();
      const labelH = gr.h > 50 ? 22 : 0;
      if (labelH > 0) {
        ctx.fillStyle = theme.textMuted;
        ctx.font = `bold 11px ${theme.font}`;
        ctx.textAlign = "left";
        ctx.fillText(gData.label, gr.x + inset + 8, gr.y + inset + 15);
      }
      const taskItems = gData.tasks.map((t) => ({ area: Number(t.estimatedHours) || 0, task: t })).sort((a, b) => b.area - a.area);
      const innerPad = 4;
      const taskRects = squarify(taskItems, {
        x: gr.x + inset + innerPad,
        y: gr.y + inset + labelH + innerPad,
        w: gr.w - inset * 2 - innerPad * 2,
        h: gr.h - inset * 2 - labelH - innerPad * 2
      });
      for (const tr of taskRects) {
        if (tr.w < 2 || tr.h < 2) continue;
        const color = tr.task && colorMap[tr.task.stage || ""] || "#6b7280";
        ctx.fillStyle = color;
        roundRect(ctx, tr.x + 1, tr.y + 1, tr.w - 2, tr.h - 2, 5);
        ctx.fill();
        if (hoveredId && tr.task && tr.task.id === hoveredId) {
          ctx.strokeStyle = "#fff";
          ctx.lineWidth = 2;
          roundRect(ctx, tr.x + 1, tr.y + 1, tr.w - 2, tr.h - 2, 5);
          ctx.stroke();
        }
        if (tr.w > 50 && tr.h > 28 && tr.task) {
          ctx.fillStyle = "#fff";
          ctx.font = `bold 10px ${theme.font}`;
          ctx.textAlign = "center";
          ctx.textBaseline = "middle";
          const cx = tr.x + tr.w / 2, cy = tr.y + tr.h / 2;
          const maxChars = Math.floor(tr.w / 7);
          const name = tr.task.title || tr.task.name || tr.task.id;
          const label = name.length > maxChars ? name.slice(0, maxChars - 1) + "…" : name;
          ctx.fillText(label, cx, cy - 7);
          ctx.font = `10px ${theme.font}`;
          ctx.fillText((Number(tr.task.estimatedHours) || 0) + "h", cx, cy + 7);
        }
      }
    }
    ctx.textBaseline = "alphabetic";
  }
  function parseDate(s) {
    return new Date(s).getTime();
  }
  function renderBubble(ctx, w, h, tasks, opts) {
    const { theme, colorMap, hoveredId } = opts;
    const pad2 = 16;
    const titleH = 40;
    const labelW = 120;
    const bottomH = 36;
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = theme.text;
    ctx.font = `bold 16px ${theme.font}`;
    ctx.textAlign = "center";
    ctx.fillText("Bubble Chart — Size by Hours", w / 2, titleH / 2 + 6);
    const valid = tasks.filter((t) => t.startDate && t.endDate && (t.estimatedHours || 0) > 0);
    if (valid.length === 0) return;
    const chartX = labelW + pad2;
    const chartY = titleH + pad2;
    const chartW = w - chartX - pad2;
    const chartH = h - chartY - bottomH - pad2;
    const groupNames = Array.from(new Set(valid.map((t) => t.priorityGroup || t.stage || "Other")));
    const allDates = valid.flatMap((t) => [parseDate(t.startDate), parseDate(t.endDate)]);
    const minDate = Math.min(...allDates);
    const maxDate = Math.max(...allDates);
    const dateRange = maxDate - minDate || 1;
    const rowH = chartH / groupNames.length;
    const maxHours = Math.max(...valid.map((t) => Number(t.estimatedHours) || 0), 1);
    const scaleFactor = Math.min(rowH * 0.35, 28) / Math.sqrt(maxHours);
    for (let i = 0; i < groupNames.length; i++) {
      const rowY = chartY + i * rowH;
      if (i % 2 === 1) {
        ctx.fillStyle = theme.altRowBg;
        ctx.fillRect(chartX, rowY, chartW, rowH);
      }
      ctx.strokeStyle = theme.gridLine;
      ctx.lineWidth = 0.5;
      ctx.beginPath();
      ctx.moveTo(chartX, rowY + rowH);
      ctx.lineTo(chartX + chartW, rowY + rowH);
      ctx.stroke();
      ctx.fillStyle = theme.text;
      ctx.font = `12px ${theme.font}`;
      ctx.textAlign = "right";
      ctx.fillText(groupNames[i], chartX - 10, rowY + rowH / 2 + 4);
    }
    const today = Date.now();
    if (today >= minDate && today <= maxDate) {
      const tx = chartX + (today - minDate) / dateRange * chartW;
      ctx.save();
      ctx.setLineDash([6, 4]);
      ctx.strokeStyle = theme.todayLine;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(tx, chartY);
      ctx.lineTo(tx, chartY + chartH);
      ctx.stroke();
      ctx.restore();
      ctx.fillStyle = theme.todayLine;
      ctx.font = `bold 10px ${theme.font}`;
      ctx.textAlign = "center";
      ctx.fillText("Today", tx, chartY - 4);
    }
    ctx.fillStyle = theme.textMuted;
    ctx.font = `10px ${theme.font}`;
    ctx.textAlign = "center";
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const startD = new Date(minDate);
    const endD = new Date(maxDate);
    const cur = new Date(startD.getFullYear(), startD.getMonth(), 1);
    while (cur <= endD) {
      const t = cur.getTime();
      if (t >= minDate) {
        const mx = chartX + (t - minDate) / dateRange * chartW;
        ctx.fillText(months[cur.getMonth()] + " " + cur.getFullYear().toString().slice(2), mx, chartY + chartH + 16);
      }
      cur.setMonth(cur.getMonth() + 1);
    }
    for (const task of valid) {
      const midTime = (parseDate(task.startDate) + parseDate(task.endDate)) / 2;
      const grpKey = task.priorityGroup || task.stage || "Other";
      const gIdx = groupNames.indexOf(grpKey);
      const bx = chartX + (midTime - minDate) / dateRange * chartW;
      const by = chartY + gIdx * rowH + rowH / 2;
      const r = Math.max(Math.sqrt(Number(task.estimatedHours) || 0) * scaleFactor, 4);
      const color = colorMap[task.stage || ""] || "#6b7280";
      ctx.beginPath();
      ctx.arc(bx + 1, by + 1, r, 0, Math.PI * 2);
      ctx.fillStyle = "rgba(0,0,0,0.15)";
      ctx.fill();
      ctx.beginPath();
      ctx.arc(bx, by, r, 0, Math.PI * 2);
      ctx.fillStyle = color;
      ctx.globalAlpha = 0.8;
      ctx.fill();
      ctx.globalAlpha = 1;
      if (hoveredId === task.id) {
        ctx.strokeStyle = "#fff";
        ctx.lineWidth = 2;
        ctx.stroke();
      }
      if (r > 18) {
        ctx.fillStyle = "#fff";
        ctx.font = `bold 9px ${theme.font}`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        const name = task.title || task.name || task.id;
        const maxChars = Math.floor(r * 2 / 6);
        const label = name.length > maxChars ? name.slice(0, maxChars - 1) + "…" : name;
        ctx.fillText(label, bx, by);
        ctx.textBaseline = "alphabetic";
      }
    }
    ctx.textBaseline = "alphabetic";
  }
  const registry$1 = [];
  function findIndex(name) {
    for (let i = 0; i < registry$1.length; i++) {
      if (registry$1[i].name === name) return i;
    }
    return -1;
  }
  function registerTemplate(template) {
    if (!template || !template.name) {
      throw new Error("Template.name is required");
    }
    const idx = findIndex(template.name);
    if (idx >= 0) registry$1[idx].template = template;
    else registry$1.push({ name: template.name, template });
  }
  function getTemplate(name) {
    const idx = findIndex(name);
    if (idx < 0) throw new Error("Unknown template: '" + name + "'");
    return registry$1[idx].template;
  }
  function hasTemplate(name) {
    return findIndex(name) >= 0;
  }
  function listTemplates() {
    const names = [];
    for (let i = 0; i < registry$1.length; i++) names.push(registry$1[i].name);
    return names;
  }
  function defineTemplate(template) {
    return template;
  }
  const DEFAULT_FEATURES = {
    titleBar: true,
    statsPanel: true,
    filterBar: true,
    zoomBar: true,
    sidebar: true,
    detailPanel: true,
    auditPanel: true,
    hrsWkStrip: true,
    dragReparent: true,
    depthShading: true,
    groupByToggle: true,
    hideCompletedToggle: true,
    // DM-3 (0.183) — new columns default OFF so existing surfaces keep their
    // current tree width. DH opts in per-template / per-mount via features
    // overrides. hoursLabel (combined "40h (75% budget)") remains on the
    // default column — DM-3 is for surfaces that want the two values split.
    hoursColumn: false,
    budgetUsedColumn: false,
    // DM-5 (0.183) — header-row completion bar defaults ON; pairs with DM-4.
    headerRowCompletionBar: true
  };
  const DEFAULT_THEME = {
    primary: "#2563eb",
    primaryHover: "#1d4ed8",
    accent: "#7c3aed",
    bg: "#f8fafc",
    surface: "#ffffff",
    surfaceAlt: "#f1f5f9",
    border: "#e2e8f0",
    borderSubtle: "#f1f5f9",
    textPrimary: "#0f172a",
    textSecondary: "#475569",
    textMuted: "#94a3b8",
    textInverse: "#ffffff",
    danger: "#ef4444",
    warning: "#f59e0b",
    success: "#10b981",
    info: "#3b82f6",
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
    fontFamilyMono: "'SF Mono', 'Cascadia Code', 'Consolas', monospace",
    fontSizeBase: "12px",
    fontSizeSm: "10px",
    fontSizeXs: "9px",
    radiusSm: "4px",
    radiusMd: "6px",
    radiusLg: "12px",
    radiusFull: "9999px",
    spacingUnit: "4px",
    ganttGridColor: "#e5e7eb",
    ganttHeaderBg: "#f3f4f6",
    ganttWeekendBg: "rgba(229,231,235,0.4)",
    ganttTodayLine: "#ef4444",
    ganttTodayBg: "rgba(239,68,68,0.08)",
    ganttBarDefault: "#94a3b8",
    ganttBarTextColor: "#ffffff",
    ganttRowHoverBg: "rgba(59,130,246,0.04)",
    ganttSelectionRing: "#3b82f6",
    ganttDependencyLine: "#3b82f6"
  };
  const ALL_SLOT_NAMES = [
    "TitleBar",
    "StatsPanel",
    "FilterBar",
    "ZoomBar",
    "Sidebar",
    "ContentArea",
    "DetailPanel",
    "AuditPanel",
    "HrsWkStrip"
  ];
  function inheritReact(prev, next) {
    return {
      react: next && next.react || prev && prev.react,
      vanilla: next && next.vanilla || prev && prev.vanilla
    };
  }
  function collectChain(template) {
    const chain = [];
    const visited = /* @__PURE__ */ new Set();
    let cursor = typeof template === "string" ? getTemplate(template) : template;
    while (cursor) {
      if (visited.has(cursor.name)) {
        throw new Error("Template cycle detected at '" + cursor.name + "'");
      }
      visited.add(cursor.name);
      chain.push(cursor);
      if (cursor.extends) {
        if (!hasTemplate(cursor.extends)) {
          throw new Error(
            "Template '" + cursor.name + "' extends unknown '" + cursor.extends + "'"
          );
        }
        cursor = getTemplate(cursor.extends);
      } else {
        cursor = void 0;
      }
    }
    chain.reverse();
    return chain;
  }
  function shallowMerge(prev, next) {
    const out = { ...prev };
    Object.keys(next).forEach((k) => {
      if (next[k] !== void 0) out[k] = next[k];
    });
    return out;
  }
  function mergeComponents(prev, next) {
    const out = { ...prev };
    Object.keys(next).forEach((slot) => {
      out[slot] = inheritReact(prev[slot], next[slot]);
    });
    return out;
  }
  function resolveTemplate(template, overrides) {
    const chain = collectChain(template);
    const leaf = chain[chain.length - 1];
    let features = { ...DEFAULT_FEATURES };
    let theme = { ...DEFAULT_THEME };
    let buckets = [];
    let filters = [];
    let views = ["gantt", "list", "treemap", "bubbles", "calendar", "flow"];
    let components = {};
    let stylesheet = {};
    let title = "Nimbus Gantt";
    let version = "";
    let apiDocsUrl;
    let fullscreenUrl;
    let progressLabel;
    let hideRecordIds;
    chain.forEach((tpl) => {
      const d = tpl.defaults || {};
      if (d.features) features = { ...features, ...d.features };
      if (d.theme) theme = { ...theme, ...d.theme };
      if (d.buckets) buckets = d.buckets;
      if (d.filters) filters = d.filters;
      if (d.views) views = d.views;
      if (d.title !== void 0) title = d.title;
      if (d.version !== void 0) version = d.version;
      if (d.apiDocsUrl !== void 0) apiDocsUrl = d.apiDocsUrl;
      if (d.fullscreenUrl !== void 0) fullscreenUrl = d.fullscreenUrl;
      if (d.progressLabel !== void 0) progressLabel = d.progressLabel;
      if (d.hideRecordIds !== void 0) hideRecordIds = d.hideRecordIds;
      if (tpl.stylesheet && (tpl.stylesheet.url || tpl.stylesheet.inline || tpl.stylesheet.importedByBundler)) {
        stylesheet = tpl.stylesheet;
      }
      if (tpl.components) {
        components = mergeComponents(components, tpl.components);
      }
    });
    if (overrides) {
      if (overrides.features) features = shallowMerge(features, overrides.features);
      if (overrides.theme) theme = shallowMerge(theme, overrides.theme);
      if (overrides.buckets) buckets = overrides.buckets;
      if (overrides.filters) filters = overrides.filters;
      if (overrides.views) views = overrides.views;
      if (overrides.title !== void 0) title = overrides.title;
      if (overrides.version !== void 0) version = overrides.version;
      if (overrides.apiDocsUrl !== void 0) apiDocsUrl = overrides.apiDocsUrl;
      if (overrides.fullscreenUrl !== void 0) fullscreenUrl = overrides.fullscreenUrl;
      if (overrides.progressLabel !== void 0) progressLabel = overrides.progressLabel;
      if (overrides.hideRecordIds !== void 0) hideRecordIds = overrides.hideRecordIds;
      if (overrides.components) {
        components = mergeComponents(components, overrides.components);
      }
    }
    const finalComponents = {};
    ALL_SLOT_NAMES.forEach((s) => {
      finalComponents[s] = components[s] || {};
    });
    return {
      templateName: leaf.name,
      features,
      theme,
      buckets,
      filters,
      views,
      components: finalComponents,
      stylesheet,
      title,
      version,
      apiDocsUrl,
      fullscreenUrl,
      progressLabel,
      hideRecordIds,
      // mode defaults to 'fullscreen'; IIFEApp / React driver may overwrite
      // this post-resolve to reflect the caller's MountOptions.mode.
      mode: "fullscreen"
    };
  }
  const INITIAL_STATE = {
    viewMode: "gantt",
    filter: "active",
    search: "",
    zoom: "week",
    groupBy: "priority",
    hideCompleted: true,
    sidebarOpen: false,
    statsOpen: false,
    detailOpen: false,
    detailMode: "view",
    auditPanelOpen: true,
    // v9 parity — Audit strip defaults to open
    fullscreen: false,
    selectedTaskId: null,
    pendingPatchCount: 0,
    adminOpen: false,
    advisorOpen: false,
    featureOverrides: {}
  };
  function reduceAppState(state, event) {
    switch (event.type) {
      case "SET_VIEW":
        return { ...state, viewMode: event.mode };
      case "SET_FILTER":
        return { ...state, filter: event.id };
      case "SET_SEARCH":
        return { ...state, search: event.q };
      case "SET_ZOOM":
        return { ...state, zoom: event.zoom };
      case "SET_GROUP_BY":
        return { ...state, groupBy: event.groupBy };
      case "TOGGLE_HIDE_COMPLETED":
        return { ...state, hideCompleted: !state.hideCompleted };
      case "TOGGLE_SIDEBAR":
        return { ...state, sidebarOpen: !state.sidebarOpen };
      case "TOGGLE_STATS":
        return { ...state, statsOpen: !state.statsOpen };
      case "TOGGLE_DETAIL": {
        const opening = event.taskId !== void 0;
        return {
          ...state,
          detailOpen: opening ? true : !state.detailOpen,
          selectedTaskId: opening ? event.taskId : state.selectedTaskId,
          // When opening: use editMode payload (default 'view'). When closing
          // or toggling (no taskId): keep existing detailMode — v10 dblclick
          // sets editMode:true, plain click leaves it 'view'.
          detailMode: opening ? event.editMode ? "edit" : "view" : state.detailMode
        };
      }
      case "SET_DETAIL_MODE":
        return { ...state, detailMode: event.mode };
      case "TOGGLE_AUDIT_PANEL":
        return { ...state, auditPanelOpen: !state.auditPanelOpen };
      case "TOGGLE_FULLSCREEN":
        return { ...state, fullscreen: !state.fullscreen };
      case "SELECT_TASK":
        return { ...state, selectedTaskId: event.taskId };
      case "PATCH":
        return { ...state, pendingPatchCount: state.pendingPatchCount + 1 };
      case "RESET_PATCHES":
        return { ...state, pendingPatchCount: 0 };
      case "TOGGLE_ADMIN":
        return { ...state, adminOpen: !state.adminOpen };
      case "TOGGLE_ADVISOR":
        return { ...state, advisorOpen: !state.advisorOpen };
      case "TOGGLE_FEATURE": {
        const current = state.featureOverrides[event.key];
        return {
          ...state,
          featureOverrides: {
            ...state.featureOverrides,
            [event.key]: current === void 0 ? false : !current
          }
        };
      }
      default:
        return state;
    }
  }
  const SLOT_TO_FEATURE = {
    TitleBar: "titleBar",
    StatsPanel: "statsPanel",
    FilterBar: "filterBar",
    ZoomBar: "zoomBar",
    Sidebar: "sidebar",
    ContentArea: "titleBar",
    // ContentArea is always rendered — titleBar as a sentinel that's effectively always on
    DetailPanel: "detailPanel",
    AuditPanel: "auditPanel",
    HrsWkStrip: "hrsWkStrip"
  };
  function shouldRenderSlot(slot, features) {
    if (slot === "ContentArea") return true;
    const flag = SLOT_TO_FEATURE[slot];
    return features[flag] !== false;
  }
  const SLOT_ORDER = [
    "TitleBar",
    "StatsPanel",
    "FilterBar",
    "ZoomBar",
    "AuditPanel",
    "HrsWkStrip",
    "ContentArea"
    // wraps Sidebar + main + DetailPanel
  ];
  const MARKER_ATTR = "data-nga-template-css";
  async function ensureTemplateCss(container, stylesheet) {
    if (!stylesheet) return;
    const key = stylesheet.url || "inline";
    const existing = container.querySelector(
      "style[" + MARKER_ATTR + '="' + cssAttrEscape(key) + '"]'
    );
    if (existing) return;
    let css = stylesheet.inline || "";
    if (!css && stylesheet.url) {
      try {
        const res = await fetch(stylesheet.url);
        if (!res.ok) {
          console.warn("[nimbus-gantt] template CSS fetch failed:", stylesheet.url, res.status);
          return;
        }
        css = await res.text();
      } catch (err) {
        console.warn("[nimbus-gantt] template CSS fetch error:", err);
        return;
      }
    }
    if (!css) return;
    const styleEl = document.createElement("style");
    styleEl.setAttribute(MARKER_ATTR, key);
    styleEl.textContent = css;
    container.appendChild(styleEl);
  }
  function removeTemplateCss(container) {
    const styles = container.querySelectorAll("style[" + MARKER_ATTR + "]");
    styles.forEach((s) => s.remove());
  }
  function cssAttrEscape(v) {
    return v.replace(/"/g, "&quot;");
  }
  function kebab(s) {
    return s.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase());
  }
  function themeToCssVars(theme) {
    const out = [];
    Object.keys(theme).forEach((k) => {
      const v = theme[k];
      if (v !== void 0 && v !== null) {
        out.push("--nga-" + kebab(String(k)) + ":" + String(v));
      }
    });
    return out.join(";");
  }
  function themeToScopedCss(templateName, theme) {
    return '.nga-root[data-template="' + templateName + '"]{' + themeToCssVars(theme) + "}";
  }
  function detectEnabled() {
    if (typeof window === "undefined") return false;
    try {
      if (window.NGA_DIAG === true) return true;
      if (typeof localStorage !== "undefined" && localStorage.getItem("NGA_DIAG") === "1") return true;
      const q = window.location && window.location.search || "";
      if (/[?&]nga_diag=1(?:&|$)/.test(q)) return true;
    } catch {
    }
    return false;
  }
  const enabled = detectEnabled();
  if (enabled && typeof window !== "undefined") {
    const w = window;
    if (!Array.isArray(w.__nga_diag)) w.__nga_diag = [];
  }
  function now() {
    if (typeof performance !== "undefined" && typeof performance.now === "function") {
      return performance.now();
    }
    return Date.now();
  }
  function diag(kind, data) {
    if (!enabled) return;
    const ev = { t: now(), kind, ...data || {} };
    try {
      const arr = window.__nga_diag;
      if (Array.isArray(arr)) arr.push(ev);
    } catch {
    }
    try {
      if (window.NGA_DIAG_VERBOSE === true) {
        console.log("[NGA]", kind, data || {});
      }
    } catch {
    }
  }
  const cloudnimbusTheme = {
    // Brand
    primary: "#2563eb",
    // blue-600
    primaryHover: "#1d4ed8",
    // blue-700
    accent: "#7c3aed",
    // violet-600
    // Surfaces
    bg: "#f8fafc",
    // slate-50
    surface: "#ffffff",
    surfaceAlt: "#f1f5f9",
    // slate-100
    border: "#e2e8f0",
    // slate-200
    borderSubtle: "#f1f5f9",
    // slate-100
    // Text
    textPrimary: "#0f172a",
    // slate-900
    textSecondary: "#475569",
    // slate-600
    textMuted: "#94a3b8",
    // slate-400
    textInverse: "#ffffff",
    // Semantic
    danger: "#ef4444",
    // red-500
    warning: "#f59e0b",
    // amber-500
    success: "#10b981",
    // emerald-500
    info: "#3b82f6",
    // blue-500
    // Typography
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
    fontFamilyMono: "'SF Mono', 'Cascadia Code', 'Consolas', monospace",
    fontSizeBase: "12px",
    fontSizeSm: "10px",
    fontSizeXs: "9px",
    // Radii
    radiusSm: "4px",
    radiusMd: "6px",
    radiusLg: "12px",
    radiusFull: "9999px",
    spacingUnit: "4px",
    // Gantt-specific (V3_MATCH_THEME verbatim)
    ganttGridColor: "#e5e7eb",
    ganttHeaderBg: "#f3f4f6",
    ganttWeekendBg: "rgba(229,231,235,0.4)",
    ganttTodayLine: "#ef4444",
    ganttTodayBg: "rgba(239,68,68,0.08)",
    ganttBarDefault: "#94a3b8",
    ganttBarTextColor: "#ffffff",
    ganttRowHoverBg: "rgba(59,130,246,0.04)",
    ganttSelectionRing: "#3b82f6",
    ganttDependencyLine: "#3b82f6"
  };
  const CLOUD_NIMBUS_PRIORITY_BUCKETS = [
    { id: "top-priority", label: "NOW", color: "#dc2626", bgTint: "#ef4444", order: 0 },
    { id: "active", label: "NEXT", color: "#d97706", bgTint: "#f59e0b", order: 1 },
    { id: "follow-on", label: "PLANNED", color: "#059669", bgTint: "#10b981", order: 2 },
    { id: "proposed", label: "PROPOSED", color: "#2563eb", bgTint: "#3b82f6", order: 3 },
    { id: "deferred", label: "HOLD", color: "#94a3b8", bgTint: "#94a3b8", order: 4 }
  ];
  const PROPOSAL_STAGES = {
    "Backlog": true,
    "Scoping In Progress": true,
    "Ready for Sizing": true,
    "Ready for Development": true
  };
  const CLOUD_NIMBUS_FILTERS = [
    {
      id: "active",
      label: "Active",
      predicate: (t) => !DONE_STAGES[t.stage || ""] && !t.isInactive
    },
    {
      id: "proposal",
      label: "Proposal & Expansion",
      predicate: (t) => PROPOSAL_STAGES[t.stage || ""] || t.priorityGroup === "proposed"
    },
    {
      id: "done",
      label: "Done",
      predicate: (t) => !!DONE_STAGES[t.stage || ""]
    },
    {
      id: "real",
      label: "Real T-NNNN tickets",
      predicate: (t) => !!(t.id && String(t.id).indexOf("T-") === 0)
    },
    {
      id: "workstreams",
      label: "Workstream rollups",
      predicate: (t) => !!(t.id && String(t.id).indexOf("WS-") === 0)
    },
    {
      id: "all",
      label: "Everything",
      predicate: () => true
    }
  ];
  const CLOUD_NIMBUS_VIEW_MODES = [
    { id: "gantt", label: "Gantt", icon: "▤" },
    { id: "list", label: "List", icon: "☰" },
    { id: "treemap", label: "Treemap", icon: "▦" },
    { id: "bubbles", label: "Bubbles", icon: "◉" },
    { id: "calendar", label: "Calendar", icon: "▥" },
    { id: "flow", label: "Flow", icon: "⟿" }
  ];
  const CLOUD_NIMBUS_VIEWS = [
    "gantt",
    "list",
    "treemap",
    "bubbles",
    "calendar",
    "flow"
  ];
  const CLOUD_NIMBUS_CATEGORIES = [
    { category: "in-flight", label: "In Flight", color: "#10b981" },
    { category: "next-up", label: "Next Up", color: "#3b82f6" },
    { category: "paused", label: "Paused", color: "#94a3b8" },
    { category: "backlog", label: "Backlog (sized)", color: "#f59e0b" },
    { category: "expansion", label: "Expansion", color: "#a78bfa" },
    { category: "done", label: "Done", color: "#cbd5e1" }
  ];
  const CLOUD_NIMBUS_POOL = [
    { name: "Glen", role: "Principal Engineer", hoursPerMonth: 80, active: true },
    { name: "Mahi", role: "SFDC Dev", hoursPerMonth: 50, active: true },
    { name: "Antima", role: "SFDC Dev (PT)", hoursPerMonth: 40, active: true }
  ];
  const CLS_TITLEBAR = "nga-titlebar bg-white border-b border-slate-200 px-3 py-1.5 flex flex-col gap-1.5 min-w-0 overflow-x-hidden";
  const CLS_TITLEBAR_ROW = "flex items-center gap-2 flex-wrap min-w-0";
  const CLS_TITLE_BRAND = "text-sm font-bold text-slate-900";
  const CLS_VERSION_PILL = "text-[9px] font-bold text-violet-600 bg-violet-50 border border-violet-200 rounded-full px-2 py-0.5";
  const CLS_SEP = "text-slate-200";
  const CLS_TB_FILL = "flex-1";
  const CLS_TB_SUMMARY = "text-[10px] text-slate-500 font-mono";
  const CLS_PILL_BTN_BASE = "text-[10px] font-semibold px-2 py-1 rounded-full border transition-colors cursor-pointer";
  const CLS_PILL_BTN_ACTIVE_VIOLET = "bg-violet-600 text-white border-violet-600";
  const CLS_PILL_BTN_IDLE_VIOLET = "bg-white text-slate-500 border-slate-200 hover:border-violet-300";
  const CLS_PILL_BTN_ACTIVE_BLUE = "bg-blue-600 text-white border-blue-600";
  const CLS_PILL_BTN_IDLE_BLUE = "bg-white text-slate-600 border-slate-200 hover:border-blue-300";
  const CLS_PILL_BTN_ACTIVE_SLATE = "bg-slate-800 text-white border-slate-800";
  const CLS_PILL_BTN_IDLE_SLATE = "bg-white text-slate-500 border-slate-200 hover:border-slate-400";
  const CLS_FILTERBAR = "nga-filterbar bg-white border-b border-slate-100 px-3 py-1.5 min-w-0 overflow-x-hidden";
  const CLS_FILTERBAR_INNER = "flex items-center gap-2 flex-wrap min-w-0";
  const CLS_FILTERBAR_LABEL = "text-[10px] font-bold text-slate-500 uppercase tracking-wide";
  const CLS_FILTER_BTN_BASE = "text-[10px] font-semibold px-2.5 py-1 rounded-full border transition-colors";
  const CLS_SEARCH_WRAP = "relative inline-flex items-center";
  const CLS_SEARCH_ICON = "absolute left-2 text-[10px] text-slate-400 pointer-events-none";
  const CLS_SEARCH_INPUT = "text-[10px] pl-6 pr-6 py-1 rounded-full border border-slate-200 bg-white text-slate-700 placeholder:text-slate-400 focus:border-blue-400 focus:outline-none w-48";
  const CLS_SEARCH_CLEAR = "absolute right-2 text-[12px] text-slate-400 hover:text-slate-700";
  const CLS_LEGEND_CHIP = "inline-flex items-center gap-1";
  const CLS_LEGEND_SWATCH = "w-3 h-3 rounded";
  const CLS_LEGEND_TEXT = "text-[9px] text-slate-600";
  const CLS_TEAM_PILL = "inline-flex items-center gap-1 text-[9px] font-semibold text-indigo-600 border border-indigo-200 bg-indigo-50 hover:bg-indigo-100 rounded px-2 py-0.5 transition-colors";
  const CLS_CAPACITY_TEXT = "text-[9px] text-slate-400 font-mono";
  const CLS_AUTO_SCHED_BTN = "text-[9px] font-bold text-white bg-indigo-600 hover:bg-indigo-700 px-2.5 py-1 rounded-full transition-colors";
  const CLS_COUNT_LABEL = "text-[10px] text-slate-400";
  const CLS_RESET_LINK = "text-[9px] text-rose-500 hover:text-rose-700 underline";
  const CLS_ZOOMBAR = "nga-zoombar flex items-center gap-2";
  const CLS_STATS_PANEL = "nga-stats bg-white border-b border-slate-100 px-3 py-3";
  const CLS_STATS_GRID = "grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2";
  const CLS_KPI_CARD_BASE = "bg-white rounded-xl border-2 px-3 py-2 shadow-sm";
  const CLS_KPI_LABEL = "text-[10px] font-bold uppercase tracking-wide opacity-70";
  const CLS_KPI_VALUE = "text-xl font-bold font-mono mt-0.5";
  const CLS_KPI_HINT = "text-[9px] text-slate-400 mt-0.5";
  const CLS_SIDEBAR = "nga-sidebar h-full flex flex-col bg-white border-r border-slate-200 select-none";
  const CLS_SIDEBAR_HEADER = "px-3 py-2 border-b border-slate-200 flex-shrink-0";
  const CLS_SIDEBAR_LABEL_BIG = "text-[10px] font-bold text-slate-500 uppercase tracking-wide";
  const CLS_SIDEBAR_LABEL_SM = "text-[9px] text-slate-400 mt-0.5";
  const CLS_SIDEBAR_RESET = "text-[9px] font-bold text-rose-500 hover:text-rose-700 uppercase px-2 py-1 rounded hover:bg-rose-50 transition-colors";
  const CLS_CAPACITY_INPUT = "w-14 text-[10px] font-mono bg-slate-50 border border-slate-200 rounded px-1.5 py-0.5 text-center";
  const CLS_SIDEBAR_AUTO_BTN = "w-full text-[10px] font-bold uppercase px-2 py-1.5 rounded-lg bg-blue-600 text-white hover:bg-blue-500 transition-colors";
  const CLS_SIDEBAR_SCROLL = "flex-1 overflow-y-auto";
  const CLS_BUCKET_HEADER = "px-3 py-1.5 flex items-center justify-between";
  const CLS_BUCKET_LABEL = "text-[9px] font-bold uppercase tracking-wider";
  const CLS_BUCKET_COUNT = "text-[9px] text-slate-400 font-mono";
  const CLS_ITEM_ROW = "px-3 py-1.5 flex items-center gap-2 border-b border-slate-50 hover:bg-slate-50 transition-colors";
  const CLS_DRAG_HANDLE = "text-[11px] text-slate-300 flex-shrink-0 leading-none cursor-grab active:cursor-grabbing hover:text-slate-500 transition-colors px-0.5 py-1";
  const CLS_CAT_DOT = "w-2 h-2 rounded-full flex-shrink-0";
  const CLS_ITEM_TITLE = "text-[10px] text-slate-700 truncate flex-1 min-w-0";
  const CLS_ITEM_HOURS = "text-[9px] text-slate-400 font-mono flex-shrink-0";
  const CLS_SIDEBAR_HEADER_ROW = "flex items-center justify-between";
  const CLS_SIDEBAR_CTRLS = "mt-2 space-y-1.5";
  const CLS_SIDEBAR_CAP_ROW = "flex items-center gap-2";
  const CLS_SIDEBAR_CAP_LBL = "text-[9px] text-slate-500";
  const CLS_SIDEBAR_CAP_SUF = "text-[9px] text-slate-400";
  const CLS_BUCKET_SECTION_BASE = "border-b transition-colors";
  const CLS_BUCKET_EMPTY_TEXT = "px-3 py-3 text-[10px] text-slate-400 italic";
  const CLS_BUCKET_EMPTY_INDICATOR_BASE = "mx-2 my-1 h-0.5 rounded transition-all";
  const CLS_BUCKET_EMPTY_INDICATOR_ON = "bg-blue-400 opacity-100";
  const CLS_BUCKET_EMPTY_INDICATOR_OFF = "bg-transparent opacity-0";
  const CLS_BUCKET_INDICATOR = "mx-2 h-0.5 bg-blue-500 rounded pointer-events-none";
  const CLS_CONTENT_OUTER = "nga-content-outer flex-1 flex overflow-hidden min-w-0 min-h-0";
  const CLS_SIDEBAR_WRAP = "flex-shrink-0 border-r border-slate-200 bg-white overflow-y-auto overflow-x-hidden";
  const CLS_RESIZER = "w-1 flex-shrink-0 bg-slate-200 hover:bg-blue-400 cursor-col-resize transition-colors";
  const CLS_CONTENT = "nga-content flex-1 relative min-w-0 min-h-0";
  const CLS_DETAIL = "nga-detail fixed z-[9999] shadow-2xl rounded-xl border-2 overflow-hidden bg-white";
  const CLS_DETAIL_HEADER = "flex items-center justify-between px-3 py-2 cursor-grab active:cursor-grabbing select-none";
  const CLS_DETAIL_BODY = "px-3 py-3 space-y-2 max-h-[400px] overflow-y-auto text-xs";
  const CLS_CATEGORY_PILL = "text-[9px] font-bold uppercase px-1.5 py-0.5 rounded-full flex-shrink-0";
  const CLS_AUDIT = "nga-audit bg-fuchsia-50/60 border-b border-fuchsia-200 px-3 py-2";
  const CLS_AUDIT_LABEL = "text-[10px] font-bold text-fuchsia-700 uppercase tracking-wide shrink-0";
  const CLS_AUDIT_STATUS_DIRTY = "text-[10px] font-semibold px-2 py-0.5 rounded-full bg-amber-100 text-amber-800";
  const CLS_AUDIT_STATUS_CLEAN = "text-[10px] font-semibold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800";
  const CLS_AUDIT_INPUT = "flex-1 min-w-[200px] text-[11px] px-2 py-1 border border-slate-300 rounded focus:outline-none focus:border-fuchsia-500";
  const CLS_AUDIT_SUBMIT = "text-[11px] font-bold px-3 py-1 rounded bg-fuchsia-600 text-white hover:bg-fuchsia-700 disabled:opacity-50 disabled:cursor-not-allowed";
  const CLS_AUDIT_RESET = "text-[11px] font-bold px-3 py-1 rounded bg-white text-slate-700 border border-slate-300 hover:border-rose-400 hover:text-rose-600";
  const CLS_HRSWK = "nga-hrswkstrip bg-slate-50 border-b border-slate-200 px-3 py-1.5 flex items-end gap-1 overflow-x-auto flex-shrink-0";
  const CLS_HRSWK_LABEL = "text-[9px] font-bold text-slate-400 uppercase tracking-wide mr-1 shrink-0 self-center";
  const CLS_HRSWK_COL = "flex flex-col items-center gap-0.5 shrink-0 w-12";
  const BUCKET_META = {
    "top-priority": { label: "Now", text: "text-red-700", bg: "bg-red-50", border: "border-red-200", activeBg: "bg-red-100" },
    "active": { label: "Next", text: "text-amber-700", bg: "bg-amber-50", border: "border-amber-200", activeBg: "bg-amber-100" },
    "follow-on": { label: "Planned", text: "text-emerald-700", bg: "bg-emerald-50", border: "border-emerald-200", activeBg: "bg-emerald-100" },
    "proposed": { label: "Proposed", text: "text-blue-700", bg: "bg-blue-50", border: "border-blue-200", activeBg: "bg-blue-100" },
    "deferred": { label: "Hold", text: "text-slate-400", bg: "bg-slate-50", border: "border-slate-200", activeBg: "bg-slate-100" }
  };
  const CATEGORY_DOT = {
    "in-flight": "#10b981",
    "next-up": "#3b82f6",
    "paused": "#94a3b8",
    "backlog": "#f59e0b",
    "expansion": "#a78bfa",
    "done": "#cbd5e1"
  };
  const STATS_TONE = {
    slate: { border: "border-slate-200", label: "text-slate-500", value: "text-slate-800" },
    emerald: { border: "border-emerald-200", label: "text-emerald-700", value: "text-emerald-800" },
    blue: { border: "border-blue-200", label: "text-blue-700", value: "text-blue-800" },
    purple: { border: "border-purple-200", label: "text-purple-700", value: "text-purple-800" },
    amber: { border: "border-amber-200", label: "text-amber-700", value: "text-amber-800" },
    indigo: { border: "border-indigo-200", label: "text-indigo-700", value: "text-indigo-800" }
  };
  const ZOOMS$2 = ["day", "week", "month", "quarter"];
  const GROUPS = ["priority", "epic"];
  const CLS_GROUP_BOTH = "bg-indigo-600 text-white border-indigo-600";
  const CLS_GROUP_GANTT = "bg-indigo-100 text-indigo-700 border-indigo-400";
  const CLS_GROUP_SIDE = "bg-blue-100 text-blue-700 border-blue-400";
  const CLS_GROUP_NEITHER = "bg-white text-slate-500 border-slate-200 hover:border-indigo-300";
  const CLS_RIGHT_UNPIN_OFF = "bg-white text-slate-500 border-slate-200 hover:border-amber-300";
  const CLS_RIGHT_FS_ON = "bg-slate-700 text-white border-slate-700";
  const CLS_RIGHT_FS_OFF = "bg-white text-slate-500 border-slate-200 hover:border-slate-400";
  const CLS_RIGHT_ADMIN_ON = "bg-rose-500 text-white border-rose-500";
  const CLS_RIGHT_ADMIN_OFF = "bg-white text-slate-400 border-slate-200 hover:border-rose-300";
  const CLS_RIGHT_ADVISOR_ON = "bg-indigo-600 text-white border-indigo-600";
  const CLS_RIGHT_ADVISOR_OFF = "bg-white text-indigo-500 border-indigo-200 hover:border-indigo-400";
  const CLS_GROUP_LABEL = "text-[9px] text-slate-400";
  const CLS_V3_LINK = "text-[9px] text-slate-400 hover:text-blue-500";
  const CLS_SUPER_TAG = "ml-0.5 text-[8px] opacity-60";
  function mkSep$1() {
    const s = el$1("span", CLS_SEP);
    s.textContent = "|";
    return s;
  }
  function monthsToComplete(hours, hoursPerMonth) {
    if (!hoursPerMonth || hoursPerMonth <= 0) return Infinity;
    return hours / hoursPerMonth;
  }
  function TitleBarVanilla$1(initial) {
    const root = el$1("div", CLS_TITLEBAR);
    root.setAttribute("data-slot", "TitleBar");
    let currentProps = initial;
    function render(p) {
      clear(root);
      const { config, state, dispatch, data } = p;
      const rowViews = el$1("div", CLS_TITLEBAR_ROW);
      rowViews.setAttribute("data-nga-titlebar-row", "views");
      const rowMain = el$1("div", CLS_TITLEBAR_ROW);
      rowMain.setAttribute("data-nga-titlebar-row", "main");
      const enabledViews = CLOUD_NIMBUS_VIEW_MODES.filter(
        (v) => !config.views || config.views.includes(v.id)
      );
      if (enabledViews.length > 1) {
        enabledViews.forEach((v) => {
          const on = state.viewMode === v.id;
          const cls = CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_VIOLET : CLS_PILL_BTN_IDLE_VIOLET);
          const btn = el$1("button", cls);
          const ico = el$1("span", "mr-1");
          ico.textContent = v.icon;
          btn.appendChild(ico);
          btn.appendChild(document.createTextNode(v.label));
          btn.addEventListener("click", () => dispatch({ type: "SET_VIEW", mode: v.id }));
          rowViews.appendChild(btn);
        });
        root.appendChild(rowViews);
      }
      const brand = el$1("span", CLS_TITLE_BRAND);
      brand.textContent = config.title || "Pro Forma Timeline";
      rowMain.appendChild(brand);
      const version = el$1("span", CLS_VERSION_PILL);
      version.textContent = config.version || "v10 · Nimbus Gantt";
      rowMain.appendChild(version);
      rowMain.appendChild(mkSep$1());
      function toggleBtn(label, on, ev) {
        const cls = CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_BLUE : CLS_PILL_BTN_IDLE_BLUE);
        const b = el$1("button", cls);
        b.textContent = label;
        b.addEventListener("click", ev);
        return b;
      }
      rowMain.appendChild(toggleBtn("Sidebar", state.sidebarOpen, () => dispatch({ type: "TOGGLE_SIDEBAR" })));
      rowMain.appendChild(toggleBtn("Stats", state.statsOpen, () => dispatch({ type: "TOGGLE_STATS" })));
      if (config.features.auditPanel) {
        rowMain.appendChild(toggleBtn("Audit", state.auditPanelOpen, () => dispatch({ type: "TOGGLE_AUDIT_PANEL" })));
      }
      rowMain.appendChild(mkSep$1());
      ZOOMS$2.forEach((z) => {
        const on = state.zoom === z;
        const cls = CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_SLATE : CLS_PILL_BTN_IDLE_SLATE);
        const b = el$1("button", cls);
        b.textContent = z.charAt(0).toUpperCase() + z.slice(1);
        b.addEventListener("click", () => dispatch({ type: "SET_ZOOM", zoom: z }));
        rowMain.appendChild(b);
      });
      if (config.features.groupByToggle) {
        rowMain.appendChild(mkSep$1());
        const gLbl = el$1("span", CLS_GROUP_LABEL);
        gLbl.textContent = "Group:";
        gLbl.title = "Left-click = Gantt · Right-click = Sidebar";
        rowMain.appendChild(gLbl);
        GROUPS.forEach((g) => {
          const isGantt = state.groupBy === g;
          const isSide = state.groupBy === g;
          let variant = CLS_GROUP_NEITHER;
          if (isGantt && isSide) variant = CLS_GROUP_BOTH;
          else if (isGantt) variant = CLS_GROUP_GANTT;
          else if (isSide) variant = CLS_GROUP_SIDE;
          const cls = CLS_PILL_BTN_BASE + " " + variant;
          const b = el$1("button", cls);
          b.textContent = g === "priority" ? "Priority" : "Epics";
          b.title = "Left-click: Gantt → " + g + " · Right-click: Sidebar → " + g;
          if (isGantt && !isSide) {
            const sup = el$1("span", CLS_SUPER_TAG);
            sup.textContent = "G";
            b.appendChild(sup);
          } else if (isSide && !isGantt) {
            const sup = el$1("span", CLS_SUPER_TAG);
            sup.textContent = "S";
            b.appendChild(sup);
          }
          b.addEventListener("click", () => dispatch({ type: "SET_GROUP_BY", groupBy: g }));
          b.addEventListener("contextmenu", (e) => {
            e.preventDefault();
            dispatch({ type: "SET_GROUP_BY", groupBy: g });
          });
          rowMain.appendChild(b);
        });
      }
      const fill = el$1("div", CLS_TB_FILL);
      rowMain.appendChild(fill);
      const hoursHigh = data.stats.est;
      const hoursLow = data.stats.estLow || data.stats.est;
      const totalCap = CLOUD_NIMBUS_POOL.reduce((s, m) => s + (m.active !== false ? m.hoursPerMonth : 0), 0);
      const mLow = monthsToComplete(hoursLow, totalCap);
      const mHigh = monthsToComplete(hoursHigh, totalCap);
      const mLowS = isFinite(mLow) ? mLow.toFixed(1) : "∞";
      const mHighS = isFinite(mHigh) ? mHigh.toFixed(1) : "∞";
      const summary = el$1("span", CLS_TB_SUMMARY);
      summary.textContent = data.stats.scheduled + " scheduled · " + hoursLow + "–" + hoursHigh + "h · " + mLowS + "–" + mHighS + " mo";
      rowMain.appendChild(summary);
      const unpinBtn = el$1(
        "button",
        CLS_PILL_BTN_BASE + " " + CLS_RIGHT_UNPIN_OFF
      );
      unpinBtn.textContent = "Unpin";
      unpinBtn.title = "Hide toolbar";
      unpinBtn.setAttribute("data-nga-unpin", "1");
      unpinBtn.addEventListener("click", () => {
        if (typeof config.toggleChrome === "function") {
          config.toggleChrome(false);
        } else {
          render(currentProps);
        }
      });
      rowMain.appendChild(unpinBtn);
      const fsUrl = config.fullscreenUrl;
      const onCurrentFsUrl = !!(fsUrl && typeof location !== "undefined" && location.pathname === fsUrl);
      if (!onCurrentFsUrl) {
        const hostExit = config.mode === "fullscreen" && typeof config.onExitFullscreen === "function";
        const active = state.fullscreen || hostExit;
        const fsBtn = el$1(
          "button",
          CLS_PILL_BTN_BASE + " " + (active ? CLS_RIGHT_FS_ON : CLS_RIGHT_FS_OFF)
        );
        if (fsUrl) {
          fsBtn.textContent = "Fullscreen";
          fsBtn.setAttribute("data-nga-fullscreen-url", "1");
          fsBtn.addEventListener("click", () => {
            window.location.href = fsUrl;
          });
        } else if (hostExit) {
          fsBtn.textContent = "← Exit Full Screen";
          fsBtn.setAttribute("data-nga-fullscreen-exit", "1");
          fsBtn.addEventListener("click", () => {
            config.onExitFullscreen();
          });
        } else {
          fsBtn.textContent = state.fullscreen ? "Exit Fullscreen" : "Fullscreen";
          fsBtn.addEventListener("click", () => dispatch({ type: "TOGGLE_FULLSCREEN" }));
        }
        rowMain.appendChild(fsBtn);
      }
      const adminOn = !!state.adminOpen;
      const adminBtn = el$1(
        "button",
        CLS_PILL_BTN_BASE + " " + (adminOn ? CLS_RIGHT_ADMIN_ON : CLS_RIGHT_ADMIN_OFF)
      );
      adminBtn.textContent = "Admin";
      adminBtn.title = "Feature toggles";
      adminBtn.addEventListener("click", () => {
        dispatch({ type: "TOGGLE_ADMIN" });
      });
      rowMain.appendChild(adminBtn);
      const advisorOn = !!state.advisorOpen;
      const advisorBtn = el$1(
        "button",
        CLS_PILL_BTN_BASE + " " + (advisorOn ? CLS_RIGHT_ADVISOR_ON : CLS_RIGHT_ADVISOR_OFF)
      );
      advisorBtn.textContent = "Advisor";
      advisorBtn.title = "Claude-powered narrative mode";
      advisorBtn.addEventListener("click", () => {
        dispatch({ type: "TOGGLE_ADVISOR" });
      });
      rowMain.appendChild(advisorBtn);
      if (config.apiDocsUrl) {
        const apiDocs = el$1(
          "a",
          "text-[10px] text-slate-500 hover:text-fuchsia-600 underline decoration-dotted shrink-0"
        );
        apiDocs.href = config.apiDocsUrl;
        apiDocs.title = "API docs — how to automate submits";
        apiDocs.setAttribute("data-nga-api-docs", "1");
        apiDocs.textContent = "API docs";
        rowMain.appendChild(apiDocs);
      }
      const v3 = el$1("a", CLS_V3_LINK);
      v3.href = "#";
      v3.textContent = "v3 (Canvas)";
      rowMain.appendChild(v3);
      root.appendChild(rowMain);
      const legend = el$1("div", "flex items-center gap-3 px-3 py-1 text-[10px] text-slate-500 border-t border-slate-100");
      legend.setAttribute("data-slot-part", "status-legend");
      const legendItems = [
        { label: "In Flight", color: "#10b981" },
        { label: "Next Up", color: "#3b82f6" },
        { label: "Backlog", color: "#f59e0b" },
        { label: "Blocked", color: "#ef4444" },
        { label: "Paused", color: "#94a3b8" },
        { label: "Done", color: "#cbd5e1" }
      ];
      const legendLabel = el$1("span", "text-[9px] text-slate-400 uppercase tracking-wide");
      legendLabel.textContent = "Status";
      legend.appendChild(legendLabel);
      for (const item of legendItems) {
        const chip = el$1("span", "flex items-center gap-1");
        const dot = el$1("span", "");
        dot.style.cssText = `width:8px;height:8px;border-radius:50%;background:${item.color};display:inline-block`;
        chip.appendChild(dot);
        const lbl = el$1("span", "");
        lbl.textContent = item.label;
        chip.appendChild(lbl);
        legend.appendChild(chip);
      }
      root.appendChild(legend);
    }
    render(initial);
    return {
      el: root,
      update(p) {
        currentProps = p;
        render(p);
      },
      destroy() {
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  const ZOOMS$1 = ["day", "week", "month", "quarter"];
  function ZoomBarVanilla$1(initial) {
    const root = el$1("div", CLS_ZOOMBAR);
    root.setAttribute("data-slot", "ZoomBar");
    function render(p) {
      clear(root);
      ZOOMS$1.forEach((z) => {
        const on = p.state.zoom === z;
        const cls = CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_SLATE : CLS_PILL_BTN_IDLE_SLATE);
        const b = el$1("button", cls);
        b.textContent = z.charAt(0).toUpperCase() + z.slice(1);
        b.addEventListener("click", () => p.dispatch({ type: "SET_ZOOM", zoom: z }));
        root.appendChild(b);
      });
    }
    render(initial);
    return {
      el: root,
      update: render,
      destroy() {
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  function mkSep() {
    const s = el$1("span", CLS_SEP + " mx-1");
    s.textContent = "|";
    return s;
  }
  function FilterBarVanilla(initial) {
    const root = el$1("div", CLS_FILTERBAR);
    root.setAttribute("data-slot", "FilterBar");
    const inner = el$1("div", CLS_FILTERBAR_INNER);
    root.appendChild(inner);
    const searchInput = el$1("input", CLS_SEARCH_INPUT);
    searchInput.setAttribute("data-testid", "gantt-search-input");
    searchInput.type = "text";
    searchInput.placeholder = "Search T-NNNN, title, owner…";
    function render(p) {
      clear(inner);
      const { config, state, dispatch, data } = p;
      const viewLbl = el$1("span", CLS_FILTERBAR_LABEL);
      viewLbl.textContent = "View:";
      inner.appendChild(viewLbl);
      config.filters.forEach((f) => {
        const on = state.filter === f.id;
        const cls = CLS_FILTER_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_BLUE : CLS_PILL_BTN_IDLE_BLUE);
        const b = el$1("button", cls);
        b.textContent = f.label;
        b.addEventListener("click", () => dispatch({ type: "SET_FILTER", id: f.id }));
        inner.appendChild(b);
      });
      inner.appendChild(mkSep());
      const sw = el$1("div", CLS_SEARCH_WRAP);
      const icon = el$1("span", CLS_SEARCH_ICON);
      icon.textContent = "🔎";
      sw.appendChild(icon);
      if (searchInput.value !== state.search) {
        searchInput.value = state.search;
      }
      searchInput.oninput = (e) => dispatch({ type: "SET_SEARCH", q: e.target.value });
      sw.appendChild(searchInput);
      if (state.search) {
        const clr = el$1("button", CLS_SEARCH_CLEAR);
        clr.textContent = "×";
        clr.title = "Clear search";
        clr.setAttribute("aria-label", "Clear search");
        clr.addEventListener("click", () => dispatch({ type: "SET_SEARCH", q: "" }));
        sw.appendChild(clr);
      }
      inner.appendChild(sw);
      inner.appendChild(mkSep());
      const clrLbl = el$1("span", CLS_FILTERBAR_LABEL);
      clrLbl.textContent = "Colors:";
      inner.appendChild(clrLbl);
      CLOUD_NIMBUS_CATEGORIES.forEach((cat) => {
        const n = data.stats.categoryCounts[cat.label] || 0;
        if (n <= 0) return;
        const chip = el$1("span", CLS_LEGEND_CHIP);
        const sw2 = el$1("span", CLS_LEGEND_SWATCH);
        sw2.style.background = cat.color;
        chip.appendChild(sw2);
        const txt = el$1("span", CLS_LEGEND_TEXT);
        txt.textContent = cat.label + " (" + n + ")";
        chip.appendChild(txt);
        inner.appendChild(chip);
      });
      inner.appendChild(mkSep());
      const active = CLOUD_NIMBUS_POOL.filter((m) => m.active !== false);
      const totalH = active.reduce((s, m) => s + m.hoursPerMonth, 0);
      const teamWrap = el$1("span", "inline-flex items-center gap-1");
      const teamBtn = el$1("button", CLS_TEAM_PILL);
      teamBtn.title = "Edit team resource capacity";
      const tLbl = document.createElement("span");
      tLbl.textContent = "Team";
      teamBtn.appendChild(tLbl);
      const tCnt = el$1("span", "font-mono text-indigo-500");
      tCnt.textContent = active.length + "×";
      teamBtn.appendChild(tCnt);
      teamBtn.addEventListener("click", () => {
        console.log("[FilterBar] open resource panel (placeholder)");
      });
      teamWrap.appendChild(teamBtn);
      const cap = el$1("span", CLS_CAPACITY_TEXT);
      cap.textContent = totalH + "h/mo";
      teamWrap.appendChild(cap);
      inner.appendChild(teamWrap);
      const autoBtn = el$1("button", CLS_AUTO_SCHED_BTN);
      autoBtn.textContent = "Auto-Schedule";
      autoBtn.addEventListener("click", () => {
        console.log("[FilterBar] auto-schedule (placeholder)");
      });
      inner.appendChild(autoBtn);
      const spacer = el$1("div", "flex-1");
      inner.appendChild(spacer);
      const count = el$1("span", CLS_COUNT_LABEL);
      count.textContent = data.stats.total + " items · " + data.stats.scheduled + " scheduled · " + data.stats.needDates + " need dates";
      inner.appendChild(count);
      if (state.pendingPatchCount > 0) {
        const rst = el$1("button", CLS_RESET_LINK);
        rst.textContent = "Reset changes";
        rst.addEventListener("click", () => dispatch({ type: "RESET_PATCHES" }));
        inner.appendChild(rst);
      }
    }
    render(initial);
    return {
      el: root,
      update: render,
      destroy() {
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  function kpiCard(label, value, tone, hint) {
    const t = STATS_TONE[tone] || STATS_TONE.slate;
    const card = el$1("div", CLS_KPI_CARD_BASE + " " + t.border);
    const lbl = el$1("p", CLS_KPI_LABEL + " " + t.label);
    lbl.textContent = label;
    const val = el$1("p", CLS_KPI_VALUE + " " + t.value);
    val.textContent = value;
    card.appendChild(lbl);
    card.appendChild(val);
    if (hint) {
      const h = el$1("p", CLS_KPI_HINT);
      h.textContent = hint;
      card.appendChild(h);
    }
    return card;
  }
  function StatsPanelVanilla(initial) {
    const root = el$1("div", CLS_STATS_PANEL + " flex-shrink-0");
    root.setAttribute("data-slot", "StatsPanel");
    const grid = el$1("div", CLS_STATS_GRID);
    root.appendChild(grid);
    let hoursPerMonth = 120;
    function render(p) {
      root.style.display = p.state.statsOpen ? "" : "none";
      clear(grid);
      if (!p.state.statsOpen) return;
      const s = p.data.stats;
      const visibleCount = p.data.visibleTasks ? p.data.visibleTasks.length : s.total;
      const hrsLow = s.estLow;
      const hrsHigh = s.est;
      const logged = s.logged;
      const needDates = s.needDates;
      const moLow = hrsLow > 0 ? (hrsLow / hoursPerMonth).toFixed(1) : "0.0";
      const moHigh = hrsHigh > 0 ? (hrsHigh / hoursPerMonth).toFixed(1) : "0.0";
      const hrsRange = hrsLow < hrsHigh && hrsLow > 0 ? hrsLow + "–" + hrsHigh + "h" : hrsHigh + "h";
      const activeHint = needDates > 0 ? needDates + " need dates" : "all scheduled";
      grid.appendChild(kpiCard("Items in View", String(visibleCount), "slate"));
      grid.appendChild(kpiCard("Active (scheduled)", String(s.scheduled), "emerald", activeHint));
      grid.appendChild(kpiCard("Scheduled", String(s.scheduled), "blue", "of " + s.total + " total"));
      grid.appendChild(kpiCard("Hours Logged", logged + "h", "purple", "Actuals"));
      grid.appendChild(kpiCard("Hours Range", hrsRange, "amber", "Estimate envelope"));
      const mcard = el$1("div", CLS_KPI_CARD_BASE + " border-indigo-200");
      const mlbl = el$1("p", CLS_KPI_LABEL + " text-indigo-700");
      mlbl.textContent = "Months to complete";
      mcard.appendChild(mlbl);
      const mval = el$1("p", CLS_KPI_VALUE + " text-indigo-700");
      mval.textContent = moLow + "–" + moHigh;
      mcard.appendChild(mval);
      const row = el$1("div", "mt-0.5 flex items-center gap-1");
      const atSpan = el$1("span", "text-[9px] text-indigo-700");
      atSpan.textContent = "at";
      const input = el$1(
        "input",
        "w-12 text-[10px] font-mono font-bold text-indigo-700 bg-indigo-50 border border-indigo-200 rounded px-1 py-0.5 text-center"
      );
      input.type = "number";
      input.min = "1";
      input.value = String(hoursPerMonth);
      input.addEventListener("input", () => {
        const n = Math.max(1, Number(input.value) || 120);
        hoursPerMonth = n;
        const newLow = hrsLow > 0 ? (hrsLow / hoursPerMonth).toFixed(1) : "0.0";
        const newHigh = hrsHigh > 0 ? (hrsHigh / hoursPerMonth).toFixed(1) : "0.0";
        mval.textContent = newLow + "–" + newHigh;
      });
      const unit = el$1("span", "text-[9px] text-indigo-700");
      unit.textContent = "h/mo";
      row.appendChild(atSpan);
      row.appendChild(input);
      row.appendChild(unit);
      mcard.appendChild(row);
      grid.appendChild(mcard);
    }
    render(initial);
    return {
      el: root,
      update: render,
      destroy() {
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  function stageToCategory(stage) {
    const s = (stage || "").toLowerCase();
    if (s.indexOf("backlog") === 0) return "backlog";
    if (s.indexOf("paused") === 0) return "paused";
    if (s.indexOf("done") === 0) return "done";
    if (s.indexOf("next") === 0) return "next-up";
    if (s.indexOf("expansion") === 0) return "expansion";
    return "in-flight";
  }
  function SidebarVanilla(initial) {
    const root = el$1("aside", CLS_SIDEBAR);
    root.setAttribute("data-slot", "Sidebar");
    let capacity = 120;
    let currentProps = initial;
    let hoverGroup = null;
    let indicatorBeforeId = null;
    let indicatorGroup = null;
    let dragItemId = null;
    let ghost = null;
    let startX = 0;
    let startY = 0;
    let hasMoved = false;
    const THRESHOLD = 5;
    function getGroupAtY(clientY) {
      const groupEls = Array.from(root.querySelectorAll("[data-group-id]"));
      let best = currentProps.config.buckets.length > 0 ? currentProps.config.buckets[currentProps.config.buckets.length - 1].id : "deferred";
      for (const gel of groupEls) {
        const rect = gel.getBoundingClientRect();
        if (clientY >= rect.top) best = gel.getAttribute("data-group-id") || best;
        if (clientY < rect.bottom) break;
      }
      return best;
    }
    function getDropPosition(clientY, targetGroup) {
      const groupEl = root.querySelector('[data-group-id="' + targetGroup + '"]');
      if (!groupEl) return { index: 0, insertBeforeId: null };
      const itemEls = Array.from(groupEl.querySelectorAll("[data-item-id]"));
      let idx = 0;
      let insertBeforeId = null;
      for (const iel of itemEls) {
        const r = iel.getBoundingClientRect();
        const mid = r.top + r.height / 2;
        if (clientY < mid) {
          insertBeforeId = iel.getAttribute("data-item-id");
          break;
        }
        idx++;
      }
      return { index: idx, insertBeforeId };
    }
    function createGhost(title, x, y) {
      ghost = document.createElement("div");
      ghost.style.cssText = [
        "position:fixed;z-index:99999;pointer-events:none;",
        "left:" + (x + 12) + "px;top:" + (y - 14) + "px;",
        "max-width:220px;",
        "background:#eff6ff;border:2px solid #3b82f6;border-radius:6px;",
        "box-shadow:0 8px 24px rgba(59,130,246,0.35);",
        "padding:5px 10px;font-size:11px;font-weight:600;color:#1e40af;",
        "white-space:nowrap;overflow:hidden;text-overflow:ellipsis;",
        "display:flex;align-items:center;gap:6px;",
        "cursor:grabbing;user-select:none;"
      ].join("");
      const t = (title || "").slice(0, 40);
      ghost.innerHTML = '<span style="font-size:13px;opacity:0.7">⣿</span><span></span>';
      const last = ghost.lastChild;
      if (last) last.textContent = t;
      document.body.appendChild(ghost);
    }
    function cleanupDrag() {
      if (ghost) {
        ghost.remove();
        ghost = null;
      }
      dragItemId = null;
      hasMoved = false;
      document.body.style.cursor = "";
      hoverGroup = null;
      indicatorBeforeId = null;
      indicatorGroup = null;
      render(currentProps);
    }
    function onMouseDown(e) {
      if (e.button !== 0) return;
      const handle = e.target.closest("[data-drag-handle]");
      if (!handle) return;
      const itemEl = handle.closest("[data-item-id]");
      if (!itemEl) return;
      dragItemId = itemEl.getAttribute("data-item-id");
      if (!dragItemId) return;
      startX = e.clientX;
      startY = e.clientY;
      hasMoved = false;
      document.body.style.cursor = "grabbing";
      e.preventDefault();
      e.stopPropagation();
    }
    function onMouseMove(e) {
      if (!dragItemId) return;
      if (!hasMoved) {
        const dx = Math.abs(e.clientX - startX);
        const dy = Math.abs(e.clientY - startY);
        if (dx < THRESHOLD && dy < THRESHOLD) return;
        hasMoved = true;
        const itemEl = root.querySelector('[data-item-id="' + dragItemId + '"]');
        const title = (itemEl == null ? void 0 : itemEl.getAttribute("data-item-title")) || dragItemId || "";
        createGhost(title, e.clientX, e.clientY);
      }
      if (ghost) {
        ghost.style.left = e.clientX + 12 + "px";
        ghost.style.top = e.clientY - 14 + "px";
      }
      const targetGroup = getGroupAtY(e.clientY);
      const { insertBeforeId } = getDropPosition(e.clientY, targetGroup);
      const prevHover = hoverGroup;
      const prevBefore = indicatorBeforeId;
      const prevGroup = indicatorGroup;
      hoverGroup = targetGroup;
      indicatorGroup = targetGroup;
      indicatorBeforeId = insertBeforeId;
      if (prevHover !== hoverGroup || prevBefore !== indicatorBeforeId || prevGroup !== indicatorGroup) {
        render(currentProps);
      }
    }
    function onMouseUp(e) {
      if (!dragItemId || !hasMoved) {
        cleanupDrag();
        return;
      }
      const targetGroup = getGroupAtY(e.clientY);
      const { index } = getDropPosition(e.clientY, targetGroup);
      const savedId = dragItemId;
      const dispatch = currentProps.dispatch;
      cleanupDrag();
      const patchEvent = {
        type: "PATCH",
        patch: { id: savedId, priorityGroup: targetGroup, sortOrder: index }
      };
      dispatch(patchEvent);
    }
    root.addEventListener("mousedown", onMouseDown, true);
    window.addEventListener("mousemove", onMouseMove, true);
    window.addEventListener("mouseup", onMouseUp, true);
    function render(p) {
      currentProps = p;
      clear(root);
      const { config, data, dispatch, state } = p;
      const isDirty = state.pendingPatchCount > 0;
      const hdr = el$1("div", CLS_SIDEBAR_HEADER);
      const hdrRow = el$1("div", CLS_SIDEBAR_HEADER_ROW);
      const titleWrap = el$1("div");
      const big = el$1("p", CLS_SIDEBAR_LABEL_BIG);
      big.textContent = "Priority Groups";
      titleWrap.appendChild(big);
      const sm = el$1("p", CLS_SIDEBAR_LABEL_SM);
      sm.textContent = "Drag ☰ to move between buckets";
      titleWrap.appendChild(sm);
      hdrRow.appendChild(titleWrap);
      if (isDirty) {
        const rst = el$1("button", CLS_SIDEBAR_RESET);
        rst.textContent = "Reset";
        rst.addEventListener("click", () => dispatch({ type: "RESET_PATCHES" }));
        hdrRow.appendChild(rst);
      }
      hdr.appendChild(hdrRow);
      const ctrls = el$1("div", CLS_SIDEBAR_CTRLS);
      const capRow = el$1("div", CLS_SIDEBAR_CAP_ROW);
      const capLbl = el$1("span", CLS_SIDEBAR_CAP_LBL);
      capLbl.textContent = "Capacity";
      capRow.appendChild(capLbl);
      const capInput = el$1("input", CLS_CAPACITY_INPUT);
      capInput.type = "number";
      capInput.min = "1";
      capInput.value = String(capacity);
      capInput.addEventListener("input", (ev) => {
        const v = Math.max(1, Number(ev.target.value) || 120);
        capacity = v;
      });
      capRow.appendChild(capInput);
      const capSuf = el$1("span", CLS_SIDEBAR_CAP_SUF);
      capSuf.textContent = "h/mo";
      capRow.appendChild(capSuf);
      ctrls.appendChild(capRow);
      const autoBtn = el$1("button", CLS_SIDEBAR_AUTO_BTN);
      autoBtn.textContent = "Auto-Schedule";
      autoBtn.addEventListener("click", () => {
        dispatch({ type: "TOGGLE_STATS" });
        dispatch({ type: "TOGGLE_STATS" });
      });
      ctrls.appendChild(autoBtn);
      hdr.appendChild(ctrls);
      root.appendChild(hdr);
      const scroll = el$1("div", CLS_SIDEBAR_SCROLL);
      root.appendChild(scroll);
      config.buckets.forEach((b) => {
        const members = data.tasks.filter(
          (t) => t.priorityGroup === b.id && !t.parentWorkItemId
        );
        const totalHours = members.reduce(
          (s, t) => s + (Number(t.estimatedHours) || 0),
          0
        );
        const meta = BUCKET_META[b.id] || BUCKET_META.deferred;
        const isHover = hoverGroup === b.id;
        const sec = el$1(
          "div",
          CLS_BUCKET_SECTION_BASE + " " + meta.border + (isHover ? " " + meta.activeBg : "")
        );
        sec.setAttribute("data-group-id", b.id);
        const bhdr = el$1("div", CLS_BUCKET_HEADER + " " + meta.bg);
        const blbl = el$1("span", CLS_BUCKET_LABEL + " " + meta.text);
        blbl.textContent = meta.label;
        bhdr.appendChild(blbl);
        const bcnt = el$1("span", CLS_BUCKET_COUNT);
        bcnt.textContent = members.length + " · " + Math.round(totalHours) + "h";
        bhdr.appendChild(bcnt);
        sec.appendChild(bhdr);
        if (members.length === 0) {
          const emptyInd = el$1(
            "div",
            CLS_BUCKET_EMPTY_INDICATOR_BASE + " " + (isHover ? CLS_BUCKET_EMPTY_INDICATOR_ON : CLS_BUCKET_EMPTY_INDICATOR_OFF)
          );
          sec.appendChild(emptyInd);
          if (!isHover) {
            const empty = el$1("div", CLS_BUCKET_EMPTY_TEXT);
            empty.textContent = "Drop items here";
            sec.appendChild(empty);
          }
        } else {
          members.forEach((it) => {
            const itemId = String(it.id);
            if (indicatorGroup === b.id && indicatorBeforeId === itemId) {
              const indLine = el$1("div", CLS_BUCKET_INDICATOR);
              sec.appendChild(indLine);
            }
            const cat = stageToCategory(it.stage);
            const dotColor = CATEGORY_DOT[cat] || "#94a3b8";
            const row = el$1("div", CLS_ITEM_ROW);
            row.setAttribute("data-item-id", itemId);
            row.setAttribute("data-item-title", it.title);
            row.addEventListener("click", (ev) => {
              const tgt = ev.target;
              if (tgt.closest("[data-drag-handle]")) return;
              dispatch({ type: "TOGGLE_DETAIL", taskId: itemId });
            });
            const handle = el$1("span", CLS_DRAG_HANDLE);
            handle.setAttribute("data-drag-handle", "1");
            handle.setAttribute("title", "Drag to reorder or move to a different bucket");
            handle.innerHTML = "&#x2630;";
            row.appendChild(handle);
            const dot = el$1("span", CLS_CAT_DOT);
            dot.style.background = dotColor;
            row.appendChild(dot);
            const title = el$1("span", CLS_ITEM_TITLE);
            title.textContent = it.title;
            row.appendChild(title);
            const hrs = el$1("span", CLS_ITEM_HOURS);
            hrs.textContent = (Number(it.estimatedHours) || 0) + "h";
            row.appendChild(hrs);
            sec.appendChild(row);
          });
          if (indicatorGroup === b.id && indicatorBeforeId === null) {
            const trailInd = el$1("div", CLS_BUCKET_INDICATOR);
            sec.appendChild(trailInd);
          }
        }
        scroll.appendChild(sec);
      });
    }
    render(initial);
    return {
      el: root,
      update: (p) => render(p),
      destroy() {
        root.removeEventListener("mousedown", onMouseDown, true);
        window.removeEventListener("mousemove", onMouseMove, true);
        window.removeEventListener("mouseup", onMouseUp, true);
        if (ghost) {
          ghost.remove();
          ghost = null;
        }
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  function DetailPanelVanilla(initial) {
    const root = el$1("div", CLS_DETAIL);
    root.setAttribute("data-slot", "DetailPanel");
    let draftStart = "";
    let draftEnd = "";
    let lastRenderedKey = "";
    function render(p) {
      var _a;
      clear(root);
      const { state, data, dispatch } = p;
      if (!state.selectedTaskId) {
        root.style.display = "none";
        return;
      }
      const task = data.tasks.find((t) => String(t.id) === state.selectedTaskId);
      if (!task) {
        root.style.display = "none";
        return;
      }
      root.style.display = "";
      const editing = state.detailMode === "edit";
      const catColor = "#64748b";
      root.style.bottom = "80px";
      root.style.right = "24px";
      root.style.width = "380px";
      root.style.borderColor = catColor;
      root.setAttribute("data-detail-mode", state.detailMode);
      const renderKey = `${task.id}|${editing ? 1 : 0}|${task.startDate || ""}|${task.endDate || ""}`;
      if (renderKey !== lastRenderedKey) {
        draftStart = task.startDate || "";
        draftEnd = task.endDate || "";
        lastRenderedKey = renderKey;
      }
      const header = el$1("div", CLS_DETAIL_HEADER);
      header.style.background = catColor + "15";
      const lwrap = el$1("div", "flex items-center gap-2 min-w-0");
      const dot = el$1("span", "w-2.5 h-2.5 rounded-full flex-shrink-0");
      dot.style.background = catColor;
      lwrap.appendChild(dot);
      const urlTemplate = (_a = p.config) == null ? void 0 : _a.recordUrlTemplate;
      let idEl;
      if (urlTemplate && task.id) {
        const a = document.createElement("a");
        a.className = "text-[10px] font-mono font-bold text-slate-500 hover:text-slate-900 hover:underline flex-shrink-0";
        a.textContent = String(task.id);
        a.href = urlTemplate.replace("{id}", encodeURIComponent(String(task.id)));
        a.setAttribute("target", "_top");
        a.setAttribute("title", "Open record");
        a.addEventListener("click", (e) => {
          e.stopPropagation();
        });
        idEl = a;
      } else {
        idEl = el$1("span", "text-[10px] font-mono font-bold text-slate-500 flex-shrink-0");
        idEl.textContent = String(task.id);
      }
      lwrap.appendChild(idEl);
      const titleSp = el$1("span", "text-xs font-bold text-slate-900 truncate");
      titleSp.textContent = task.title;
      lwrap.appendChild(titleSp);
      header.appendChild(lwrap);
      const rwrap = el$1("div", "flex items-center gap-1 flex-shrink-0 ml-2");
      const editBtn = el$1(
        "button",
        editing ? "text-fuchsia-600 hover:text-fuchsia-800 text-sm px-1 transition-colors" : "text-slate-400 hover:text-slate-700 text-sm px-1 transition-colors"
      );
      editBtn.setAttribute("data-testid", "detail-edit-toggle");
      editBtn.setAttribute("title", editing ? "Exit edit mode" : "Edit");
      editBtn.setAttribute("aria-pressed", editing ? "true" : "false");
      editBtn.textContent = "✎";
      editBtn.addEventListener("click", () => {
        dispatch({ type: "SET_DETAIL_MODE", mode: editing ? "view" : "edit" });
      });
      rwrap.appendChild(editBtn);
      const closeBtn = el$1("button", "text-slate-400 hover:text-slate-700 text-sm px-1 transition-colors");
      closeBtn.textContent = "×";
      closeBtn.setAttribute("title", "Close");
      closeBtn.addEventListener("click", () => dispatch({ type: "TOGGLE_DETAIL" }));
      rwrap.appendChild(closeBtn);
      header.appendChild(rwrap);
      root.appendChild(header);
      const body = el$1("div", CLS_DETAIL_BODY);
      const pill = el$1("span", CLS_CATEGORY_PILL);
      pill.style.background = catColor + "20";
      pill.style.color = catColor;
      pill.textContent = task.stage || "—";
      const pillWrap = el$1("div", "flex items-center gap-2");
      pillWrap.appendChild(pill);
      body.appendChild(pillWrap);
      const grid = el$1("div", "grid grid-cols-2 gap-x-4 gap-y-1.5 pt-1");
      function fld(label, value) {
        const w = el$1("div", "");
        const l = el$1("p", "text-[9px] text-slate-400 uppercase tracking-wide");
        l.textContent = label;
        const v = el$1("p", "text-slate-900");
        v.textContent = value;
        w.appendChild(l);
        w.appendChild(v);
        grid.appendChild(w);
      }
      function inpField(label, type, value, onInput) {
        const w = el$1("div", "");
        const l = el$1("p", "text-[9px] text-slate-400 uppercase tracking-wide");
        l.textContent = label;
        const input = document.createElement("input");
        input.type = type;
        input.value = value;
        input.className = "w-full px-1.5 py-0.5 text-xs text-slate-900 border border-slate-300 rounded bg-white focus:outline-none focus:ring-1 focus:ring-fuchsia-400";
        input.addEventListener("input", () => onInput(input.value));
        w.appendChild(l);
        w.appendChild(input);
        grid.appendChild(w);
      }
      fld("Status", task.stage || "—");
      fld("Priority", task.priorityGroup || "—");
      if (editing) {
        inpField("Start", "date", draftStart, (v) => {
          draftStart = v;
        });
        inpField("End", "date", draftEnd, (v) => {
          draftEnd = v;
        });
      } else {
        fld("Start", task.startDate || "—");
        fld("End", task.endDate || "—");
      }
      fld("Estimated", task.estimatedHours ? task.estimatedHours + "h" : "—");
      fld("Logged", task.loggedHours ? task.loggedHours + "h" : "—");
      body.appendChild(grid);
      if (editing) {
        const actions = el$1("div", "pt-2 border-t border-slate-100 flex gap-2");
        const saveBtn = el$1(
          "button",
          "flex-1 text-[10px] font-bold uppercase px-2 py-1.5 rounded-lg bg-emerald-600 text-white hover:bg-emerald-700 transition-colors"
        );
        saveBtn.textContent = "Save";
        saveBtn.addEventListener("click", () => {
          const patch = {
            id: String(task.id)
          };
          if (draftStart !== (task.startDate || "")) patch.startDate = draftStart;
          if (draftEnd !== (task.endDate || "")) patch.endDate = draftEnd;
          if (patch.startDate !== void 0 || patch.endDate !== void 0) {
            dispatch({ type: "PATCH", patch });
          }
          dispatch({ type: "SET_DETAIL_MODE", mode: "view" });
        });
        actions.appendChild(saveBtn);
        const cancelBtn = el$1(
          "button",
          "flex-1 text-[10px] font-bold uppercase px-2 py-1.5 rounded-lg bg-slate-100 text-slate-600 hover:bg-slate-200 transition-colors"
        );
        cancelBtn.textContent = "Cancel";
        cancelBtn.addEventListener("click", () => {
          draftStart = task.startDate || "";
          draftEnd = task.endDate || "";
          dispatch({ type: "SET_DETAIL_MODE", mode: "view" });
        });
        actions.appendChild(cancelBtn);
        body.appendChild(actions);
      }
      root.appendChild(body);
    }
    render(initial);
    return {
      el: root,
      update: render,
      destroy() {
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  function ContentAreaVanilla$1(initial) {
    const root = el$1("div", CLS_CONTENT_OUTER);
    root.setAttribute("data-slot", "ContentArea");
    const host = el$1("div", CLS_CONTENT);
    host.setAttribute("data-nga-gantt-host", "1");
    let sidebarInst = null;
    let detailInst = null;
    function render(p) {
      clear(root);
      if (p.state.sidebarOpen && p.config.features.sidebar) {
        if (!sidebarInst) sidebarInst = SidebarVanilla(p);
        else sidebarInst.update(p);
        const wrap = el$1("div", CLS_SIDEBAR_WRAP);
        wrap.style.width = "280px";
        wrap.appendChild(sidebarInst.el);
        root.appendChild(wrap);
        const resizer = el$1("div", CLS_RESIZER);
        root.appendChild(resizer);
      } else if (sidebarInst) {
        sidebarInst.destroy();
        sidebarInst = null;
      }
      root.appendChild(host);
      if (p.state.detailOpen && p.config.features.detailPanel) {
        if (!detailInst) detailInst = DetailPanelVanilla(p);
        else detailInst.update(p);
        root.appendChild(detailInst.el);
      } else if (detailInst) {
        detailInst.destroy();
        detailInst = null;
      }
    }
    render(initial);
    return {
      el: root,
      update: render,
      destroy() {
        if (sidebarInst) sidebarInst.destroy();
        if (detailInst) detailInst.destroy();
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  function AuditPanelVanilla(initial) {
    const root = el$1("div", CLS_AUDIT);
    root.setAttribute("data-slot", "AuditPanel");
    root.setAttribute("data-testid", "audit-panel");
    let note = "";
    let submitting = false;
    let lastResult = null;
    let inputEl = null;
    let latestProps = initial;
    function render(p) {
      latestProps = p;
      clear(root);
      inputEl = null;
      root.style.display = p.state.auditPanelOpen ? "" : "none";
      if (!p.state.auditPanelOpen) return;
      const dirty = (p.config.isDirty ?? false) || p.state.pendingPatchCount > 0;
      const inner = el$1("div", "flex flex-wrap items-center gap-2");
      const lbl = el$1("span", CLS_AUDIT_LABEL);
      lbl.textContent = "📤 Audit pass";
      inner.appendChild(lbl);
      const stat = el$1("span", dirty ? CLS_AUDIT_STATUS_DIRTY : CLS_AUDIT_STATUS_CLEAN);
      stat.textContent = dirty ? "unsaved changes" : "clean";
      inner.appendChild(stat);
      const input = el$1("input", CLS_AUDIT_INPUT);
      input.type = "text";
      input.placeholder = "commit note (optional - auto-summarized if empty)";
      input.value = note;
      input.setAttribute("data-testid", "audit-note-input");
      input.disabled = submitting;
      input.addEventListener("input", (e) => {
        note = e.target.value;
      });
      inputEl = input;
      inner.appendChild(input);
      const sb = el$1("button", CLS_AUDIT_SUBMIT);
      sb.type = "button";
      sb.textContent = submitting ? "Committing..." : "📤 Submit + commit";
      sb.setAttribute("data-testid", "audit-submit-btn");
      sb.disabled = !dirty || submitting;
      sb.addEventListener("click", onSubmitClick);
      inner.appendChild(sb);
      const rst = el$1("button", CLS_AUDIT_RESET);
      rst.type = "button";
      rst.textContent = "↺ Reset";
      rst.setAttribute("data-testid", "audit-reset-btn");
      rst.disabled = submitting;
      rst.addEventListener("click", () => {
        if (dirty && !confirm("Reset all unsaved overrides? This discards every drag/edit you made this session.")) return;
        note = "";
        if (inputEl) inputEl.value = "";
        lastResult = null;
        p.dispatch({ type: "RESET_PATCHES" });
      });
      inner.appendChild(rst);
      root.appendChild(inner);
      if (lastResult) {
        const r = el$1("div", `mt-1.5 text-[11px] ${lastResult.ok ? "text-emerald-700" : "text-rose-700"}`);
        r.setAttribute("data-testid", "audit-result");
        r.textContent = (lastResult.ok ? "✓ " : "✗ ") + lastResult.msg;
        if (lastResult.sha) {
          const sha = el$1("code", "ml-2 font-mono bg-slate-100 px-1 rounded");
          sha.textContent = lastResult.sha;
          r.appendChild(sha);
        }
        root.appendChild(r);
      }
    }
    async function onSubmitClick() {
      const p = latestProps;
      const pending = p.config.pendingChanges ?? [];
      if (pending.length === 0) {
        await runSubmit();
        return;
      }
      openPreviewModal(pending, async () => {
        await runSubmit();
      });
    }
    async function runSubmit() {
      const p = latestProps;
      lastResult = null;
      if (p.config.onAuditSubmit) {
        submitting = true;
        render(p);
        try {
          const res = await p.config.onAuditSubmit(note);
          lastResult = res;
          if (res.ok) {
            note = "";
            p.dispatch({ type: "RESET_PATCHES" });
          }
        } catch (e) {
          lastResult = { ok: false, msg: e instanceof Error ? e.message : String(e) };
        } finally {
          submitting = false;
          render(latestProps);
        }
      } else {
        note = "";
        p.dispatch({ type: "RESET_PATCHES" });
        render(latestProps);
      }
    }
    render(initial);
    return {
      el: root,
      update: render,
      destroy() {
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  function openPreviewModal(items, onConfirm) {
    const existing = document.getElementById("ng-audit-preview-modal");
    if (existing) existing.remove();
    const backdrop = document.createElement("div");
    backdrop.id = "ng-audit-preview-modal";
    backdrop.setAttribute("role", "dialog");
    backdrop.setAttribute("aria-modal", "true");
    backdrop.setAttribute("aria-label", "Audit preview");
    backdrop.style.cssText = "position:fixed;inset:0;background:rgba(15,23,42,0.55);display:flex;align-items:center;justify-content:center;z-index:2147483646;backdrop-filter:blur(2px)";
    const panel = document.createElement("div");
    panel.style.cssText = "background:#fff;border-radius:10px;box-shadow:0 20px 40px rgba(15,23,42,0.25);width:min(720px,92vw);max-height:80vh;display:flex;flex-direction:column;overflow:hidden;font-family:ui-sans-serif,system-ui,sans-serif";
    const header = document.createElement("div");
    header.style.cssText = "padding:14px 18px;border-bottom:1px solid #e2e8f0;display:flex;align-items:center;justify-content:space-between";
    const title = document.createElement("div");
    title.style.cssText = "font-size:14px;font-weight:600;color:#0f172a";
    const kinds = summarizeKinds(items);
    title.textContent = "Review " + items.length + " change" + (items.length === 1 ? "" : "s") + " - " + kinds;
    const close = document.createElement("button");
    close.type = "button";
    close.textContent = "✕";
    close.setAttribute("aria-label", "Close preview");
    close.style.cssText = "background:transparent;border:0;font-size:18px;cursor:pointer;color:#64748b;padding:4px 8px;line-height:1";
    close.addEventListener("click", cleanup);
    header.appendChild(title);
    header.appendChild(close);
    panel.appendChild(header);
    const body = document.createElement("div");
    body.style.cssText = "padding:8px 18px 12px;overflow-y:auto;flex:1";
    const list = document.createElement("ul");
    list.style.cssText = "margin:0;padding:0;list-style:none;font-size:12.5px;color:#334155";
    for (const it of items) {
      const li = document.createElement("li");
      li.style.cssText = "padding:8px 0;border-bottom:1px solid #f1f5f9";
      const head = document.createElement("div");
      head.style.cssText = "display:flex;align-items:baseline;gap:8px;flex-wrap:wrap";
      const idEl = document.createElement("code");
      idEl.style.cssText = "font-family:ui-monospace,monospace;background:#f1f5f9;padding:1px 6px;border-radius:4px;font-size:11.5px;color:#0f172a";
      idEl.textContent = it.id;
      head.appendChild(idEl);
      if (it.title && it.title !== it.id) {
        const titleEl = document.createElement("span");
        titleEl.style.cssText = "color:#0f172a;font-weight:500";
        titleEl.textContent = it.title;
        head.appendChild(titleEl);
      }
      li.appendChild(head);
      const descs = it.descs && it.descs.length ? it.descs : it.fields.map((f) => f + " edited");
      const descList = document.createElement("div");
      descList.style.cssText = "margin-top:3px;color:#475569;font-size:12px;line-height:1.45";
      descList.textContent = descs.join(" · ");
      li.appendChild(descList);
      list.appendChild(li);
    }
    body.appendChild(list);
    panel.appendChild(body);
    const footer = document.createElement("div");
    footer.style.cssText = "padding:12px 18px;border-top:1px solid #e2e8f0;display:flex;align-items:center;justify-content:flex-end;gap:8px";
    const cancel = document.createElement("button");
    cancel.type = "button";
    cancel.textContent = "Cancel";
    cancel.style.cssText = "padding:6px 14px;font-size:13px;border-radius:6px;border:1px solid #cbd5e1;background:#fff;color:#334155;cursor:pointer";
    cancel.addEventListener("click", cleanup);
    const confirmBtn = document.createElement("button");
    confirmBtn.type = "button";
    confirmBtn.textContent = "📤 Confirm + commit";
    confirmBtn.setAttribute("data-testid", "audit-preview-confirm");
    confirmBtn.style.cssText = "padding:6px 14px;font-size:13px;border-radius:6px;border:1px solid #a21caf;background:#a21caf;color:#fff;cursor:pointer;font-weight:500";
    confirmBtn.addEventListener("click", async () => {
      confirmBtn.disabled = true;
      cancel.disabled = true;
      confirmBtn.textContent = "Committing...";
      try {
        await onConfirm();
      } finally {
        cleanup();
      }
    });
    footer.appendChild(cancel);
    footer.appendChild(confirmBtn);
    panel.appendChild(footer);
    backdrop.appendChild(panel);
    document.body.appendChild(backdrop);
    backdrop.addEventListener("click", (e) => {
      if (e.target === backdrop) cleanup();
    });
    const onKey = (e) => {
      if (e.key === "Escape") cleanup();
    };
    document.addEventListener("keydown", onKey);
    function cleanup() {
      document.removeEventListener("keydown", onKey);
      if (backdrop.parentNode) backdrop.parentNode.removeChild(backdrop);
    }
  }
  function summarizeKinds(items) {
    const counts = { dates: 0, group: 0, reorder: 0, parent: 0, other: 0 };
    const covered = /* @__PURE__ */ new Set(["start", "end", "group", "sortOrder", "parentId"]);
    for (const it of items) {
      const f = new Set(it.fields);
      if (f.has("start") || f.has("end")) counts.dates++;
      if (f.has("group")) counts.group++;
      if (f.has("sortOrder") && !f.has("start") && !f.has("end") && !f.has("group")) counts.reorder++;
      if (f.has("parentId")) counts.parent++;
      if (it.fields.some((k) => !covered.has(k))) counts.other++;
    }
    const parts = [];
    if (counts.dates) parts.push(counts.dates + " date");
    if (counts.group) parts.push(counts.group + " group");
    if (counts.reorder) parts.push(counts.reorder + " reorder");
    if (counts.parent) parts.push(counts.parent + " parent");
    if (counts.other) parts.push(counts.other + " field");
    return parts.length ? parts.join(", ") : "changes";
  }
  const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const DAY_MS = 24 * 3600 * 1e3;
  const WEEK_MS = 7 * DAY_MS;
  const NUM_WEEKS = 16;
  const TRACK_PX = 32;
  function computeWeeks(tasks) {
    const now2 = /* @__PURE__ */ new Date();
    const dow = now2.getDay();
    const monday = new Date(now2);
    monday.setDate(now2.getDate() - (dow === 0 ? 6 : dow - 1));
    monday.setHours(0, 0, 0, 0);
    const weeks = [];
    for (let i = 0; i < NUM_WEEKS; i++) {
      const s = new Date(monday.getTime() + i * WEEK_MS);
      weeks.push({
        startMs: s.getTime(),
        endMs: s.getTime() + WEEK_MS,
        label: MON[s.getMonth()] + " " + String(s.getDate()),
        hours: 0,
        isCurrent: i === 0
      });
    }
    tasks.forEach((t) => {
      const h = Number(t.estimatedHours) || 0;
      if (!h || !t.startDate || !t.endDate || t.isInactive) return;
      const ts = (/* @__PURE__ */ new Date(t.startDate + "T00:00:00")).getTime();
      const te = (/* @__PURE__ */ new Date(t.endDate + "T00:00:00")).getTime();
      const td = Math.max(1, (te - ts) / DAY_MS);
      const hpd = h / td;
      weeks.forEach((w) => {
        const oS = Math.max(ts, w.startMs);
        const oE = Math.min(te, w.endMs);
        if (oE > oS) w.hours += hpd * (oE - oS) / DAY_MS;
      });
    });
    return weeks.map((w) => ({ label: w.label, hours: Math.round(w.hours), isCurrent: w.isCurrent }));
  }
  function HrsWkStripVanilla(initial) {
    const root = el$1("div", CLS_HRSWK);
    root.setAttribute("data-slot", "HrsWkStrip");
    function render(p) {
      clear(root);
      const weeks = computeWeeks(p.data.tasks);
      const totalHours = weeks.reduce((s, w) => s + w.hours, 0);
      const maxH = Math.max(1, ...weeks.map((w) => w.hours));
      const lbl = el$1("span", CLS_HRSWK_LABEL);
      lbl.textContent = "HRS/WK";
      root.appendChild(lbl);
      if (totalHours === 0) {
        const empty = el$1("span", "text-[9px] text-slate-400 italic ml-2");
        empty.textContent = "No scheduled hours";
        root.appendChild(empty);
        return;
      }
      weeks.forEach((w) => {
        const pct = Math.round(w.hours / maxH * 100);
        const col = el$1("div", CLS_HRSWK_COL);
        const hrsLbl = el$1("span", "text-[9px] font-mono " + (w.isCurrent ? "text-indigo-600 font-bold" : "text-slate-500"));
        hrsLbl.textContent = w.hours + "h";
        col.appendChild(hrsLbl);
        const track = el$1("div", "w-full rounded-sm overflow-hidden bg-slate-200 relative");
        track.style.height = TRACK_PX + "px";
        const fill = el$1("div", "absolute bottom-0 left-0 right-0 rounded-sm " + (w.isCurrent ? "bg-indigo-500" : "bg-slate-400"));
        fill.style.height = pct + "%";
        track.appendChild(fill);
        col.appendChild(track);
        const dLbl = el$1("span", "text-[9px] " + (w.isCurrent ? "text-indigo-500 font-semibold" : "text-slate-500"));
        dLbl.textContent = w.label;
        col.appendChild(dLbl);
        root.appendChild(col);
      });
    }
    render(initial);
    return {
      el: root,
      update: render,
      destroy() {
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  const inlineStyles = "";
  const cloudnimbusTemplate = defineTemplate({
    name: "cloudnimbus",
    defaults: {
      features: {
        titleBar: true,
        statsPanel: true,
        filterBar: true,
        // zoomBar default OFF — TitleBar already renders inline zoom pills
        // (Day/Week/Month/Quarter), matching v9's gold-standard layout. The
        // standalone ZoomBar slot exists for minimal-template consumers that
        // skip TitleBar; cloudnimbus consumers would render it twice. Observed
        // 2026-04-16 on /v12 (8 zoom buttons instead of 4). Same class of
        // dup as the AuditPanel fix at c9c765d.
        // KEEP IN SYNC with index.ts — the React variant.
        zoomBar: false,
        sidebar: true,
        detailPanel: true,
        auditPanel: true,
        hrsWkStrip: true,
        dragReparent: true,
        depthShading: true,
        groupByToggle: true,
        hideCompletedToggle: true
      },
      theme: cloudnimbusTheme,
      buckets: CLOUD_NIMBUS_PRIORITY_BUCKETS,
      filters: CLOUD_NIMBUS_FILTERS,
      views: CLOUD_NIMBUS_VIEWS,
      title: "Pro Forma Timeline",
      version: "v10 · Nimbus Gantt"
    },
    stylesheet: {
      inline: inlineStyles
    },
    components: {
      TitleBar: { vanilla: TitleBarVanilla$1 },
      ZoomBar: { vanilla: ZoomBarVanilla$1 },
      FilterBar: { vanilla: FilterBarVanilla },
      StatsPanel: { vanilla: StatsPanelVanilla },
      Sidebar: { vanilla: SidebarVanilla },
      ContentArea: { vanilla: ContentAreaVanilla$1 },
      DetailPanel: { vanilla: DetailPanelVanilla },
      AuditPanel: { vanilla: AuditPanelVanilla },
      HrsWkStrip: { vanilla: HrsWkStripVanilla }
    }
  });
  registerTemplate(cloudnimbusTemplate);
  const minimalTheme = {
    primary: "#334155",
    primaryHover: "#1e293b",
    accent: "#475569",
    bg: "#ffffff",
    surface: "#ffffff",
    surfaceAlt: "#f8fafc",
    border: "#e5e7eb",
    borderSubtle: "#f1f5f9",
    textPrimary: "#0f172a",
    textSecondary: "#475569",
    textMuted: "#94a3b8",
    textInverse: "#ffffff",
    danger: "#ef4444",
    warning: "#f59e0b",
    success: "#10b981",
    info: "#3b82f6",
    fontFamily: "sans-serif",
    fontFamilyMono: "monospace",
    fontSizeBase: "13px",
    fontSizeSm: "11px",
    fontSizeXs: "10px",
    radiusSm: "4px",
    radiusMd: "6px",
    radiusLg: "8px",
    radiusFull: "9999px",
    spacingUnit: "4px",
    ganttGridColor: "#e5e7eb",
    ganttHeaderBg: "#f3f4f6",
    ganttWeekendBg: "rgba(0,0,0,0.03)",
    ganttTodayLine: "#ef4444",
    ganttTodayBg: "rgba(239,68,68,0.08)",
    ganttBarDefault: "#94a3b8",
    ganttBarTextColor: "#ffffff",
    ganttRowHoverBg: "rgba(0,0,0,0.03)",
    ganttSelectionRing: "#3b82f6",
    ganttDependencyLine: "#94a3b8"
  };
  const VIEWS = ["gantt", "list"];
  function TitleBarVanilla(initial) {
    const root = el$1("div", "nga-titlebar");
    root.setAttribute("data-slot", "TitleBar");
    function render(p) {
      clear(root);
      const strong = document.createElement("strong");
      strong.textContent = p.config.title || "Nimbus Gantt";
      root.appendChild(strong);
      const spacer = el$1("span");
      spacer.style.flex = "1";
      root.appendChild(spacer);
      VIEWS.forEach((v) => {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.textContent = v;
        if (p.state.viewMode === v) btn.style.fontWeight = "700";
        btn.addEventListener("click", () => p.dispatch({ type: "SET_VIEW", mode: v }));
        root.appendChild(btn);
      });
    }
    render(initial);
    return {
      el: root,
      update: render,
      destroy() {
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  const ZOOMS = ["day", "week", "month", "quarter"];
  function ZoomBarVanilla(initial) {
    const root = el$1("div", "nga-zoombar");
    root.setAttribute("data-slot", "ZoomBar");
    function render(p) {
      clear(root);
      ZOOMS.forEach((z) => {
        const b = document.createElement("button");
        b.type = "button";
        b.textContent = z;
        if (p.state.zoom === z) b.style.fontWeight = "700";
        b.addEventListener("click", () => p.dispatch({ type: "SET_ZOOM", zoom: z }));
        root.appendChild(b);
      });
    }
    render(initial);
    return {
      el: root,
      update: render,
      destroy() {
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  function ContentAreaVanilla(_initial) {
    const root = el$1("div", "nga-content-outer");
    root.setAttribute("data-slot", "ContentArea");
    const host = el$1("div", "nga-content");
    host.setAttribute("data-nga-gantt-host", "1");
    root.appendChild(host);
    return {
      el: root,
      update: () => {
      },
      destroy() {
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  const minimalTemplate = defineTemplate({
    name: "minimal",
    defaults: {
      features: {
        titleBar: true,
        statsPanel: false,
        filterBar: false,
        zoomBar: true,
        sidebar: false,
        detailPanel: false,
        auditPanel: false,
        hrsWkStrip: false,
        dragReparent: false,
        depthShading: false,
        groupByToggle: false,
        hideCompletedToggle: false
      },
      theme: minimalTheme,
      title: "Gantt",
      version: "minimal",
      views: ["gantt", "list"]
    },
    stylesheet: { importedByBundler: true },
    components: {
      TitleBar: { vanilla: TitleBarVanilla },
      ZoomBar: { vanilla: ZoomBarVanilla },
      ContentArea: { vanilla: ContentAreaVanilla }
    }
  });
  registerTemplate(minimalTemplate);
  diag("lib:loaded", { app: "unknown" });
  const V3_THEME = {
    timelineBg: "#ffffff",
    timelineGridColor: "#e5e7eb",
    timelineHeaderBg: "#f3f4f6",
    timelineHeaderText: "#1f2937",
    timelineWeekendBg: "rgba(229,231,235,0.4)",
    todayLineColor: "#ef4444",
    todayBg: "rgba(239,68,68,0.08)",
    barDefaultColor: "#94a3b8",
    barBorderRadius: 4,
    barTextColor: "#ffffff",
    barSelectedBorder: "#3b82f6",
    gridBg: "#ffffff",
    gridAltRowBg: "rgba(255,255,255,0)",
    gridBorderColor: "#e5e7eb",
    gridTextColor: "#1f2937",
    gridHeaderBg: "#f3f4f6",
    gridHeaderText: "#1f2937",
    gridHoverBg: "rgba(229,231,235,0.3)",
    dependencyColor: "#3b82f6",
    dependencyWidth: 2,
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
    fontSize: 12,
    selectionColor: "#3b82f6",
    singleRowHeader: true
  };
  function buildGanttCols(features) {
    const cols = [
      { field: "title", header: "", width: 210, tree: true },
      { field: "hoursLabel", header: "", width: 85, align: "right" }
    ];
    if (features.hoursColumn) {
      cols.push({ field: "hours", header: "Hours", width: 60, align: "right" });
    }
    if (features.budgetUsedColumn) {
      cols.push({ field: "budgetUsedPct", header: "Budget Used", width: 90, align: "right" });
    }
    return cols;
  }
  const INITIAL_VIEWPORT_OFFSET_MS = 14 * 24 * 60 * 60 * 1e3;
  function snapDateToZoomPeriod(date, zoom) {
    const d = new Date(date.getTime());
    d.setUTCHours(0, 0, 0, 0);
    if (zoom === "week") {
      const dow = d.getUTCDay();
      const offsetDays = dow === 0 ? -6 : 1 - dow;
      d.setUTCDate(d.getUTCDate() + offsetDays);
    } else if (zoom === "month") {
      d.setUTCDate(1);
    } else if (zoom === "quarter") {
      const m = d.getUTCMonth();
      const qm = Math.floor(m / 3) * 3;
      d.setUTCMonth(qm, 1);
    }
    return d;
  }
  function parseFocusDate(input) {
    if (!input) return null;
    if (input instanceof Date) return isNaN(input.getTime()) ? null : input;
    const t = Date.parse(input);
    if (isNaN(t)) return null;
    return new Date(t);
  }
  function injectLegacyNgCss() {
    if (document.getElementById("nga-v5-css")) return;
    const s = document.createElement("style");
    s.id = "nga-v5-css";
    s.textContent = [
      /* Critical template-flex rules — must apply synchronously at mount. */
      ".nga-root{display:flex;flex-direction:column;height:100%;width:100%;overflow:hidden}",
      /* Fullscreen mode safety floor — if the consumer\'s parent chain doesn\'t
       * resolve to a real viewport height (e.g. Lightning app page with weird
       * layout, or a plain div that lost its position:fixed), fall back to
       * 100vh so the canvas always has room. Embedded mode is explicitly NOT
       * floored — embedded consumers opt into small container sizes. */
      '.nga-root[data-mode="fullscreen"]{min-height:100vh}',
      ".nga-titlebar,.nga-filterbar,.nga-zoombar,.nga-stats,.nga-hrswkstrip,.nga-audit{flex-shrink:0}",
      ".nga-content-outer{flex:1 1 auto;display:flex;overflow:hidden;min-width:0;min-height:0}",
      ".nga-content{flex:1 1 auto;position:relative;min-width:0;min-height:0}",
      /* Library-class (.ng-*) overrides — v5 styling carried forward. */
      ".ng-grid{font-family:sans-serif!important;font-size:12px!important;color:#1f2937!important;letter-spacing:-.01em}",
      ".ng-grid table{border-collapse:collapse!important;border-spacing:0!important}",
      ".ng-grid-header{background:#f3f4f6!important;visibility:hidden!important}",
      ".ng-grid-th{font-size:12px!important;font-weight:700!important;color:#1f2937!important;padding:0 6px!important;border-right:none!important}",
      ".ng-grid-row:not(.ng-group-row) .ng-tree-cell .ng-expand-icon+.ng-grid-cell-text{font-weight:700!important;color:#1f2937!important}",
      ".ng-grid-row .ng-tree-cell .ng-expand-spacer+.ng-grid-cell-text{font-weight:400!important;color:#6b7280!important;font-size:11px!important}",
      ".ng-grid-cell{padding-top:0!important;padding-right:6px!important;padding-bottom:0!important;padding-left:6px;line-height:32px!important;border-right:none!important}",
      ".ng-expand-spacer{width:0!important;min-width:0!important}",
      /* .ng-expand-icon — ARROW_DIFF 2026-04-18 font-family normalization.
       * Must match the canonical rule in styles.css:~687 so SF's
       * synchronous injection backstop doesn't fight the async template
       * stylesheet. See styles.css for rationale. */
      '.ng-expand-icon{font-family:-apple-system,"Segoe UI Symbol","Apple Symbols","Helvetica Neue",Arial,sans-serif!important;font-size:10px!important;line-height:1!important;display:inline-block!important;text-align:center!important;opacity:.5!important;color:#6b7280!important;width:16px!important;min-width:16px!important}',
      ".ng-expand-icon:hover{opacity:1!important}",
      ".ng-grid-row{border:none!important;box-shadow:inset 0 -1px 0 #f3f4f6;box-sizing:border-box!important}",
      ".ng-grid-row:not(.ng-group-row){cursor:grab}",
      ".ng-grid-row:not(.ng-group-row):hover{background:rgba(59,130,246,0.04)!important;outline:1px solid rgba(59,130,246,0.12)!important;outline-offset:-1px}",
      ".ng-grid-row:not(.ng-group-row):active{cursor:grabbing}",
      ".ng-grid-row td{border:none!important;box-sizing:border-box!important}",
      ".ng-row-alt:not(.ng-group-row){background:unset}",
      ".ng-scroll-content>canvas{position:sticky!important;left:0!important}",
      "[data-depth-stripes]{display:none!important}",
      ".ng-group-row{font-weight:700;font-size:11px;letter-spacing:.03em;box-sizing:border-box!important;box-shadow:none!important;color:#fff!important}",
      ".ng-group-row .ng-grid-cell-text{font-weight:700!important;font-size:12px!important;color:#fff!important;text-transform:uppercase}",
      ".ng-group-row .ng-expand-icon{color:inherit!important;opacity:.5!important}",
      '.ng-group-row .ng-grid-cell[data-field="hoursLabel"]{font-weight:600!important;font-size:11px!important;color:inherit!important;opacity:.75;white-space:nowrap!important;overflow:visible!important}',
      '.ng-grid-cell[data-field="hoursLabel"]{font-family:monospace;font-size:10px;color:#94a3b8;font-weight:400}',
      ".ng-row-selected:not(.ng-group-row){background:rgba(59,130,246,0.06)!important;box-shadow:inset 3px 0 0 #3b82f6!important}",
      '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 28px"]{padding-left:8px!important}',
      '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 48px"]{padding-left:18px!important}',
      '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 68px"]{padding-left:28px!important}',
      '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 88px"]{padding-left:38px!important}',
      /* 0.183.1 — chrome button cursor. CLS_PILL_BTN_BASE (Tailwind) doesn't
       * declare cursor, so the UA default for <button> (which is 'default'
       * per spec, regardless of Chrome's old override) renders a non-click-
       * signal arrow. Force pointer inside every chrome surface so users
       * read the buttons as interactive. VF/Locker-safe — bare selector,
       * no Tailwind arbitrary-value syntax. */
      ".nga-titlebar button,.nga-filterbar button,.nga-zoombar button,.nga-audit button,.nga-stats button,.nga-sidebar button{cursor:pointer}"
    ].join("");
    document.head.appendChild(s);
  }
  function el(tag, css) {
    const e = document.createElement(tag);
    if (css) e.style.cssText = css;
    return e;
  }
  function mountAltCanvasView(container, tasks, renderer, colorMap) {
    container.innerHTML = "";
    const canvas = document.createElement("canvas");
    canvas.style.display = "block";
    canvas.style.width = "100%";
    canvas.style.height = "100%";
    container.appendChild(canvas);
    const rect = container.getBoundingClientRect();
    const w = Math.max(320, Math.floor(rect.width));
    const h = Math.max(240, Math.floor(rect.height));
    const dpr = window.devicePixelRatio || 1;
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.scale(dpr, dpr);
    renderer(ctx, w, h, tasks, {
      colorMap,
      hoveredId: null,
      theme: {
        bg: "#ffffff",
        text: "#1f2937",
        altRowBg: "rgba(229,231,235,0.4)",
        textMuted: "#64748b",
        font: "-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif"
      }
    });
  }
  const ADMIN_TOGGLEABLE_FEATURES = [
    { key: "statsPanel", label: "Stats panel" },
    { key: "filterBar", label: "Filter bar" },
    { key: "zoomBar", label: "Zoom bar" },
    { key: "sidebar", label: "Sidebar" },
    { key: "auditPanel", label: "Audit panel" },
    { key: "hrsWkStrip", label: "Hours/week strip" },
    { key: "depthShading", label: "Depth shading" },
    { key: "hoursColumn", label: "Hours column" },
    { key: "budgetUsedColumn", label: "Budget-used column" },
    { key: "headerRowCompletionBar", label: "Header completion bar" }
  ];
  function renderAdminPanel(container, state, dispatch, tplConfig) {
    const id = "nga-admin-panel";
    let panel = container.querySelector(`#${id}`);
    if (!state.adminOpen) {
      if (panel) panel.remove();
      return;
    }
    if (!panel) {
      panel = document.createElement("div");
      panel.id = id;
      panel.style.cssText = [
        "position:absolute",
        "top:60px",
        "right:12px",
        "width:260px",
        "max-height:calc(100vh - 120px)",
        "overflow:auto",
        "background:#ffffff",
        "border:1px solid #e5e7eb",
        "border-radius:8px",
        "box-shadow:0 12px 32px rgba(15,23,42,0.18)",
        "padding:12px 14px",
        "z-index:9998",
        "font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif"
      ].join(";");
      container.appendChild(panel);
    }
    panel.innerHTML = "";
    const header = document.createElement("div");
    header.style.cssText = "display:flex;align-items:center;justify-content:space-between;margin-bottom:10px";
    const title = document.createElement("div");
    title.textContent = "Admin — Feature Toggles";
    title.style.cssText = "font-size:12px;font-weight:700;color:#1f2937";
    header.appendChild(title);
    const close = document.createElement("button");
    close.textContent = "×";
    close.style.cssText = "background:none;border:none;font-size:18px;line-height:1;color:#64748b;cursor:pointer;padding:0 4px";
    close.addEventListener("click", () => dispatch({ type: "TOGGLE_ADMIN" }));
    header.appendChild(close);
    panel.appendChild(header);
    const hint = document.createElement("div");
    hint.textContent = "Toggle chrome surfaces on/off. Changes apply immediately.";
    hint.style.cssText = "font-size:10px;color:#64748b;margin-bottom:10px;line-height:1.4";
    panel.appendChild(hint);
    const features = tplConfig.features;
    for (const item of ADMIN_TOGGLEABLE_FEATURES) {
      const base = features[item.key];
      const override = state.featureOverrides[item.key];
      const on = override === void 0 ? !!base : override;
      const row = document.createElement("label");
      row.style.cssText = "display:flex;align-items:center;gap:8px;padding:6px 0;cursor:pointer;font-size:11px;color:#1f2937";
      const cb = document.createElement("input");
      cb.type = "checkbox";
      cb.checked = on;
      cb.style.cssText = "cursor:pointer";
      cb.addEventListener("change", () => dispatch({ type: "TOGGLE_FEATURE", key: item.key }));
      row.appendChild(cb);
      const lbl = document.createElement("span");
      lbl.textContent = item.label;
      row.appendChild(lbl);
      panel.appendChild(row);
    }
  }
  function renderAdvisorPanel(container, state, dispatch) {
    const id = "nga-advisor-panel";
    let panel = container.querySelector(`#${id}`);
    if (!state.advisorOpen) {
      if (panel) panel.remove();
      return;
    }
    if (!panel) {
      panel = document.createElement("div");
      panel.id = id;
      panel.style.cssText = [
        "position:absolute",
        "top:60px",
        "right:282px",
        "width:300px",
        "background:#ffffff",
        "border:1px solid #e5e7eb",
        "border-radius:8px",
        "box-shadow:0 12px 32px rgba(15,23,42,0.18)",
        "padding:14px 16px",
        "z-index:9998",
        "font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif"
      ].join(";");
      container.appendChild(panel);
    }
    panel.innerHTML = "";
    const header = document.createElement("div");
    header.style.cssText = "display:flex;align-items:center;justify-content:space-between;margin-bottom:10px";
    const title = document.createElement("div");
    title.textContent = "Advisor — Narrative Mode";
    title.style.cssText = "font-size:12px;font-weight:700;color:#1f2937";
    header.appendChild(title);
    const close = document.createElement("button");
    close.textContent = "×";
    close.style.cssText = "background:none;border:none;font-size:18px;line-height:1;color:#64748b;cursor:pointer;padding:0 4px";
    close.addEventListener("click", () => dispatch({ type: "TOGGLE_ADVISOR" }));
    header.appendChild(close);
    panel.appendChild(header);
    const body = document.createElement("div");
    body.style.cssText = "font-size:11px;color:#475569;line-height:1.5";
    body.innerHTML = '<p style="margin:0 0 8px 0"><strong>Coming in a later cut.</strong></p><p style="margin:0 0 8px 0">Advisor mode turns the visible task list + date range into a Claude-generated narrative walkthrough of what the timeline actually says.</p><p style="margin:0;color:#64748b">Restoration pending API infrastructure decisions (auth, CSP under LWS, streaming UX, error handling).</p>';
    panel.appendChild(body);
  }
  function renderComingSoon(container, viewLabel) {
    container.innerHTML = "";
    const wrap = el("div", [
      "height:100%",
      "width:100%",
      "display:flex",
      "flex-direction:column",
      "align-items:center",
      "justify-content:center",
      "gap:12px",
      "padding:32px",
      "font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif",
      "color:#475569",
      "background:#f8fafc",
      "text-align:center"
    ].join(";"));
    const title = el("div", "font-size:18px;font-weight:700;color:#1f2937");
    title.textContent = viewLabel + " view — coming in 0.183";
    wrap.appendChild(title);
    const msg = el("div", "font-size:13px;color:#64748b;max-width:480px;line-height:1.5");
    msg.textContent = "Only the Gantt view is fully ported in this release. Switch back to Gantt to see the timeline. The other views are planned for the next cut alongside the AuditListView port.";
    wrap.appendChild(msg);
    container.appendChild(wrap);
  }
  const registry = [];
  function getEntry(c) {
    return registry.find((e) => e.container === c) || null;
  }
  function removeEntry(c) {
    const idx = registry.findIndex((e) => e.container === c);
    if (idx !== -1) registry.splice(idx, 1);
  }
  const EMBEDDED_FEATURE_OVERRIDES = {
    titleBar: false,
    statsPanel: false,
    filterBar: false,
    zoomBar: false,
    sidebar: false,
    detailPanel: false,
    auditPanel: false,
    hrsWkStrip: false
  };
  function renderEmbeddedFullscreenButton(container, onClick) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.setAttribute("data-nga-fullscreen-enter", "1");
    btn.textContent = "↗ Full Screen";
    btn.style.cssText = [
      "position:absolute",
      "top:8px",
      "right:8px",
      "z-index:50",
      "padding:6px 10px",
      "font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif",
      "font-size:11px",
      "font-weight:600",
      "color:#1f2937",
      "background:#ffffff",
      "border:1px solid #e5e7eb",
      "border-radius:6px",
      "box-shadow:0 1px 2px rgba(0,0,0,0.04)",
      "cursor:pointer"
    ].join(";");
    btn.addEventListener("click", onClick);
    if (!container.style.position) container.style.position = "relative";
    container.appendChild(btn);
    return () => {
      try {
        btn.remove();
      } catch (_e) {
      }
    };
  }
  class IIFEApp {
    static mount(container, options) {
      var _a, _b, _c, _d, _e, _f;
      const mountStartedAt = typeof performance !== "undefined" && performance.now ? performance.now() : Date.now();
      IIFEApp.unmount(container);
      const templateName = options.template || "cloudnimbus";
      const mode = options.mode || "fullscreen";
      try {
        const r = container.getBoundingClientRect();
        diag("mount:start", {
          containerRect: { x: r.x, y: r.y, w: r.width, h: r.height },
          mode,
          engineVersion: options.engine && options.engine.version || "unknown",
          hasOnExit: typeof options.onExitFullscreen === "function",
          hasOnEnter: typeof options.onEnterFullscreen === "function",
          engineOnly: !!options.engineOnly,
          template: templateName
        });
      } catch (_e2) {
      }
      const overrides = options.overrides ? { ...options.overrides } : {};
      if (((_a = options.config) == null ? void 0 : _a.title) !== void 0) overrides.title = options.config.title;
      if (((_b = options.config) == null ? void 0 : _b.version) !== void 0) overrides.version = options.config.version;
      if ((_c = options.config) == null ? void 0 : _c.buckets) overrides.buckets = options.config.buckets;
      if (mode === "embedded") {
        overrides.features = {
          ...EMBEDDED_FEATURE_OVERRIDES,
          ...overrides.features || {}
        };
      }
      let tplConfig;
      try {
        tplConfig = resolveTemplate(templateName, overrides);
      } catch (err) {
        console.error("[nimbus-gantt] template resolution failed:", err);
        tplConfig = resolveTemplate("cloudnimbus", overrides);
      }
      tplConfig.mode = mode;
      if (options.onEnterFullscreen) tplConfig.onEnterFullscreen = options.onEnterFullscreen;
      if (options.onExitFullscreen) tplConfig.onExitFullscreen = options.onExitFullscreen;
      if (options.cssUrl) tplConfig.stylesheet = { ...tplConfig.stylesheet, url: options.cssUrl };
      if (options.engine) tplConfig.engine = options.engine;
      if (options.recordUrlTemplate) tplConfig.recordUrlTemplate = options.recordUrlTemplate;
      if (options.engineOnly) {
        let _syncToCanvas = function() {
          const f = applyFilter(allTasks2, state2.filter, state2.search);
          const g = state2.groupBy === "epic" ? buildTasks(buildTasksEpic(f)) : buildTasks(f);
          const gi = inst;
          if (typeof gi.setData === "function") {
            gi.setData(g, []);
            try {
              gi.expandAll();
            } catch (_e2) {
            }
          }
        };
        if (!container.style.position) container.style.position = "relative";
        if (!container.style.height) container.style.height = "100%";
        if (!container.style.width) container.style.width = "100%";
        const ganttEl = document.createElement("div");
        ganttEl.style.cssText = "height:100%;width:100%;position:absolute;inset:0";
        container.innerHTML = "";
        container.appendChild(ganttEl);
        const _win = typeof window !== "undefined" ? window : null;
        const eng = options.engine ?? (_win == null ? void 0 : _win.NimbusGantt) ?? null;
        if (!eng || !eng.NimbusGantt) {
          ganttEl.style.cssText += ";padding:20px;color:#b91c1c;font-size:13px";
          ganttEl.textContent = "nimbus-gantt engine not loaded";
          registry.push({ container, cleanup: () => {
            container.innerHTML = "";
          } });
          return { setTasks: () => {
          }, destroy: () => IIFEApp.unmount(container) };
        }
        injectLegacyNgCss();
        let allTasks2 = options.tasks || [];
        const state2 = { ...INITIAL_STATE };
        const depthMap2 = buildDepthMap(allTasks2);
        const filtered = applyFilter(allTasks2, state2.filter, state2.search);
        const gtasks = buildTasks(filtered);
        let lastHoveredTaskId = null;
        const findTaskById = (id) => {
          if (!id) return null;
          return allTasks2.find((t) => t.id === id) ?? null;
        };
        const inst = new eng.NimbusGantt(ganttEl, {
          tasks: gtasks,
          dependencies: [],
          columns: buildGanttCols(tplConfig.features),
          theme: V3_THEME,
          rowHeight: 32,
          barHeight: 20,
          headerHeight: 32,
          gridWidth: 295,
          zoomLevel: state2.zoom,
          showToday: true,
          showWeekends: true,
          showProgress: true,
          colorMap: ((_d = options.config) == null ? void 0 : _d.colorMap) || { ...STAGE_COLORS, ...STAGE_TO_CATEGORY_COLOR },
          readOnly: false,
          onTaskClick: (task) => {
            var _a2, _b2;
            if (!task || !task.id || isBucketId(task.id)) return;
            const t = findTaskById(task.id);
            if (t) (_a2 = options.onTaskClick) == null ? void 0 : _a2.call(options, t, "canvas");
            (_b2 = options.onItemClick) == null ? void 0 : _b2.call(options, task.id);
          },
          onTaskDblClick: (task) => {
            var _a2;
            if (!task || !task.id || isBucketId(task.id)) return;
            const t = findTaskById(task.id);
            if (t) (_a2 = options.onTaskDoubleClick) == null ? void 0 : _a2.call(options, t);
          },
          // Canvas-bar hover: engine fires onHover on every pointermove that
          // hits a bar, with task=null when the cursor leaves all bars. We
          // coalesce to avoid duplicate fires when the cursor stays over the
          // same bar, and share lastHoveredTaskId with the grid-row + context-
          // menu path so right-click on a canvas bar resolves correctly.
          onHover: (task) => {
            var _a2;
            const id = (task == null ? void 0 : task.id) && !isBucketId(task.id) ? task.id : null;
            if (id === lastHoveredTaskId) return;
            lastHoveredTaskId = id;
            (_a2 = options.onTaskHover) == null ? void 0 : _a2.call(options, id);
          },
          onTaskMove: (task, s, e) => {
            var _a2;
            if (task && task.id && !isBucketId(task.id)) (_a2 = options.onPatch) == null ? void 0 : _a2.call(options, { id: task.id, startDate: s, endDate: e });
          },
          onTaskResize: (task, s, e) => {
            var _a2;
            if (task && task.id && !isBucketId(task.id)) (_a2 = options.onPatch) == null ? void 0 : _a2.call(options, { id: task.id, startDate: s, endDate: e });
          }
        });
        const handleMouseOver = (e) => {
          var _a2, _b2;
          const target = e.target;
          const row = (_a2 = target == null ? void 0 : target.closest) == null ? void 0 : _a2.call(target, ".ng-grid-row[data-task-id]");
          const id = (row == null ? void 0 : row.getAttribute("data-task-id")) ?? null;
          if (id && !isBucketId(id) && id !== lastHoveredTaskId) {
            lastHoveredTaskId = id;
            (_b2 = options.onTaskHover) == null ? void 0 : _b2.call(options, id);
          }
        };
        const handleMouseLeave = () => {
          var _a2;
          if (lastHoveredTaskId !== null) {
            lastHoveredTaskId = null;
            (_a2 = options.onTaskHover) == null ? void 0 : _a2.call(options, null);
          }
        };
        const handleContextMenu = (e) => {
          var _a2;
          if (!options.onTaskContextMenu) return;
          const target = e.target;
          const row = (_a2 = target == null ? void 0 : target.closest) == null ? void 0 : _a2.call(target, ".ng-grid-row[data-task-id]");
          const rowId = (row == null ? void 0 : row.getAttribute("data-task-id")) ?? null;
          const taskId = rowId && !isBucketId(rowId) ? rowId : lastHoveredTaskId;
          const t = findTaskById(taskId);
          if (!t) return;
          e.preventDefault();
          options.onTaskContextMenu(t, { x: e.clientX, y: e.clientY });
        };
        ganttEl.addEventListener("mouseover", handleMouseOver);
        ganttEl.addEventListener("mouseleave", handleMouseLeave);
        ganttEl.addEventListener("contextmenu", handleContextMenu);
        if (typeof ((_e = tplConfig.engine) == null ? void 0 : _e.PriorityGroupingPlugin) === "function") {
          inst.use(tplConfig.engine.PriorityGroupingPlugin({
            buckets: tplConfig.buckets,
            getBucket: (task) => task.groupId || null
          }));
        }
        inst.setData(gtasks, []);
        try {
          inst.expandAll();
        } catch (_e2) {
        }
        setTimeout(() => {
          var _a2, _b2, _c2, _d2, _e2, _f2, _g, _h, _i, _j;
          try {
            const gi = inst;
            const iv = options.initialViewport;
            if (iv && typeof iv.scrollLeft === "number") {
              (_b2 = (_a2 = gi.scrollManager) == null ? void 0 : _a2.scrollToX) == null ? void 0 : _b2.call(_a2, Math.max(0, iv.scrollLeft));
            } else if (options.initialFocusDate) {
              const parsed = parseFocusDate(options.initialFocusDate);
              if (parsed) {
                const snapped = snapDateToZoomPeriod(parsed, state2.zoom);
                const x = (_d2 = (_c2 = gi.timeScale) == null ? void 0 : _c2.dateToX) == null ? void 0 : _d2.call(_c2, snapped);
                if (typeof x === "number") (_f2 = (_e2 = gi.scrollManager) == null ? void 0 : _e2.scrollToX) == null ? void 0 : _f2.call(_e2, Math.max(0, x));
              }
            } else {
              const x = (_h = (_g = gi.timeScale) == null ? void 0 : _g.dateToX) == null ? void 0 : _h.call(_g, new Date(Date.now() - INITIAL_VIEWPORT_OFFSET_MS));
              if (typeof x === "number") (_j = (_i = gi.scrollManager) == null ? void 0 : _i.scrollToX) == null ? void 0 : _j.call(_i, Math.max(0, x));
            }
          } catch (_e3) {
          }
        }, 50);
        let cleanupShading2 = null;
        let cleanupDrag2 = null;
        if (tplConfig.features.depthShading) cleanupShading2 = startDepthShading(ganttEl, depthMap2);
        if (tplConfig.features.dragReparent) cleanupDrag2 = startDragReparent(ganttEl, allTasks2, depthMap2, options.onPatch || (() => {
        }));
        const cleanup2 = () => {
          if (cleanupShading2) cleanupShading2();
          if (cleanupDrag2) cleanupDrag2();
          ganttEl.removeEventListener("mouseover", handleMouseOver);
          ganttEl.removeEventListener("mouseleave", handleMouseLeave);
          ganttEl.removeEventListener("contextmenu", handleContextMenu);
          try {
            inst.destroy();
          } catch (_e2) {
          }
          container.innerHTML = "";
        };
        registry.push({ container, cleanup: cleanup2 });
        return {
          setTasks(tasks) {
            allTasks2 = tasks;
            _syncToCanvas();
          },
          /** Called by NimbusGanttAppReact when the React filter/search state changes. */
          setFilter(filter, search) {
            state2.filter = filter;
            state2.search = search;
            _syncToCanvas();
          },
          /** Called by NimbusGanttAppReact when the zoom pill changes. */
          setZoom(zoom) {
            state2.zoom = zoom;
            const gi = inst;
            if (typeof gi.setZoom === "function") gi.setZoom(zoom);
          },
          /** Called by NimbusGanttAppReact when the groupBy toggle changes. */
          setGroupBy(groupBy) {
            state2.groupBy = groupBy;
            _syncToCanvas();
          },
          /** 0.185 — engineOnly batchMode stubs.
           *
           *  The engineOnly mount path doesn't currently buffer edits — it
           *  forwards onTaskMove/onTaskResize directly to options.onPatch.
           *  These stubs exist so NimbusGanttAppReact consumers calling
           *  `handleRef.current.commitEdits()` get a clean no-op rather than
           *  a TypeError. Real batch buffering for the React driver is queued
           *  for a follow-up cut once a React consumer needs it (CN v10/v12
           *  stay on per-patch flow per 0.185 spec). */
          getPendingEdits() {
            return [];
          },
          commitEdits() {
            return Promise.resolve({ committed: [] });
          },
          discardEdits() {
          },
          /** 0.185.1 — same impl as the chrome-aware path. Snap then scroll. */
          scrollToDate(date) {
            var _a2, _b2, _c2, _d2;
            const parsed = parseFocusDate(date);
            if (!parsed) return;
            try {
              const gi = inst;
              const snapped = snapDateToZoomPeriod(parsed, state2.zoom);
              const x = (_b2 = (_a2 = gi.timeScale) == null ? void 0 : _a2.dateToX) == null ? void 0 : _b2.call(_a2, snapped);
              if (typeof x === "number") (_d2 = (_c2 = gi.scrollManager) == null ? void 0 : _c2.scrollToX) == null ? void 0 : _d2.call(_c2, Math.max(0, x));
            } catch (_e2) {
            }
          },
          destroy() {
            IIFEApp.unmount(container);
          }
        };
      }
      let state = { ...INITIAL_STATE };
      if ((_f = options.initialViewport) == null ? void 0 : _f.zoom) {
        state = { ...state, zoom: options.initialViewport.zoom };
      }
      let allTasks = options.tasks || [];
      const patchLog = [];
      const _viewportEmitTimer = { t: null };
      function emitViewport() {
        if (!options.onViewportChange || !ganttInst) return;
        if (_viewportEmitTimer.t) clearTimeout(_viewportEmitTimer.t);
        _viewportEmitTimer.t = setTimeout(() => {
          var _a2, _b2;
          _viewportEmitTimer.t = null;
          try {
            const sm = ganttInst.scrollManager;
            const pos = ((_a2 = sm == null ? void 0 : sm.getScrollPosition) == null ? void 0 : _a2.call(sm)) ?? { x: 0, y: 0 };
            (_b2 = options.onViewportChange) == null ? void 0 : _b2.call(options, {
              scrollLeft: pos.x,
              scrollTop: pos.y,
              zoom: state.zoom
            });
          } catch (_e2) {
          }
        }, 150);
      }
      let chromeVisible = options.chromeVisibleDefault !== false;
      if (mode === "embedded") chromeVisible = false;
      const ORIGINAL_FEATURES = { ...tplConfig.features };
      function applyChromeVisibility() {
        if (chromeVisible) {
          tplConfig.features = { ...ORIGINAL_FEATURES };
        } else {
          tplConfig.features = {
            ...ORIGINAL_FEATURES,
            ...EMBEDDED_FEATURE_OVERRIDES
          };
        }
      }
      applyChromeVisibility();
      function runToggleChrome(visible) {
        const next = typeof visible === "boolean" ? visible : !chromeVisible;
        if (next === chromeVisible) return;
        chromeVisible = next;
        applyChromeVisibility();
        renderSlots();
      }
      tplConfig.toggleChrome = runToggleChrome;
      injectLegacyNgCss();
      const themeStyleEl = document.createElement("style");
      themeStyleEl.setAttribute("data-nga-theme", tplConfig.templateName);
      themeStyleEl.textContent = themeToScopedCss(tplConfig.templateName, tplConfig.theme);
      container.appendChild(themeStyleEl);
      ensureTemplateCss(container, tplConfig.stylesheet).catch((err) => {
        console.warn("[nimbus-gantt] stylesheet load error", err);
      });
      container.className = "nga-root";
      container.setAttribute("data-template", tplConfig.templateName);
      container.setAttribute("data-mode", mode);
      container.style.display = "flex";
      container.style.flexDirection = "column";
      container.style.overflow = "hidden";
      container.style.background = tplConfig.theme.bg;
      container.style.fontFamily = tplConfig.theme.fontFamily;
      diag("mount:styles-applied", {
        propsWritten: ["display", "flex-direction", "overflow", "background", "font-family"],
        preservedConsumer: {
          height: container.style.height || "(inherits)",
          width: container.style.width || "(inherits)",
          position: container.style.position || "(inherits)"
        }
      });
      diag("mount:data-mode", { mode });
      const _patchRefreshTimer = { t: null };
      const rawOnPatch = options.onPatch || (() => {
      });
      const pendingEdits = /* @__PURE__ */ new Map();
      let nextEditSeq = 0;
      const inflightTaskIds = /* @__PURE__ */ new Set();
      const pendingBuffer = /* @__PURE__ */ new Map();
      const dirtyTaskIds = /* @__PURE__ */ new Set();
      function bufferEdit(taskId, kind, payloadDelta, originalDelta) {
        const key = taskId + "::" + kind;
        const existing = pendingBuffer.get(key);
        if (kind === "edit") {
          pendingBuffer.set(key, {
            taskId,
            kind: "edit",
            changes: { ...(existing == null ? void 0 : existing.changes) ?? {}, ...payloadDelta },
            original: (existing == null ? void 0 : existing.original) ?? originalDelta,
            ts: Date.now()
          });
        } else {
          pendingBuffer.set(key, {
            taskId,
            kind: "reorder",
            reorderPayload: {
              ...(existing == null ? void 0 : existing.reorderPayload) ?? {},
              ...payloadDelta
            },
            original: (existing == null ? void 0 : existing.original) ?? originalDelta,
            ts: Date.now()
          });
        }
      }
      function buildPendingChangesFromBuffer() {
        if (pendingBuffer.size === 0) return [];
        const byTask = /* @__PURE__ */ new Map();
        for (const p of pendingBuffer.values()) {
          let entry = byTask.get(p.taskId);
          if (!entry) {
            const task = allTasks.find((t) => t.id === p.taskId);
            const title = (task == null ? void 0 : task.title) || (task == null ? void 0 : task.name) || p.taskId;
            entry = { id: p.taskId, title, fields: [], descs: [] };
            byTask.set(p.taskId, entry);
          }
          if (p.kind === "edit" && p.changes) {
            if (p.changes.startDate !== void 0) {
              entry.fields.push("startDate");
              entry.descs.push("start: " + (p.original.startDate || "?") + " → " + p.changes.startDate);
            }
            if (p.changes.endDate !== void 0) {
              entry.fields.push("endDate");
              entry.descs.push("end: " + (p.original.endDate || "?") + " → " + p.changes.endDate);
            }
          }
          if (p.kind === "reorder" && p.reorderPayload) {
            if (p.reorderPayload.priorityGroup !== void 0) {
              entry.fields.push("priorityGroup");
              entry.descs.push("group: " + (p.original.priorityGroup || "?") + " → " + p.reorderPayload.priorityGroup);
            }
            if (p.reorderPayload.parentId !== void 0) {
              entry.fields.push("parentId");
              entry.descs.push("parent: " + (p.original.parentId || "none") + " → " + (p.reorderPayload.parentId || "none"));
            }
            if (p.reorderPayload.sortOrder !== void 0) {
              entry.fields.push("sortOrder");
              entry.descs.push("sortOrder → " + p.reorderPayload.sortOrder);
            }
          }
        }
        return Array.from(byTask.values());
      }
      function syncPendingChanges() {
        if (!options.batchMode) return;
        tplConfig.pendingChanges = buildPendingChangesFromBuffer();
        renderSlots();
      }
      function dimColor(hex) {
        if (!hex) return "#94a3b880";
        if (hex.startsWith("rgb")) return hex;
        const s = hex.charAt(0) === "#" ? hex.slice(1) : hex;
        const full = s.length === 3 ? s.charAt(0) + s.charAt(0) + s.charAt(1) + s.charAt(1) + s.charAt(2) + s.charAt(2) : s;
        if (full.length !== 6) return hex;
        return "#" + full + "80";
      }
      async function onTaskEditAsync(taskId, nextStart, nextEnd, changes) {
        var _a2, _b2;
        const idx = allTasks.findIndex((t) => t.id === taskId);
        try {
          console.log("[NG] onTaskEditAsync hit", taskId, "idx=", idx, "hasOnItemEdit=", !!options.onItemEdit, "hasOnPatch=", !!options.onPatch);
        } catch (_e2) {
        }
        if (idx === -1) {
          if (options.batchMode) {
            try {
              diag("warn:task-not-in-allTasks", { taskId, origin: "edit-batch", changes });
            } catch (_e2) {
            }
            return;
          }
          try {
            diag("warn:task-not-in-allTasks", { taskId, origin: "edit", changes });
          } catch (_e2) {
          }
          try {
            if (options.onItemEdit) {
              await options.onItemEdit(taskId, changes);
            } else {
              rawOnPatch({ id: taskId, startDate: nextStart, endDate: nextEnd });
            }
          } catch (err) {
            try {
              (_a2 = options.onItemEditError) == null ? void 0 : _a2.call(
                options,
                taskId,
                err instanceof Error ? err : new Error(String(err))
              );
            } catch (_e2) {
            }
          }
          return;
        }
        if (options.batchMode) {
          const origStartB = allTasks[idx].startDate || "";
          const origEndB = allTasks[idx].endDate || "";
          allTasks[idx] = { ...allTasks[idx], startDate: nextStart, endDate: nextEnd };
          const titleB = allTasks[idx].title || allTasks[idx].name || taskId;
          patchLog.unshift({ ts: /* @__PURE__ */ new Date(), desc: titleB + ": dates updated (pending)" });
          if (patchLog.length > 50) patchLog.pop();
          bufferEdit(
            taskId,
            "edit",
            { startDate: nextStart, endDate: nextEnd },
            { startDate: origStartB, endDate: origEndB }
          );
          dirtyTaskIds.add(taskId);
          syncPendingChanges();
          refreshGantt();
          return;
        }
        const existing = pendingEdits.get(taskId);
        const origStart = existing ? existing.origStart : allTasks[idx].startDate || "";
        const origEnd = existing ? existing.origEnd : allTasks[idx].endDate || "";
        const seq = ++nextEditSeq;
        pendingEdits.set(taskId, { seq, origStart, origEnd });
        inflightTaskIds.add(taskId);
        allTasks[idx] = { ...allTasks[idx], startDate: nextStart, endDate: nextEnd };
        const title = allTasks[idx].title || allTasks[idx].name || taskId;
        patchLog.unshift({ ts: /* @__PURE__ */ new Date(), desc: title + ": dates updated" });
        if (patchLog.length > 50) patchLog.pop();
        dispatch({ type: "PATCH", patch: { id: taskId, startDate: nextStart, endDate: nextEnd } });
        refreshGantt();
        if (!options.onItemEdit) {
          inflightTaskIds.delete(taskId);
          pendingEdits.delete(taskId);
          try {
            console.log("[NG] rawOnPatch firing", { taskId, startDate: nextStart, endDate: nextEnd, hasOnPatch: !!options.onPatch });
          } catch (_e2) {
          }
          rawOnPatch({ id: taskId, startDate: nextStart, endDate: nextEnd });
          try {
            diag("edit:commit", { taskId, nextStart, nextEnd, via: "rawOnPatch" });
          } catch (_e2) {
          }
          refreshGantt();
          return;
        }
        try {
          await options.onItemEdit(taskId, changes);
          const current = pendingEdits.get(taskId);
          if (!current || current.seq !== seq) return;
          pendingEdits.delete(taskId);
          inflightTaskIds.delete(taskId);
          refreshGantt();
        } catch (err) {
          const current = pendingEdits.get(taskId);
          if (!current || current.seq !== seq) return;
          const idxNow = allTasks.findIndex((t) => t.id === taskId);
          if (idxNow !== -1) {
            allTasks[idxNow] = { ...allTasks[idxNow], startDate: origStart, endDate: origEnd };
          }
          pendingEdits.delete(taskId);
          inflightTaskIds.delete(taskId);
          refreshGantt();
          try {
            (_b2 = options.onItemEditError) == null ? void 0 : _b2.call(
              options,
              taskId,
              err instanceof Error ? err : new Error(String(err))
            );
          } catch (_e2) {
          }
        }
      }
      const pendingReorders = /* @__PURE__ */ new Map();
      let nextReorderSeq = 0;
      async function onTaskReorderAsync(patch) {
        var _a2, _b2;
        const taskId = patch.id;
        const idx = allTasks.findIndex((t) => t.id === taskId);
        if (idx === -1) {
          if (options.batchMode) {
            try {
              diag("warn:task-not-in-allTasks", { taskId, origin: "reorder-batch", patch });
            } catch (_e2) {
            }
            return;
          }
          try {
            diag("warn:task-not-in-allTasks", { taskId, origin: "reorder", patch });
          } catch (_e2) {
          }
          try {
            if (options.onItemReorder) {
              const newIndex = typeof patch.sortOrder === "number" ? patch.sortOrder : 0;
              const reorderPayload = { newIndex };
              if (patch.parentId !== void 0) reorderPayload.newParentId = patch.parentId;
              if (patch.priorityGroup !== void 0) reorderPayload.newPriorityGroup = patch.priorityGroup;
              await options.onItemReorder(taskId, reorderPayload);
            } else {
              rawOnPatch(patch);
            }
          } catch (err) {
            try {
              (_a2 = options.onItemReorderError) == null ? void 0 : _a2.call(
                options,
                taskId,
                err instanceof Error ? err : new Error(String(err))
              );
            } catch (_e2) {
            }
          }
          return;
        }
        if (options.batchMode) {
          const origTaskB = allTasks[idx];
          const u2 = { ...origTaskB };
          if (patch.parentId !== void 0) u2.parentWorkItemId = patch.parentId;
          if (patch.priorityGroup !== void 0) u2.priorityGroup = patch.priorityGroup;
          if (patch.sortOrder !== void 0) u2.sortOrder = patch.sortOrder;
          allTasks[idx] = u2;
          const titleB = origTaskB.title || origTaskB.name || taskId;
          const partsB = [];
          if (patch.priorityGroup) partsB.push("→ " + patch.priorityGroup);
          if (patch.parentId !== void 0) partsB.push("parent " + (patch.parentId || "none"));
          if (patch.sortOrder !== void 0) partsB.push("reordered");
          patchLog.unshift({ ts: /* @__PURE__ */ new Date(), desc: titleB + ": " + partsB.join(", ") + " (pending)" });
          if (patchLog.length > 50) patchLog.pop();
          const reorderDelta = {};
          if (patch.priorityGroup !== void 0) reorderDelta.priorityGroup = patch.priorityGroup;
          if (patch.sortOrder !== void 0) reorderDelta.sortOrder = patch.sortOrder;
          if (patch.parentId !== void 0) reorderDelta.parentId = patch.parentId;
          bufferEdit(taskId, "reorder", reorderDelta, {
            priorityGroup: origTaskB.priorityGroup ?? void 0,
            sortOrder: origTaskB.sortOrder,
            parentId: origTaskB.parentWorkItemId ?? null
          });
          dirtyTaskIds.add(taskId);
          syncPendingChanges();
          refreshGantt();
          return;
        }
        const existing = pendingReorders.get(taskId);
        const origTask = allTasks[idx];
        const origParentId = existing ? existing.origParentId : origTask.parentWorkItemId;
        const origSortOrder = existing ? existing.origSortOrder : origTask.sortOrder;
        const origPriorityGroup = existing ? existing.origPriorityGroup : origTask.priorityGroup;
        const seq = ++nextReorderSeq;
        pendingReorders.set(taskId, { seq, origParentId, origSortOrder, origPriorityGroup });
        inflightTaskIds.add(taskId);
        const u = { ...origTask };
        if (patch.parentId !== void 0) u.parentWorkItemId = patch.parentId;
        if (patch.priorityGroup !== void 0) u.priorityGroup = patch.priorityGroup;
        if (patch.sortOrder !== void 0) u.sortOrder = patch.sortOrder;
        allTasks[idx] = u;
        const title = origTask.title || origTask.name || taskId;
        const logParts = [];
        if (patch.priorityGroup) logParts.push("→ " + patch.priorityGroup);
        if (patch.parentId !== void 0) logParts.push("parent " + (patch.parentId || "none"));
        if (patch.sortOrder !== void 0) logParts.push("reordered");
        patchLog.unshift({ ts: /* @__PURE__ */ new Date(), desc: title + ": " + logParts.join(", ") });
        if (patchLog.length > 50) patchLog.pop();
        dispatch({ type: "PATCH", patch });
        refreshGantt();
        if (!options.onItemReorder) {
          inflightTaskIds.delete(taskId);
          pendingReorders.delete(taskId);
          rawOnPatch(patch);
          refreshGantt();
          return;
        }
        try {
          const newIndex = typeof patch.sortOrder === "number" ? patch.sortOrder : 0;
          const reorderPayload = { newIndex };
          if (patch.parentId !== void 0) reorderPayload.newParentId = patch.parentId;
          if (patch.priorityGroup !== void 0) reorderPayload.newPriorityGroup = patch.priorityGroup;
          await options.onItemReorder(taskId, reorderPayload);
          const current = pendingReorders.get(taskId);
          if (!current || current.seq !== seq) return;
          pendingReorders.delete(taskId);
          inflightTaskIds.delete(taskId);
          refreshGantt();
        } catch (err) {
          const current = pendingReorders.get(taskId);
          if (!current || current.seq !== seq) return;
          const idxNow = allTasks.findIndex((t) => t.id === taskId);
          if (idxNow !== -1) {
            const rev = { ...allTasks[idxNow] };
            rev.parentWorkItemId = origParentId ?? null;
            if (origSortOrder !== void 0) rev.sortOrder = origSortOrder;
            rev.priorityGroup = origPriorityGroup ?? null;
            allTasks[idxNow] = rev;
          }
          pendingReorders.delete(taskId);
          inflightTaskIds.delete(taskId);
          refreshGantt();
          try {
            (_b2 = options.onItemReorderError) == null ? void 0 : _b2.call(
              options,
              taskId,
              err instanceof Error ? err : new Error(String(err))
            );
          } catch (_e2) {
          }
        }
      }
      const _reorderBuffer = /* @__PURE__ */ new Map();
      let _reorderFlushScheduled = false;
      function flushReorderBuffer() {
        _reorderFlushScheduled = false;
        const merged = Array.from(_reorderBuffer.values());
        _reorderBuffer.clear();
        merged.forEach((p) => onTaskReorderAsync(p));
      }
      function interceptedOnPatch(patch) {
        const hasStructural = patch.parentId !== void 0 || patch.priorityGroup !== void 0 || patch.sortOrder !== void 0;
        const hasDates = patch.startDate !== void 0 || patch.endDate !== void 0;
        if (hasStructural && !hasDates) {
          const prev = _reorderBuffer.get(patch.id);
          _reorderBuffer.set(patch.id, prev ? { ...prev, ...patch } : { ...patch });
          if (!_reorderFlushScheduled) {
            _reorderFlushScheduled = true;
            Promise.resolve().then(flushReorderBuffer);
          }
        } else {
          onTaskPatch(patch);
        }
      }
      function onTaskPatch(patch) {
        const idx = allTasks.findIndex((t) => t.id === patch.id);
        if (idx !== -1) {
          const t = allTasks[idx];
          const u = { ...t };
          if (patch.priorityGroup !== void 0) u.priorityGroup = patch.priorityGroup;
          if (patch.sortOrder !== void 0) u.sortOrder = patch.sortOrder;
          if ("parentId" in patch) u.parentWorkItemId = patch.parentId ?? null;
          if (patch.startDate !== void 0) u.startDate = patch.startDate;
          if (patch.endDate !== void 0) u.endDate = patch.endDate;
          allTasks[idx] = u;
        }
        const task = allTasks.find((t) => t.id === patch.id);
        const title = task && (task.title || task.name) || String(patch.id);
        const parts = [];
        if (patch.priorityGroup) parts.push("→ " + patch.priorityGroup);
        if (patch.parentId !== void 0) parts.push("parent " + (patch.parentId || "none"));
        if (patch.sortOrder !== void 0) parts.push("reordered");
        if (patch.startDate || patch.endDate) parts.push("dates updated");
        if (parts.length) {
          patchLog.unshift({ ts: /* @__PURE__ */ new Date(), desc: title + ": " + parts.join(", ") });
          if (patchLog.length > 50) patchLog.pop();
        }
        rawOnPatch(patch);
        if (_patchRefreshTimer.t) clearTimeout(_patchRefreshTimer.t);
        _patchRefreshTimer.t = setTimeout(() => {
          _patchRefreshTimer.t = null;
          refreshGantt();
        }, 50);
      }
      function dispatch(ev) {
        if (ev.type === "PATCH") {
          onTaskPatch(ev.patch);
          return;
        }
        const nextState = reduceAppState(state, ev);
        const stateChanged = nextState !== state;
        state = nextState;
        if (stateChanged) {
          if (state.fullscreen) container.classList.add("nga-fullscreen");
          else container.classList.remove("nga-fullscreen");
          reconcileFeatureOverrides();
          renderSlots();
          const viewChangingEvents = ["SET_VIEW", "SET_GROUP_BY", "SET_FILTER", "SET_SEARCH", "TOGGLE_HIDE_COMPLETED"];
          if (viewChangingEvents.indexOf(ev.type) >= 0) {
            rebuildView();
          } else if (ev.type === "TOGGLE_FEATURE") {
            rebuildView();
          } else if (ev.type === "SET_ZOOM") {
            if (ganttInst && typeof ganttInst.setZoom === "function") ganttInst.setZoom(state.zoom);
            emitViewport();
          }
        }
      }
      const FEATURE_DEFAULTS = {};
      function snapshotFeatureDefaults() {
        const f = tplConfig.features;
        for (const k of Object.keys(f)) FEATURE_DEFAULTS[k] = f[k];
      }
      function reconcileFeatureOverrides() {
        const f = tplConfig.features;
        for (const k of Object.keys(FEATURE_DEFAULTS)) {
          const override = state.featureOverrides[k];
          f[k] = override === void 0 ? FEATURE_DEFAULTS[k] : override;
        }
      }
      function buildSlotData() {
        const stats = computeStats(applyFilter(allTasks, state.filter, state.search));
        const visibleTasks = buildTasks(applyFilter(allTasks, state.filter, state.search));
        return { tasks: allTasks, visibleTasks, stats, patchLog: patchLog.slice() };
      }
      function currentProps() {
        return { config: tplConfig, state, dispatch, data: buildSlotData() };
      }
      const slotInstances = /* @__PURE__ */ new Map();
      let ganttHost = null;
      function renderSlots() {
        const props = currentProps();
        SLOT_ORDER.forEach((slotName) => {
          const enabled2 = shouldRenderSlot(slotName, tplConfig.features);
          const existing = slotInstances.get(slotName);
          const slotDef = tplConfig.components[slotName];
          if (!enabled2) {
            if (existing) {
              existing.destroy();
              slotInstances.delete(slotName);
            }
            return;
          }
          const factory = slotDef && slotDef.vanilla;
          if (!factory) {
            if (existing) {
              existing.destroy();
              slotInstances.delete(slotName);
            }
            return;
          }
          if (existing) {
            existing.update(props);
          } else {
            const inst = factory(props);
            slotInstances.set(slotName, inst);
            container.appendChild(inst.el);
          }
        });
        SLOT_ORDER.forEach((slotName) => {
          const inst = slotInstances.get(slotName);
          if (inst && inst.el.parentNode === container) {
            container.appendChild(inst.el);
          }
        });
        const contentInst = slotInstances.get("ContentArea");
        if (contentInst) {
          ganttHost = contentInst.el.querySelector('[data-nga-gantt-host="1"]');
        }
        renderAdminPanel(container, state, dispatch, tplConfig);
        renderAdvisorPanel(container, state, dispatch);
      }
      let ganttInst = null;
      let cleanupShading = null;
      let cleanupDrag = null;
      let depthMap = buildDepthMap(allTasks);
      function resolveEngine() {
        if (options.engine) return options.engine;
        const w = window;
        if (w && w.NimbusGantt) return w.NimbusGantt;
        return null;
      }
      function initGantt(host) {
        var _a2;
        const eng = resolveEngine();
        if (!eng || !eng.NimbusGantt) {
          host.style.cssText = "padding:20px;color:#b91c1c;font-size:13px";
          host.textContent = "nimbus-gantt engine not loaded";
          return;
        }
        const Ctor = eng.NimbusGantt;
        const PGP = eng.PriorityGroupingPlugin;
        const hwp = eng.hoursWeightedProgress;
        const filtered = applyFilter(allTasks, state.filter, state.search);
        const maybeHide = state.hideCompleted ? filtered.filter((t) => !DONE_STAGES[t.stage || ""]) : filtered;
        const gtasks = state.groupBy === "epic" ? buildTasks(buildTasksEpic(maybeHide)) : buildTasks(maybeHide);
        const ganttEl = document.createElement("div");
        ganttEl.style.cssText = "height:100%;width:100%;position:absolute;inset:0";
        host.innerHTML = "";
        host.appendChild(ganttEl);
        let lastHoveredTaskId = null;
        ganttInst = new Ctor(ganttEl, {
          tasks: gtasks,
          dependencies: [],
          columns: buildGanttCols(tplConfig.features),
          theme: V3_THEME,
          rowHeight: 32,
          barHeight: 20,
          headerHeight: 32,
          gridWidth: 295,
          zoomLevel: state.zoom,
          showToday: true,
          showWeekends: true,
          showProgress: true,
          colorMap: ((_a2 = options.config) == null ? void 0 : _a2.colorMap) || { ...STAGE_COLORS, ...STAGE_TO_CATEGORY_COLOR },
          readOnly: false,
          onTaskClick: (task) => {
            var _a3, _b2;
            if (!task || !task.id || isBucketId(task.id)) return;
            dispatch({ type: "TOGGLE_DETAIL", taskId: task.id });
            const t = allTasks.find((x) => x.id === task.id);
            if (t) (_a3 = options.onTaskClick) == null ? void 0 : _a3.call(options, t, "canvas");
            (_b2 = options.onItemClick) == null ? void 0 : _b2.call(options, task.id);
          },
          onTaskDblClick: (task) => {
            var _a3;
            if (!task || !task.id || isBucketId(task.id)) return;
            dispatch({ type: "TOGGLE_DETAIL", taskId: task.id, editMode: true });
            const t = allTasks.find((x) => x.id === task.id);
            if (t) (_a3 = options.onTaskDoubleClick) == null ? void 0 : _a3.call(options, t);
          },
          // Canvas-bar hover — engine fires onHover on pointermove hits.
          // Coalesce so identical-id sequential fires are a no-op, and keep
          // lastHoveredTaskId in sync with the DOM grid-row path (set below)
          // so right-click on a canvas bar resolves correctly.
          onHover: (task) => {
            var _a3;
            const id = (task == null ? void 0 : task.id) && !isBucketId(task.id) ? task.id : null;
            if (id === lastHoveredTaskId) return;
            lastHoveredTaskId = id;
            (_a3 = options.onTaskHover) == null ? void 0 : _a3.call(options, id);
          },
          onTaskMove: (task, s, e) => {
            try {
              console.log("[NG] main onTaskMove received", task == null ? void 0 : task.id, s, e);
            } catch (_e2) {
            }
            if (!task || !task.id || isBucketId(task.id)) return;
            onTaskEditAsync(task.id, s, e, { startDate: s, endDate: e });
          },
          onTaskResize: (task, s, e) => {
            try {
              console.log("[NG] main onTaskResize received", task == null ? void 0 : task.id, s, e);
            } catch (_e2) {
            }
            if (!task || !task.id || isBucketId(task.id)) return;
            const orig = allTasks.find((t) => t.id === task.id);
            const changes = {};
            if (!orig || orig.startDate !== s) changes.startDate = s;
            if (!orig || orig.endDate !== e) changes.endDate = e;
            onTaskEditAsync(task.id, s, e, changes);
          }
        });
        const findTaskById = (id) => id ? allTasks.find((t) => t.id === id) ?? null : null;
        const onMouseOver = (e) => {
          var _a3, _b2;
          const target = e.target;
          const row = (_a3 = target == null ? void 0 : target.closest) == null ? void 0 : _a3.call(target, ".ng-grid-row[data-task-id]");
          const id = (row == null ? void 0 : row.getAttribute("data-task-id")) ?? null;
          if (id && !isBucketId(id) && id !== lastHoveredTaskId) {
            lastHoveredTaskId = id;
            (_b2 = options.onTaskHover) == null ? void 0 : _b2.call(options, id);
          }
        };
        const onMouseLeave = () => {
          var _a3;
          if (lastHoveredTaskId !== null) {
            lastHoveredTaskId = null;
            (_a3 = options.onTaskHover) == null ? void 0 : _a3.call(options, null);
          }
        };
        const onContextMenu = (e) => {
          var _a3;
          if (!options.onTaskContextMenu) return;
          const target = e.target;
          const row = (_a3 = target == null ? void 0 : target.closest) == null ? void 0 : _a3.call(target, ".ng-grid-row[data-task-id]");
          const rowId = (row == null ? void 0 : row.getAttribute("data-task-id")) ?? null;
          const taskId = rowId && !isBucketId(rowId) ? rowId : lastHoveredTaskId;
          const t = findTaskById(taskId);
          if (!t) return;
          e.preventDefault();
          options.onTaskContextMenu(t, { x: e.clientX, y: e.clientY });
        };
        ganttEl.addEventListener("mouseover", onMouseOver);
        ganttEl.addEventListener("mouseleave", onMouseLeave);
        ganttEl.addEventListener("contextmenu", onContextMenu);
        const prevCleanupDrag = cleanupDrag;
        cleanupDrag = () => {
          ganttEl.removeEventListener("mouseover", onMouseOver);
          ganttEl.removeEventListener("mouseleave", onMouseLeave);
          ganttEl.removeEventListener("contextmenu", onContextMenu);
          if (prevCleanupDrag) prevCleanupDrag();
        };
        if (typeof PGP === "function") {
          const pluginBuckets = tplConfig.buckets;
          const bucketProgressFn = tplConfig.features.headerRowCompletionBar === false ? () => 0 : typeof hwp === "function" ? hwp : void 0;
          ganttInst.use(PGP({
            buckets: pluginBuckets,
            getBucket: (task) => task.groupId || null,
            getBucketProgress: bucketProgressFn
          }));
        }
        ganttInst.setData(gtasks, []);
        try {
          ganttInst.expandAll();
        } catch (_e2) {
        }
        setTimeout(() => {
          var _a3, _b2, _c2, _d2, _e2, _f2, _g, _h, _i, _j, _k, _l, _m;
          try {
            const gi = ganttInst;
            const iv = options.initialViewport;
            if (iv && (typeof iv.scrollLeft === "number" || typeof iv.scrollTop === "number")) {
              const x = typeof iv.scrollLeft === "number" ? Math.max(0, iv.scrollLeft) : 0;
              const y = typeof iv.scrollTop === "number" ? Math.max(0, iv.scrollTop) : 0;
              if (typeof ((_a3 = gi.scrollManager) == null ? void 0 : _a3.setScrollPosition) === "function") {
                gi.scrollManager.setScrollPosition(x, y);
              } else {
                (_c2 = (_b2 = gi.scrollManager) == null ? void 0 : _b2.scrollToX) == null ? void 0 : _c2.call(_b2, x);
                (_e2 = (_d2 = gi.scrollManager) == null ? void 0 : _d2.scrollToY) == null ? void 0 : _e2.call(_d2, y);
              }
            } else if (options.initialFocusDate) {
              const parsed = parseFocusDate(options.initialFocusDate);
              if (parsed) {
                const snapped = snapDateToZoomPeriod(parsed, state.zoom);
                const x = (_g = (_f2 = gi.timeScale) == null ? void 0 : _f2.dateToX) == null ? void 0 : _g.call(_f2, snapped);
                if (typeof x === "number") (_i = (_h = gi.scrollManager) == null ? void 0 : _h.scrollToX) == null ? void 0 : _i.call(_h, Math.max(0, x));
              }
            } else {
              const x = (_k = (_j = gi.timeScale) == null ? void 0 : _j.dateToX) == null ? void 0 : _k.call(_j, new Date(Date.now() - INITIAL_VIEWPORT_OFFSET_MS));
              if (typeof x === "number") (_m = (_l = gi.scrollManager) == null ? void 0 : _l.scrollToX) == null ? void 0 : _m.call(_l, Math.max(0, x));
            }
          } catch (_e3) {
          }
        }, 50);
        if (cleanupShading) cleanupShading();
        if (cleanupDrag) cleanupDrag();
        if (tplConfig.features.depthShading) cleanupShading = startDepthShading(ganttEl, depthMap);
        if (tplConfig.features.dragReparent) cleanupDrag = startDragReparent(ganttEl, allTasks, depthMap, interceptedOnPatch);
        if (options.onViewportChange) {
          try {
            const wrapper = ganttEl.querySelector(".ng-scroll-wrapper");
            if (wrapper) {
              const onScroll = () => emitViewport();
              wrapper.addEventListener("scroll", onScroll, { passive: true });
              const prevCleanupDrag2 = cleanupDrag;
              cleanupDrag = () => {
                wrapper.removeEventListener("scroll", onScroll);
                if (prevCleanupDrag2) prevCleanupDrag2();
              };
            }
          } catch (_e2) {
          }
        }
      }
      function refreshGantt() {
        if (!ganttHost) return;
        if (state.viewMode === "gantt" && ganttInst) {
          const filtered = applyFilter(allTasks, state.filter, state.search);
          const maybeHide = state.hideCompleted ? filtered.filter((t) => !DONE_STAGES[t.stage || ""]) : filtered;
          let gtasks = state.groupBy === "epic" ? buildTasks(buildTasksEpic(maybeHide)) : buildTasks(maybeHide);
          if (inflightTaskIds.size > 0 || dirtyTaskIds.size > 0) {
            gtasks = gtasks.map((t) => inflightTaskIds.has(t.id) || dirtyTaskIds.has(t.id) ? { ...t, color: dimColor(t.color) } : t);
          }
          const gi = ganttInst;
          if (typeof gi.setData === "function") {
            gi.setData(gtasks, []);
            try {
              gi.expandAll();
            } catch (_e2) {
            }
          }
        } else {
          rebuildView();
        }
        renderSlots();
      }
      function rebuildView() {
        var _a2;
        if (!ganttHost) return;
        if (cleanupShading) {
          cleanupShading();
          cleanupShading = null;
        }
        if (cleanupDrag) {
          cleanupDrag();
          cleanupDrag = null;
        }
        if (ganttInst) {
          try {
            ganttInst.destroy();
          } catch (_e2) {
          }
          ganttInst = null;
        }
        ganttHost.innerHTML = "";
        if (state.viewMode === "gantt") {
          initGantt(ganttHost);
        } else if (state.viewMode === "list") {
          renderAuditListView(ganttHost, allTasks, {
            progressLabel: tplConfig.progressLabel,
            hideRecordIds: tplConfig.hideRecordIds,
            // 0.185.5 — forward the host's onItemReorder contract so the
            // list-view 3-dot handle persists drops through the same path
            // the gantt sidebar uses.
            onReorder: options.onItemReorder ? (taskId, payload) => {
              void options.onItemReorder(taskId, payload);
            } : void 0
          });
        } else if (state.viewMode === "treemap" || state.viewMode === "bubbles") {
          mountAltCanvasView(
            ganttHost,
            allTasks,
            state.viewMode === "treemap" ? renderTreemap : renderBubble,
            ((_a2 = options.config) == null ? void 0 : _a2.colorMap) || { ...STAGE_COLORS, ...STAGE_TO_CATEGORY_COLOR }
          );
        } else {
          const labelMap = {
            calendar: "Calendar",
            flow: "Flow"
          };
          renderComingSoon(ganttHost, labelMap[state.viewMode] || state.viewMode);
        }
        renderSlots();
      }
      snapshotFeatureDefaults();
      renderSlots();
      try {
        const renderedSlots = [];
        slotInstances.forEach((_inst, name) => renderedSlots.push(name));
        diag("mount:slots-rendered", {
          slotOrder: SLOT_ORDER,
          rendered: renderedSlots,
          features: tplConfig.features
        });
      } catch (_e2) {
      }
      if (ganttHost) initGantt(ganttHost);
      try {
        const raf = typeof requestAnimationFrame === "function" ? requestAnimationFrame : (fn) => setTimeout(() => fn(Date.now()), 16);
        raf(() => {
          try {
            const measure = (sel) => {
              const elSel = container.querySelector(sel);
              return elSel ? Math.round(elSel.getBoundingClientRect().height) : 0;
            };
            diag("mount:chrome-heights", {
              root: Math.round(container.getBoundingClientRect().height),
              titlebar: measure(".nga-titlebar"),
              stats: measure(".nga-stats"),
              filterbar: measure(".nga-filterbar"),
              zoombar: measure(".nga-zoombar"),
              audit: measure(".nga-audit"),
              hrswkstrip: measure(".nga-hrswkstrip"),
              contentOuter: measure(".nga-content-outer"),
              content: measure(".nga-content")
            });
            const canvasEl = container.querySelector("canvas");
            if (canvasEl) {
              diag("mount:init-gantt", {
                canvasW: canvasEl.width,
                canvasH: canvasEl.height,
                cssW: Math.round(canvasEl.getBoundingClientRect().width),
                cssH: Math.round(canvasEl.getBoundingClientRect().height)
              });
              if (canvasEl.height < 64) {
                diag("warn:zero-height", { surface: "canvas", canvasH: canvasEl.height });
              }
            } else {
              diag("warn:no-canvas", {});
            }
            const durationMs = (typeof performance !== "undefined" && performance.now ? performance.now() : Date.now()) - mountStartedAt;
            diag("mount:complete", {
              taskCount: allTasks.length,
              durationMs: Math.round(durationMs)
            });
          } catch (err) {
            diag("err:post-mount", { message: (err == null ? void 0 : err.message) || String(err) });
          }
        });
      } catch (_e2) {
      }
      let cleanupEmbeddedBtn = null;
      if (mode === "embedded" && options.onEnterFullscreen) {
        cleanupEmbeddedBtn = renderEmbeddedFullscreenButton(
          container,
          () => {
            var _a2;
            return (_a2 = options.onEnterFullscreen) == null ? void 0 : _a2.call(options);
          }
        );
      }
      const cleanup = () => {
        if (cleanupShading) cleanupShading();
        if (cleanupDrag) cleanupDrag();
        if (cleanupEmbeddedBtn) cleanupEmbeddedBtn();
        if (ganttInst) {
          try {
            ganttInst.destroy();
          } catch (_e2) {
          }
        }
        slotInstances.forEach((inst) => inst.destroy());
        slotInstances.clear();
        removeTemplateCss(container);
        try {
          themeStyleEl.remove();
        } catch (_e2) {
        }
      };
      registry.push({ container, cleanup });
      return {
        setTasks(tasks) {
          allTasks = tasks;
          depthMap = buildDepthMap(allTasks);
          rebuildView();
        },
        /** CH-1 (0.183) — toggle chrome visibility at runtime. With no arg,
         *  flips current state; boolean arg sets explicitly. Embedded-mode
         *  mounts cannot re-show chrome this way because features were
         *  scrubbed at resolve time (mount with mode='fullscreen' first if
         *  runtime re-show is needed). Delegates to runToggleChrome so
         *  slot-dispatched toggles (TitleBar Unpin) and handle-dispatched
         *  toggles share one code path. */
        toggleChrome(visible) {
          runToggleChrome(visible);
        },
        /** 0.185 — snapshot of the batch buffer. Empty array when batchMode
         *  is off or the buffer is clean. Insertion-order preserved across
         *  the Map iteration. */
        getPendingEdits() {
          return Array.from(pendingBuffer.values());
        },
        /** 0.185 — flush every buffered edit to the host. Edits first
         *  (date changes), reorders second (parent/sortOrder/priorityGroup) —
         *  matches DH Apex's race-avoidance pattern (sortOrder reads neighbor
         *  state, so updateWorkItemDates must land first). Resolves with
         *  `{ committed }` on full success. On first failure, throws
         *  `{ failedAt, successful, error }`; failed + remaining stay in
         *  the buffer so the host can retry or discardEdits(). */
        async commitEdits() {
          const all = Array.from(pendingBuffer.values());
          const edits = all.filter((p) => p.kind === "edit");
          const reorders = all.filter((p) => p.kind === "reorder");
          const ordered = [...edits, ...reorders];
          const committed = [];
          for (const p of ordered) {
            try {
              if (p.kind === "edit" && p.changes) {
                if (options.onItemEdit) {
                  await options.onItemEdit(p.taskId, p.changes);
                } else if (options.onPatch) {
                  await Promise.resolve(options.onPatch({
                    id: p.taskId,
                    startDate: p.changes.startDate,
                    endDate: p.changes.endDate
                  }));
                }
              } else if (p.kind === "reorder" && p.reorderPayload) {
                if (options.onItemReorder) {
                  const newIndex = typeof p.reorderPayload.sortOrder === "number" ? p.reorderPayload.sortOrder : 0;
                  const payload = { newIndex };
                  if (p.reorderPayload.parentId !== void 0) payload.newParentId = p.reorderPayload.parentId;
                  if (p.reorderPayload.priorityGroup !== void 0) payload.newPriorityGroup = p.reorderPayload.priorityGroup;
                  await options.onItemReorder(p.taskId, payload);
                } else if (options.onPatch) {
                  await Promise.resolve(options.onPatch({
                    id: p.taskId,
                    parentId: p.reorderPayload.parentId,
                    priorityGroup: p.reorderPayload.priorityGroup,
                    sortOrder: p.reorderPayload.sortOrder
                  }));
                }
              }
              pendingBuffer.delete(p.taskId + "::" + p.kind);
              const stillBuffered = pendingBuffer.has(p.taskId + "::edit") || pendingBuffer.has(p.taskId + "::reorder");
              if (!stillBuffered) dirtyTaskIds.delete(p.taskId);
              committed.push(p);
            } catch (err) {
              syncPendingChanges();
              refreshGantt();
              throw { failedAt: p, successful: committed, error: err };
            }
          }
          syncPendingChanges();
          refreshGantt();
          return { committed };
        },
        /** 0.185.1 — imperative scroll-to-date. Snaps to start-of-period for
         *  the current zoom (Mon for week, 1st for month, 1st of quarter for
         *  quarter; day = no snap), then computes scrollLeft via
         *  `timeScale.dateToX` and lands the date at the LEFT edge. No-op if
         *  the engine isn't mounted yet (early call before initGantt). */
        scrollToDate(date) {
          var _a2, _b2, _c2, _d2;
          if (!ganttInst) return;
          const parsed = parseFocusDate(date);
          if (!parsed) return;
          try {
            const gi = ganttInst;
            const snapped = snapDateToZoomPeriod(parsed, state.zoom);
            const x = (_b2 = (_a2 = gi.timeScale) == null ? void 0 : _a2.dateToX) == null ? void 0 : _b2.call(_a2, snapped);
            if (typeof x === "number") (_d2 = (_c2 = gi.scrollManager) == null ? void 0 : _c2.scrollToX) == null ? void 0 : _d2.call(_c2, Math.max(0, x));
          } catch (_e2) {
          }
        },
        /** 0.185 — visual-only revert. Restores `original` on every buffered
         *  task and clears the buffer. Host never sees a callback. Use when
         *  the user clicks Cancel on the audit preview modal. */
        discardEdits() {
          for (const p of pendingBuffer.values()) {
            const idx = allTasks.findIndex((t) => t.id === p.taskId);
            if (idx === -1) continue;
            const u = { ...allTasks[idx] };
            if (p.kind === "edit") {
              if (p.original.startDate !== void 0) u.startDate = p.original.startDate;
              if (p.original.endDate !== void 0) u.endDate = p.original.endDate;
            } else {
              if (p.original.priorityGroup !== void 0) u.priorityGroup = p.original.priorityGroup;
              if (p.original.parentId !== void 0) u.parentWorkItemId = p.original.parentId;
              if (p.original.sortOrder !== void 0) u.sortOrder = p.original.sortOrder;
            }
            allTasks[idx] = u;
          }
          pendingBuffer.clear();
          dirtyTaskIds.clear();
          syncPendingChanges();
          refreshGantt();
        },
        destroy() {
          IIFEApp.unmount(container);
        }
      };
    }
    static unmount(container) {
      const e = getEntry(container);
      if (e) {
        if (e.cleanup) e.cleanup();
        removeEntry(container);
      }
      container.innerHTML = "";
    }
  }
  const NimbusGanttApp2 = {
    mount: (container, options) => IIFEApp.mount(container, options),
    unmount: (container) => IIFEApp.unmount(container),
    /**
     * Register a custom template. Silently ignores React-only fields; only
     * .vanilla slot factories are honoured in IIFE builds.
     */
    registerTemplate: (template) => {
      registerTemplate(template);
    },
    /** Return names of all registered templates. */
    listTemplates: () => listTemplates(),
    /** Retrieve a template by name. */
    getTemplate: (name) => getTemplate(name)
  };
  exports.NimbusGanttApp = NimbusGanttApp2;
  Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
  return exports;
})({});
typeof window !== "undefined" && (window.NimbusGanttApp = NimbusGanttApp.NimbusGanttApp || NimbusGanttApp);
