var NimbusGanttApp = (function(exports) {
  "use strict";
  const GROUP_BAR = {
    "top-priority": "#f87171",
    "active": "#fbbf24",
    "follow-on": "#34d399",
    "proposed": "#60a5fa",
    "deferred": "#cbd5e1"
  };
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
      const hLabel = hrs > 0 ? logged > 0 ? hrs + "h (" + pct + "%)" : hrs + "h" : "";
      const gid = t.parentWorkItemId ? null : t.priorityGroup || null;
      const col = gid ? GROUP_BAR[gid] || "#94a3b8" : STAGE_TO_CATEGORY_COLOR[t.stage || ""] || STAGE_COLORS[t.stage || ""] || "#94a3b8";
      const start = t.startDate || fallback;
      const end = t.endDate || addDays(start, 14);
      return {
        id: t.id,
        title: t.title || t.name || t.id,
        name: hrs > 0 ? logged > 0 ? hrs + "h (" + pct + "%)" : hrs + "h" : "",
        hoursLabel: hLabel,
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
      return {
        id: t.id,
        title: t.title,
        name: t.name + (count > 0 ? " · " + count + " items" : ""),
        hoursLabel: t.hoursLabel,
        startDate: allS.length ? allS[0] : t.startDate,
        endDate: allE.length ? allE[allE.length - 1] : t.endDate,
        progress: t.progress,
        status: t.status,
        // Darken the root bucket's bar color — all parent bars share the same hue family
        color: darkenColor(parentBaseColor, 0.25),
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
      const targetBucket = getGroupAtY(clientY) || dragSourceGroup || "";
      return { parentId, depth: desiredDepth, targetBucket, targetSortOrder: targetSort, insertBeforeRow: rowBelow };
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
        if (tb) {
          if (ip.insertBeforeRow && ip.insertBeforeRow !== spacer) tb.insertBefore(spacer, ip.insertBeforeRow);
          else if (!ip.insertBeforeRow) tb.appendChild(spacer);
        }
        const indent = INDENT_BASE + ip.depth * LEAF_STEP;
        const lbl = spacer.querySelector("td span");
        if (lbl) lbl.style.paddingLeft = indent + 8 + "px";
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
    hideCompletedToggle: true
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
    chain.forEach((tpl) => {
      const d = tpl.defaults || {};
      if (d.features) features = { ...features, ...d.features };
      if (d.theme) theme = { ...theme, ...d.theme };
      if (d.buckets) buckets = d.buckets;
      if (d.filters) filters = d.filters;
      if (d.views) views = d.views;
      if (d.title !== void 0) title = d.title;
      if (d.version !== void 0) version = d.version;
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
    pendingPatchCount: 0
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
  const CLOUD_NIMBUS_VIEWS = ["gantt"];
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
  const CLS_TITLEBAR = "nga-titlebar bg-white border-b border-slate-200 px-3 py-1.5 flex items-center gap-2 flex-wrap min-w-0 overflow-x-hidden";
  const CLS_TITLE_BRAND = "text-sm font-bold text-slate-900";
  const CLS_VERSION_PILL = "text-[9px] font-bold text-violet-600 bg-violet-50 border border-violet-200 rounded-full px-2 py-0.5";
  const CLS_SEP = "text-slate-200";
  const CLS_TB_FILL = "flex-1";
  const CLS_TB_SUMMARY = "text-[10px] text-slate-500 font-mono";
  const CLS_PILL_BTN_BASE = "text-[10px] font-semibold px-2 py-1 rounded-full border transition-colors";
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
  function el$1(tag, className, styleText) {
    const e = document.createElement(tag);
    if (className) e.className = className;
    return e;
  }
  function clear(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
  }
  const ZOOMS$2 = ["day", "week", "month", "quarter"];
  const GROUPS = ["priority", "epic"];
  const CLS_GROUP_BOTH = "bg-indigo-600 text-white border-indigo-600";
  const CLS_GROUP_GANTT = "bg-indigo-100 text-indigo-700 border-indigo-400";
  const CLS_GROUP_SIDE = "bg-blue-100 text-blue-700 border-blue-400";
  const CLS_GROUP_NEITHER = "bg-white text-slate-500 border-slate-200 hover:border-indigo-300";
  const CLS_RIGHT_UNPIN_ON = "bg-amber-500 text-white border-amber-500";
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
    let adminOn = false;
    let advisorOn = false;
    let unpinOn = false;
    function render(p) {
      clear(root);
      const { config, state, dispatch, data } = p;
      const brand = el$1("span", CLS_TITLE_BRAND);
      brand.textContent = config.title || "Pro Forma Timeline";
      root.appendChild(brand);
      const version = el$1("span", CLS_VERSION_PILL);
      version.textContent = config.version || "v10 · Nimbus Gantt";
      root.appendChild(version);
      root.appendChild(mkSep$1());
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
          root.appendChild(btn);
        });
        root.appendChild(mkSep$1());
      }
      function toggleBtn(label, on, ev) {
        const cls = CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_BLUE : CLS_PILL_BTN_IDLE_BLUE);
        const b = el$1("button", cls);
        b.textContent = label;
        b.addEventListener("click", ev);
        return b;
      }
      root.appendChild(toggleBtn("Sidebar", state.sidebarOpen, () => dispatch({ type: "TOGGLE_SIDEBAR" })));
      root.appendChild(toggleBtn("Stats", state.statsOpen, () => dispatch({ type: "TOGGLE_STATS" })));
      if (config.features.auditPanel) {
        root.appendChild(toggleBtn("Audit", state.auditPanelOpen, () => dispatch({ type: "TOGGLE_AUDIT_PANEL" })));
      }
      root.appendChild(mkSep$1());
      ZOOMS$2.forEach((z) => {
        const on = state.zoom === z;
        const cls = CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_SLATE : CLS_PILL_BTN_IDLE_SLATE);
        const b = el$1("button", cls);
        b.textContent = z.charAt(0).toUpperCase() + z.slice(1);
        b.addEventListener("click", () => dispatch({ type: "SET_ZOOM", zoom: z }));
        root.appendChild(b);
      });
      if (config.features.groupByToggle) {
        root.appendChild(mkSep$1());
        const gLbl = el$1("span", CLS_GROUP_LABEL);
        gLbl.textContent = "Group:";
        gLbl.title = "Left-click = Gantt · Right-click = Sidebar";
        root.appendChild(gLbl);
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
          root.appendChild(b);
        });
      }
      const fill = el$1("div", CLS_TB_FILL);
      root.appendChild(fill);
      const hoursHigh = data.stats.est;
      const hoursLow = data.stats.estLow || data.stats.est;
      const totalCap = CLOUD_NIMBUS_POOL.reduce((s, m) => s + (m.active !== false ? m.hoursPerMonth : 0), 0);
      const mLow = monthsToComplete(hoursLow, totalCap);
      const mHigh = monthsToComplete(hoursHigh, totalCap);
      const mLowS = isFinite(mLow) ? mLow.toFixed(1) : "∞";
      const mHighS = isFinite(mHigh) ? mHigh.toFixed(1) : "∞";
      const summary = el$1("span", CLS_TB_SUMMARY);
      summary.textContent = data.stats.scheduled + " scheduled · " + hoursLow + "–" + hoursHigh + "h · " + mLowS + "–" + mHighS + " mo";
      root.appendChild(summary);
      const unpinBtn = el$1(
        "button",
        CLS_PILL_BTN_BASE + " " + (unpinOn ? CLS_RIGHT_UNPIN_ON : CLS_RIGHT_UNPIN_OFF)
      );
      unpinBtn.textContent = unpinOn ? "Pin" : "Unpin";
      unpinBtn.title = unpinOn ? "Pin toolbar" : "Unpin toolbar";
      unpinBtn.addEventListener("click", () => {
        unpinOn = !unpinOn;
        console.log("[TitleBar] unpin toggled →", unpinOn);
        render(currentProps);
      });
      root.appendChild(unpinBtn);
      const hostExit = config.mode === "fullscreen" && typeof config.onExitFullscreen === "function";
      const fsBtn = el$1(
        "button",
        CLS_PILL_BTN_BASE + " " + (state.fullscreen || hostExit ? CLS_RIGHT_FS_ON : CLS_RIGHT_FS_OFF)
      );
      if (hostExit) {
        fsBtn.textContent = "← Exit Full Screen";
        fsBtn.setAttribute("data-nga-fullscreen-exit", "1");
        fsBtn.addEventListener("click", () => {
          config.onExitFullscreen();
        });
      } else {
        fsBtn.textContent = state.fullscreen ? "Exit Fullscreen" : "Fullscreen";
        fsBtn.addEventListener("click", () => dispatch({ type: "TOGGLE_FULLSCREEN" }));
      }
      root.appendChild(fsBtn);
      const adminBtn = el$1(
        "button",
        CLS_PILL_BTN_BASE + " " + (adminOn ? CLS_RIGHT_ADMIN_ON : CLS_RIGHT_ADMIN_OFF)
      );
      adminBtn.textContent = "Admin";
      adminBtn.title = "Advanced feature toggles";
      adminBtn.addEventListener("click", () => {
        adminOn = !adminOn;
        console.log("[TitleBar] admin toggled →", adminOn);
        render(currentProps);
      });
      root.appendChild(adminBtn);
      const advisorBtn = el$1(
        "button",
        CLS_PILL_BTN_BASE + " " + (advisorOn ? CLS_RIGHT_ADVISOR_ON : CLS_RIGHT_ADVISOR_OFF)
      );
      advisorBtn.textContent = "Advisor";
      advisorBtn.title = "Scope advisor — local analysis, no API needed";
      advisorBtn.addEventListener("click", () => {
        advisorOn = !advisorOn;
        console.log("[TitleBar] advisor toggled →", advisorOn);
        render(currentProps);
      });
      root.appendChild(advisorBtn);
      const v3 = el$1("a", CLS_V3_LINK);
      v3.href = "#";
      v3.textContent = "v3 (Canvas)";
      root.appendChild(v3);
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
      const idSp = el$1("span", "text-[10px] font-mono font-bold text-slate-500 flex-shrink-0");
      idSp.textContent = String(task.id);
      lwrap.appendChild(idSp);
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
    let inputEl = null;
    function render(p) {
      clear(root);
      inputEl = null;
      root.style.display = p.state.auditPanelOpen ? "" : "none";
      if (!p.state.auditPanelOpen) return;
      const dirty = p.state.pendingPatchCount > 0;
      const inner = el$1("div", "flex flex-wrap items-center gap-2");
      const lbl = el$1("span", CLS_AUDIT_LABEL);
      lbl.textContent = "📤 Audit pass";
      inner.appendChild(lbl);
      const stat = el$1("span", dirty ? CLS_AUDIT_STATUS_DIRTY : CLS_AUDIT_STATUS_CLEAN);
      stat.textContent = dirty ? "unsaved changes" : "clean";
      inner.appendChild(stat);
      const submitBtn = el$1("button", CLS_AUDIT_SUBMIT);
      const input = el$1("input", CLS_AUDIT_INPUT);
      input.type = "text";
      input.placeholder = "commit note (optional)";
      input.value = note;
      input.setAttribute("data-testid", "audit-note-input");
      input.addEventListener("input", (e) => {
        note = e.target.value;
        submitBtn.disabled = note.length === 0 && !dirty;
      });
      inputEl = input;
      inner.appendChild(input);
      submitBtn.type = "button";
      submitBtn.textContent = "📤 Submit + commit";
      submitBtn.setAttribute("data-testid", "audit-submit-btn");
      submitBtn.disabled = note.length === 0 && !dirty;
      submitBtn.addEventListener("click", () => {
        p.dispatch({ type: "RESET_PATCHES" });
        note = "";
        if (inputEl) inputEl.value = "";
        submitBtn.disabled = true;
      });
      inner.appendChild(submitBtn);
      const rst = el$1("button", CLS_AUDIT_RESET);
      rst.type = "button";
      rst.textContent = "↺ Reset";
      rst.setAttribute("data-testid", "audit-reset-btn");
      rst.addEventListener("click", () => {
        note = "";
        if (inputEl) inputEl.value = "";
        p.dispatch({ type: "RESET_PATCHES" });
      });
      inner.appendChild(rst);
      root.appendChild(inner);
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
  const GANTT_COLS = [
    { field: "title", header: "", width: 210, tree: true },
    { field: "hoursLabel", header: "", width: 85, align: "right" }
  ];
  const INITIAL_VIEWPORT_OFFSET_MS = 14 * 24 * 60 * 60 * 1e3;
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
      ".ng-expand-icon{font-size:9px!important;opacity:.5!important;color:#6b7280!important;width:14px!important;min-width:14px!important}",
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
      '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 88px"]{padding-left:38px!important}'
    ].join("");
    document.head.appendChild(s);
  }
  function el(tag, css) {
    const e = document.createElement(tag);
    if (css) e.style.cssText = css;
    return e;
  }
  function renderList(container, tasks, buckets) {
    container.innerHTML = "";
    const wrap = el("div", "height:100%;overflow:auto;font-family:sans-serif;font-size:12px");
    const byGroup = {};
    tasks.forEach((t) => {
      if (t.parentId) return;
      if (t.groupId) {
        if (!byGroup[t.groupId]) byGroup[t.groupId] = [];
        byGroup[t.groupId].push(t);
      }
    });
    buckets.forEach((b) => {
      const members = byGroup[b.id] || [];
      if (!members.length) return;
      const hdr = el("div", "background:" + b.bgTint + ";color:#fff;font-weight:700;font-size:11px;padding:7px 14px;text-transform:uppercase;position:sticky;top:0;z-index:1");
      hdr.textContent = b.label + " — " + members.length + " items";
      wrap.appendChild(hdr);
      members.forEach((t) => {
        const row = el("div", "display:flex;align-items:center;padding:5px 14px;gap:8px;border-bottom:1px solid #f3f4f6");
        const dot = el("span", "width:7px;height:7px;border-radius:50%;background:" + (STAGE_COLORS[t.status] || "#94a3b8"));
        row.appendChild(dot);
        const title = el("span", "flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:12px;color:#1f2937");
        title.textContent = t.title;
        row.appendChild(title);
        if (t.hoursLabel) {
          const h = el("span", "font-size:10px;color:#94a3b8;font-family:monospace");
          h.textContent = t.hoursLabel;
          row.appendChild(h);
        }
        wrap.appendChild(row);
      });
    });
    container.appendChild(wrap);
  }
  function renderTreemap(container, tasks, buckets) {
    container.innerHTML = "";
    const wrap = el("div", "height:100%;overflow:auto;padding:8px;font-family:sans-serif;background:#f8fafc");
    const leaves = tasks.filter((t) => {
      var _a;
      return !t.isParent && (((_a = t.metadata) == null ? void 0 : _a.hoursHigh) || 0) > 0;
    });
    const total = leaves.reduce((s, t) => {
      var _a;
      return s + (((_a = t.metadata) == null ? void 0 : _a.hoursHigh) || 0);
    }, 0);
    if (!total) {
      wrap.textContent = "No hours to show";
      container.appendChild(wrap);
      return;
    }
    const grouped = {};
    leaves.forEach((t) => {
      const g = t.groupId || "other";
      (grouped[g] = grouped[g] || []).push(t);
    });
    buckets.forEach((b) => {
      const members = grouped[b.id] || [];
      if (!members.length) return;
      const sec = el("div", "margin-bottom:8px");
      const hdr = el("div", "font-size:10px;font-weight:700;color:#fff;padding:3px 8px;border-radius:4px;display:inline-block;margin-bottom:3px;background:" + b.bgTint);
      hdr.textContent = b.label;
      sec.appendChild(hdr);
      const row = el("div", "display:flex;flex-wrap:wrap;gap:3px");
      members.forEach((t) => {
        var _a;
        const tile = el("div", "background:" + (t.color || "#94a3b8") + "44;border:1px solid " + (t.color || "#94a3b8") + ";padding:4px 6px;border-radius:4px;font-size:10px");
        tile.textContent = t.title.slice(0, 20) + " " + (((_a = t.metadata) == null ? void 0 : _a.hoursHigh) || 0) + "h";
        row.appendChild(tile);
      });
      sec.appendChild(row);
      wrap.appendChild(sec);
    });
    container.appendChild(wrap);
  }
  function renderBubbles(container, tasks) {
    container.innerHTML = "";
    const leaves = tasks.filter((t) => {
      var _a;
      return !t.isParent && (((_a = t.metadata) == null ? void 0 : _a.hoursHigh) || 0) > 0;
    });
    const wrap = el("div", "height:100%;overflow:auto;padding:10px;font-family:sans-serif;background:#f8fafc");
    if (!leaves.length) {
      wrap.textContent = "No tasks";
      container.appendChild(wrap);
      return;
    }
    const maxH = Math.max(1, ...leaves.map((t) => {
      var _a;
      return ((_a = t.metadata) == null ? void 0 : _a.hoursHigh) || 0;
    }));
    leaves.forEach((t) => {
      var _a;
      const r = Math.max(20, Math.sqrt((((_a = t.metadata) == null ? void 0 : _a.hoursHigh) || 0) / maxH) * 60);
      const bub = el("div", "display:inline-block;width:" + r * 2 + "px;height:" + r * 2 + "px;border-radius:50%;background:" + (t.color || "#94a3b8") + "55;border:1.5px solid " + (t.color || "#94a3b8") + ";margin:4px;text-align:center;line-height:" + r * 2 + "px;font-size:10px;color:#1f2937");
      bub.textContent = t.title.slice(0, 8);
      wrap.appendChild(bub);
    });
    container.appendChild(wrap);
  }
  function renderCalendar(container, tasks) {
    container.innerHTML = "";
    const wrap = el("div", "height:100%;overflow:auto;padding:10px;font-family:sans-serif");
    const today = /* @__PURE__ */ new Date();
    const monday = new Date(today);
    const dow = today.getDay();
    monday.setDate(today.getDate() - (dow === 0 ? 6 : dow - 1));
    monday.setHours(0, 0, 0, 0);
    const WEEK_MS2 = 7 * 864e5;
    for (let i = 0; i < 8; i++) {
      const wkStart = new Date(monday.getTime() + i * WEEK_MS2);
      const wkEnd = new Date(wkStart.getTime() + WEEK_MS2);
      const wkTasks = tasks.filter((t) => {
        if (!t.startDate || !t.endDate) return false;
        const tS = (/* @__PURE__ */ new Date(t.startDate + "T00:00:00")).getTime();
        const tE = (/* @__PURE__ */ new Date(t.endDate + "T00:00:00")).getTime();
        return tE > wkStart.getTime() && tS < wkEnd.getTime();
      });
      const row = el("div", "display:flex;gap:4px;padding:6px;border-bottom:1px solid #e5e7eb");
      const lbl = el("div", "width:80px;font-size:10px;color:#64748b");
      lbl.textContent = wkStart.toISOString().slice(0, 10);
      row.appendChild(lbl);
      const cnt = el("div", "flex:1;font-size:10px;color:#1f2937");
      cnt.textContent = wkTasks.length + " task" + (wkTasks.length === 1 ? "" : "s");
      row.appendChild(cnt);
      wrap.appendChild(row);
    }
    container.appendChild(wrap);
  }
  function renderFlow(container, tasks) {
    container.innerHTML = "";
    const wrap = el("div", "height:100%;overflow-x:auto;display:flex;gap:8px;padding:8px;background:#f8fafc;font-family:sans-serif");
    const cols = [
      { label: "Backlog", color: "#f59e0b", match: (c) => c === "#f59e0b" },
      { label: "Next Up", color: "#3b82f6", match: (c) => c === "#3b82f6" },
      { label: "In Flight", color: "#10b981", match: (c) => c === "#10b981" },
      { label: "Blocked", color: "#ef4444", match: (c) => c === "#ef4444" },
      { label: "Done", color: "#cbd5e1", match: (c) => c === "#cbd5e1" }
    ];
    const leaves = tasks.filter((t) => !t.isParent);
    cols.forEach((c) => {
      const colEl = el("div", "width:200px;flex-shrink:0");
      const hdr = el("div", "background:" + c.color + "22;color:" + c.color + ";padding:5px 8px;font-size:11px;font-weight:700;border-radius:4px 4px 0 0");
      hdr.textContent = c.label;
      colEl.appendChild(hdr);
      const inner = el("div", "border:1px solid " + c.color + "55;border-radius:0 0 4px 4px;padding:4px");
      leaves.filter((t) => c.match(t.color || "")).forEach((t) => {
        const card = el("div", "background:#fff;border-left:3px solid " + (t.color || "#94a3b8") + ";padding:5px 8px;margin-bottom:3px;font-size:10px;border-radius:4px");
        card.textContent = t.title;
        inner.appendChild(card);
      });
      colEl.appendChild(inner);
      wrap.appendChild(colEl);
    });
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
      var _a, _b, _c, _d, _e;
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
          columns: GANTT_COLS,
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
            var _a2;
            if (!task || !task.id || isBucketId(task.id)) return;
            const t = findTaskById(task.id);
            if (t) (_a2 = options.onTaskClick) == null ? void 0 : _a2.call(options, t, "canvas");
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
          var _a2, _b2, _c2, _d2;
          try {
            const gi = inst;
            const x = (_b2 = (_a2 = gi.timeScale) == null ? void 0 : _a2.dateToX) == null ? void 0 : _b2.call(_a2, new Date(Date.now() - INITIAL_VIEWPORT_OFFSET_MS));
            if (typeof x === "number") (_d2 = (_c2 = gi.scrollManager) == null ? void 0 : _c2.scrollToX) == null ? void 0 : _d2.call(_c2, Math.max(0, x));
          } catch (_e2) {
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
          destroy() {
            IIFEApp.unmount(container);
          }
        };
      }
      let state = { ...INITIAL_STATE };
      let allTasks = options.tasks || [];
      const patchLog = [];
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
        dispatch({ type: "PATCH", patch });
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
          renderSlots();
          if (ev.type === "SET_VIEW" || ev.type === "SET_GROUP_BY" || ev.type === "SET_FILTER" || ev.type === "SET_SEARCH" || ev.type === "TOGGLE_HIDE_COMPLETED") {
            rebuildView();
          } else if (ev.type === "SET_ZOOM") {
            if (ganttInst && typeof ganttInst.setZoom === "function") ganttInst.setZoom(state.zoom);
          }
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
        const contentInst = slotInstances.get("ContentArea");
        if (contentInst) {
          ganttHost = contentInst.el.querySelector('[data-nga-gantt-host="1"]');
        }
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
          columns: GANTT_COLS,
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
            var _a3;
            if (!task || !task.id || isBucketId(task.id)) return;
            dispatch({ type: "TOGGLE_DETAIL", taskId: task.id });
            const t = allTasks.find((x) => x.id === task.id);
            if (t) (_a3 = options.onTaskClick) == null ? void 0 : _a3.call(options, t, "canvas");
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
            if (task && task.id && !isBucketId(task.id)) onTaskPatch({ id: task.id, startDate: s, endDate: e });
          },
          onTaskResize: (task, s, e) => {
            if (task && task.id && !isBucketId(task.id)) onTaskPatch({ id: task.id, startDate: s, endDate: e });
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
          ganttInst.use(PGP({
            buckets: pluginBuckets,
            getBucket: (task) => task.groupId || null,
            getBucketProgress: typeof hwp === "function" ? hwp : void 0
          }));
        }
        ganttInst.setData(gtasks, []);
        try {
          ganttInst.expandAll();
        } catch (_e2) {
        }
        setTimeout(() => {
          var _a3, _b2, _c2, _d2;
          try {
            const gi = ganttInst;
            const x = (_b2 = (_a3 = gi.timeScale) == null ? void 0 : _a3.dateToX) == null ? void 0 : _b2.call(_a3, new Date(Date.now() - INITIAL_VIEWPORT_OFFSET_MS));
            if (typeof x === "number") (_d2 = (_c2 = gi.scrollManager) == null ? void 0 : _c2.scrollToX) == null ? void 0 : _d2.call(_c2, Math.max(0, x));
          } catch (_e2) {
          }
        }, 50);
        if (cleanupShading) cleanupShading();
        if (cleanupDrag) cleanupDrag();
        if (tplConfig.features.depthShading) cleanupShading = startDepthShading(ganttEl, depthMap);
        if (tplConfig.features.dragReparent) cleanupDrag = startDragReparent(ganttEl, allTasks, depthMap, onTaskPatch);
      }
      function refreshGantt() {
        if (!ganttHost) return;
        if (state.viewMode === "gantt" && ganttInst) {
          const filtered = applyFilter(allTasks, state.filter, state.search);
          const maybeHide = state.hideCompleted ? filtered.filter((t) => !DONE_STAGES[t.stage || ""]) : filtered;
          const gtasks = state.groupBy === "epic" ? buildTasks(buildTasksEpic(maybeHide)) : buildTasks(maybeHide);
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
        const filtered = applyFilter(allTasks, state.filter, state.search);
        const maybeHide = state.hideCompleted ? filtered.filter((t) => !DONE_STAGES[t.stage || ""]) : filtered;
        const mapped = buildTasks(maybeHide);
        if (state.viewMode === "gantt") initGantt(ganttHost);
        else if (state.viewMode === "flow") renderFlow(ganttHost, mapped);
        else if (state.viewMode === "calendar") renderCalendar(ganttHost, mapped);
        else if (state.viewMode === "treemap") renderTreemap(ganttHost, mapped, tplConfig.buckets);
        else if (state.viewMode === "bubbles") renderBubbles(ganttHost, mapped);
        else renderList(ganttHost, mapped, tplConfig.buckets);
        renderSlots();
      }
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
