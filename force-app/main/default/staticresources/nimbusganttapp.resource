var NimbusGanttApp = function(exports) {
  "use strict";
  const DEFAULT_PRIORITY_BUCKETS = [
    { id: "top-priority", label: "NOW", color: "#dc2626", bgTint: "#ef4444", order: 0 },
    { id: "active", label: "NEXT", color: "#d97706", bgTint: "#f59e0b", order: 1 },
    { id: "follow-on", label: "PLANNED", color: "#059669", bgTint: "#10b981", order: 2 },
    { id: "proposed", label: "PROPOSED", color: "#2563eb", bgTint: "#3b82f6", order: 3 },
    { id: "deferred", label: "HOLD", color: "#94a3b8", bgTint: "#94a3b8", order: 4 }
  ];
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
    const mapped = tasks.map((t) => {
      const hrs = t.estimatedHours ? Math.round(Number(t.estimatedHours)) : 0;
      const logged = t.loggedHours ? Number(t.loggedHours) : 0;
      const pct = hrs > 0 ? Math.round(logged / hrs * 100) : 0;
      const hLabel = hrs > 0 ? logged > 0 ? hrs + "h (" + pct + "%)" : hrs + "h" : "";
      const gid = t.parentWorkItemId ? null : t.priorityGroup || null;
      const col = gid ? GROUP_BAR[gid] || "#94a3b8" : STAGE_COLORS[t.stage || ""] || "#94a3b8";
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
      return {
        id: t.id,
        title: t.title,
        name: t.name + (count > 0 ? " · " + count + " items" : ""),
        hoursLabel: t.hoursLabel,
        startDate: allS.length ? allS[0] : t.startDate,
        endDate: allE.length ? allE[allE.length - 1] : t.endDate,
        progress: t.progress,
        status: t.status,
        color: darkenColor(t.color || "#64748b", 0.2),
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
  const PROPOSAL_STAGES = {
    "Backlog": true,
    "Scoping In Progress": true,
    "Ready for Sizing": true,
    "Ready for Development": true
  };
  function applyFilter(tasks, filter, q) {
    let r = tasks;
    if (filter === "active") {
      r = r.filter((t) => !DONE_STAGES[t.stage || ""] && !t.isInactive);
    } else if (filter === "proposal") {
      r = r.filter((t) => PROPOSAL_STAGES[t.stage || ""] || t.priorityGroup === "proposed");
    } else if (filter === "done") {
      r = r.filter((t) => !!DONE_STAGES[t.stage || ""]);
    } else if (filter === "workstreams") {
      r = r.filter((t) => !!(t.id && t.id.indexOf("WS-") === 0));
    }
    if (q) {
      const ql = q.toLowerCase();
      r = r.filter((t) => t.title && t.title.toLowerCase().indexOf(ql) !== -1);
    }
    return r;
  }
  function computeStats(tasks) {
    const active = tasks.filter((t) => !t.isInactive);
    const est = active.reduce((s, t) => s + (Number(t.estimatedHours) || 0), 0);
    const logged = active.reduce((s, t) => s + (Number(t.loggedHours) || 0), 0);
    const sched = active.filter((t) => t.startDate && t.endDate).length;
    const counts = {
      "top-priority": 0,
      "active": 0,
      "follow-on": 0,
      "proposed": 0,
      "deferred": 0
    };
    active.forEach((t) => {
      if (t.priorityGroup && Object.prototype.hasOwnProperty.call(counts, t.priorityGroup)) {
        counts[t.priorityGroup]++;
      }
    });
    return { total: active.length, scheduled: sched, est: Math.round(est), logged: Math.round(logged * 10) / 10, counts };
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
      const targetSort = (sortAbove + sortBelow) / 2;
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
      const grp = getGroup(taskId);
      if (!grp) return;
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
      if (!savedId || !savedGroup) return;
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
    fontFamily: "sans-serif",
    fontSize: 12,
    selectionColor: "#3b82f6",
    singleRowHeader: true
  };
  const GANTT_COLS = [
    { field: "title", header: "", width: 210, tree: true },
    { field: "hoursLabel", header: "", width: 85, align: "right" }
  ];
  function injectStyles() {
    if (document.getElementById("nga-v5-css")) return;
    const s = document.createElement("style");
    s.id = "nga-v5-css";
    s.textContent = [
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
    const noGroup = [];
    const childMap = {};
    tasks.forEach((t) => {
      if (t.parentId) {
        if (!childMap[t.parentId]) childMap[t.parentId] = [];
        childMap[t.parentId].push(t);
      }
    });
    tasks.forEach((t) => {
      if (t.parentId) return;
      if (t.groupId) {
        if (!byGroup[t.groupId]) byGroup[t.groupId] = [];
        byGroup[t.groupId].push(t);
      } else {
        noGroup.push(t);
      }
    });
    buckets.forEach((b) => {
      const members = byGroup[b.id] || [];
      if (!members.length) return;
      const hdr = el("div", "background:" + b.bgTint + ";color:#fff;font-weight:700;font-size:11px;letter-spacing:.05em;padding:7px 14px;text-transform:uppercase;position:sticky;top:0;z-index:1");
      hdr.textContent = b.label + " — " + members.length + " items";
      wrap.appendChild(hdr);
      members.forEach((t) => appendListRow(wrap, t, childMap, 0));
    });
    if (noGroup.length) {
      const hdr2 = el("div", "background:#475569;color:#fff;font-weight:700;font-size:11px;letter-spacing:.05em;padding:7px 14px;text-transform:uppercase;position:sticky;top:0;z-index:1");
      hdr2.textContent = "Ungrouped — " + noGroup.length + " items";
      wrap.appendChild(hdr2);
      noGroup.forEach((t) => appendListRow(wrap, t, childMap, 0));
    }
    container.appendChild(wrap);
  }
  function appendListRow(wrap, t, childMap, depth) {
    const row = el("div", "display:flex;align-items:center;padding:5px 14px 5px " + (14 + depth * 14) + "px;border-bottom:1px solid #f3f4f6;gap:8px");
    row.onmouseover = () => {
      row.style.background = "rgba(59,130,246,0.04)";
    };
    row.onmouseout = () => {
      row.style.background = "";
    };
    const dot = el("span", "width:7px;height:7px;border-radius:50%;background:" + (STAGE_COLORS[t.status] || "#94a3b8") + ";flex-shrink:0;display:inline-block");
    row.appendChild(dot);
    const title = el("span", "flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:12px;color:#1f2937");
    title.title = t.title;
    title.textContent = t.title;
    row.appendChild(title);
    if (t.hoursLabel) {
      const hrs = el("span", "font-size:10px;color:#94a3b8;font-family:monospace;flex-shrink:0");
      hrs.textContent = t.hoursLabel;
      row.appendChild(hrs);
    }
    const stg = el("span", "font-size:10px;color:#94a3b8;flex-shrink:0;max-width:110px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap");
    stg.textContent = t.status || "";
    row.appendChild(stg);
    wrap.appendChild(row);
    (childMap[t.id] || []).forEach((c) => appendListRow(wrap, c, childMap, depth + 1));
  }
  const registry = [];
  function getEntry(c) {
    return registry.find((e) => e.container === c) || null;
  }
  function removeEntry(c) {
    const idx = registry.findIndex((e) => e.container === c);
    if (idx !== -1) registry.splice(idx, 1);
  }
  class IIFEApp {
    static mount(container, options) {
      var _a, _b, _c, _d;
      IIFEApp.unmount(container);
      const buckets = ((_a = options.config) == null ? void 0 : _a.buckets) || DEFAULT_PRIORITY_BUCKETS;
      const appTitle = ((_b = options.config) == null ? void 0 : _b.title) || "Pro Forma Timeline";
      const appVersion = ((_c = options.config) == null ? void 0 : _c.version) || "v5 · Nimbus Gantt";
      const features = ((_d = options.config) == null ? void 0 : _d.features) || {};
      let allTasks = options.tasks || [];
      const onPatch = options.onPatch || (() => {
      });
      let viewMode = "gantt";
      let filter = "active";
      let searchQ = "";
      let zoomLevel = "week";
      let groupBy = "priority";
      let ganttInst = null;
      let depthMap = buildDepthMap(allTasks);
      let cleanupShading = null;
      let cleanupDrag = null;
      injectStyles();
      container.style.cssText = "height:100%;display:flex;flex-direction:column;font-family:sans-serif;background:#f8fafc;overflow:hidden";
      const titleBar = el("div", "background:#fff;border-bottom:1px solid #e2e8f0;padding:0 12px;display:flex;align-items:center;gap:2px;flex-shrink:0;min-height:36px;flex-wrap:wrap");
      const titleTxt = el("span", "font-size:14px;font-weight:700;color:#0f172a;margin-right:8px;white-space:nowrap");
      titleTxt.textContent = appTitle;
      titleBar.appendChild(titleTxt);
      const badge = el("span", "font-size:9px;font-weight:700;color:#7c3aed;background:#f5f3ff;border:1px solid #ede9fe;border-radius:9999px;padding:2px 8px;margin-right:8px;white-space:nowrap");
      badge.textContent = appVersion;
      titleBar.appendChild(badge);
      function lsep() {
        const s = el("span", "color:#e2e8f0;font-size:14px;margin:0 6px;flex-shrink:0;user-select:none");
        s.textContent = "|";
        return s;
      }
      const viewDefs = [
        { id: "gantt", icon: "▤", label: "Gantt" },
        { id: "list", icon: "☰", label: "List" },
        { id: "treemap", icon: "▦", label: "Treemap" },
        { id: "bubbles", icon: "◉", label: "Bubbles" },
        { id: "calendar", icon: "▥", label: "Calendar" },
        { id: "flow", icon: "⟿", label: "Flow" }
      ];
      const viewBtns = [];
      titleBar.appendChild(lsep());
      viewDefs.forEach((v) => {
        const isActive = v.id === viewMode;
        const btn = el("button", [
          "cursor:pointer;padding:4px 8px;font-size:10px;font-weight:600;",
          "border-radius:9999px;border:1px solid;display:flex;align-items:center;gap:4px;white-space:nowrap;line-height:1.4;",
          isActive ? "background:#7c3aed;color:#fff;border-color:#7c3aed;" : "background:#fff;color:#64748b;border-color:#e2e8f0;"
        ].join(""));
        btn.innerHTML = "<span>" + v.icon + "</span><span>" + v.label + "</span>";
        btn.addEventListener("click", () => {
          viewMode = v.id;
          viewBtns.forEach((b) => {
            const a = b.id === viewMode;
            b.btn.style.background = a ? "#7c3aed" : "#fff";
            b.btn.style.color = a ? "#fff" : "#64748b";
            b.btn.style.borderColor = a ? "#7c3aed" : "#e2e8f0";
          });
          rebuildView();
        });
        viewBtns.push({ id: v.id, btn });
        titleBar.appendChild(btn);
      });
      titleBar.appendChild(lsep());
      let showKpis = false;
      const kpiBtn = el("button", "background:#fff;border:1px solid #e2e8f0;cursor:pointer;padding:4px 8px;font-size:10px;border-radius:9999px;color:#64748b;font-weight:600;white-space:nowrap");
      kpiBtn.textContent = "Stats";
      kpiBtn.addEventListener("click", () => {
        showKpis = !showKpis;
        kpiPanel.style.display = showKpis ? "flex" : "none";
        kpiBtn.style.background = showKpis ? "#2563eb" : "#fff";
        kpiBtn.style.borderColor = showKpis ? "#2563eb" : "#e2e8f0";
        kpiBtn.style.color = showKpis ? "#fff" : "#64748b";
      });
      if (features.statsPanel !== false) titleBar.appendChild(kpiBtn);
      function makeToggleBtn(label, onToggle) {
        let on = false;
        const btn = el("button", "background:#fff;border:1px solid #e2e8f0;cursor:pointer;padding:4px 8px;font-size:10px;border-radius:9999px;color:#64748b;font-weight:600;white-space:nowrap");
        btn.textContent = label;
        btn.addEventListener("click", () => {
          on = !on;
          btn.style.background = on ? "#2563eb" : "#fff";
          btn.style.borderColor = on ? "#2563eb" : "#e2e8f0";
          btn.style.color = on ? "#fff" : "#64748b";
          onToggle(on);
        });
        return btn;
      }
      const sidebarBtn = makeToggleBtn("Sidebar", (on) => {
        sidebarPanel.style.width = on ? "260px" : "0";
      });
      titleBar.appendChild(sidebarBtn);
      const auditBtn = makeToggleBtn("Audit", (on) => {
        auditPanel.style.width = on ? "280px" : "0";
      });
      titleBar.appendChild(auditBtn);
      const titleSpacer = el("div");
      titleSpacer.style.flex = "1";
      titleBar.appendChild(titleSpacer);
      const statsLabel = el("span", "font-size:11px;color:#94a3b8;white-space:nowrap");
      titleBar.appendChild(statsLabel);
      container.appendChild(titleBar);
      const kpiPanel = el("div", "display:none;background:#fff;border-bottom:1px solid #e5e7eb;padding:10px 14px;gap:12px;flex-wrap:wrap;flex-shrink:0");
      const kpiDefs = [
        { id: "total", label: "Items", tone: "#64748b" },
        { id: "sched", label: "Scheduled", tone: "#059669" },
        { id: "est", label: "Est Hours", tone: "#2563eb" },
        { id: "logged", label: "Logged", tone: "#7c3aed" },
        { id: "months", label: "Months @ 120h", tone: "#d97706" }
      ];
      const kpiEls = {};
      kpiDefs.forEach((k) => {
        const card = el("div", "background:#f8fafc;border:1.5px solid #e5e7eb;border-radius:8px;padding:8px 14px;min-width:90px;display:flex;flex-direction:column;gap:2px");
        const lbl = el("span", "font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:" + k.tone + ";opacity:.7");
        lbl.textContent = k.label;
        const val = el("span", "font-size:20px;font-weight:700;font-family:monospace;color:" + k.tone);
        val.textContent = "—";
        card.appendChild(lbl);
        card.appendChild(val);
        kpiEls[k.id] = val;
        kpiPanel.appendChild(card);
      });
      container.appendChild(kpiPanel);
      const filterBar = el("div", "background:#fff;border-bottom:1px solid #e5e7eb;padding:5px 14px;display:flex;align-items:center;gap:10px;flex-shrink:0;flex-wrap:wrap");
      const fLabel = el("span", "font-size:11px;color:#64748b;white-space:nowrap");
      fLabel.textContent = "View:";
      filterBar.appendChild(fLabel);
      const filterOpts = [
        { id: "active", label: "Active" },
        { id: "proposal", label: "Proposal & Expansion" },
        { id: "done", label: "Done" },
        { id: "workstreams", label: "Workstreams" },
        { id: "all", label: "Everything" }
      ];
      const filterStylers = [];
      filterOpts.forEach((f) => {
        const btn = el("button", "");
        btn.textContent = f.label;
        function styleBtn() {
          const on = f.id === filter;
          btn.style.cssText = "padding:2px 9px;font-size:11px;border-radius:10px;cursor:pointer;border:1px solid " + (on ? "#3b82f6" : "#e5e7eb") + ";background:" + (on ? "#eff6ff" : "#fff") + ";color:" + (on ? "#2563eb" : "#374151") + ";font-weight:" + (on ? "600" : "400");
        }
        styleBtn();
        btn.addEventListener("click", () => {
          filter = f.id;
          filterStylers.forEach((fn) => fn());
          refresh();
        });
        filterStylers.push(styleBtn);
        filterBar.appendChild(btn);
      });
      const fbsep = el("div", "width:1px;height:18px;background:#e5e7eb;flex-shrink:0");
      filterBar.appendChild(fbsep);
      const sw = el("div", "display:flex;align-items:center;gap:4px;border:1px solid #e5e7eb;border-radius:6px;padding:2px 8px;background:#fff");
      const si = el("span", "font-size:12px;color:#94a3b8");
      si.textContent = "🔎";
      sw.appendChild(si);
      const sinput = el("input", "border:none;outline:none;font-size:11px;color:#374151;background:transparent;width:140px");
      sinput.type = "text";
      sinput.placeholder = "Search title…";
      sinput.addEventListener("input", () => {
        searchQ = sinput.value.trim();
        refresh();
      });
      sw.appendChild(sinput);
      filterBar.appendChild(sw);
      const fbspace = el("div");
      fbspace.style.flex = "1";
      filterBar.appendChild(fbspace);
      const legWrap = el("div", "display:flex;align-items:center;gap:8px;flex-wrap:wrap");
      const legLbl = el("span", "font-size:9px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;white-space:nowrap");
      legLbl.textContent = "Colors:";
      legWrap.appendChild(legLbl);
      const legendChips = [];
      buckets.forEach((b) => {
        const chip = el("span", "display:flex;align-items:center;gap:3px;font-size:11px;color:#374151;white-space:nowrap;cursor:pointer");
        const dot = el("span", "width:9px;height:9px;border-radius:50%;background:" + b.bgTint + ";display:inline-block;flex-shrink:0");
        chip.appendChild(dot);
        const txt = el("span");
        txt.textContent = b.label;
        chip.appendChild(txt);
        legendChips.push({ bid: b.id, txt });
        legWrap.appendChild(chip);
      });
      filterBar.appendChild(legWrap);
      container.appendChild(filterBar);
      const ctrlBar = el("div", "background:#fff;border-bottom:1px solid #e5e7eb;padding:4px 14px;display:flex;align-items:center;gap:8px;flex-shrink:0");
      const zDefs = [
        { label: "Day", zoom: "day" },
        { label: "Week", zoom: "week" },
        { label: "Month", zoom: "month" },
        { label: "Quarter", zoom: "quarter" }
      ];
      const zBtns = [];
      zDefs.forEach((z) => {
        const act = z.zoom === zoomLevel;
        const btn = el("button", [
          "padding:4px 8px;font-size:10px;font-weight:600;cursor:pointer;",
          "border-radius:9999px;border:1px solid;line-height:1.4;white-space:nowrap;",
          act ? "background:#1e293b;color:#fff;border-color:#1e293b;" : "background:#fff;color:#64748b;border-color:#e2e8f0;"
        ].join(""));
        btn.textContent = z.label;
        btn.addEventListener("click", () => {
          zoomLevel = z.zoom;
          zBtns.forEach((b) => {
            const a = b.zoom === zoomLevel;
            b.el.style.background = a ? "#1e293b" : "#fff";
            b.el.style.color = a ? "#fff" : "#64748b";
            b.el.style.borderColor = a ? "#1e293b" : "#e2e8f0";
          });
          if (ganttInst && typeof ganttInst.setZoom === "function") ganttInst.setZoom(zoomLevel);
        });
        zBtns.push({ el: btn, zoom: z.zoom });
        ctrlBar.appendChild(btn);
      });
      if (features.groupByToggle !== false) {
        const gbSep = el("span", "color:#e2e8f0;font-size:14px;margin:0 6px;flex-shrink:0");
        gbSep.textContent = "|";
        ctrlBar.appendChild(gbSep);
        const gbLabel = el("span", "font-size:9px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;white-space:nowrap;margin-right:4px");
        gbLabel.textContent = "Group:";
        ctrlBar.appendChild(gbLabel);
        const gbDefs = [
          { id: "priority", label: "Priority" },
          { id: "epic", label: "Epics" }
        ];
        const gbBtns = [];
        gbDefs.forEach((g) => {
          const act = g.id === groupBy;
          const btn = el("button", [
            "padding:4px 8px;font-size:10px;font-weight:600;cursor:pointer;",
            "border-radius:9999px;border:1px solid;line-height:1.4;white-space:nowrap;margin-right:2px;",
            act ? "background:#1e293b;color:#fff;border-color:#1e293b;" : "background:#fff;color:#64748b;border-color:#e2e8f0;"
          ].join(""));
          btn.textContent = g.label;
          btn.addEventListener("click", () => {
            groupBy = g.id;
            gbBtns.forEach((b) => {
              const a = b.id === groupBy;
              b.el.style.background = a ? "#1e293b" : "#fff";
              b.el.style.color = a ? "#fff" : "#64748b";
              b.el.style.borderColor = a ? "#1e293b" : "#e2e8f0";
            });
            rebuildView();
          });
          gbBtns.push({ id: g.id, el: btn });
          ctrlBar.appendChild(btn);
        });
      }
      const cbLabel = el("label", "display:flex;align-items:center;gap:4px;font-size:11px;color:#374151;cursor:pointer;white-space:nowrap;margin-left:8px");
      const cb = el("input", "");
      cb.type = "checkbox";
      cbLabel.appendChild(cb);
      cbLabel.appendChild(document.createTextNode("Completed"));
      ctrlBar.appendChild(cbLabel);
      const ctrlSpacer = el("div");
      ctrlSpacer.style.flex = "1";
      ctrlBar.appendChild(ctrlSpacer);
      const countLbl = el("span", "font-size:11px;color:#64748b;white-space:nowrap");
      ctrlBar.appendChild(countLbl);
      container.appendChild(ctrlBar);
      const contentOuter = el("div", "flex:1 1 auto;min-height:0;display:flex;overflow:hidden");
      container.appendChild(contentOuter);
      const sidebarPanel = el("div", "width:0;flex-shrink:0;overflow:hidden;background:#f8fafc;border-right:1px solid #e5e7eb;transition:width .2s;font-size:12px");
      contentOuter.appendChild(sidebarPanel);
      const contentEl = el("div", "flex:1 1 auto;min-height:0;position:relative;overflow:hidden");
      contentOuter.appendChild(contentEl);
      const detailPanel = el("div", "width:0;flex-shrink:0;overflow:hidden;background:#fff;border-left:1px solid #e5e7eb;transition:width .2s;font-family:sans-serif;font-size:12px;position:relative");
      if (features.detailPanel !== false) contentOuter.appendChild(detailPanel);
      const auditPanel = el("div", "width:0;flex-shrink:0;overflow:hidden;background:#fff;border-left:1px solid #e5e7eb;transition:width .2s;font-size:12px");
      contentOuter.appendChild(auditPanel);
      function openDetail(taskId) {
        let raw = null;
        for (let i = 0; i < allTasks.length; i++) if (allTasks[i].id === taskId) {
          raw = allTasks[i];
          break;
        }
        if (!raw) return;
        let grpLabel = "—", grpColor = "#374151";
        buckets.forEach((b) => {
          if (b.id === raw.priorityGroup) {
            grpLabel = b.label;
            grpColor = b.bgTint;
          }
        });
        detailPanel.innerHTML = "";
        detailPanel.style.width = "240px";
        const hdr = el("div", "padding:10px 12px 6px;border-bottom:1px solid #f3f4f6;display:flex;align-items:flex-start;gap:6px");
        const ttl = el("span", "flex:1;font-weight:600;font-size:12px;color:#0f172a;line-height:1.4");
        ttl.textContent = raw.title || raw.name || raw.id;
        const cls = el("button", "background:none;border:none;cursor:pointer;font-size:16px;color:#94a3b8;padding:0;line-height:1;flex-shrink:0;margin-top:-2px");
        cls.textContent = "×";
        cls.addEventListener("click", closeDetail);
        hdr.appendChild(ttl);
        hdr.appendChild(cls);
        detailPanel.appendChild(hdr);
        const body = el("div", "padding:10px 12px;display:flex;flex-direction:column;gap:8px;overflow-y:auto;max-height:calc(100vh - 180px)");
        function row2(lbl, val, color) {
          const r = el("div", "display:flex;flex-direction:column;gap:2px");
          const l = el("span", "font-size:10px;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em");
          l.textContent = lbl;
          const v = el("span", "font-size:12px;color:" + (color || "#1f2937") + ";font-weight:500");
          v.textContent = val || "—";
          r.appendChild(l);
          r.appendChild(v);
          body.appendChild(r);
        }
        row2("Priority", grpLabel, grpColor);
        row2("Stage", raw.stage);
        row2("Start", raw.startDate);
        row2("End", raw.endDate);
        const hrs = raw.estimatedHours ? Math.round(Number(raw.estimatedHours)) : 0;
        const lgd = raw.loggedHours ? Number(raw.loggedHours) : 0;
        row2("Estimated", hrs > 0 ? hrs + "h" : "—");
        row2("Logged", lgd > 0 ? lgd + "h" : "—");
        if (raw.developerName) row2("Developer", raw.developerName);
        if (raw.entityName) row2("Entity", raw.entityName);
        detailPanel.appendChild(body);
      }
      function closeDetail() {
        detailPanel.style.width = "0";
        setTimeout(() => {
          detailPanel.innerHTML = "";
        }, 210);
      }
      function updateStats() {
        const s = computeStats(allTasks);
        const mo = (s.est / 120).toFixed(1);
        statsLabel.textContent = s.scheduled + " scheduled · " + s.est + "h · " + mo + " mo";
        legendChips.forEach((c) => {
          const b = buckets.find((bk) => bk.id === c.bid);
          c.txt.textContent = (b ? b.label : c.bid) + " (" + (s.counts[c.bid] || 0) + ")";
        });
        const vs = computeStats(applyFilter(allTasks, filter, searchQ));
        countLbl.textContent = vs.total + " items · " + vs.scheduled + " scheduled";
        if (kpiEls.total) kpiEls.total.textContent = String(s.total);
        if (kpiEls.sched) kpiEls.sched.textContent = String(s.scheduled);
        if (kpiEls.est) kpiEls.est.textContent = s.est + "h";
        if (kpiEls.logged) kpiEls.logged.textContent = s.logged + "h";
        if (kpiEls.months) kpiEls.months.textContent = mo + "mo";
      }
      function initGantt() {
        var _a2;
        let Ctor, PGP, hwp;
        if (options.engine) {
          Ctor = options.engine.NimbusGantt;
          PGP = options.engine.PriorityGroupingPlugin;
          hwp = options.engine.hoursWeightedProgress;
        } else {
          const NG = window["NimbusGantt"];
          if (!NG) {
            contentEl.style.cssText = "padding:20px;color:#b91c1c;font-size:13px";
            contentEl.textContent = "nimbus-gantt not loaded";
            return;
          }
          Ctor = NG["NimbusGantt"];
          PGP = NG["PriorityGroupingPlugin"];
          hwp = NG["hoursWeightedProgress"];
        }
        const ganttEl = el("div", "height:100%;width:100%;position:absolute;inset:0");
        contentEl.appendChild(ganttEl);
        let filtered = applyFilter(allTasks, filter, searchQ);
        if (!cb.checked) filtered = filtered.filter((t) => !DONE_STAGES[t.stage || ""]);
        const gtasks = groupBy === "epic" ? buildTasks(buildTasksEpic(filtered)) : buildTasks(filtered);
        let pluginBuckets = buckets;
        let pluginGetBucket = (task) => task.groupId || null;
        if (groupBy === "epic") {
          const epicMap = {};
          filtered.filter((t) => !t.parentWorkItemId).forEach((t, i) => {
            epicMap[t.id] = { id: t.id, label: (t.title || t.id).slice(0, 20), color: "#475569", bgTint: "#64748b", order: i };
          });
          pluginBuckets = Object.keys(epicMap).map((k) => epicMap[k]);
          pluginGetBucket = (task) => task.groupId || null;
        }
        ganttInst = new Ctor(ganttEl, {
          tasks: gtasks,
          dependencies: [],
          columns: GANTT_COLS,
          theme: V3_THEME,
          rowHeight: 32,
          barHeight: 20,
          headerHeight: 32,
          gridWidth: 295,
          zoomLevel,
          showToday: true,
          showWeekends: true,
          showProgress: true,
          colorMap: ((_a2 = options.config) == null ? void 0 : _a2.colorMap) || STAGE_COLORS,
          readOnly: false,
          onTaskClick: (task) => {
            if ((task == null ? void 0 : task.id) && !isBucketId(task.id)) openDetail(task.id);
          },
          onTaskDblClick: (task) => {
            if ((task == null ? void 0 : task.id) && !isBucketId(task.id)) openDetail(task.id);
          },
          onTaskMove: (task, s, e) => {
            if ((task == null ? void 0 : task.id) && !isBucketId(task.id)) onPatch({ id: task.id, startDate: s, endDate: e });
          },
          onTaskResize: (task, s, e) => {
            if ((task == null ? void 0 : task.id) && !isBucketId(task.id)) onPatch({ id: task.id, startDate: s, endDate: e });
          }
        });
        if (typeof PGP === "function") {
          ganttInst.use(PGP({
            buckets: pluginBuckets,
            getBucket: pluginGetBucket,
            getBucketProgress: typeof hwp === "function" ? hwp : void 0
          }));
        }
        ganttInst.setData(gtasks, []);
        try {
          ganttInst.expandAll();
        } catch (_) {
        }
        if (cleanupShading) cleanupShading();
        if (cleanupDrag) cleanupDrag();
        if (features.depthShading !== false) cleanupShading = startDepthShading(ganttEl, depthMap);
        if (features.dragReparent !== false) cleanupDrag = startDragReparent(ganttEl, allTasks, depthMap, onPatch);
        setTimeout(() => {
          try {
            if ((ganttInst == null ? void 0 : ganttInst.timeScale) && (ganttInst == null ? void 0 : ganttInst.scrollManager)) {
              const ld = /* @__PURE__ */ new Date();
              ld.setDate(ld.getDate() - 14);
              const x = ganttInst.timeScale.dateToX(ld);
              if (x > 0) ganttInst.scrollManager.scrollToX(x);
            }
          } catch (_) {
          }
        }, 600);
      }
      function refresh() {
        let filtered = applyFilter(allTasks, filter, searchQ);
        if (!cb.checked) filtered = filtered.filter((t) => !DONE_STAGES[t.stage || ""]);
        if (viewMode === "gantt" && ganttInst) {
          const gtasks = groupBy === "epic" ? buildTasks(buildTasksEpic(filtered)) : buildTasks(filtered);
          if (typeof ganttInst.setData === "function") {
            ganttInst.setData(gtasks, []);
            try {
              ganttInst.expandAll();
            } catch (_) {
            }
          }
        } else if (viewMode === "list") {
          renderList(contentEl, buildTasks(filtered), buckets);
        }
        updateStats();
      }
      function rebuildView() {
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
          } catch (_) {
          }
          ganttInst = null;
        }
        contentEl.innerHTML = "";
        if (viewMode === "gantt") initGantt();
        else renderList(contentEl, buildTasks(applyFilter(allTasks, filter, searchQ)), buckets);
        updateStats();
      }
      cb.addEventListener("change", () => {
        refresh();
      });
      initGantt();
      updateStats();
      const cleanup = () => {
        if (cleanupShading) cleanupShading();
        if (cleanupDrag) cleanupDrag();
        if (ganttInst) {
          try {
            ganttInst.destroy();
          } catch (_) {
          }
        }
      };
      registry.push({ container, cleanup });
      return {
        setTasks(tasks) {
          allTasks = tasks;
          depthMap = buildDepthMap(allTasks);
          if (cleanupShading) {
            cleanupShading();
            cleanupShading = null;
          }
          if (cleanupDrag) {
            cleanupDrag();
            cleanupDrag = null;
          }
          refresh();
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
    unmount: (container) => IIFEApp.unmount(container)
  };
  exports.NimbusGanttApp = NimbusGanttApp2;
  Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
  return exports;
}({});
typeof window !== "undefined" && (window.NimbusGanttApp = NimbusGanttApp.NimbusGanttApp || NimbusGanttApp);
