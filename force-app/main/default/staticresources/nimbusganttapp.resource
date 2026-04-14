var NimbusGanttApp = function(exports) {
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
  function applyFilter(tasks, filter, q) {
    let r = tasks;
    if (filter === "active") {
      r = r.filter((t) => !DONE_STAGES[t.stage || ""] && !t.isInactive);
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
  function stageToCategory(stage) {
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
      const cat = stageToCategory(t.stage || "");
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
  const registry$1 = /* @__PURE__ */ new Map();
  function registerTemplate(template) {
    if (!template || !template.name) {
      throw new Error("Template.name is required");
    }
    registry$1.set(template.name, template);
  }
  function getTemplate(name) {
    const t = registry$1.get(name);
    if (!t) throw new Error("Unknown template: '" + name + "'");
    return t;
  }
  function hasTemplate(name) {
    return registry$1.has(name);
  }
  function listTemplates() {
    return Array.from(registry$1.keys());
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
      version
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
    auditPanelOpen: false,
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
      case "TOGGLE_DETAIL":
        return {
          ...state,
          detailOpen: event.taskId !== void 0 ? true : !state.detailOpen,
          selectedTaskId: event.taskId !== void 0 ? event.taskId : state.selectedTaskId
        };
      case "TOGGLE_AUDIT_PANEL":
        return { ...state, auditPanelOpen: !state.auditPanelOpen };
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
    "HrsWkStrip",
    "ContentArea"
    // wraps Sidebar + main + DetailPanel + AuditPanel
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
  const CLOUD_NIMBUS_VIEWS = CLOUD_NIMBUS_VIEW_MODES.map((v) => v.id);
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
  var jsxRuntime = { exports: {} };
  var reactJsxRuntime_production = {};
  /**
   * @license React
   * react-jsx-runtime.production.js
   *
   * Copyright (c) Meta Platforms, Inc. and affiliates.
   *
   * This source code is licensed under the MIT license found in the
   * LICENSE file in the root directory of this source tree.
   */
  var hasRequiredReactJsxRuntime_production;
  function requireReactJsxRuntime_production() {
    if (hasRequiredReactJsxRuntime_production) return reactJsxRuntime_production;
    hasRequiredReactJsxRuntime_production = 1;
    var REACT_ELEMENT_TYPE = Symbol.for("react.transitional.element"), REACT_FRAGMENT_TYPE = Symbol.for("react.fragment");
    function jsxProd(type, config, maybeKey) {
      var key = null;
      void 0 !== maybeKey && (key = "" + maybeKey);
      void 0 !== config.key && (key = "" + config.key);
      if ("key" in config) {
        maybeKey = {};
        for (var propName in config)
          "key" !== propName && (maybeKey[propName] = config[propName]);
      } else maybeKey = config;
      config = maybeKey.ref;
      return {
        $$typeof: REACT_ELEMENT_TYPE,
        type,
        key,
        ref: void 0 !== config ? config : null,
        props: maybeKey
      };
    }
    reactJsxRuntime_production.Fragment = REACT_FRAGMENT_TYPE;
    reactJsxRuntime_production.jsx = jsxProd;
    reactJsxRuntime_production.jsxs = jsxProd;
    return reactJsxRuntime_production;
  }
  var reactJsxRuntime_development = {};
  var react = { exports: {} };
  var react_production = {};
  /**
   * @license React
   * react.production.js
   *
   * Copyright (c) Meta Platforms, Inc. and affiliates.
   *
   * This source code is licensed under the MIT license found in the
   * LICENSE file in the root directory of this source tree.
   */
  var hasRequiredReact_production;
  function requireReact_production() {
    if (hasRequiredReact_production) return react_production;
    hasRequiredReact_production = 1;
    var REACT_ELEMENT_TYPE = Symbol.for("react.transitional.element"), REACT_PORTAL_TYPE = Symbol.for("react.portal"), REACT_FRAGMENT_TYPE = Symbol.for("react.fragment"), REACT_STRICT_MODE_TYPE = Symbol.for("react.strict_mode"), REACT_PROFILER_TYPE = Symbol.for("react.profiler"), REACT_CONSUMER_TYPE = Symbol.for("react.consumer"), REACT_CONTEXT_TYPE = Symbol.for("react.context"), REACT_FORWARD_REF_TYPE = Symbol.for("react.forward_ref"), REACT_SUSPENSE_TYPE = Symbol.for("react.suspense"), REACT_MEMO_TYPE = Symbol.for("react.memo"), REACT_LAZY_TYPE = Symbol.for("react.lazy"), REACT_ACTIVITY_TYPE = Symbol.for("react.activity"), MAYBE_ITERATOR_SYMBOL = Symbol.iterator;
    function getIteratorFn(maybeIterable) {
      if (null === maybeIterable || "object" !== typeof maybeIterable) return null;
      maybeIterable = MAYBE_ITERATOR_SYMBOL && maybeIterable[MAYBE_ITERATOR_SYMBOL] || maybeIterable["@@iterator"];
      return "function" === typeof maybeIterable ? maybeIterable : null;
    }
    var ReactNoopUpdateQueue = {
      isMounted: function() {
        return false;
      },
      enqueueForceUpdate: function() {
      },
      enqueueReplaceState: function() {
      },
      enqueueSetState: function() {
      }
    }, assign = Object.assign, emptyObject = {};
    function Component(props, context, updater) {
      this.props = props;
      this.context = context;
      this.refs = emptyObject;
      this.updater = updater || ReactNoopUpdateQueue;
    }
    Component.prototype.isReactComponent = {};
    Component.prototype.setState = function(partialState, callback) {
      if ("object" !== typeof partialState && "function" !== typeof partialState && null != partialState)
        throw Error(
          "takes an object of state variables to update or a function which returns an object of state variables."
        );
      this.updater.enqueueSetState(this, partialState, callback, "setState");
    };
    Component.prototype.forceUpdate = function(callback) {
      this.updater.enqueueForceUpdate(this, callback, "forceUpdate");
    };
    function ComponentDummy() {
    }
    ComponentDummy.prototype = Component.prototype;
    function PureComponent(props, context, updater) {
      this.props = props;
      this.context = context;
      this.refs = emptyObject;
      this.updater = updater || ReactNoopUpdateQueue;
    }
    var pureComponentPrototype = PureComponent.prototype = new ComponentDummy();
    pureComponentPrototype.constructor = PureComponent;
    assign(pureComponentPrototype, Component.prototype);
    pureComponentPrototype.isPureReactComponent = true;
    var isArrayImpl = Array.isArray;
    function noop() {
    }
    var ReactSharedInternals = { H: null, A: null, T: null, S: null }, hasOwnProperty = Object.prototype.hasOwnProperty;
    function ReactElement(type, key, props) {
      var refProp = props.ref;
      return {
        $$typeof: REACT_ELEMENT_TYPE,
        type,
        key,
        ref: void 0 !== refProp ? refProp : null,
        props
      };
    }
    function cloneAndReplaceKey(oldElement, newKey) {
      return ReactElement(oldElement.type, newKey, oldElement.props);
    }
    function isValidElement(object) {
      return "object" === typeof object && null !== object && object.$$typeof === REACT_ELEMENT_TYPE;
    }
    function escape(key) {
      var escaperLookup = { "=": "=0", ":": "=2" };
      return "$" + key.replace(/[=:]/g, function(match) {
        return escaperLookup[match];
      });
    }
    var userProvidedKeyEscapeRegex = /\/+/g;
    function getElementKey(element, index) {
      return "object" === typeof element && null !== element && null != element.key ? escape("" + element.key) : index.toString(36);
    }
    function resolveThenable(thenable) {
      switch (thenable.status) {
        case "fulfilled":
          return thenable.value;
        case "rejected":
          throw thenable.reason;
        default:
          switch ("string" === typeof thenable.status ? thenable.then(noop, noop) : (thenable.status = "pending", thenable.then(
            function(fulfilledValue) {
              "pending" === thenable.status && (thenable.status = "fulfilled", thenable.value = fulfilledValue);
            },
            function(error) {
              "pending" === thenable.status && (thenable.status = "rejected", thenable.reason = error);
            }
          )), thenable.status) {
            case "fulfilled":
              return thenable.value;
            case "rejected":
              throw thenable.reason;
          }
      }
      throw thenable;
    }
    function mapIntoArray(children, array, escapedPrefix, nameSoFar, callback) {
      var type = typeof children;
      if ("undefined" === type || "boolean" === type) children = null;
      var invokeCallback = false;
      if (null === children) invokeCallback = true;
      else
        switch (type) {
          case "bigint":
          case "string":
          case "number":
            invokeCallback = true;
            break;
          case "object":
            switch (children.$$typeof) {
              case REACT_ELEMENT_TYPE:
              case REACT_PORTAL_TYPE:
                invokeCallback = true;
                break;
              case REACT_LAZY_TYPE:
                return invokeCallback = children._init, mapIntoArray(
                  invokeCallback(children._payload),
                  array,
                  escapedPrefix,
                  nameSoFar,
                  callback
                );
            }
        }
      if (invokeCallback)
        return callback = callback(children), invokeCallback = "" === nameSoFar ? "." + getElementKey(children, 0) : nameSoFar, isArrayImpl(callback) ? (escapedPrefix = "", null != invokeCallback && (escapedPrefix = invokeCallback.replace(userProvidedKeyEscapeRegex, "$&/") + "/"), mapIntoArray(callback, array, escapedPrefix, "", function(c) {
          return c;
        })) : null != callback && (isValidElement(callback) && (callback = cloneAndReplaceKey(
          callback,
          escapedPrefix + (null == callback.key || children && children.key === callback.key ? "" : ("" + callback.key).replace(
            userProvidedKeyEscapeRegex,
            "$&/"
          ) + "/") + invokeCallback
        )), array.push(callback)), 1;
      invokeCallback = 0;
      var nextNamePrefix = "" === nameSoFar ? "." : nameSoFar + ":";
      if (isArrayImpl(children))
        for (var i = 0; i < children.length; i++)
          nameSoFar = children[i], type = nextNamePrefix + getElementKey(nameSoFar, i), invokeCallback += mapIntoArray(
            nameSoFar,
            array,
            escapedPrefix,
            type,
            callback
          );
      else if (i = getIteratorFn(children), "function" === typeof i)
        for (children = i.call(children), i = 0; !(nameSoFar = children.next()).done; )
          nameSoFar = nameSoFar.value, type = nextNamePrefix + getElementKey(nameSoFar, i++), invokeCallback += mapIntoArray(
            nameSoFar,
            array,
            escapedPrefix,
            type,
            callback
          );
      else if ("object" === type) {
        if ("function" === typeof children.then)
          return mapIntoArray(
            resolveThenable(children),
            array,
            escapedPrefix,
            nameSoFar,
            callback
          );
        array = String(children);
        throw Error(
          "Objects are not valid as a React child (found: " + ("[object Object]" === array ? "object with keys {" + Object.keys(children).join(", ") + "}" : array) + "). If you meant to render a collection of children, use an array instead."
        );
      }
      return invokeCallback;
    }
    function mapChildren(children, func, context) {
      if (null == children) return children;
      var result = [], count = 0;
      mapIntoArray(children, result, "", "", function(child) {
        return func.call(context, child, count++);
      });
      return result;
    }
    function lazyInitializer(payload) {
      if (-1 === payload._status) {
        var ctor = payload._result;
        ctor = ctor();
        ctor.then(
          function(moduleObject) {
            if (0 === payload._status || -1 === payload._status)
              payload._status = 1, payload._result = moduleObject;
          },
          function(error) {
            if (0 === payload._status || -1 === payload._status)
              payload._status = 2, payload._result = error;
          }
        );
        -1 === payload._status && (payload._status = 0, payload._result = ctor);
      }
      if (1 === payload._status) return payload._result.default;
      throw payload._result;
    }
    var reportGlobalError = "function" === typeof reportError ? reportError : function(error) {
      if ("object" === typeof window && "function" === typeof window.ErrorEvent) {
        var event = new window.ErrorEvent("error", {
          bubbles: true,
          cancelable: true,
          message: "object" === typeof error && null !== error && "string" === typeof error.message ? String(error.message) : String(error),
          error
        });
        if (!window.dispatchEvent(event)) return;
      } else if ("object" === typeof process && "function" === typeof process.emit) {
        process.emit("uncaughtException", error);
        return;
      }
      console.error(error);
    }, Children = {
      map: mapChildren,
      forEach: function(children, forEachFunc, forEachContext) {
        mapChildren(
          children,
          function() {
            forEachFunc.apply(this, arguments);
          },
          forEachContext
        );
      },
      count: function(children) {
        var n = 0;
        mapChildren(children, function() {
          n++;
        });
        return n;
      },
      toArray: function(children) {
        return mapChildren(children, function(child) {
          return child;
        }) || [];
      },
      only: function(children) {
        if (!isValidElement(children))
          throw Error(
            "React.Children.only expected to receive a single React element child."
          );
        return children;
      }
    };
    react_production.Activity = REACT_ACTIVITY_TYPE;
    react_production.Children = Children;
    react_production.Component = Component;
    react_production.Fragment = REACT_FRAGMENT_TYPE;
    react_production.Profiler = REACT_PROFILER_TYPE;
    react_production.PureComponent = PureComponent;
    react_production.StrictMode = REACT_STRICT_MODE_TYPE;
    react_production.Suspense = REACT_SUSPENSE_TYPE;
    react_production.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE = ReactSharedInternals;
    react_production.__COMPILER_RUNTIME = {
      __proto__: null,
      c: function(size) {
        return ReactSharedInternals.H.useMemoCache(size);
      }
    };
    react_production.cache = function(fn) {
      return function() {
        return fn.apply(null, arguments);
      };
    };
    react_production.cacheSignal = function() {
      return null;
    };
    react_production.cloneElement = function(element, config, children) {
      if (null === element || void 0 === element)
        throw Error(
          "The argument must be a React element, but you passed " + element + "."
        );
      var props = assign({}, element.props), key = element.key;
      if (null != config)
        for (propName in void 0 !== config.key && (key = "" + config.key), config)
          !hasOwnProperty.call(config, propName) || "key" === propName || "__self" === propName || "__source" === propName || "ref" === propName && void 0 === config.ref || (props[propName] = config[propName]);
      var propName = arguments.length - 2;
      if (1 === propName) props.children = children;
      else if (1 < propName) {
        for (var childArray = Array(propName), i = 0; i < propName; i++)
          childArray[i] = arguments[i + 2];
        props.children = childArray;
      }
      return ReactElement(element.type, key, props);
    };
    react_production.createContext = function(defaultValue) {
      defaultValue = {
        $$typeof: REACT_CONTEXT_TYPE,
        _currentValue: defaultValue,
        _currentValue2: defaultValue,
        _threadCount: 0,
        Provider: null,
        Consumer: null
      };
      defaultValue.Provider = defaultValue;
      defaultValue.Consumer = {
        $$typeof: REACT_CONSUMER_TYPE,
        _context: defaultValue
      };
      return defaultValue;
    };
    react_production.createElement = function(type, config, children) {
      var propName, props = {}, key = null;
      if (null != config)
        for (propName in void 0 !== config.key && (key = "" + config.key), config)
          hasOwnProperty.call(config, propName) && "key" !== propName && "__self" !== propName && "__source" !== propName && (props[propName] = config[propName]);
      var childrenLength = arguments.length - 2;
      if (1 === childrenLength) props.children = children;
      else if (1 < childrenLength) {
        for (var childArray = Array(childrenLength), i = 0; i < childrenLength; i++)
          childArray[i] = arguments[i + 2];
        props.children = childArray;
      }
      if (type && type.defaultProps)
        for (propName in childrenLength = type.defaultProps, childrenLength)
          void 0 === props[propName] && (props[propName] = childrenLength[propName]);
      return ReactElement(type, key, props);
    };
    react_production.createRef = function() {
      return { current: null };
    };
    react_production.forwardRef = function(render) {
      return { $$typeof: REACT_FORWARD_REF_TYPE, render };
    };
    react_production.isValidElement = isValidElement;
    react_production.lazy = function(ctor) {
      return {
        $$typeof: REACT_LAZY_TYPE,
        _payload: { _status: -1, _result: ctor },
        _init: lazyInitializer
      };
    };
    react_production.memo = function(type, compare) {
      return {
        $$typeof: REACT_MEMO_TYPE,
        type,
        compare: void 0 === compare ? null : compare
      };
    };
    react_production.startTransition = function(scope) {
      var prevTransition = ReactSharedInternals.T, currentTransition = {};
      ReactSharedInternals.T = currentTransition;
      try {
        var returnValue = scope(), onStartTransitionFinish = ReactSharedInternals.S;
        null !== onStartTransitionFinish && onStartTransitionFinish(currentTransition, returnValue);
        "object" === typeof returnValue && null !== returnValue && "function" === typeof returnValue.then && returnValue.then(noop, reportGlobalError);
      } catch (error) {
        reportGlobalError(error);
      } finally {
        null !== prevTransition && null !== currentTransition.types && (prevTransition.types = currentTransition.types), ReactSharedInternals.T = prevTransition;
      }
    };
    react_production.unstable_useCacheRefresh = function() {
      return ReactSharedInternals.H.useCacheRefresh();
    };
    react_production.use = function(usable) {
      return ReactSharedInternals.H.use(usable);
    };
    react_production.useActionState = function(action, initialState, permalink) {
      return ReactSharedInternals.H.useActionState(action, initialState, permalink);
    };
    react_production.useCallback = function(callback, deps) {
      return ReactSharedInternals.H.useCallback(callback, deps);
    };
    react_production.useContext = function(Context) {
      return ReactSharedInternals.H.useContext(Context);
    };
    react_production.useDebugValue = function() {
    };
    react_production.useDeferredValue = function(value, initialValue) {
      return ReactSharedInternals.H.useDeferredValue(value, initialValue);
    };
    react_production.useEffect = function(create, deps) {
      return ReactSharedInternals.H.useEffect(create, deps);
    };
    react_production.useEffectEvent = function(callback) {
      return ReactSharedInternals.H.useEffectEvent(callback);
    };
    react_production.useId = function() {
      return ReactSharedInternals.H.useId();
    };
    react_production.useImperativeHandle = function(ref, create, deps) {
      return ReactSharedInternals.H.useImperativeHandle(ref, create, deps);
    };
    react_production.useInsertionEffect = function(create, deps) {
      return ReactSharedInternals.H.useInsertionEffect(create, deps);
    };
    react_production.useLayoutEffect = function(create, deps) {
      return ReactSharedInternals.H.useLayoutEffect(create, deps);
    };
    react_production.useMemo = function(create, deps) {
      return ReactSharedInternals.H.useMemo(create, deps);
    };
    react_production.useOptimistic = function(passthrough, reducer) {
      return ReactSharedInternals.H.useOptimistic(passthrough, reducer);
    };
    react_production.useReducer = function(reducer, initialArg, init) {
      return ReactSharedInternals.H.useReducer(reducer, initialArg, init);
    };
    react_production.useRef = function(initialValue) {
      return ReactSharedInternals.H.useRef(initialValue);
    };
    react_production.useState = function(initialState) {
      return ReactSharedInternals.H.useState(initialState);
    };
    react_production.useSyncExternalStore = function(subscribe, getSnapshot, getServerSnapshot) {
      return ReactSharedInternals.H.useSyncExternalStore(
        subscribe,
        getSnapshot,
        getServerSnapshot
      );
    };
    react_production.useTransition = function() {
      return ReactSharedInternals.H.useTransition();
    };
    react_production.version = "19.2.4";
    return react_production;
  }
  var react_development = { exports: {} };
  /**
   * @license React
   * react.development.js
   *
   * Copyright (c) Meta Platforms, Inc. and affiliates.
   *
   * This source code is licensed under the MIT license found in the
   * LICENSE file in the root directory of this source tree.
   */
  react_development.exports;
  var hasRequiredReact_development;
  function requireReact_development() {
    if (hasRequiredReact_development) return react_development.exports;
    hasRequiredReact_development = 1;
    (function(module, exports$1) {
      "production" !== process.env.NODE_ENV && function() {
        function defineDeprecationWarning(methodName, info) {
          Object.defineProperty(Component.prototype, methodName, {
            get: function() {
              console.warn(
                "%s(...) is deprecated in plain JavaScript React classes. %s",
                info[0],
                info[1]
              );
            }
          });
        }
        function getIteratorFn(maybeIterable) {
          if (null === maybeIterable || "object" !== typeof maybeIterable)
            return null;
          maybeIterable = MAYBE_ITERATOR_SYMBOL && maybeIterable[MAYBE_ITERATOR_SYMBOL] || maybeIterable["@@iterator"];
          return "function" === typeof maybeIterable ? maybeIterable : null;
        }
        function warnNoop(publicInstance, callerName) {
          publicInstance = (publicInstance = publicInstance.constructor) && (publicInstance.displayName || publicInstance.name) || "ReactClass";
          var warningKey = publicInstance + "." + callerName;
          didWarnStateUpdateForUnmountedComponent[warningKey] || (console.error(
            "Can't call %s on a component that is not yet mounted. This is a no-op, but it might indicate a bug in your application. Instead, assign to `this.state` directly or define a `state = {};` class property with the desired state in the %s component.",
            callerName,
            publicInstance
          ), didWarnStateUpdateForUnmountedComponent[warningKey] = true);
        }
        function Component(props, context, updater) {
          this.props = props;
          this.context = context;
          this.refs = emptyObject;
          this.updater = updater || ReactNoopUpdateQueue;
        }
        function ComponentDummy() {
        }
        function PureComponent(props, context, updater) {
          this.props = props;
          this.context = context;
          this.refs = emptyObject;
          this.updater = updater || ReactNoopUpdateQueue;
        }
        function noop() {
        }
        function testStringCoercion(value) {
          return "" + value;
        }
        function checkKeyStringCoercion(value) {
          try {
            testStringCoercion(value);
            var JSCompiler_inline_result = false;
          } catch (e) {
            JSCompiler_inline_result = true;
          }
          if (JSCompiler_inline_result) {
            JSCompiler_inline_result = console;
            var JSCompiler_temp_const = JSCompiler_inline_result.error;
            var JSCompiler_inline_result$jscomp$0 = "function" === typeof Symbol && Symbol.toStringTag && value[Symbol.toStringTag] || value.constructor.name || "Object";
            JSCompiler_temp_const.call(
              JSCompiler_inline_result,
              "The provided key is an unsupported type %s. This value must be coerced to a string before using it here.",
              JSCompiler_inline_result$jscomp$0
            );
            return testStringCoercion(value);
          }
        }
        function getComponentNameFromType(type) {
          if (null == type) return null;
          if ("function" === typeof type)
            return type.$$typeof === REACT_CLIENT_REFERENCE ? null : type.displayName || type.name || null;
          if ("string" === typeof type) return type;
          switch (type) {
            case REACT_FRAGMENT_TYPE:
              return "Fragment";
            case REACT_PROFILER_TYPE:
              return "Profiler";
            case REACT_STRICT_MODE_TYPE:
              return "StrictMode";
            case REACT_SUSPENSE_TYPE:
              return "Suspense";
            case REACT_SUSPENSE_LIST_TYPE:
              return "SuspenseList";
            case REACT_ACTIVITY_TYPE:
              return "Activity";
          }
          if ("object" === typeof type)
            switch ("number" === typeof type.tag && console.error(
              "Received an unexpected object in getComponentNameFromType(). This is likely a bug in React. Please file an issue."
            ), type.$$typeof) {
              case REACT_PORTAL_TYPE:
                return "Portal";
              case REACT_CONTEXT_TYPE:
                return type.displayName || "Context";
              case REACT_CONSUMER_TYPE:
                return (type._context.displayName || "Context") + ".Consumer";
              case REACT_FORWARD_REF_TYPE:
                var innerType = type.render;
                type = type.displayName;
                type || (type = innerType.displayName || innerType.name || "", type = "" !== type ? "ForwardRef(" + type + ")" : "ForwardRef");
                return type;
              case REACT_MEMO_TYPE:
                return innerType = type.displayName || null, null !== innerType ? innerType : getComponentNameFromType(type.type) || "Memo";
              case REACT_LAZY_TYPE:
                innerType = type._payload;
                type = type._init;
                try {
                  return getComponentNameFromType(type(innerType));
                } catch (x) {
                }
            }
          return null;
        }
        function getTaskName(type) {
          if (type === REACT_FRAGMENT_TYPE) return "<>";
          if ("object" === typeof type && null !== type && type.$$typeof === REACT_LAZY_TYPE)
            return "<...>";
          try {
            var name = getComponentNameFromType(type);
            return name ? "<" + name + ">" : "<...>";
          } catch (x) {
            return "<...>";
          }
        }
        function getOwner() {
          var dispatcher = ReactSharedInternals.A;
          return null === dispatcher ? null : dispatcher.getOwner();
        }
        function UnknownOwner() {
          return Error("react-stack-top-frame");
        }
        function hasValidKey(config) {
          if (hasOwnProperty.call(config, "key")) {
            var getter = Object.getOwnPropertyDescriptor(config, "key").get;
            if (getter && getter.isReactWarning) return false;
          }
          return void 0 !== config.key;
        }
        function defineKeyPropWarningGetter(props, displayName) {
          function warnAboutAccessingKey() {
            specialPropKeyWarningShown || (specialPropKeyWarningShown = true, console.error(
              "%s: `key` is not a prop. Trying to access it will result in `undefined` being returned. If you need to access the same value within the child component, you should pass it as a different prop. (https://react.dev/link/special-props)",
              displayName
            ));
          }
          warnAboutAccessingKey.isReactWarning = true;
          Object.defineProperty(props, "key", {
            get: warnAboutAccessingKey,
            configurable: true
          });
        }
        function elementRefGetterWithDeprecationWarning() {
          var componentName = getComponentNameFromType(this.type);
          didWarnAboutElementRef[componentName] || (didWarnAboutElementRef[componentName] = true, console.error(
            "Accessing element.ref was removed in React 19. ref is now a regular prop. It will be removed from the JSX Element type in a future release."
          ));
          componentName = this.props.ref;
          return void 0 !== componentName ? componentName : null;
        }
        function ReactElement(type, key, props, owner, debugStack, debugTask) {
          var refProp = props.ref;
          type = {
            $$typeof: REACT_ELEMENT_TYPE,
            type,
            key,
            props,
            _owner: owner
          };
          null !== (void 0 !== refProp ? refProp : null) ? Object.defineProperty(type, "ref", {
            enumerable: false,
            get: elementRefGetterWithDeprecationWarning
          }) : Object.defineProperty(type, "ref", { enumerable: false, value: null });
          type._store = {};
          Object.defineProperty(type._store, "validated", {
            configurable: false,
            enumerable: false,
            writable: true,
            value: 0
          });
          Object.defineProperty(type, "_debugInfo", {
            configurable: false,
            enumerable: false,
            writable: true,
            value: null
          });
          Object.defineProperty(type, "_debugStack", {
            configurable: false,
            enumerable: false,
            writable: true,
            value: debugStack
          });
          Object.defineProperty(type, "_debugTask", {
            configurable: false,
            enumerable: false,
            writable: true,
            value: debugTask
          });
          Object.freeze && (Object.freeze(type.props), Object.freeze(type));
          return type;
        }
        function cloneAndReplaceKey(oldElement, newKey) {
          newKey = ReactElement(
            oldElement.type,
            newKey,
            oldElement.props,
            oldElement._owner,
            oldElement._debugStack,
            oldElement._debugTask
          );
          oldElement._store && (newKey._store.validated = oldElement._store.validated);
          return newKey;
        }
        function validateChildKeys(node) {
          isValidElement(node) ? node._store && (node._store.validated = 1) : "object" === typeof node && null !== node && node.$$typeof === REACT_LAZY_TYPE && ("fulfilled" === node._payload.status ? isValidElement(node._payload.value) && node._payload.value._store && (node._payload.value._store.validated = 1) : node._store && (node._store.validated = 1));
        }
        function isValidElement(object) {
          return "object" === typeof object && null !== object && object.$$typeof === REACT_ELEMENT_TYPE;
        }
        function escape(key) {
          var escaperLookup = { "=": "=0", ":": "=2" };
          return "$" + key.replace(/[=:]/g, function(match) {
            return escaperLookup[match];
          });
        }
        function getElementKey(element, index) {
          return "object" === typeof element && null !== element && null != element.key ? (checkKeyStringCoercion(element.key), escape("" + element.key)) : index.toString(36);
        }
        function resolveThenable(thenable) {
          switch (thenable.status) {
            case "fulfilled":
              return thenable.value;
            case "rejected":
              throw thenable.reason;
            default:
              switch ("string" === typeof thenable.status ? thenable.then(noop, noop) : (thenable.status = "pending", thenable.then(
                function(fulfilledValue) {
                  "pending" === thenable.status && (thenable.status = "fulfilled", thenable.value = fulfilledValue);
                },
                function(error) {
                  "pending" === thenable.status && (thenable.status = "rejected", thenable.reason = error);
                }
              )), thenable.status) {
                case "fulfilled":
                  return thenable.value;
                case "rejected":
                  throw thenable.reason;
              }
          }
          throw thenable;
        }
        function mapIntoArray(children, array, escapedPrefix, nameSoFar, callback) {
          var type = typeof children;
          if ("undefined" === type || "boolean" === type) children = null;
          var invokeCallback = false;
          if (null === children) invokeCallback = true;
          else
            switch (type) {
              case "bigint":
              case "string":
              case "number":
                invokeCallback = true;
                break;
              case "object":
                switch (children.$$typeof) {
                  case REACT_ELEMENT_TYPE:
                  case REACT_PORTAL_TYPE:
                    invokeCallback = true;
                    break;
                  case REACT_LAZY_TYPE:
                    return invokeCallback = children._init, mapIntoArray(
                      invokeCallback(children._payload),
                      array,
                      escapedPrefix,
                      nameSoFar,
                      callback
                    );
                }
            }
          if (invokeCallback) {
            invokeCallback = children;
            callback = callback(invokeCallback);
            var childKey = "" === nameSoFar ? "." + getElementKey(invokeCallback, 0) : nameSoFar;
            isArrayImpl(callback) ? (escapedPrefix = "", null != childKey && (escapedPrefix = childKey.replace(userProvidedKeyEscapeRegex, "$&/") + "/"), mapIntoArray(callback, array, escapedPrefix, "", function(c) {
              return c;
            })) : null != callback && (isValidElement(callback) && (null != callback.key && (invokeCallback && invokeCallback.key === callback.key || checkKeyStringCoercion(callback.key)), escapedPrefix = cloneAndReplaceKey(
              callback,
              escapedPrefix + (null == callback.key || invokeCallback && invokeCallback.key === callback.key ? "" : ("" + callback.key).replace(
                userProvidedKeyEscapeRegex,
                "$&/"
              ) + "/") + childKey
            ), "" !== nameSoFar && null != invokeCallback && isValidElement(invokeCallback) && null == invokeCallback.key && invokeCallback._store && !invokeCallback._store.validated && (escapedPrefix._store.validated = 2), callback = escapedPrefix), array.push(callback));
            return 1;
          }
          invokeCallback = 0;
          childKey = "" === nameSoFar ? "." : nameSoFar + ":";
          if (isArrayImpl(children))
            for (var i = 0; i < children.length; i++)
              nameSoFar = children[i], type = childKey + getElementKey(nameSoFar, i), invokeCallback += mapIntoArray(
                nameSoFar,
                array,
                escapedPrefix,
                type,
                callback
              );
          else if (i = getIteratorFn(children), "function" === typeof i)
            for (i === children.entries && (didWarnAboutMaps || console.warn(
              "Using Maps as children is not supported. Use an array of keyed ReactElements instead."
            ), didWarnAboutMaps = true), children = i.call(children), i = 0; !(nameSoFar = children.next()).done; )
              nameSoFar = nameSoFar.value, type = childKey + getElementKey(nameSoFar, i++), invokeCallback += mapIntoArray(
                nameSoFar,
                array,
                escapedPrefix,
                type,
                callback
              );
          else if ("object" === type) {
            if ("function" === typeof children.then)
              return mapIntoArray(
                resolveThenable(children),
                array,
                escapedPrefix,
                nameSoFar,
                callback
              );
            array = String(children);
            throw Error(
              "Objects are not valid as a React child (found: " + ("[object Object]" === array ? "object with keys {" + Object.keys(children).join(", ") + "}" : array) + "). If you meant to render a collection of children, use an array instead."
            );
          }
          return invokeCallback;
        }
        function mapChildren(children, func, context) {
          if (null == children) return children;
          var result = [], count = 0;
          mapIntoArray(children, result, "", "", function(child) {
            return func.call(context, child, count++);
          });
          return result;
        }
        function lazyInitializer(payload) {
          if (-1 === payload._status) {
            var ioInfo = payload._ioInfo;
            null != ioInfo && (ioInfo.start = ioInfo.end = performance.now());
            ioInfo = payload._result;
            var thenable = ioInfo();
            thenable.then(
              function(moduleObject) {
                if (0 === payload._status || -1 === payload._status) {
                  payload._status = 1;
                  payload._result = moduleObject;
                  var _ioInfo = payload._ioInfo;
                  null != _ioInfo && (_ioInfo.end = performance.now());
                  void 0 === thenable.status && (thenable.status = "fulfilled", thenable.value = moduleObject);
                }
              },
              function(error) {
                if (0 === payload._status || -1 === payload._status) {
                  payload._status = 2;
                  payload._result = error;
                  var _ioInfo2 = payload._ioInfo;
                  null != _ioInfo2 && (_ioInfo2.end = performance.now());
                  void 0 === thenable.status && (thenable.status = "rejected", thenable.reason = error);
                }
              }
            );
            ioInfo = payload._ioInfo;
            if (null != ioInfo) {
              ioInfo.value = thenable;
              var displayName = thenable.displayName;
              "string" === typeof displayName && (ioInfo.name = displayName);
            }
            -1 === payload._status && (payload._status = 0, payload._result = thenable);
          }
          if (1 === payload._status)
            return ioInfo = payload._result, void 0 === ioInfo && console.error(
              "lazy: Expected the result of a dynamic import() call. Instead received: %s\n\nYour code should look like: \n  const MyComponent = lazy(() => import('./MyComponent'))\n\nDid you accidentally put curly braces around the import?",
              ioInfo
            ), "default" in ioInfo || console.error(
              "lazy: Expected the result of a dynamic import() call. Instead received: %s\n\nYour code should look like: \n  const MyComponent = lazy(() => import('./MyComponent'))",
              ioInfo
            ), ioInfo.default;
          throw payload._result;
        }
        function resolveDispatcher() {
          var dispatcher = ReactSharedInternals.H;
          null === dispatcher && console.error(
            "Invalid hook call. Hooks can only be called inside of the body of a function component. This could happen for one of the following reasons:\n1. You might have mismatching versions of React and the renderer (such as React DOM)\n2. You might be breaking the Rules of Hooks\n3. You might have more than one copy of React in the same app\nSee https://react.dev/link/invalid-hook-call for tips about how to debug and fix this problem."
          );
          return dispatcher;
        }
        function releaseAsyncTransition() {
          ReactSharedInternals.asyncTransitions--;
        }
        function enqueueTask(task) {
          if (null === enqueueTaskImpl)
            try {
              var requireString = ("require" + Math.random()).slice(0, 7);
              enqueueTaskImpl = (module && module[requireString]).call(
                module,
                "timers"
              ).setImmediate;
            } catch (_err) {
              enqueueTaskImpl = function(callback) {
                false === didWarnAboutMessageChannel && (didWarnAboutMessageChannel = true, "undefined" === typeof MessageChannel && console.error(
                  "This browser does not have a MessageChannel implementation, so enqueuing tasks via await act(async () => ...) will fail. Please file an issue at https://github.com/facebook/react/issues if you encounter this warning."
                ));
                var channel = new MessageChannel();
                channel.port1.onmessage = callback;
                channel.port2.postMessage(void 0);
              };
            }
          return enqueueTaskImpl(task);
        }
        function aggregateErrors(errors) {
          return 1 < errors.length && "function" === typeof AggregateError ? new AggregateError(errors) : errors[0];
        }
        function popActScope(prevActQueue, prevActScopeDepth) {
          prevActScopeDepth !== actScopeDepth - 1 && console.error(
            "You seem to have overlapping act() calls, this is not supported. Be sure to await previous act() calls before making a new one. "
          );
          actScopeDepth = prevActScopeDepth;
        }
        function recursivelyFlushAsyncActWork(returnValue, resolve, reject) {
          var queue = ReactSharedInternals.actQueue;
          if (null !== queue)
            if (0 !== queue.length)
              try {
                flushActQueue(queue);
                enqueueTask(function() {
                  return recursivelyFlushAsyncActWork(returnValue, resolve, reject);
                });
                return;
              } catch (error) {
                ReactSharedInternals.thrownErrors.push(error);
              }
            else ReactSharedInternals.actQueue = null;
          0 < ReactSharedInternals.thrownErrors.length ? (queue = aggregateErrors(ReactSharedInternals.thrownErrors), ReactSharedInternals.thrownErrors.length = 0, reject(queue)) : resolve(returnValue);
        }
        function flushActQueue(queue) {
          if (!isFlushing) {
            isFlushing = true;
            var i = 0;
            try {
              for (; i < queue.length; i++) {
                var callback = queue[i];
                do {
                  ReactSharedInternals.didUsePromise = false;
                  var continuation = callback(false);
                  if (null !== continuation) {
                    if (ReactSharedInternals.didUsePromise) {
                      queue[i] = callback;
                      queue.splice(0, i);
                      return;
                    }
                    callback = continuation;
                  } else break;
                } while (1);
              }
              queue.length = 0;
            } catch (error) {
              queue.splice(0, i + 1), ReactSharedInternals.thrownErrors.push(error);
            } finally {
              isFlushing = false;
            }
          }
        }
        "undefined" !== typeof __REACT_DEVTOOLS_GLOBAL_HOOK__ && "function" === typeof __REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStart && __REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStart(Error());
        var REACT_ELEMENT_TYPE = Symbol.for("react.transitional.element"), REACT_PORTAL_TYPE = Symbol.for("react.portal"), REACT_FRAGMENT_TYPE = Symbol.for("react.fragment"), REACT_STRICT_MODE_TYPE = Symbol.for("react.strict_mode"), REACT_PROFILER_TYPE = Symbol.for("react.profiler"), REACT_CONSUMER_TYPE = Symbol.for("react.consumer"), REACT_CONTEXT_TYPE = Symbol.for("react.context"), REACT_FORWARD_REF_TYPE = Symbol.for("react.forward_ref"), REACT_SUSPENSE_TYPE = Symbol.for("react.suspense"), REACT_SUSPENSE_LIST_TYPE = Symbol.for("react.suspense_list"), REACT_MEMO_TYPE = Symbol.for("react.memo"), REACT_LAZY_TYPE = Symbol.for("react.lazy"), REACT_ACTIVITY_TYPE = Symbol.for("react.activity"), MAYBE_ITERATOR_SYMBOL = Symbol.iterator, didWarnStateUpdateForUnmountedComponent = {}, ReactNoopUpdateQueue = {
          isMounted: function() {
            return false;
          },
          enqueueForceUpdate: function(publicInstance) {
            warnNoop(publicInstance, "forceUpdate");
          },
          enqueueReplaceState: function(publicInstance) {
            warnNoop(publicInstance, "replaceState");
          },
          enqueueSetState: function(publicInstance) {
            warnNoop(publicInstance, "setState");
          }
        }, assign = Object.assign, emptyObject = {};
        Object.freeze(emptyObject);
        Component.prototype.isReactComponent = {};
        Component.prototype.setState = function(partialState, callback) {
          if ("object" !== typeof partialState && "function" !== typeof partialState && null != partialState)
            throw Error(
              "takes an object of state variables to update or a function which returns an object of state variables."
            );
          this.updater.enqueueSetState(this, partialState, callback, "setState");
        };
        Component.prototype.forceUpdate = function(callback) {
          this.updater.enqueueForceUpdate(this, callback, "forceUpdate");
        };
        var deprecatedAPIs = {
          isMounted: [
            "isMounted",
            "Instead, make sure to clean up subscriptions and pending requests in componentWillUnmount to prevent memory leaks."
          ],
          replaceState: [
            "replaceState",
            "Refactor your code to use setState instead (see https://github.com/facebook/react/issues/3236)."
          ]
        };
        for (fnName in deprecatedAPIs)
          deprecatedAPIs.hasOwnProperty(fnName) && defineDeprecationWarning(fnName, deprecatedAPIs[fnName]);
        ComponentDummy.prototype = Component.prototype;
        deprecatedAPIs = PureComponent.prototype = new ComponentDummy();
        deprecatedAPIs.constructor = PureComponent;
        assign(deprecatedAPIs, Component.prototype);
        deprecatedAPIs.isPureReactComponent = true;
        var isArrayImpl = Array.isArray, REACT_CLIENT_REFERENCE = Symbol.for("react.client.reference"), ReactSharedInternals = {
          H: null,
          A: null,
          T: null,
          S: null,
          actQueue: null,
          asyncTransitions: 0,
          isBatchingLegacy: false,
          didScheduleLegacyUpdate: false,
          didUsePromise: false,
          thrownErrors: [],
          getCurrentStack: null,
          recentlyCreatedOwnerStacks: 0
        }, hasOwnProperty = Object.prototype.hasOwnProperty, createTask = console.createTask ? console.createTask : function() {
          return null;
        };
        deprecatedAPIs = {
          react_stack_bottom_frame: function(callStackForError) {
            return callStackForError();
          }
        };
        var specialPropKeyWarningShown, didWarnAboutOldJSXRuntime;
        var didWarnAboutElementRef = {};
        var unknownOwnerDebugStack = deprecatedAPIs.react_stack_bottom_frame.bind(
          deprecatedAPIs,
          UnknownOwner
        )();
        var unknownOwnerDebugTask = createTask(getTaskName(UnknownOwner));
        var didWarnAboutMaps = false, userProvidedKeyEscapeRegex = /\/+/g, reportGlobalError = "function" === typeof reportError ? reportError : function(error) {
          if ("object" === typeof window && "function" === typeof window.ErrorEvent) {
            var event = new window.ErrorEvent("error", {
              bubbles: true,
              cancelable: true,
              message: "object" === typeof error && null !== error && "string" === typeof error.message ? String(error.message) : String(error),
              error
            });
            if (!window.dispatchEvent(event)) return;
          } else if ("object" === typeof process && "function" === typeof process.emit) {
            process.emit("uncaughtException", error);
            return;
          }
          console.error(error);
        }, didWarnAboutMessageChannel = false, enqueueTaskImpl = null, actScopeDepth = 0, didWarnNoAwaitAct = false, isFlushing = false, queueSeveralMicrotasks = "function" === typeof queueMicrotask ? function(callback) {
          queueMicrotask(function() {
            return queueMicrotask(callback);
          });
        } : enqueueTask;
        deprecatedAPIs = Object.freeze({
          __proto__: null,
          c: function(size) {
            return resolveDispatcher().useMemoCache(size);
          }
        });
        var fnName = {
          map: mapChildren,
          forEach: function(children, forEachFunc, forEachContext) {
            mapChildren(
              children,
              function() {
                forEachFunc.apply(this, arguments);
              },
              forEachContext
            );
          },
          count: function(children) {
            var n = 0;
            mapChildren(children, function() {
              n++;
            });
            return n;
          },
          toArray: function(children) {
            return mapChildren(children, function(child) {
              return child;
            }) || [];
          },
          only: function(children) {
            if (!isValidElement(children))
              throw Error(
                "React.Children.only expected to receive a single React element child."
              );
            return children;
          }
        };
        exports$1.Activity = REACT_ACTIVITY_TYPE;
        exports$1.Children = fnName;
        exports$1.Component = Component;
        exports$1.Fragment = REACT_FRAGMENT_TYPE;
        exports$1.Profiler = REACT_PROFILER_TYPE;
        exports$1.PureComponent = PureComponent;
        exports$1.StrictMode = REACT_STRICT_MODE_TYPE;
        exports$1.Suspense = REACT_SUSPENSE_TYPE;
        exports$1.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE = ReactSharedInternals;
        exports$1.__COMPILER_RUNTIME = deprecatedAPIs;
        exports$1.act = function(callback) {
          var prevActQueue = ReactSharedInternals.actQueue, prevActScopeDepth = actScopeDepth;
          actScopeDepth++;
          var queue = ReactSharedInternals.actQueue = null !== prevActQueue ? prevActQueue : [], didAwaitActCall = false;
          try {
            var result = callback();
          } catch (error) {
            ReactSharedInternals.thrownErrors.push(error);
          }
          if (0 < ReactSharedInternals.thrownErrors.length)
            throw popActScope(prevActQueue, prevActScopeDepth), callback = aggregateErrors(ReactSharedInternals.thrownErrors), ReactSharedInternals.thrownErrors.length = 0, callback;
          if (null !== result && "object" === typeof result && "function" === typeof result.then) {
            var thenable = result;
            queueSeveralMicrotasks(function() {
              didAwaitActCall || didWarnNoAwaitAct || (didWarnNoAwaitAct = true, console.error(
                "You called act(async () => ...) without await. This could lead to unexpected testing behaviour, interleaving multiple act calls and mixing their scopes. You should - await act(async () => ...);"
              ));
            });
            return {
              then: function(resolve, reject) {
                didAwaitActCall = true;
                thenable.then(
                  function(returnValue) {
                    popActScope(prevActQueue, prevActScopeDepth);
                    if (0 === prevActScopeDepth) {
                      try {
                        flushActQueue(queue), enqueueTask(function() {
                          return recursivelyFlushAsyncActWork(
                            returnValue,
                            resolve,
                            reject
                          );
                        });
                      } catch (error$0) {
                        ReactSharedInternals.thrownErrors.push(error$0);
                      }
                      if (0 < ReactSharedInternals.thrownErrors.length) {
                        var _thrownError = aggregateErrors(
                          ReactSharedInternals.thrownErrors
                        );
                        ReactSharedInternals.thrownErrors.length = 0;
                        reject(_thrownError);
                      }
                    } else resolve(returnValue);
                  },
                  function(error) {
                    popActScope(prevActQueue, prevActScopeDepth);
                    0 < ReactSharedInternals.thrownErrors.length ? (error = aggregateErrors(
                      ReactSharedInternals.thrownErrors
                    ), ReactSharedInternals.thrownErrors.length = 0, reject(error)) : reject(error);
                  }
                );
              }
            };
          }
          var returnValue$jscomp$0 = result;
          popActScope(prevActQueue, prevActScopeDepth);
          0 === prevActScopeDepth && (flushActQueue(queue), 0 !== queue.length && queueSeveralMicrotasks(function() {
            didAwaitActCall || didWarnNoAwaitAct || (didWarnNoAwaitAct = true, console.error(
              "A component suspended inside an `act` scope, but the `act` call was not awaited. When testing React components that depend on asynchronous data, you must await the result:\n\nawait act(() => ...)"
            ));
          }), ReactSharedInternals.actQueue = null);
          if (0 < ReactSharedInternals.thrownErrors.length)
            throw callback = aggregateErrors(ReactSharedInternals.thrownErrors), ReactSharedInternals.thrownErrors.length = 0, callback;
          return {
            then: function(resolve, reject) {
              didAwaitActCall = true;
              0 === prevActScopeDepth ? (ReactSharedInternals.actQueue = queue, enqueueTask(function() {
                return recursivelyFlushAsyncActWork(
                  returnValue$jscomp$0,
                  resolve,
                  reject
                );
              })) : resolve(returnValue$jscomp$0);
            }
          };
        };
        exports$1.cache = function(fn) {
          return function() {
            return fn.apply(null, arguments);
          };
        };
        exports$1.cacheSignal = function() {
          return null;
        };
        exports$1.captureOwnerStack = function() {
          var getCurrentStack = ReactSharedInternals.getCurrentStack;
          return null === getCurrentStack ? null : getCurrentStack();
        };
        exports$1.cloneElement = function(element, config, children) {
          if (null === element || void 0 === element)
            throw Error(
              "The argument must be a React element, but you passed " + element + "."
            );
          var props = assign({}, element.props), key = element.key, owner = element._owner;
          if (null != config) {
            var JSCompiler_inline_result;
            a: {
              if (hasOwnProperty.call(config, "ref") && (JSCompiler_inline_result = Object.getOwnPropertyDescriptor(
                config,
                "ref"
              ).get) && JSCompiler_inline_result.isReactWarning) {
                JSCompiler_inline_result = false;
                break a;
              }
              JSCompiler_inline_result = void 0 !== config.ref;
            }
            JSCompiler_inline_result && (owner = getOwner());
            hasValidKey(config) && (checkKeyStringCoercion(config.key), key = "" + config.key);
            for (propName in config)
              !hasOwnProperty.call(config, propName) || "key" === propName || "__self" === propName || "__source" === propName || "ref" === propName && void 0 === config.ref || (props[propName] = config[propName]);
          }
          var propName = arguments.length - 2;
          if (1 === propName) props.children = children;
          else if (1 < propName) {
            JSCompiler_inline_result = Array(propName);
            for (var i = 0; i < propName; i++)
              JSCompiler_inline_result[i] = arguments[i + 2];
            props.children = JSCompiler_inline_result;
          }
          props = ReactElement(
            element.type,
            key,
            props,
            owner,
            element._debugStack,
            element._debugTask
          );
          for (key = 2; key < arguments.length; key++)
            validateChildKeys(arguments[key]);
          return props;
        };
        exports$1.createContext = function(defaultValue) {
          defaultValue = {
            $$typeof: REACT_CONTEXT_TYPE,
            _currentValue: defaultValue,
            _currentValue2: defaultValue,
            _threadCount: 0,
            Provider: null,
            Consumer: null
          };
          defaultValue.Provider = defaultValue;
          defaultValue.Consumer = {
            $$typeof: REACT_CONSUMER_TYPE,
            _context: defaultValue
          };
          defaultValue._currentRenderer = null;
          defaultValue._currentRenderer2 = null;
          return defaultValue;
        };
        exports$1.createElement = function(type, config, children) {
          for (var i = 2; i < arguments.length; i++)
            validateChildKeys(arguments[i]);
          i = {};
          var key = null;
          if (null != config)
            for (propName in didWarnAboutOldJSXRuntime || !("__self" in config) || "key" in config || (didWarnAboutOldJSXRuntime = true, console.warn(
              "Your app (or one of its dependencies) is using an outdated JSX transform. Update to the modern JSX transform for faster performance: https://react.dev/link/new-jsx-transform"
            )), hasValidKey(config) && (checkKeyStringCoercion(config.key), key = "" + config.key), config)
              hasOwnProperty.call(config, propName) && "key" !== propName && "__self" !== propName && "__source" !== propName && (i[propName] = config[propName]);
          var childrenLength = arguments.length - 2;
          if (1 === childrenLength) i.children = children;
          else if (1 < childrenLength) {
            for (var childArray = Array(childrenLength), _i = 0; _i < childrenLength; _i++)
              childArray[_i] = arguments[_i + 2];
            Object.freeze && Object.freeze(childArray);
            i.children = childArray;
          }
          if (type && type.defaultProps)
            for (propName in childrenLength = type.defaultProps, childrenLength)
              void 0 === i[propName] && (i[propName] = childrenLength[propName]);
          key && defineKeyPropWarningGetter(
            i,
            "function" === typeof type ? type.displayName || type.name || "Unknown" : type
          );
          var propName = 1e4 > ReactSharedInternals.recentlyCreatedOwnerStacks++;
          return ReactElement(
            type,
            key,
            i,
            getOwner(),
            propName ? Error("react-stack-top-frame") : unknownOwnerDebugStack,
            propName ? createTask(getTaskName(type)) : unknownOwnerDebugTask
          );
        };
        exports$1.createRef = function() {
          var refObject = { current: null };
          Object.seal(refObject);
          return refObject;
        };
        exports$1.forwardRef = function(render) {
          null != render && render.$$typeof === REACT_MEMO_TYPE ? console.error(
            "forwardRef requires a render function but received a `memo` component. Instead of forwardRef(memo(...)), use memo(forwardRef(...))."
          ) : "function" !== typeof render ? console.error(
            "forwardRef requires a render function but was given %s.",
            null === render ? "null" : typeof render
          ) : 0 !== render.length && 2 !== render.length && console.error(
            "forwardRef render functions accept exactly two parameters: props and ref. %s",
            1 === render.length ? "Did you forget to use the ref parameter?" : "Any additional parameter will be undefined."
          );
          null != render && null != render.defaultProps && console.error(
            "forwardRef render functions do not support defaultProps. Did you accidentally pass a React component?"
          );
          var elementType = { $$typeof: REACT_FORWARD_REF_TYPE, render }, ownName;
          Object.defineProperty(elementType, "displayName", {
            enumerable: false,
            configurable: true,
            get: function() {
              return ownName;
            },
            set: function(name) {
              ownName = name;
              render.name || render.displayName || (Object.defineProperty(render, "name", { value: name }), render.displayName = name);
            }
          });
          return elementType;
        };
        exports$1.isValidElement = isValidElement;
        exports$1.lazy = function(ctor) {
          ctor = { _status: -1, _result: ctor };
          var lazyType = {
            $$typeof: REACT_LAZY_TYPE,
            _payload: ctor,
            _init: lazyInitializer
          }, ioInfo = {
            name: "lazy",
            start: -1,
            end: -1,
            value: null,
            owner: null,
            debugStack: Error("react-stack-top-frame"),
            debugTask: console.createTask ? console.createTask("lazy()") : null
          };
          ctor._ioInfo = ioInfo;
          lazyType._debugInfo = [{ awaited: ioInfo }];
          return lazyType;
        };
        exports$1.memo = function(type, compare) {
          null == type && console.error(
            "memo: The first argument must be a component. Instead received: %s",
            null === type ? "null" : typeof type
          );
          compare = {
            $$typeof: REACT_MEMO_TYPE,
            type,
            compare: void 0 === compare ? null : compare
          };
          var ownName;
          Object.defineProperty(compare, "displayName", {
            enumerable: false,
            configurable: true,
            get: function() {
              return ownName;
            },
            set: function(name) {
              ownName = name;
              type.name || type.displayName || (Object.defineProperty(type, "name", { value: name }), type.displayName = name);
            }
          });
          return compare;
        };
        exports$1.startTransition = function(scope) {
          var prevTransition = ReactSharedInternals.T, currentTransition = {};
          currentTransition._updatedFibers = /* @__PURE__ */ new Set();
          ReactSharedInternals.T = currentTransition;
          try {
            var returnValue = scope(), onStartTransitionFinish = ReactSharedInternals.S;
            null !== onStartTransitionFinish && onStartTransitionFinish(currentTransition, returnValue);
            "object" === typeof returnValue && null !== returnValue && "function" === typeof returnValue.then && (ReactSharedInternals.asyncTransitions++, returnValue.then(releaseAsyncTransition, releaseAsyncTransition), returnValue.then(noop, reportGlobalError));
          } catch (error) {
            reportGlobalError(error);
          } finally {
            null === prevTransition && currentTransition._updatedFibers && (scope = currentTransition._updatedFibers.size, currentTransition._updatedFibers.clear(), 10 < scope && console.warn(
              "Detected a large number of updates inside startTransition. If this is due to a subscription please re-write it to use React provided hooks. Otherwise concurrent mode guarantees are off the table."
            )), null !== prevTransition && null !== currentTransition.types && (null !== prevTransition.types && prevTransition.types !== currentTransition.types && console.error(
              "We expected inner Transitions to have transferred the outer types set and that you cannot add to the outer Transition while inside the inner.This is a bug in React."
            ), prevTransition.types = currentTransition.types), ReactSharedInternals.T = prevTransition;
          }
        };
        exports$1.unstable_useCacheRefresh = function() {
          return resolveDispatcher().useCacheRefresh();
        };
        exports$1.use = function(usable) {
          return resolveDispatcher().use(usable);
        };
        exports$1.useActionState = function(action, initialState, permalink) {
          return resolveDispatcher().useActionState(
            action,
            initialState,
            permalink
          );
        };
        exports$1.useCallback = function(callback, deps) {
          return resolveDispatcher().useCallback(callback, deps);
        };
        exports$1.useContext = function(Context) {
          var dispatcher = resolveDispatcher();
          Context.$$typeof === REACT_CONSUMER_TYPE && console.error(
            "Calling useContext(Context.Consumer) is not supported and will cause bugs. Did you mean to call useContext(Context) instead?"
          );
          return dispatcher.useContext(Context);
        };
        exports$1.useDebugValue = function(value, formatterFn) {
          return resolveDispatcher().useDebugValue(value, formatterFn);
        };
        exports$1.useDeferredValue = function(value, initialValue) {
          return resolveDispatcher().useDeferredValue(value, initialValue);
        };
        exports$1.useEffect = function(create, deps) {
          null == create && console.warn(
            "React Hook useEffect requires an effect callback. Did you forget to pass a callback to the hook?"
          );
          return resolveDispatcher().useEffect(create, deps);
        };
        exports$1.useEffectEvent = function(callback) {
          return resolveDispatcher().useEffectEvent(callback);
        };
        exports$1.useId = function() {
          return resolveDispatcher().useId();
        };
        exports$1.useImperativeHandle = function(ref, create, deps) {
          return resolveDispatcher().useImperativeHandle(ref, create, deps);
        };
        exports$1.useInsertionEffect = function(create, deps) {
          null == create && console.warn(
            "React Hook useInsertionEffect requires an effect callback. Did you forget to pass a callback to the hook?"
          );
          return resolveDispatcher().useInsertionEffect(create, deps);
        };
        exports$1.useLayoutEffect = function(create, deps) {
          null == create && console.warn(
            "React Hook useLayoutEffect requires an effect callback. Did you forget to pass a callback to the hook?"
          );
          return resolveDispatcher().useLayoutEffect(create, deps);
        };
        exports$1.useMemo = function(create, deps) {
          return resolveDispatcher().useMemo(create, deps);
        };
        exports$1.useOptimistic = function(passthrough, reducer) {
          return resolveDispatcher().useOptimistic(passthrough, reducer);
        };
        exports$1.useReducer = function(reducer, initialArg, init) {
          return resolveDispatcher().useReducer(reducer, initialArg, init);
        };
        exports$1.useRef = function(initialValue) {
          return resolveDispatcher().useRef(initialValue);
        };
        exports$1.useState = function(initialState) {
          return resolveDispatcher().useState(initialState);
        };
        exports$1.useSyncExternalStore = function(subscribe, getSnapshot, getServerSnapshot) {
          return resolveDispatcher().useSyncExternalStore(
            subscribe,
            getSnapshot,
            getServerSnapshot
          );
        };
        exports$1.useTransition = function() {
          return resolveDispatcher().useTransition();
        };
        exports$1.version = "19.2.4";
        "undefined" !== typeof __REACT_DEVTOOLS_GLOBAL_HOOK__ && "function" === typeof __REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStop && __REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStop(Error());
      }();
    })(react_development, react_development.exports);
    return react_development.exports;
  }
  var hasRequiredReact;
  function requireReact() {
    if (hasRequiredReact) return react.exports;
    hasRequiredReact = 1;
    if (process.env.NODE_ENV === "production") {
      react.exports = requireReact_production();
    } else {
      react.exports = requireReact_development();
    }
    return react.exports;
  }
  /**
   * @license React
   * react-jsx-runtime.development.js
   *
   * Copyright (c) Meta Platforms, Inc. and affiliates.
   *
   * This source code is licensed under the MIT license found in the
   * LICENSE file in the root directory of this source tree.
   */
  var hasRequiredReactJsxRuntime_development;
  function requireReactJsxRuntime_development() {
    if (hasRequiredReactJsxRuntime_development) return reactJsxRuntime_development;
    hasRequiredReactJsxRuntime_development = 1;
    "production" !== process.env.NODE_ENV && function() {
      function getComponentNameFromType(type) {
        if (null == type) return null;
        if ("function" === typeof type)
          return type.$$typeof === REACT_CLIENT_REFERENCE ? null : type.displayName || type.name || null;
        if ("string" === typeof type) return type;
        switch (type) {
          case REACT_FRAGMENT_TYPE:
            return "Fragment";
          case REACT_PROFILER_TYPE:
            return "Profiler";
          case REACT_STRICT_MODE_TYPE:
            return "StrictMode";
          case REACT_SUSPENSE_TYPE:
            return "Suspense";
          case REACT_SUSPENSE_LIST_TYPE:
            return "SuspenseList";
          case REACT_ACTIVITY_TYPE:
            return "Activity";
        }
        if ("object" === typeof type)
          switch ("number" === typeof type.tag && console.error(
            "Received an unexpected object in getComponentNameFromType(). This is likely a bug in React. Please file an issue."
          ), type.$$typeof) {
            case REACT_PORTAL_TYPE:
              return "Portal";
            case REACT_CONTEXT_TYPE:
              return type.displayName || "Context";
            case REACT_CONSUMER_TYPE:
              return (type._context.displayName || "Context") + ".Consumer";
            case REACT_FORWARD_REF_TYPE:
              var innerType = type.render;
              type = type.displayName;
              type || (type = innerType.displayName || innerType.name || "", type = "" !== type ? "ForwardRef(" + type + ")" : "ForwardRef");
              return type;
            case REACT_MEMO_TYPE:
              return innerType = type.displayName || null, null !== innerType ? innerType : getComponentNameFromType(type.type) || "Memo";
            case REACT_LAZY_TYPE:
              innerType = type._payload;
              type = type._init;
              try {
                return getComponentNameFromType(type(innerType));
              } catch (x) {
              }
          }
        return null;
      }
      function testStringCoercion(value) {
        return "" + value;
      }
      function checkKeyStringCoercion(value) {
        try {
          testStringCoercion(value);
          var JSCompiler_inline_result = false;
        } catch (e) {
          JSCompiler_inline_result = true;
        }
        if (JSCompiler_inline_result) {
          JSCompiler_inline_result = console;
          var JSCompiler_temp_const = JSCompiler_inline_result.error;
          var JSCompiler_inline_result$jscomp$0 = "function" === typeof Symbol && Symbol.toStringTag && value[Symbol.toStringTag] || value.constructor.name || "Object";
          JSCompiler_temp_const.call(
            JSCompiler_inline_result,
            "The provided key is an unsupported type %s. This value must be coerced to a string before using it here.",
            JSCompiler_inline_result$jscomp$0
          );
          return testStringCoercion(value);
        }
      }
      function getTaskName(type) {
        if (type === REACT_FRAGMENT_TYPE) return "<>";
        if ("object" === typeof type && null !== type && type.$$typeof === REACT_LAZY_TYPE)
          return "<...>";
        try {
          var name = getComponentNameFromType(type);
          return name ? "<" + name + ">" : "<...>";
        } catch (x) {
          return "<...>";
        }
      }
      function getOwner() {
        var dispatcher = ReactSharedInternals.A;
        return null === dispatcher ? null : dispatcher.getOwner();
      }
      function UnknownOwner() {
        return Error("react-stack-top-frame");
      }
      function hasValidKey(config) {
        if (hasOwnProperty.call(config, "key")) {
          var getter = Object.getOwnPropertyDescriptor(config, "key").get;
          if (getter && getter.isReactWarning) return false;
        }
        return void 0 !== config.key;
      }
      function defineKeyPropWarningGetter(props, displayName) {
        function warnAboutAccessingKey() {
          specialPropKeyWarningShown || (specialPropKeyWarningShown = true, console.error(
            "%s: `key` is not a prop. Trying to access it will result in `undefined` being returned. If you need to access the same value within the child component, you should pass it as a different prop. (https://react.dev/link/special-props)",
            displayName
          ));
        }
        warnAboutAccessingKey.isReactWarning = true;
        Object.defineProperty(props, "key", {
          get: warnAboutAccessingKey,
          configurable: true
        });
      }
      function elementRefGetterWithDeprecationWarning() {
        var componentName = getComponentNameFromType(this.type);
        didWarnAboutElementRef[componentName] || (didWarnAboutElementRef[componentName] = true, console.error(
          "Accessing element.ref was removed in React 19. ref is now a regular prop. It will be removed from the JSX Element type in a future release."
        ));
        componentName = this.props.ref;
        return void 0 !== componentName ? componentName : null;
      }
      function ReactElement(type, key, props, owner, debugStack, debugTask) {
        var refProp = props.ref;
        type = {
          $$typeof: REACT_ELEMENT_TYPE,
          type,
          key,
          props,
          _owner: owner
        };
        null !== (void 0 !== refProp ? refProp : null) ? Object.defineProperty(type, "ref", {
          enumerable: false,
          get: elementRefGetterWithDeprecationWarning
        }) : Object.defineProperty(type, "ref", { enumerable: false, value: null });
        type._store = {};
        Object.defineProperty(type._store, "validated", {
          configurable: false,
          enumerable: false,
          writable: true,
          value: 0
        });
        Object.defineProperty(type, "_debugInfo", {
          configurable: false,
          enumerable: false,
          writable: true,
          value: null
        });
        Object.defineProperty(type, "_debugStack", {
          configurable: false,
          enumerable: false,
          writable: true,
          value: debugStack
        });
        Object.defineProperty(type, "_debugTask", {
          configurable: false,
          enumerable: false,
          writable: true,
          value: debugTask
        });
        Object.freeze && (Object.freeze(type.props), Object.freeze(type));
        return type;
      }
      function jsxDEVImpl(type, config, maybeKey, isStaticChildren, debugStack, debugTask) {
        var children = config.children;
        if (void 0 !== children)
          if (isStaticChildren)
            if (isArrayImpl(children)) {
              for (isStaticChildren = 0; isStaticChildren < children.length; isStaticChildren++)
                validateChildKeys(children[isStaticChildren]);
              Object.freeze && Object.freeze(children);
            } else
              console.error(
                "React.jsx: Static children should always be an array. You are likely explicitly calling React.jsxs or React.jsxDEV. Use the Babel transform instead."
              );
          else validateChildKeys(children);
        if (hasOwnProperty.call(config, "key")) {
          children = getComponentNameFromType(type);
          var keys = Object.keys(config).filter(function(k) {
            return "key" !== k;
          });
          isStaticChildren = 0 < keys.length ? "{key: someKey, " + keys.join(": ..., ") + ": ...}" : "{key: someKey}";
          didWarnAboutKeySpread[children + isStaticChildren] || (keys = 0 < keys.length ? "{" + keys.join(": ..., ") + ": ...}" : "{}", console.error(
            'A props object containing a "key" prop is being spread into JSX:\n  let props = %s;\n  <%s {...props} />\nReact keys must be passed directly to JSX without using spread:\n  let props = %s;\n  <%s key={someKey} {...props} />',
            isStaticChildren,
            children,
            keys,
            children
          ), didWarnAboutKeySpread[children + isStaticChildren] = true);
        }
        children = null;
        void 0 !== maybeKey && (checkKeyStringCoercion(maybeKey), children = "" + maybeKey);
        hasValidKey(config) && (checkKeyStringCoercion(config.key), children = "" + config.key);
        if ("key" in config) {
          maybeKey = {};
          for (var propName in config)
            "key" !== propName && (maybeKey[propName] = config[propName]);
        } else maybeKey = config;
        children && defineKeyPropWarningGetter(
          maybeKey,
          "function" === typeof type ? type.displayName || type.name || "Unknown" : type
        );
        return ReactElement(
          type,
          children,
          maybeKey,
          getOwner(),
          debugStack,
          debugTask
        );
      }
      function validateChildKeys(node) {
        isValidElement(node) ? node._store && (node._store.validated = 1) : "object" === typeof node && null !== node && node.$$typeof === REACT_LAZY_TYPE && ("fulfilled" === node._payload.status ? isValidElement(node._payload.value) && node._payload.value._store && (node._payload.value._store.validated = 1) : node._store && (node._store.validated = 1));
      }
      function isValidElement(object) {
        return "object" === typeof object && null !== object && object.$$typeof === REACT_ELEMENT_TYPE;
      }
      var React = requireReact(), REACT_ELEMENT_TYPE = Symbol.for("react.transitional.element"), REACT_PORTAL_TYPE = Symbol.for("react.portal"), REACT_FRAGMENT_TYPE = Symbol.for("react.fragment"), REACT_STRICT_MODE_TYPE = Symbol.for("react.strict_mode"), REACT_PROFILER_TYPE = Symbol.for("react.profiler"), REACT_CONSUMER_TYPE = Symbol.for("react.consumer"), REACT_CONTEXT_TYPE = Symbol.for("react.context"), REACT_FORWARD_REF_TYPE = Symbol.for("react.forward_ref"), REACT_SUSPENSE_TYPE = Symbol.for("react.suspense"), REACT_SUSPENSE_LIST_TYPE = Symbol.for("react.suspense_list"), REACT_MEMO_TYPE = Symbol.for("react.memo"), REACT_LAZY_TYPE = Symbol.for("react.lazy"), REACT_ACTIVITY_TYPE = Symbol.for("react.activity"), REACT_CLIENT_REFERENCE = Symbol.for("react.client.reference"), ReactSharedInternals = React.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE, hasOwnProperty = Object.prototype.hasOwnProperty, isArrayImpl = Array.isArray, createTask = console.createTask ? console.createTask : function() {
        return null;
      };
      React = {
        react_stack_bottom_frame: function(callStackForError) {
          return callStackForError();
        }
      };
      var specialPropKeyWarningShown;
      var didWarnAboutElementRef = {};
      var unknownOwnerDebugStack = React.react_stack_bottom_frame.bind(
        React,
        UnknownOwner
      )();
      var unknownOwnerDebugTask = createTask(getTaskName(UnknownOwner));
      var didWarnAboutKeySpread = {};
      reactJsxRuntime_development.Fragment = REACT_FRAGMENT_TYPE;
      reactJsxRuntime_development.jsx = function(type, config, maybeKey) {
        var trackActualOwner = 1e4 > ReactSharedInternals.recentlyCreatedOwnerStacks++;
        return jsxDEVImpl(
          type,
          config,
          maybeKey,
          false,
          trackActualOwner ? Error("react-stack-top-frame") : unknownOwnerDebugStack,
          trackActualOwner ? createTask(getTaskName(type)) : unknownOwnerDebugTask
        );
      };
      reactJsxRuntime_development.jsxs = function(type, config, maybeKey) {
        var trackActualOwner = 1e4 > ReactSharedInternals.recentlyCreatedOwnerStacks++;
        return jsxDEVImpl(
          type,
          config,
          maybeKey,
          true,
          trackActualOwner ? Error("react-stack-top-frame") : unknownOwnerDebugStack,
          trackActualOwner ? createTask(getTaskName(type)) : unknownOwnerDebugTask
        );
      };
    }();
    return reactJsxRuntime_development;
  }
  if (process.env.NODE_ENV === "production") {
    jsxRuntime.exports = requireReactJsxRuntime_production();
  } else {
    jsxRuntime.exports = requireReactJsxRuntime_development();
  }
  var jsxRuntimeExports = jsxRuntime.exports;
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
  const CLS_SIDEBAR_SCROLL = "flex-1 overflow-y-auto";
  const CLS_BUCKET_HEADER = "px-3 py-1.5 flex items-center justify-between";
  const CLS_BUCKET_LABEL = "text-[9px] font-bold uppercase tracking-wider";
  const CLS_BUCKET_COUNT = "text-[9px] text-slate-400 font-mono";
  const CLS_ITEM_ROW = "px-3 py-1.5 flex items-center gap-2 border-b border-slate-50 hover:bg-slate-50 transition-colors";
  const CLS_DRAG_HANDLE = "text-[11px] text-slate-300 flex-shrink-0 leading-none cursor-grab active:cursor-grabbing hover:text-slate-500 transition-colors px-0.5 py-1";
  const CLS_CAT_DOT = "w-2 h-2 rounded-full flex-shrink-0";
  const CLS_ITEM_TITLE = "text-[10px] text-slate-700 truncate flex-1 min-w-0";
  const CLS_ITEM_HOURS = "text-[9px] text-slate-400 font-mono flex-shrink-0";
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
  const CLS_HRSWK = "nga-hrswkstrip bg-slate-50 border-b border-slate-200 px-3 py-1.5 flex items-end gap-1 overflow-x-auto";
  const CLS_HRSWK_LABEL = "text-[9px] font-bold text-slate-400 uppercase tracking-wide mr-1 shrink-0 self-center";
  const CLS_HRSWK_COL = "flex flex-col items-center gap-0.5 shrink-0 w-12";
  const CLS_HRSWK_TRACK = "w-full rounded-sm overflow-hidden bg-slate-200 h-2";
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
  const ZOOMS$5 = ["day", "week", "month", "quarter"];
  const GROUPS$1 = ["priority", "epic"];
  function Sep$1() {
    return /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_SEP, children: "|" });
  }
  function TitleBar$1({ config, state, dispatch, data }) {
    const s = data.stats;
    const summary = s.scheduled + " scheduled · " + (s.est || 0) + "h";
    return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_TITLEBAR, "data-slot": "TitleBar", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_TITLE_BRAND, children: config.title || "Pro Forma Timeline" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_VERSION_PILL, children: config.version || "v10 · Nimbus Gantt" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(Sep$1, {}),
      CLOUD_NIMBUS_VIEW_MODES.map((v) => {
        const on = state.viewMode === v.id;
        return /* @__PURE__ */ jsxRuntimeExports.jsxs(
          "button",
          {
            type: "button",
            className: CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_VIOLET : CLS_PILL_BTN_IDLE_VIOLET),
            onClick: () => dispatch({ type: "SET_VIEW", mode: v.id }),
            children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "mr-1", children: v.icon }),
              v.label
            ]
          },
          v.id
        );
      }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(Sep$1, {}),
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        "button",
        {
          type: "button",
          className: CLS_PILL_BTN_BASE + " " + (state.sidebarOpen ? CLS_PILL_BTN_ACTIVE_BLUE : CLS_PILL_BTN_IDLE_BLUE),
          onClick: () => dispatch({ type: "TOGGLE_SIDEBAR" }),
          children: "Sidebar"
        }
      ),
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        "button",
        {
          type: "button",
          className: CLS_PILL_BTN_BASE + " " + (state.statsOpen ? CLS_PILL_BTN_ACTIVE_BLUE : CLS_PILL_BTN_IDLE_BLUE),
          onClick: () => dispatch({ type: "TOGGLE_STATS" }),
          children: "Stats"
        }
      ),
      config.features.auditPanel && /* @__PURE__ */ jsxRuntimeExports.jsx(
        "button",
        {
          type: "button",
          className: CLS_PILL_BTN_BASE + " " + (state.auditPanelOpen ? CLS_PILL_BTN_ACTIVE_BLUE : CLS_PILL_BTN_IDLE_BLUE),
          onClick: () => dispatch({ type: "TOGGLE_AUDIT_PANEL" }),
          children: "Audit"
        }
      ),
      /* @__PURE__ */ jsxRuntimeExports.jsx(Sep$1, {}),
      ZOOMS$5.map((z) => {
        const on = state.zoom === z;
        return /* @__PURE__ */ jsxRuntimeExports.jsx(
          "button",
          {
            type: "button",
            className: CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_SLATE : CLS_PILL_BTN_IDLE_SLATE),
            onClick: () => dispatch({ type: "SET_ZOOM", zoom: z }),
            children: z.charAt(0).toUpperCase() + z.slice(1)
          },
          z
        );
      }),
      config.features.groupByToggle && /* @__PURE__ */ jsxRuntimeExports.jsxs(jsxRuntimeExports.Fragment, { children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Sep$1, {}),
        GROUPS$1.map((g) => {
          const on = state.groupBy === g;
          return /* @__PURE__ */ jsxRuntimeExports.jsx(
            "button",
            {
              type: "button",
              className: CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_SLATE : CLS_PILL_BTN_IDLE_SLATE),
              onClick: () => dispatch({ type: "SET_GROUP_BY", groupBy: g }),
              children: g === "priority" ? "Priority" : "Epics"
            },
            g
          );
        })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: CLS_TB_FILL }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_TB_SUMMARY, children: summary })
    ] });
  }
  const ZOOMS$4 = ["day", "week", "month", "quarter"];
  function ZoomBar$1({ state, dispatch }) {
    return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: CLS_ZOOMBAR, "data-slot": "ZoomBar", children: ZOOMS$4.map((z) => {
      const on = state.zoom === z;
      return /* @__PURE__ */ jsxRuntimeExports.jsx(
        "button",
        {
          type: "button",
          className: CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_SLATE : CLS_PILL_BTN_IDLE_SLATE),
          onClick: () => dispatch({ type: "SET_ZOOM", zoom: z }),
          children: z.charAt(0).toUpperCase() + z.slice(1)
        },
        z
      );
    }) });
  }
  function Sep() {
    return /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_SEP + " mx-1", children: "|" });
  }
  function FilterBar({ config, state, dispatch, data }) {
    const totalH = CLOUD_NIMBUS_POOL.reduce((s2, m) => s2 + m.hoursPerMonth, 0);
    const s = data.stats;
    const filters = config.filters;
    return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: CLS_FILTERBAR, "data-slot": "FilterBar", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_FILTERBAR_INNER, children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_FILTERBAR_LABEL, children: "View:" }),
      filters.map((f) => {
        const on = state.filter === f.id;
        return /* @__PURE__ */ jsxRuntimeExports.jsx(
          "button",
          {
            type: "button",
            className: CLS_FILTER_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_BLUE : CLS_PILL_BTN_IDLE_BLUE),
            onClick: () => dispatch({ type: "SET_FILTER", id: f.id }),
            children: f.label
          },
          f.id
        );
      }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(Sep, {}),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_SEARCH_WRAP, children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_SEARCH_ICON, children: "🔎" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(
          "input",
          {
            "data-testid": "gantt-search-input",
            type: "text",
            placeholder: "Search T-NNNN, title, owner…",
            className: CLS_SEARCH_INPUT,
            value: state.search,
            onChange: (e) => dispatch({ type: "SET_SEARCH", q: e.target.value })
          }
        ),
        state.search ? /* @__PURE__ */ jsxRuntimeExports.jsx(
          "button",
          {
            type: "button",
            className: CLS_SEARCH_CLEAR,
            onClick: () => dispatch({ type: "SET_SEARCH", q: "" }),
            children: "×"
          }
        ) : null
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(Sep, {}),
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_FILTERBAR_LABEL, children: "Colors:" }),
      CLOUD_NIMBUS_CATEGORIES.map((cat) => {
        const n = s.categoryCounts[cat.label] || 0;
        if (n <= 0) return null;
        return /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: CLS_LEGEND_CHIP, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_LEGEND_SWATCH, style: { background: cat.color } }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: CLS_LEGEND_TEXT, children: [
            cat.label,
            " (",
            n,
            ")"
          ] })
        ] }, cat.category);
      }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(Sep, {}),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("button", { type: "button", className: CLS_TEAM_PILL, children: [
        "Team ",
        /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { children: [
          CLOUD_NIMBUS_POOL.length,
          "×"
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: CLS_CAPACITY_TEXT, children: [
        totalH,
        "h/mo"
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("button", { type: "button", className: CLS_AUTO_SCHED_BTN, children: "Auto-Schedule" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex-1" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: CLS_COUNT_LABEL, children: [
        s.total,
        " items · ",
        s.scheduled,
        " scheduled · ",
        s.needDates,
        " need dates"
      ] }),
      state.pendingPatchCount > 0 ? /* @__PURE__ */ jsxRuntimeExports.jsx(
        "button",
        {
          type: "button",
          className: CLS_RESET_LINK,
          onClick: () => dispatch({ type: "RESET_PATCHES" }),
          children: "Reset changes"
        }
      ) : null
    ] }) });
  }
  function KpiCard({ label, value, tone, hint }) {
    const t = STATS_TONE[tone] || STATS_TONE.slate;
    return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_KPI_CARD_BASE + " " + t.border, children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: CLS_KPI_LABEL + " " + t.label, children: label }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: CLS_KPI_VALUE + " " + t.value, children: value }),
      hint ? /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: CLS_KPI_HINT, children: hint }) : null
    ] });
  }
  function StatsPanel({ state, data }) {
    if (!state.statsOpen) return null;
    const s = data.stats;
    const hrsLow = s.estLow;
    const hrsHigh = s.est;
    const logged = s.logged;
    const hoursPerMonth = 120;
    const monthsLow = hrsLow > 0 ? (hrsLow / hoursPerMonth).toFixed(1) : "0";
    const monthsHigh = hrsHigh > 0 ? (hrsHigh / hoursPerMonth).toFixed(1) : "0";
    const hoursRange = hrsLow < hrsHigh && hrsLow > 0 ? hrsLow + "–" + hrsHigh + "h" : hrsHigh + "h";
    return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: CLS_STATS_PANEL, "data-slot": "StatsPanel", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_STATS_GRID, children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(KpiCard, { label: "Items in View", value: String(s.total), tone: "slate" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(KpiCard, { label: "Active (scheduled)", value: String(s.scheduled), tone: "emerald" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(KpiCard, { label: "Scheduled", value: String(s.scheduled), tone: "blue", hint: "of " + s.total + " total" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(KpiCard, { label: "Hours Logged", value: logged + "h", tone: "purple", hint: "Actuals" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(KpiCard, { label: "Hours Range", value: hoursRange, tone: "amber", hint: "Estimate envelope" }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_KPI_CARD_BASE + " border-indigo-200", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: CLS_KPI_LABEL + " text-indigo-700", children: "Months to complete" }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: CLS_KPI_VALUE + " text-indigo-700", children: [
          monthsLow,
          "–",
          monthsHigh
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-0.5 flex items-center gap-1", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[9px] text-indigo-700", children: "at" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[10px] font-mono font-bold text-indigo-700", children: hoursPerMonth }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[9px] text-indigo-700", children: "h/mo" })
        ] })
      ] })
    ] }) });
  }
  function Sidebar({ config, data, dispatch }) {
    const tasks = data.tasks;
    return /* @__PURE__ */ jsxRuntimeExports.jsxs("aside", { className: CLS_SIDEBAR, "data-slot": "Sidebar", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_SIDEBAR_HEADER, children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: CLS_SIDEBAR_LABEL_BIG, children: "Priority Groups" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: CLS_SIDEBAR_LABEL_SM, children: "Drag ☰ to move between buckets" })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: CLS_SIDEBAR_SCROLL, children: config.buckets.map((b) => {
        const members = tasks.filter((t) => t.priorityGroup === b.id && !t.parentWorkItemId);
        const totalHours = members.reduce((s, t) => s + (Number(t.estimatedHours) || 0), 0);
        const meta = BUCKET_META[b.id] || BUCKET_META.deferred;
        return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { "data-group-id": b.id, className: "border-b " + meta.border + " transition-colors", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_BUCKET_HEADER + " " + meta.bg, children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_BUCKET_LABEL + " " + meta.text, children: meta.label }),
            /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: CLS_BUCKET_COUNT, children: [
              members.length,
              " · ",
              Math.round(totalHours),
              "h"
            ] })
          ] }),
          members.length === 0 ? /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "px-3 py-3 text-[10px] text-slate-400 italic", children: "Drop items here" }) : members.map((it) => {
            const cat = (it.stage || "").toLowerCase().indexOf("backlog") === 0 ? "backlog" : (it.stage || "").toLowerCase().indexOf("paused") === 0 ? "paused" : (it.stage || "").toLowerCase().indexOf("done") === 0 ? "done" : "in-flight";
            const dot = CATEGORY_DOT[cat] || "#94a3b8";
            return /* @__PURE__ */ jsxRuntimeExports.jsxs(
              "div",
              {
                "data-item-id": String(it.id),
                "data-item-title": it.title,
                className: CLS_ITEM_ROW,
                onClick: () => dispatch({ type: "TOGGLE_DETAIL", taskId: String(it.id) }),
                children: [
                  /* @__PURE__ */ jsxRuntimeExports.jsx("span", { "data-drag-handle": "1", className: CLS_DRAG_HANDLE, children: "☰" }),
                  /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_CAT_DOT, style: { background: dot } }),
                  /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_ITEM_TITLE, children: it.title }),
                  /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: CLS_ITEM_HOURS, children: [
                    Number(it.estimatedHours) || 0,
                    "h"
                  ] })
                ]
              },
              String(it.id)
            );
          })
        ] }, b.id);
      }) })
    ] });
  }
  var reactExports = requireReact();
  function DetailPanel({ state, data, dispatch }) {
    if (!state.selectedTaskId) return null;
    const task = data.tasks.find((t) => String(t.id) === state.selectedTaskId);
    if (!task) return null;
    const categoryColor = "#64748b";
    return /* @__PURE__ */ jsxRuntimeExports.jsxs(
      "div",
      {
        className: CLS_DETAIL,
        "data-slot": "DetailPanel",
        style: { bottom: 80, right: 24, width: 380, borderColor: categoryColor },
        children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_DETAIL_HEADER, style: { background: categoryColor + "15" }, children: [
            /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center gap-2 min-w-0", children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "w-2.5 h-2.5 rounded-full flex-shrink-0", style: { background: categoryColor } }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[10px] font-mono font-bold text-slate-500 flex-shrink-0", children: String(task.id) }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-xs font-bold text-slate-900 truncate", children: task.title })
            ] }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex items-center gap-1 flex-shrink-0 ml-2", children: /* @__PURE__ */ jsxRuntimeExports.jsx(
              "button",
              {
                type: "button",
                className: "text-slate-400 hover:text-slate-700 text-sm px-1 transition-colors",
                onClick: () => dispatch({ type: "TOGGLE_DETAIL" }),
                children: "×"
              }
            ) })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_DETAIL_BODY, children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex items-center gap-2", children: /* @__PURE__ */ jsxRuntimeExports.jsx(
              "span",
              {
                className: CLS_CATEGORY_PILL,
                style: { background: categoryColor + "20", color: categoryColor },
                children: task.stage || "—"
              }
            ) }),
            /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid grid-cols-2 gap-x-4 gap-y-1.5 pt-1", children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Status", value: task.stage || "—" }),
              /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Priority", value: task.priorityGroup || "—" }),
              /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Start", value: task.startDate || "—" }),
              /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "End", value: task.endDate || "—" }),
              /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Estimated", value: task.estimatedHours ? task.estimatedHours + "h" : "—" }),
              /* @__PURE__ */ jsxRuntimeExports.jsx(Field, { label: "Logged", value: task.loggedHours ? task.loggedHours + "h" : "—" })
            ] })
          ] })
        ]
      }
    );
  }
  function Field({ label, value }) {
    return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[9px] text-slate-400 uppercase tracking-wide", children: label }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-slate-900", children: value })
    ] });
  }
  function AuditPanel({ state, dispatch }) {
    const [note, setNote] = reactExports.useState("");
    const dirty = state.pendingPatchCount > 0;
    return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: CLS_AUDIT, "data-slot": "AuditPanel", "data-testid": "audit-panel", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex flex-wrap items-center gap-2", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_AUDIT_LABEL, children: "📤 Audit pass" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: dirty ? CLS_AUDIT_STATUS_DIRTY : CLS_AUDIT_STATUS_CLEAN, children: dirty ? "unsaved changes" : "clean" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        "input",
        {
          type: "text",
          placeholder: "commit note (optional)",
          className: CLS_AUDIT_INPUT,
          "data-testid": "audit-note-input",
          value: note,
          onChange: (e) => setNote(e.target.value)
        }
      ),
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        "button",
        {
          type: "button",
          className: CLS_AUDIT_SUBMIT,
          "data-testid": "audit-submit-btn",
          disabled: !dirty,
          onClick: () => {
            dispatch({ type: "RESET_PATCHES" });
            setNote("");
          },
          children: "📤 Submit + commit"
        }
      ),
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        "button",
        {
          type: "button",
          className: CLS_AUDIT_RESET,
          "data-testid": "audit-reset-btn",
          onClick: () => {
            setNote("");
            dispatch({ type: "RESET_PATCHES" });
          },
          children: "↺ Reset"
        }
      )
    ] }) });
  }
  function ContentArea$1(props) {
    const { config, state } = props;
    const ganttHostRef = reactExports.useRef(null);
    reactExports.useEffect(() => {
    }, []);
    return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_CONTENT_OUTER, "data-slot": "ContentArea", children: [
      state.sidebarOpen && config.features.sidebar ? /* @__PURE__ */ jsxRuntimeExports.jsxs(jsxRuntimeExports.Fragment, { children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: CLS_SIDEBAR_WRAP, style: { width: 280 }, children: /* @__PURE__ */ jsxRuntimeExports.jsx(Sidebar, { ...props }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: CLS_RESIZER })
      ] }) : null,
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: CLS_CONTENT, ref: ganttHostRef, "data-nga-gantt-host": "1" }),
      state.detailOpen && config.features.detailPanel ? /* @__PURE__ */ jsxRuntimeExports.jsx(DetailPanel, { ...props }) : null,
      state.auditPanelOpen && config.features.auditPanel ? /* @__PURE__ */ jsxRuntimeExports.jsx(AuditPanel, { ...props }) : null
    ] });
  }
  const MON$1 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const DAY_MS$1 = 24 * 3600 * 1e3;
  const WEEK_MS$1 = 7 * DAY_MS$1;
  const NUM_WEEKS$1 = 8;
  function computeWeeks$1(tasks) {
    const now = /* @__PURE__ */ new Date();
    const dow = now.getDay();
    const monday = new Date(now);
    monday.setDate(now.getDate() - (dow === 0 ? 6 : dow - 1));
    monday.setHours(0, 0, 0, 0);
    const weeks = [];
    for (let i = 0; i < NUM_WEEKS$1; i++) {
      const s = new Date(monday.getTime() + i * WEEK_MS$1);
      weeks.push({
        startMs: s.getTime(),
        endMs: s.getTime() + WEEK_MS$1,
        label: MON$1[s.getMonth()] + String(s.getDate()),
        hours: 0,
        isCurrent: i === 0
      });
    }
    tasks.forEach((t) => {
      const h = Number(t.estimatedHours) || 0;
      if (!h || !t.startDate || !t.endDate || t.isInactive) return;
      const ts = (/* @__PURE__ */ new Date(t.startDate + "T00:00:00")).getTime();
      const te = (/* @__PURE__ */ new Date(t.endDate + "T00:00:00")).getTime();
      const td = Math.max(1, (te - ts) / DAY_MS$1);
      const hpd = h / td;
      weeks.forEach((w) => {
        const oS = Math.max(ts, w.startMs);
        const oE = Math.min(te, w.endMs);
        if (oE > oS) w.hours += hpd * (oE - oS) / DAY_MS$1;
      });
    });
    return weeks.map((w) => ({ label: w.label, hours: Math.round(w.hours), isCurrent: w.isCurrent }));
  }
  function HrsWkStrip({ data }) {
    const weeks = computeWeeks$1(data.tasks);
    const maxH = Math.max(1, ...weeks.map((w) => w.hours));
    return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_HRSWK, "data-slot": "HrsWkStrip", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: CLS_HRSWK_LABEL, children: "Hrs/wk" }),
      weeks.map((w) => {
        const pct = Math.round(w.hours / maxH * 100);
        return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: CLS_HRSWK_COL, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: "text-[9px] font-bold " + (w.isCurrent ? "text-indigo-600" : "text-slate-500"), children: [
            w.hours,
            "h"
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: CLS_HRSWK_TRACK, children: /* @__PURE__ */ jsxRuntimeExports.jsx(
            "div",
            {
              className: "h-full rounded-sm " + (w.isCurrent ? "bg-indigo-500" : "bg-slate-400"),
              style: { width: pct + "%" }
            }
          ) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[8px] " + (w.isCurrent ? "text-indigo-500 font-semibold" : "text-slate-400"), children: w.label })
        ] }, w.label);
      })
    ] });
  }
  function el$1(tag, className, styleText) {
    const e = document.createElement(tag);
    if (className) e.className = className;
    return e;
  }
  function clear(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
  }
  const ZOOMS$3 = ["day", "week", "month", "quarter"];
  const GROUPS = ["priority", "epic"];
  function mkSep$1() {
    const s = el$1("span", CLS_SEP);
    s.textContent = "|";
    return s;
  }
  function TitleBarVanilla$1(initial) {
    const root = el$1("div", CLS_TITLEBAR);
    root.setAttribute("data-slot", "TitleBar");
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
      CLOUD_NIMBUS_VIEW_MODES.forEach((v) => {
        const on = state.viewMode === v.id;
        const cls = CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_VIOLET : CLS_PILL_BTN_IDLE_VIOLET);
        const btn = el$1("button", cls);
        btn.innerHTML = '<span class="mr-1">' + v.icon + "</span>" + v.label;
        btn.addEventListener("click", () => dispatch({ type: "SET_VIEW", mode: v.id }));
        root.appendChild(btn);
      });
      root.appendChild(mkSep$1());
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
      ZOOMS$3.forEach((z) => {
        const on = state.zoom === z;
        const cls = CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_SLATE : CLS_PILL_BTN_IDLE_SLATE);
        const b = el$1("button", cls);
        b.textContent = z.charAt(0).toUpperCase() + z.slice(1);
        b.addEventListener("click", () => dispatch({ type: "SET_ZOOM", zoom: z }));
        root.appendChild(b);
      });
      if (config.features.groupByToggle) {
        root.appendChild(mkSep$1());
        GROUPS.forEach((g) => {
          const on = state.groupBy === g;
          const cls = CLS_PILL_BTN_BASE + " " + (on ? CLS_PILL_BTN_ACTIVE_SLATE : CLS_PILL_BTN_IDLE_SLATE);
          const b = el$1("button", cls);
          b.textContent = g === "priority" ? "Priority" : "Epics";
          b.addEventListener("click", () => dispatch({ type: "SET_GROUP_BY", groupBy: g }));
          root.appendChild(b);
        });
      }
      const fill = el$1("div", CLS_TB_FILL);
      root.appendChild(fill);
      const summary = el$1("span", CLS_TB_SUMMARY);
      summary.textContent = data.stats.scheduled + " scheduled · " + (data.stats.est || 0) + "h";
      root.appendChild(summary);
    }
    render(initial);
    return {
      el: root,
      update(p) {
        render(p);
      },
      destroy() {
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  const ZOOMS$2 = ["day", "week", "month", "quarter"];
  function ZoomBarVanilla$1(initial) {
    const root = el$1("div", CLS_ZOOMBAR);
    root.setAttribute("data-slot", "ZoomBar");
    function render(p) {
      clear(root);
      ZOOMS$2.forEach((z) => {
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
    function render(p) {
      clear(inner);
      const { config, state, dispatch, data } = p;
      const totalH = CLOUD_NIMBUS_POOL.reduce((s, m) => s + m.hoursPerMonth, 0);
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
      const input = el$1("input", CLS_SEARCH_INPUT);
      input.setAttribute("data-testid", "gantt-search-input");
      input.type = "text";
      input.placeholder = "Search T-NNNN, title, owner…";
      input.value = state.search;
      input.addEventListener("input", (e) => dispatch({ type: "SET_SEARCH", q: e.target.value }));
      sw.appendChild(input);
      if (state.search) {
        const clr = el$1("button", CLS_SEARCH_CLEAR);
        clr.textContent = "×";
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
      const teamBtn = el$1("button", CLS_TEAM_PILL);
      const tLbl = document.createElement("span");
      tLbl.textContent = "Team";
      teamBtn.appendChild(tLbl);
      const tCnt = document.createElement("span");
      tCnt.textContent = " " + CLOUD_NIMBUS_POOL.length + "×";
      teamBtn.appendChild(tCnt);
      inner.appendChild(teamBtn);
      const cap = el$1("span", CLS_CAPACITY_TEXT);
      cap.textContent = totalH + "h/mo";
      inner.appendChild(cap);
      const autoBtn = el$1("button", CLS_AUTO_SCHED_BTN);
      autoBtn.textContent = "Auto-Schedule";
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
    const root = el$1("div", CLS_STATS_PANEL);
    root.setAttribute("data-slot", "StatsPanel");
    const grid = el$1("div", CLS_STATS_GRID);
    root.appendChild(grid);
    function render(p) {
      root.style.display = p.state.statsOpen ? "" : "none";
      clear(grid);
      if (!p.state.statsOpen) return;
      const s = p.data.stats;
      const hrsLow = s.estLow;
      const hrsHigh = s.est;
      const logged = s.logged;
      const hpm = 120;
      const moLow = hrsLow > 0 ? (hrsLow / hpm).toFixed(1) : "0";
      const moHigh = hrsHigh > 0 ? (hrsHigh / hpm).toFixed(1) : "0";
      const hrsRange = hrsLow < hrsHigh && hrsLow > 0 ? hrsLow + "–" + hrsHigh + "h" : hrsHigh + "h";
      grid.appendChild(kpiCard("Items in View", String(s.total), "slate"));
      grid.appendChild(kpiCard("Active (scheduled)", String(s.scheduled), "emerald"));
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
      const mhint = el$1("div", "mt-0.5 flex items-center gap-1");
      const atSpan = el$1("span", "text-[9px] text-indigo-700");
      atSpan.textContent = "at";
      const num = el$1("span", "text-[10px] font-mono font-bold text-indigo-700");
      num.textContent = String(hpm);
      const u = el$1("span", "text-[9px] text-indigo-700");
      u.textContent = "h/mo";
      mhint.appendChild(atSpan);
      mhint.appendChild(num);
      mhint.appendChild(u);
      mcard.appendChild(mhint);
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
  function SidebarVanilla(initial) {
    const root = el$1("aside", CLS_SIDEBAR);
    root.setAttribute("data-slot", "Sidebar");
    function render(p) {
      clear(root);
      const { config, data, dispatch } = p;
      const hdr = el$1("div", CLS_SIDEBAR_HEADER);
      const big = el$1("p", CLS_SIDEBAR_LABEL_BIG);
      big.textContent = "Priority Groups";
      hdr.appendChild(big);
      const sm = el$1("p", CLS_SIDEBAR_LABEL_SM);
      sm.textContent = "Drag ☰ to move between buckets";
      hdr.appendChild(sm);
      root.appendChild(hdr);
      const scroll = el$1("div", CLS_SIDEBAR_SCROLL);
      root.appendChild(scroll);
      config.buckets.forEach((b) => {
        const members = data.tasks.filter((t) => t.priorityGroup === b.id && !t.parentWorkItemId);
        const totalHours = members.reduce((s, t) => s + (Number(t.estimatedHours) || 0), 0);
        const meta = BUCKET_META[b.id] || BUCKET_META.deferred;
        const sec = el$1("div", "border-b " + meta.border + " transition-colors");
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
          const empty = el$1("div", "px-3 py-3 text-[10px] text-slate-400 italic");
          empty.textContent = "Drop items here";
          sec.appendChild(empty);
        } else {
          members.forEach((it) => {
            const stage = (it.stage || "").toLowerCase();
            const cat = stage.indexOf("backlog") === 0 ? "backlog" : stage.indexOf("paused") === 0 ? "paused" : stage.indexOf("done") === 0 ? "done" : "in-flight";
            const dotColor = CATEGORY_DOT[cat] || "#94a3b8";
            const row = el$1("div", CLS_ITEM_ROW);
            row.setAttribute("data-item-id", String(it.id));
            row.setAttribute("data-item-title", it.title);
            row.addEventListener("click", () => dispatch({ type: "TOGGLE_DETAIL", taskId: String(it.id) }));
            const handle = el$1("span", CLS_DRAG_HANDLE);
            handle.setAttribute("data-drag-handle", "1");
            handle.textContent = "☰";
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
        }
        scroll.appendChild(sec);
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
  function DetailPanelVanilla(initial) {
    const root = el$1("div", CLS_DETAIL);
    root.setAttribute("data-slot", "DetailPanel");
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
      const catColor = "#64748b";
      root.style.bottom = "80px";
      root.style.right = "24px";
      root.style.width = "380px";
      root.style.borderColor = catColor;
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
      const closeBtn = el$1("button", "text-slate-400 hover:text-slate-700 text-sm px-1 transition-colors");
      closeBtn.textContent = "×";
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
      fld("Status", task.stage || "—");
      fld("Priority", task.priorityGroup || "—");
      fld("Start", task.startDate || "—");
      fld("End", task.endDate || "—");
      fld("Estimated", task.estimatedHours ? task.estimatedHours + "h" : "—");
      fld("Logged", task.loggedHours ? task.loggedHours + "h" : "—");
      body.appendChild(grid);
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
  function AuditPanelVanilla(initial) {
    const root = el$1("div", CLS_AUDIT);
    root.setAttribute("data-slot", "AuditPanel");
    root.setAttribute("data-testid", "audit-panel");
    let note = "";
    function render(p) {
      clear(root);
      const dirty = p.state.pendingPatchCount > 0;
      const inner = el$1("div", "flex flex-wrap items-center gap-2");
      const lbl = el$1("span", CLS_AUDIT_LABEL);
      lbl.textContent = "📤 Audit pass";
      inner.appendChild(lbl);
      const stat = el$1("span", dirty ? CLS_AUDIT_STATUS_DIRTY : CLS_AUDIT_STATUS_CLEAN);
      stat.textContent = dirty ? "unsaved changes" : "clean";
      inner.appendChild(stat);
      const input = el$1("input", CLS_AUDIT_INPUT);
      input.type = "text";
      input.placeholder = "commit note (optional)";
      input.value = note;
      input.setAttribute("data-testid", "audit-note-input");
      input.addEventListener("input", (e) => {
        note = e.target.value;
      });
      inner.appendChild(input);
      const submit = el$1("button", CLS_AUDIT_SUBMIT);
      submit.textContent = "📤 Submit + commit";
      submit.setAttribute("data-testid", "audit-submit-btn");
      submit.disabled = !dirty;
      submit.addEventListener("click", () => {
        p.dispatch({ type: "RESET_PATCHES" });
        note = "";
        render(p);
      });
      inner.appendChild(submit);
      const rst = el$1("button", CLS_AUDIT_RESET);
      rst.textContent = "↺ Reset";
      rst.setAttribute("data-testid", "audit-reset-btn");
      rst.addEventListener("click", () => {
        note = "";
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
  function ContentAreaVanilla$1(initial) {
    const root = el$1("div", CLS_CONTENT_OUTER);
    root.setAttribute("data-slot", "ContentArea");
    const host = el$1("div", CLS_CONTENT);
    host.setAttribute("data-nga-gantt-host", "1");
    let sidebarInst = null;
    let detailInst = null;
    let auditInst = null;
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
      if (p.state.auditPanelOpen && p.config.features.auditPanel) {
        if (!auditInst) auditInst = AuditPanelVanilla(p);
        else auditInst.update(p);
        root.appendChild(auditInst.el);
      } else if (auditInst) {
        auditInst.destroy();
        auditInst = null;
      }
    }
    render(initial);
    return {
      el: root,
      update: render,
      destroy() {
        if (sidebarInst) sidebarInst.destroy();
        if (detailInst) detailInst.destroy();
        if (auditInst) auditInst.destroy();
        clear(root);
        if (root.parentNode) root.parentNode.removeChild(root);
      }
    };
  }
  const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const DAY_MS = 24 * 3600 * 1e3;
  const WEEK_MS = 7 * DAY_MS;
  const NUM_WEEKS = 8;
  function computeWeeks(tasks) {
    const now = /* @__PURE__ */ new Date();
    const dow = now.getDay();
    const monday = new Date(now);
    monday.setDate(now.getDate() - (dow === 0 ? 6 : dow - 1));
    monday.setHours(0, 0, 0, 0);
    const weeks = [];
    for (let i = 0; i < NUM_WEEKS; i++) {
      const s = new Date(monday.getTime() + i * WEEK_MS);
      weeks.push({
        startMs: s.getTime(),
        endMs: s.getTime() + WEEK_MS,
        label: MON[s.getMonth()] + String(s.getDate()),
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
      const maxH = Math.max(1, ...weeks.map((w) => w.hours));
      const lbl = el$1("span", CLS_HRSWK_LABEL);
      lbl.textContent = "Hrs/wk";
      root.appendChild(lbl);
      weeks.forEach((w) => {
        const pct = Math.round(w.hours / maxH * 100);
        const col = el$1("div", CLS_HRSWK_COL);
        const hrsLbl = el$1("span", "text-[9px] font-bold " + (w.isCurrent ? "text-indigo-600" : "text-slate-500"));
        hrsLbl.textContent = w.hours + "h";
        col.appendChild(hrsLbl);
        const track = el$1("div", CLS_HRSWK_TRACK);
        const fill = el$1("div", "h-full rounded-sm " + (w.isCurrent ? "bg-indigo-500" : "bg-slate-400"));
        fill.style.width = pct + "%";
        track.appendChild(fill);
        col.appendChild(track);
        const dLbl = el$1("span", "text-[8px] " + (w.isCurrent ? "text-indigo-500 font-semibold" : "text-slate-400"));
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
  const cloudnimbusTemplate = defineTemplate({
    name: "cloudnimbus",
    defaults: {
      features: {
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
      },
      theme: cloudnimbusTheme,
      buckets: CLOUD_NIMBUS_PRIORITY_BUCKETS,
      filters: CLOUD_NIMBUS_FILTERS,
      views: CLOUD_NIMBUS_VIEWS,
      title: "Pro Forma Timeline",
      version: "v10 · Nimbus Gantt"
    },
    stylesheet: {
      // React bundler will resolve this import at build time (see comment below).
      importedByBundler: true
      // IIFE consumers pass `overrides.stylesheet.url` or set this via code in
      // the LWC wrapper. Left undefined here so IIFE callers can pick up the
      // static-resource URL dynamically.
    },
    components: {
      TitleBar: { react: TitleBar$1, vanilla: TitleBarVanilla$1 },
      ZoomBar: { react: ZoomBar$1, vanilla: ZoomBarVanilla$1 },
      FilterBar: { react: FilterBar, vanilla: FilterBarVanilla },
      StatsPanel: { react: StatsPanel, vanilla: StatsPanelVanilla },
      Sidebar: { react: Sidebar, vanilla: SidebarVanilla },
      ContentArea: { react: ContentArea$1, vanilla: ContentAreaVanilla$1 },
      DetailPanel: { react: DetailPanel, vanilla: DetailPanelVanilla },
      AuditPanel: { react: AuditPanel, vanilla: AuditPanelVanilla },
      HrsWkStrip: { react: HrsWkStrip, vanilla: HrsWkStripVanilla }
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
  const VIEWS$1 = ["gantt", "list"];
  function TitleBar({ config, state, dispatch }) {
    return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "nga-titlebar", "data-slot": "TitleBar", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("strong", { children: config.title || "Nimbus Gantt" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { style: { flex: 1 } }),
      VIEWS$1.map((v) => /* @__PURE__ */ jsxRuntimeExports.jsx(
        "button",
        {
          type: "button",
          onClick: () => dispatch({ type: "SET_VIEW", mode: v }),
          style: { fontWeight: state.viewMode === v ? 700 : 400 },
          children: v
        },
        v
      ))
    ] });
  }
  const ZOOMS$1 = ["day", "week", "month", "quarter"];
  function ZoomBar({ state, dispatch }) {
    return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "nga-zoombar", "data-slot": "ZoomBar", children: ZOOMS$1.map((z) => /* @__PURE__ */ jsxRuntimeExports.jsx(
      "button",
      {
        type: "button",
        onClick: () => dispatch({ type: "SET_ZOOM", zoom: z }),
        style: { fontWeight: state.zoom === z ? 700 : 400 },
        children: z
      },
      z
    )) });
  }
  function ContentArea(_props) {
    return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "nga-content-outer", "data-slot": "ContentArea", children: /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "nga-content", "data-nga-gantt-host": "1" }) });
  }
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
    stylesheet: {
      importedByBundler: true
    },
    components: {
      TitleBar: { react: TitleBar, vanilla: TitleBarVanilla },
      ZoomBar: { react: ZoomBar, vanilla: ZoomBarVanilla },
      ContentArea: { react: ContentArea, vanilla: ContentAreaVanilla }
    }
  });
  registerTemplate(minimalTemplate);
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
  function injectLegacyNgCss() {
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
  class IIFEApp {
    static mount(container, options) {
      var _a, _b, _c;
      IIFEApp.unmount(container);
      const templateName = options.template || "cloudnimbus";
      const overrides = options.overrides ? { ...options.overrides } : {};
      if (((_a = options.config) == null ? void 0 : _a.title) !== void 0) overrides.title = options.config.title;
      if (((_b = options.config) == null ? void 0 : _b.version) !== void 0) overrides.version = options.config.version;
      if ((_c = options.config) == null ? void 0 : _c.buckets) overrides.buckets = options.config.buckets;
      let tplConfig;
      try {
        tplConfig = resolveTemplate(templateName, overrides);
      } catch (err) {
        console.error("[nimbus-gantt] template resolution failed:", err);
        tplConfig = resolveTemplate("cloudnimbus", overrides);
      }
      if (options.engine) tplConfig.engine = options.engine;
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
      container.style.cssText = "height:100%;display:flex;flex-direction:column;background:" + tplConfig.theme.bg + ";overflow:hidden;font-family:" + tplConfig.theme.fontFamily;
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
        dispatch({ type: "PATCH" });
        rawOnPatch(patch);
        if (_patchRefreshTimer.t) clearTimeout(_patchRefreshTimer.t);
        _patchRefreshTimer.t = setTimeout(() => {
          _patchRefreshTimer.t = null;
          refreshGantt();
        }, 50);
      }
      function dispatch(ev) {
        const nextState = reduceAppState(state, ev);
        const stateChanged = nextState !== state;
        state = nextState;
        if (stateChanged) {
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
          const enabled = shouldRenderSlot(slotName, tplConfig.features);
          const existing = slotInstances.get(slotName);
          const slotDef = tplConfig.components[slotName];
          if (!enabled) {
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
            if (task && task.id && !isBucketId(task.id)) dispatch({ type: "TOGGLE_DETAIL", taskId: task.id });
          },
          onTaskDblClick: (task) => {
            if (task && task.id && !isBucketId(task.id)) dispatch({ type: "TOGGLE_DETAIL", taskId: task.id });
          },
          onTaskMove: (task, s, e) => {
            if (task && task.id && !isBucketId(task.id)) onTaskPatch({ id: task.id, startDate: s, endDate: e });
          },
          onTaskResize: (task, s, e) => {
            if (task && task.id && !isBucketId(task.id)) onTaskPatch({ id: task.id, startDate: s, endDate: e });
          }
        });
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
        } catch (_e) {
        }
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
            } catch (_e) {
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
          } catch (_e) {
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
      if (ganttHost) initGantt(ganttHost);
      const cleanup = () => {
        if (cleanupShading) cleanupShading();
        if (cleanupDrag) cleanupDrag();
        if (ganttInst) {
          try {
            ganttInst.destroy();
          } catch (_e) {
          }
        }
        slotInstances.forEach((inst) => inst.destroy());
        slotInstances.clear();
        removeTemplateCss(container);
        try {
          themeStyleEl.remove();
        } catch (_e) {
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
}({});
typeof window !== "undefined" && (window.NimbusGanttApp = NimbusGanttApp.NimbusGanttApp || NimbusGanttApp);
