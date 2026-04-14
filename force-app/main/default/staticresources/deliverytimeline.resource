;(function () {
    'use strict';

    /* -----------------------------------------------------------------------
     * DeliveryTimeline v5 — Salesforce port of cloudnimbusllc.com v8.
     * Feature-complete: priority grouping, depth-shading, drag-to-reparent,
     * filter chips, search, zoom, list view, detail panel, initial scroll.
     * Data adapter: Apex DTOs in / onPatch callbacks out.
     * Engine: window.NimbusGantt (nimbusgantt.resource IIFE).
     * -------------------------------------------------------------------- */

    var INIT_ERROR    = null;
    var ganttRegistry = [];  /* [{container, gantt, cleanup}] — no Map() for LS compat */

    /* ── Priority buckets (CLOUD_NIMBUS_PRIORITY_BUCKETS exact) ────────── */
    var PRIORITY_BUCKETS = [
        { id: 'top-priority', label: 'NOW',      color: '#dc2626', bgTint: '#ef4444', order: 0 },
        { id: 'active',       label: 'NEXT',     color: '#d97706', bgTint: '#f59e0b', order: 1 },
        { id: 'follow-on',    label: 'PLANNED',  color: '#059669', bgTint: '#10b981', order: 2 },
        { id: 'proposed',     label: 'PROPOSED', color: '#2563eb', bgTint: '#3b82f6', order: 3 },
        { id: 'deferred',     label: 'HOLD',     color: '#94a3b8', bgTint: '#94a3b8', order: 4 },
    ];

    /* ── GROUP_BG / GROUP_BAR_COLORS (mirrors v5) ────────────────────── */
    var GROUP_BG = {
        'top-priority': '#ef4444',
        'active':       '#f59e0b',
        'follow-on':    '#10b981',
        'proposed':     '#3b82f6',
        'deferred':     '#94a3b8',
    };
    var GROUP_BAR = {
        'top-priority': '#f87171',
        'active':       '#fbbf24',
        'follow-on':    '#34d399',
        'proposed':     '#60a5fa',
        'deferred':     '#cbd5e1',
    };

    /* ── Stage → color ───────────────────────────────────────────────── */
    var STAGE_COLORS = {
        'Backlog':                '#64748b',
        'Scoping In Progress':    '#64748b',
        'Ready for Sizing':       '#3b82f6',
        'Ready for Development':  '#22c55e',
        'In Development':         '#22c55e',
        'Ready for QA':           '#a855f7',
        'QA In Progress':         '#a855f7',
        'Ready for Client UAT':   '#14b8a6',
        'In Client UAT':          '#14b8a6',
        'Ready for UAT Sign-off': '#14b8a6',
        'Ready for Deployment':   '#f97316',
        'Deploying':              '#f97316',
        'Done':                   '#9ca3af',
        'Deployed to Prod':       '#9ca3af',
        'Cancelled':              '#cbd5e1',
        'Paused':                 '#94a3b8',
        'On Hold':                '#94a3b8',
        'Blocked':                '#ef4444',
    };
    var DONE_STAGES = { 'Done': true, 'Deployed to Prod': true, 'Cancelled': true };

    /* ── Theme (V3_MATCH_THEME) ──────────────────────────────────────── */
    var V3_THEME = {
        timelineBg:         '#ffffff',
        timelineGridColor:  '#e5e7eb',
        timelineHeaderBg:   '#f3f4f6',
        timelineHeaderText: '#1f2937',
        timelineWeekendBg:  'rgba(229,231,235,0.4)',
        todayLineColor:     '#ef4444',
        todayBg:            'rgba(239,68,68,0.08)',
        barDefaultColor:    '#94a3b8',
        barBorderRadius:    4,
        barTextColor:       '#ffffff',
        barSelectedBorder:  '#3b82f6',
        gridBg:             '#ffffff',
        gridAltRowBg:       'rgba(255,255,255,0)',
        gridBorderColor:    '#e5e7eb',
        gridTextColor:      '#1f2937',
        gridHeaderBg:       '#f3f4f6',
        gridHeaderText:     '#1f2937',
        gridHoverBg:        'rgba(229,231,235,0.3)',
        dependencyColor:    '#3b82f6',
        dependencyWidth:    2,
        fontFamily:         'sans-serif',
        fontSize:           12,
        selectionColor:     '#3b82f6',
        singleRowHeader:    true,
    };

    var GANTT_COLS = [
        { field: 'title',      header: '', width: 210, tree: true },
        { field: 'hoursLabel', header: '', width: 85,  align: 'right' },
    ];

    /* ══════════════════════════════════════════════════════════════════
       REGISTRY HELPERS
    ══════════════════════════════════════════════════════════════════ */
    function getEntry(c)    { for (var i=0;i<ganttRegistry.length;i++) if (ganttRegistry[i].container===c) return ganttRegistry[i]; return null; }
    function removeEntry(c) { for (var i=0;i<ganttRegistry.length;i++) if (ganttRegistry[i].container===c) { ganttRegistry.splice(i,1); return; } }

    /* ══════════════════════════════════════════════════════════════════
       UTILITY FUNCTIONS
    ══════════════════════════════════════════════════════════════════ */
    function darkenColor(hex, f) {
        var h = hex.replace('#',''); if (h.length===3) h=h[0]+h[0]+h[1]+h[1]+h[2]+h[2];
        function ch(s) { return Math.max(0,Math.round(parseInt(h.substring(s,s+2),16)*(1-f))); }
        function x2(n) { var s=n.toString(16); return s.length<2?'0'+s:s; }
        return '#'+x2(ch(0))+x2(ch(2))+x2(ch(4));
    }
    function todayISO() {
        var d=new Date();
        return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate());
    }
    function pad(n) { return n<10?'0'+n:String(n); }
    function addDays(iso,n) {
        var d=new Date(iso+'T00:00:00'); d.setDate(d.getDate()+n);
        return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate());
    }
    function addMonths(iso,n) {
        var d=new Date(iso+'T00:00:00'); d.setMonth(d.getMonth()+n);
        return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate());
    }
    function isBucketId(id) { return id && (String(id).indexOf('__bucket_header__')===0 || String(id).indexOf('group-')===0); }

    /* ══════════════════════════════════════════════════════════════════
       DEPTH MAP  (mirrors proForma parentId graph — uses parentWorkItemId)
    ══════════════════════════════════════════════════════════════════ */
    function buildDepthMap(tasks) {
        var byId = {}, dm = {};
        tasks.forEach(function(t) { byId[t.id] = t; });
        function depth(id) {
            if (dm[id] !== undefined) return dm[id];
            var t = byId[id];
            if (!t || !t.parentWorkItemId || !byId[t.parentWorkItemId]) { dm[id]=0; return 0; }
            dm[id] = 1 + depth(t.parentWorkItemId);
            return dm[id];
        }
        tasks.forEach(function(t) { depth(t.id); });
        return dm;
    }

    /* ══════════════════════════════════════════════════════════════════
       TASK PIPELINE  (mirrors v5 nimbusGanttTasks memo chain)
    ══════════════════════════════════════════════════════════════════ */
    function buildTasks(tasks) {
        var today = todayISO();
        var fallback = addMonths(today, -1);

        /* Pass 1: basic map */
        var mapped = tasks.map(function(t) {
            var hrs    = t.estimatedHours ? Math.round(Number(t.estimatedHours)) : 0;
            var logged = t.loggedHours    ? Number(t.loggedHours) : 0;
            var pct    = hrs>0 ? Math.round(logged/hrs*100) : 0;
            var hLabel = hrs>0 ? (logged>0 ? hrs+'h ('+pct+'%)' : hrs+'h') : '';
            var gid    = t.parentWorkItemId ? null : (t.priorityGroup || null);
            var col    = gid ? (GROUP_BAR[gid]||'#94a3b8') : (STAGE_COLORS[t.stage]||'#94a3b8');
            var start  = t.startDate || fallback;
            var end    = t.endDate   || addDays(start, 14);
            return {
                id: t.id, title: t.title||t.name||t.id,
                name: hrs>0?(logged>0?hrs+'h ('+pct+'%)':hrs+'h'):'',
                hoursLabel: hLabel,
                startDate: start, endDate: end,
                progress: hrs>0 ? Math.min(logged/hrs,1) : 0,
                status: t.stage||'', color: col,
                groupId: gid, parentId: t.parentWorkItemId||undefined,
                sortOrder: Number(t.sortOrder)||0,
                isInactive: !!t.isInactive,
                metadata: { hoursHigh: hrs, hoursLogged: logged },
            };
        });

        /* Pass 2: detect parents */
        var parentIds={}, childCounts={};
        mapped.forEach(function(t){ if(t.parentId){parentIds[t.parentId]=true; childCounts[t.parentId]=(childCounts[t.parentId]||0)+1;} });

        /* Pass 3: expand parent date spans from descendants */
        function descDates(pid, vis) {
            if(!vis) vis={}; if(vis[pid]) return {s:[],e:[]}; vis[pid]=true;
            var r={s:[],e:[]};
            mapped.forEach(function(t){
                if(t.parentId!==pid) return;
                if(t.startDate) r.s.push(t.startDate);
                if(t.endDate)   r.e.push(t.endDate);
                if(parentIds[t.id]){var sub=descDates(t.id,vis); r.s=r.s.concat(sub.s); r.e=r.e.concat(sub.e);}
            });
            return r;
        }

        return mapped.map(function(t) {
            if (!parentIds[t.id]) return t;
            var count=childCounts[t.id]||0, dd=descDates(t.id);
            var allS=[t.startDate].concat(dd.s).filter(Boolean).sort();
            var allE=[t.endDate].concat(dd.e).filter(Boolean).sort();
            return {id:t.id,title:t.title,name:t.name+(count>0?' \u00b7 '+count+' items':''),
                hoursLabel:t.hoursLabel,
                startDate:allS.length?allS[0]:t.startDate, endDate:allE.length?allE[allE.length-1]:t.endDate,
                progress:t.progress, status:t.status, color:darkenColor(t.color||'#64748b',0.2),
                groupId:t.groupId, parentId:t.parentId, sortOrder:t.sortOrder,
                isInactive:t.isInactive, metadata:t.metadata, isParent:true};
        });
    }

    function applyFilter(tasks, filter, q) {
        var r=tasks;
        if (filter==='active') r=r.filter(function(t){return !DONE_STAGES[t.status]&&!t.isInactive;});
        else if (filter==='done') r=r.filter(function(t){return !!DONE_STAGES[t.status];});
        if (q) { var ql=q.toLowerCase(); r=r.filter(function(t){return t.title&&t.title.toLowerCase().indexOf(ql)!==-1;}); }
        return r;
    }

    function computeStats(tasks) {
        var active=tasks.filter(function(t){return !t.isInactive;});
        var est=active.reduce(function(s,t){return s+(Number(t.estimatedHours)||0);},0);
        var logged=active.reduce(function(s,t){return s+(Number(t.loggedHours)||0);},0);
        var sched=active.filter(function(t){return t.startDate&&t.endDate;}).length;
        var counts={'top-priority':0,'active':0,'follow-on':0,'proposed':0,'deferred':0};
        active.forEach(function(t){if(t.priorityGroup&&Object.prototype.hasOwnProperty.call(counts,t.priorityGroup))counts[t.priorityGroup]++;});
        return {total:active.length, scheduled:sched, est:Math.round(est), logged:Math.round(logged*10)/10, counts:counts};
    }

    /* ══════════════════════════════════════════════════════════════════
       CSS — mirrors the full <style> block in v5 JSX
    ══════════════════════════════════════════════════════════════════ */
    function injectStyles() {
        if (document.getElementById('dh-tl-v5-css')) return;
        var s = document.createElement('style');
        s.id  = 'dh-tl-v5-css';
        s.textContent = [
            '.ng-grid{font-family:sans-serif!important;font-size:12px!important;color:#1f2937!important;letter-spacing:-.01em}',
            '.ng-grid table{border-collapse:collapse!important;border-spacing:0!important}',
            '.ng-grid-header{background:#f3f4f6!important;visibility:hidden!important}',
            '.ng-grid-th{font-size:12px!important;font-weight:700!important;color:#1f2937!important;padding:0 6px!important;border-right:none!important}',
            '.ng-grid-row:not(.ng-group-row) .ng-tree-cell .ng-expand-icon+.ng-grid-cell-text{font-weight:700!important;color:#1f2937!important}',
            '.ng-grid-row .ng-tree-cell .ng-expand-spacer+.ng-grid-cell-text{font-weight:400!important;color:#6b7280!important;font-size:11px!important}',
            '.ng-grid-cell{padding-top:0!important;padding-right:6px!important;padding-bottom:0!important;padding-left:6px;line-height:32px!important;border-right:none!important}',
            '.ng-expand-spacer{width:0!important;min-width:0!important}',
            '.ng-expand-icon{font-size:9px!important;opacity:.5!important;color:#6b7280!important;width:14px!important;min-width:14px!important}',
            '.ng-expand-icon:hover{opacity:1!important}',
            '.ng-grid-row{border:none!important;box-shadow:inset 0 -1px 0 #f3f4f6;box-sizing:border-box!important}',
            '.ng-grid-row:not(.ng-group-row){cursor:grab}',
            '.ng-grid-row:not(.ng-group-row):hover{background:rgba(59,130,246,0.04)!important;outline:1px solid rgba(59,130,246,0.12)!important;outline-offset:-1px}',
            '.ng-grid-row:not(.ng-group-row):active{cursor:grabbing}',
            '.ng-grid-row td{border:none!important;box-sizing:border-box!important}',
            '.ng-row-alt:not(.ng-group-row){background:unset}',
            '.ng-scroll-content>canvas{position:sticky!important;left:0!important}',
            '[data-depth-stripes]{display:none!important}',
            '.ng-group-row{font-weight:700;font-size:11px;letter-spacing:.03em;box-sizing:border-box!important;box-shadow:none!important;color:#fff!important}',
            '.ng-group-row .ng-grid-cell-text{font-weight:700!important;font-size:12px!important;color:#fff!important;text-transform:uppercase}',
            '.ng-group-row .ng-expand-icon{color:inherit!important;opacity:.5!important}',
            '.ng-group-row .ng-grid-cell[data-field="hoursLabel"]{font-weight:600!important;font-size:11px!important;color:inherit!important;opacity:.75;white-space:nowrap!important;overflow:visible!important}',
            '.ng-grid-cell[data-field="hoursLabel"]{font-family:monospace;font-size:10px;color:#94a3b8;font-weight:400}',
            '.ng-row-selected:not(.ng-group-row){background:rgba(59,130,246,0.06)!important;box-shadow:inset 3px 0 0 #3b82f6!important}',
            '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 28px"]{padding-left:8px!important}',
            '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 48px"]{padding-left:18px!important}',
            '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 68px"]{padding-left:28px!important}',
            '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 88px"]{padding-left:38px!important}',
        ].join('');
        document.head.appendChild(s);
    }

    /* ══════════════════════════════════════════════════════════════════
       DEPTH SHADING ENGINE  (ported from v5 depth-shading useEffect)
    ══════════════════════════════════════════════════════════════════ */
    function startDepthShading(ganttContainer, depthMap) {
        var applied = [], lastGrad = '', isApplying = false;

        function parseRgb(s) {
            var m = s && s.match(/(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/);
            return m ? {r:+m[1],g:+m[2],b:+m[3]} : null;
        }

        function run() {
            if (isApplying) return;
            isApplying = true;

            var scrollContent = ganttContainer.querySelector('.ng-scroll-content');
            if (scrollContent) scrollContent.querySelector('[data-depth-stripes]') && scrollContent.querySelector('[data-depth-stripes]').remove();

            var rows = ganttContainer.querySelectorAll('.ng-grid-row');
            var bucketRgb = null;
            var stripes = [];

            for (var ri=0; ri<rows.length; ri++) {
                var el = rows[ri];
                if (el.classList.contains('ng-group-row')) {
                    var bgRgb = parseRgb(el.style.background||'');
                    if (bgRgb) stripes.push({top:el.offsetTop,height:el.offsetHeight,color:'rgba('+bgRgb.r+','+bgRgb.g+','+bgRgb.b+',0.18)'});
                    bucketRgb = bgRgb;
                    continue;
                }
                var tid = el.getAttribute('data-task-id')||'';
                var d   = depthMap[tid] !== undefined ? depthMap[tid] : 0;
                var target = '';
                if (bucketRgb) {
                    var alpha = Math.max(0.03, 0.12 - d*0.04);
                    target = 'rgba('+bucketRgb.r+','+bucketRgb.g+','+bucketRgb.b+','+alpha+')';
                    stripes.push({top:el.offsetTop,height:el.offsetHeight,color:target});
                }
                /* only write if changed */
                var found = false;
                for (var ai=0;ai<applied.length;ai++) if (applied[ai].el===el) { found=true; if(applied[ai].val!==target){applied[ai].val=target; if(target)el.style.setProperty('background',target,'important'); else el.style.removeProperty('background');} break; }
                if (!found) { applied.push({el:el,val:target}); if(target)el.style.setProperty('background',target,'important'); }
            }

            /* Canvas-side shading via background-image on .ng-scroll-content */
            if (scrollContent && stripes.length) {
                var liveCanvas = scrollContent.querySelector('canvas');
                if (liveCanvas) {
                    var cw = liveCanvas.offsetWidth || liveCanvas.width;
                    if (cw>0) { scrollContent.style.backgroundSize=cw+'px 100%'; scrollContent.style.backgroundRepeat='no-repeat'; }
                }
                var totalH = scrollContent.scrollHeight||2000, stops=[], lastEnd=0;
                for (var si=0;si<stripes.length;si++) {
                    var st=stripes[si];
                    if(st.top>lastEnd){ stops.push('transparent '+lastEnd+'px','transparent '+st.top+'px'); }
                    stops.push(st.color+' '+st.top+'px',st.color+' '+(st.top+st.height)+'px');
                    lastEnd=st.top+st.height;
                }
                if(lastEnd<totalH) stops.push('transparent '+lastEnd+'px','transparent '+totalH+'px');
                var grad='linear-gradient(to bottom,'+stops.join(',')+')';
                if(grad!==lastGrad){ lastGrad=grad; scrollContent.style.backgroundImage=grad; }
            }

            isApplying = false;
        }

        var raf = requestAnimationFrame(run);
        var timer = null;
        var observer = new MutationObserver(function() {
            if (isApplying) return;
            if (timer) clearTimeout(timer);
            timer = setTimeout(run, 50);
        });
        observer.observe(ganttContainer, {childList:true, subtree:true});

        return function cleanup() {
            cancelAnimationFrame(raf);
            if (timer) clearTimeout(timer);
            observer.disconnect();
            var sc = ganttContainer.querySelector('.ng-scroll-content');
            if (sc) { sc.style.backgroundImage=''; sc.style.backgroundSize=''; sc.style.backgroundRepeat=''; }
        };
    }

    /* ══════════════════════════════════════════════════════════════════
       DRAG-REPARENT ENGINE  (ported from v5 drag useEffect)
    ══════════════════════════════════════════════════════════════════ */
    function startDragReparent(ganttContainer, allTasks, depthMap, onPatch) {
        var DRAG_THRESHOLD = 6, LEAF_STEP = 10, INDENT_BASE = 6;
        var taskById = {};
        allTasks.forEach(function(t){ taskById[t.id]=t; });

        var dragTaskId=null, dragSourceGroup=null, dragRow=null;
        var startY=0, startX=0, dragStartX=0, dragStartDepth=0;
        var hasMoved=false, didDrag=false;
        var ghost=null, spacer=null;
        var pendingIP=null;

        function getSortOrder(id) { var t=taskById[id]; return t ? (Number(t.sortOrder)||0) : 0; }
        function getGroup(id)     { var t=taskById[id]; return t ? (t.priorityGroup||null) : null; }

        function getGroupAtY(clientY) {
            var gRows=Array.prototype.slice.call(ganttContainer.querySelectorAll('.ng-group-row'));
            var cur=null;
            gRows.forEach(function(row){
                var rect=row.getBoundingClientRect();
                if(rect.top<=clientY){ var tid=row.getAttribute('data-task-id'); if(tid){ if(tid.indexOf('__bucket_header__')===0) cur=tid.slice('__bucket_header__'.length); else if(tid.indexOf('group-')===0) cur=tid.slice(6); } }
            });
            return cur;
        }

        function getInsertionPoint(clientY, clientX) {
            var allRows=Array.prototype.slice.call(ganttContainer.querySelectorAll('.ng-grid-row:not(.ng-group-row)'));
            var vis=allRows.filter(function(r){return r!==dragRow&&r!==spacer;});
            var rowAbove=null, rowBelow=null;
            for (var i=0;i<vis.length;i++) {
                var rect=vis[i].getBoundingClientRect();
                if(clientY<rect.top+rect.height/2){rowBelow=vis[i];break;}
                rowAbove=vis[i];
            }
            var aboveId=rowAbove?rowAbove.getAttribute('data-task-id'):null;
            var belowId=rowBelow?rowBelow.getAttribute('data-task-id'):null;
            var aboveDepth=aboveId!=null?(depthMap[aboveId]||0):-1;
            var aboveHasExpand=!!(rowAbove&&rowAbove.querySelector('.ng-expand-icon'));
            var maxDepth=rowAbove==null?0:(aboveHasExpand?aboveDepth+1:aboveDepth);
            var depthDelta=Math.round((clientX-dragStartX)/25);
            var desiredDepth=Math.max(0,Math.min(maxDepth,dragStartDepth+depthDelta));
            var parentId=null;
            if (desiredDepth>0) {
                var curId=aboveId;
                while(curId){
                    var d=depthMap[curId]||0;
                    if(d===desiredDepth-1){parentId=curId;break;}
                    var it=taskById[curId]; curId=it?it.parentWorkItemId:null;
                }
            }
            var sortAbove=aboveId?getSortOrder(aboveId):0;
            var sortBelow=belowId?getSortOrder(belowId):sortAbove+2;
            var targetSort=(sortAbove+sortBelow)/2;
            var targetBucket=getGroupAtY(clientY)||dragSourceGroup||'';
            return {parentId:parentId, depth:desiredDepth, targetBucket:targetBucket, targetSortOrder:targetSort, insertBeforeRow:rowBelow};
        }

        function cleanupDrag() {
            if(ghost){ghost.remove();ghost=null;}
            if(spacer){spacer.remove();spacer=null;}
            if(dragRow){dragRow.style.opacity='';dragRow.style.outline='';}
            document.body.style.cursor='';
            dragTaskId=null;dragSourceGroup=null;dragRow=null;hasMoved=false;pendingIP=null;
        }

        var autoScrollVel=0, autoScrollRAF=null;
        function findScrollEl(){return ganttContainer.querySelector('.ng-scroll-wrapper');}
        function tickAutoScroll(){
            var el=findScrollEl();
            if(!el||!dragTaskId||autoScrollVel===0){autoScrollRAF=null;return;}
            el.scrollTop=Math.max(0,Math.min(el.scrollHeight-el.clientHeight,el.scrollTop+autoScrollVel));
            autoScrollRAF=requestAnimationFrame(tickAutoScroll);
        }

        function onMouseDown(e) {
            var row=e.target.closest('.ng-grid-row:not(.ng-group-row)');
            if(!row) return;
            var tag=e.target.tagName.toLowerCase();
            if(tag==='input'||tag==='button'||tag==='select'||tag==='textarea') return;
            var taskId=row.getAttribute('data-task-id');
            if(!taskId) return;
            var grp=getGroup(taskId);
            if(!grp) return;
            e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
            dragTaskId=taskId; dragSourceGroup=grp; dragRow=row;
            startY=e.clientY; startX=e.clientX; dragStartX=e.clientX;
            dragStartDepth=depthMap[taskId]||0;
            hasMoved=false; didDrag=false; pendingIP=null;
            document.body.style.cursor='grabbing';
            row.style.outline='2px solid #3b82f6';
        }

        function onMouseMove(e) {
            if(!dragTaskId||!dragRow) return;
            var dx=e.clientX-startX, dy=e.clientY-startY;
            if(!hasMoved&&(Math.abs(dy)>DRAG_THRESHOLD||Math.abs(dx)>DRAG_THRESHOLD)){
                hasMoved=true; didDrag=true;
                /* Ghost */
                var firstCell=dragRow.querySelector('td');
                ghost=document.createElement('div');
                ghost.style.cssText='position:fixed;z-index:10000;pointer-events:none;left:'+(e.clientX-16)+'px;top:'+(e.clientY-18)+'px;background:#dbeafe;border:2px solid #2563eb;border-radius:8px;box-shadow:0 16px 40px rgba(37,99,235,0.4);padding:6px 12px;font-size:12px;font-weight:700;color:#1d4ed8;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;cursor:grabbing;transform:rotate(-1.5deg) scale(1.04);display:flex;align-items:center;gap:8px;max-width:320px';
                ghost.innerHTML='<span style="opacity:.6;font-size:14px">\u2807</span><span style="overflow:hidden;text-overflow:ellipsis">'+(firstCell?firstCell.innerText.replace(/\s+/g,' ').slice(0,60):'')+'</span>';
                document.body.appendChild(ghost);
                /* Spacer */
                var tbody=dragRow.parentElement;
                if(tbody){
                    spacer=document.createElement('tr');
                    spacer.setAttribute('data-drag-spacer','1');
                    spacer.style.pointerEvents='none';
                    var numCols=dragRow.querySelectorAll('td').length||6;
                    var td=document.createElement('td');
                    td.setAttribute('colspan',String(numCols));
                    td.style.cssText='padding:0;height:34px;background:rgba(59,130,246,0.07);border-top:2px solid #3b82f6;border-bottom:2px solid rgba(59,130,246,0.3)';
                    var span=document.createElement('span');
                    span.style.cssText='display:flex;align-items:center;height:100%;padding-left:10px;font-size:10px;font-weight:700;color:#3b82f6;letter-spacing:.05em;opacity:.7';
                    span.textContent='\u2193 drop here';
                    td.appendChild(span); spacer.appendChild(td);
                    tbody.insertBefore(spacer,dragRow.nextSibling);
                }
                dragRow.style.opacity='0.25';dragRow.style.outline='';
            }
            if(!hasMoved) return;
            if(ghost){ghost.style.left=(e.clientX-12)+'px';ghost.style.top=(e.clientY-14)+'px';}
            /* Auto-scroll */
            var scrollEl=findScrollEl();
            if(scrollEl){
                var sr=scrollEl.getBoundingClientRect(),EDGE=60,MAX=18,v=0;
                if(e.clientY<sr.top+EDGE) v=-Math.ceil(MAX*Math.min(1,(sr.top+EDGE-e.clientY)/EDGE));
                else if(e.clientY>sr.bottom-EDGE) v=Math.ceil(MAX*Math.min(1,(e.clientY-(sr.bottom-EDGE))/EDGE));
                autoScrollVel=v;
                if(v!==0&&autoScrollRAF==null) autoScrollRAF=requestAnimationFrame(tickAutoScroll);
            }
            var ip=getInsertionPoint(e.clientY,e.clientX);
            pendingIP=ip;
            if(spacer){
                var tb=dragRow?dragRow.parentElement:null;
                if(tb){if(ip.insertBeforeRow&&ip.insertBeforeRow!==spacer) tb.insertBefore(spacer,ip.insertBeforeRow); else if(!ip.insertBeforeRow) tb.appendChild(spacer);}
                var indent=INDENT_BASE+ip.depth*LEAF_STEP;
                var lbl=spacer.querySelector('td span');
                if(lbl) lbl.style.paddingLeft=(indent+8)+'px';
            }
        }

        function onMouseUp(e) {
            autoScrollVel=0;
            if(autoScrollRAF!=null){cancelAnimationFrame(autoScrollRAF);autoScrollRAF=null;}
            var savedId=dragTaskId, savedGroup=dragSourceGroup, savedMoved=hasMoved, ip=pendingIP;
            cleanupDrag();
            if(!savedId||!savedGroup) return;
            if(!savedMoved) return; /* single-click handled by onTaskClick */
            if(!ip) return;
            /* Dispatch patches */
            if(ip.targetBucket&&ip.targetBucket!==savedGroup) {
                onPatch({id:savedId, priorityGroup:ip.targetBucket});
            }
            if(ip.parentId !== (taskById[savedId]?taskById[savedId].parentWorkItemId:undefined)) {
                onPatch({id:savedId, parentId:ip.parentId||''});
            }
            onPatch({id:savedId, sortOrder:ip.targetSortOrder});
        }

        ganttContainer.addEventListener('mousedown', onMouseDown, true);
        window.addEventListener('mousemove', onMouseMove, true);
        window.addEventListener('mouseup', onMouseUp, true);

        return function cleanup() {
            ganttContainer.removeEventListener('mousedown', onMouseDown, true);
            window.removeEventListener('mousemove', onMouseMove, true);
            window.removeEventListener('mouseup', onMouseUp, true);
            cleanupDrag();
        };
    }

    /* ══════════════════════════════════════════════════════════════════
       LIST VIEW  (tabular fallback, grouped by priority)
    ══════════════════════════════════════════════════════════════════ */
    function renderList(container, tasks) {
        container.innerHTML='';
        var wrap=document.createElement('div');
        wrap.style.cssText='height:100%;overflow:auto;font-family:sans-serif;font-size:12px';
        var byGroup={}, noGroup=[];
        var childMap={};
        tasks.forEach(function(t){ if(t.parentId){if(!childMap[t.parentId])childMap[t.parentId]=[]; childMap[t.parentId].push(t);} });
        tasks.forEach(function(t){
            if(t.parentId) return;
            if(t.groupId) { if(!byGroup[t.groupId])byGroup[t.groupId]=[]; byGroup[t.groupId].push(t); }
            else noGroup.push(t);
        });
        PRIORITY_BUCKETS.forEach(function(b){
            var members=byGroup[b.id]||[];
            if(!members.length) return;
            var hdr=document.createElement('div');
            hdr.style.cssText='background:'+b.bgTint+';color:#fff;font-weight:700;font-size:11px;letter-spacing:.05em;padding:7px 14px;text-transform:uppercase;position:sticky;top:0;z-index:1';
            hdr.textContent=b.label+' — '+members.length+' items';
            wrap.appendChild(hdr);
            members.forEach(function(t){appendListRow(wrap,t,childMap,0);});
        });
        if(noGroup.length){
            var hdr2=document.createElement('div');
            hdr2.style.cssText='background:#475569;color:#fff;font-weight:700;font-size:11px;letter-spacing:.05em;padding:7px 14px;text-transform:uppercase;position:sticky;top:0;z-index:1';
            hdr2.textContent='Ungrouped — '+noGroup.length+' items';
            wrap.appendChild(hdr2);
            noGroup.forEach(function(t){appendListRow(wrap,t,childMap,0);});
        }
        container.appendChild(wrap);
    }

    function appendListRow(wrap, t, childMap, depth) {
        var row=document.createElement('div');
        row.style.cssText='display:flex;align-items:center;padding:5px 14px 5px '+(14+depth*14)+'px;border-bottom:1px solid #f3f4f6;gap:8px';
        row.onmouseover=function(){row.style.background='rgba(59,130,246,0.04)';};
        row.onmouseout =function(){row.style.background='';};
        var dot=document.createElement('span');
        dot.style.cssText='width:7px;height:7px;border-radius:50%;background:'+(STAGE_COLORS[t.status]||'#94a3b8')+';flex-shrink:0;display:inline-block';
        row.appendChild(dot);
        var title=document.createElement('span');
        title.style.cssText='flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:12px;color:#1f2937';
        title.title=t.title; title.textContent=t.title;
        row.appendChild(title);
        if(t.hoursLabel){
            var hrs=document.createElement('span');
            hrs.style.cssText='font-size:10px;color:#94a3b8;font-family:monospace;flex-shrink:0';
            hrs.textContent=t.hoursLabel; row.appendChild(hrs);
        }
        var stg=document.createElement('span');
        stg.style.cssText='font-size:10px;color:#94a3b8;flex-shrink:0;max-width:110px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap';
        stg.textContent=t.status||''; row.appendChild(stg);
        wrap.appendChild(row);
        (childMap[t.id]||[]).forEach(function(c){appendListRow(wrap,c,childMap,depth+1);});
    }

    /* ══════════════════════════════════════════════════════════════════
       MOUNT
    ══════════════════════════════════════════════════════════════════ */
    function mount(container, props) {
        if (INIT_ERROR) {
            var e=document.createElement('div');
            e.style.cssText='padding:20px;color:#b91c1c;font-family:monospace;font-size:13px';
            e.textContent='DeliveryTimeline init error: '+INIT_ERROR;
            container.appendChild(e); return;
        }

        var allTasks = (props&&props.tasks)||[];
        var onPatch  = (props&&props.onPatch)||function(){};

        /* State */
        var viewMode  = 'gantt';
        var filter    = 'active';
        var searchQ   = '';
        var zoomLevel = 'week';
        var ganttInst = null;
        var ganttEl   = null;
        var depthMap  = buildDepthMap(allTasks);
        var cleanupShading = null;
        var cleanupDrag    = null;

        injectStyles();

        /* ── Shell ────────────────────────────────────────────────────── */
        container.style.cssText='height:100%;display:flex;flex-direction:column;font-family:sans-serif;background:#f8fafc;overflow:hidden';

        /* ── Title bar ────────────────────────────────────────────────── */
        var titleBar=document.createElement('div');
        titleBar.style.cssText='background:#0f172a;color:#f8fafc;padding:0 14px;display:flex;align-items:center;gap:0;flex-shrink:0;height:38px';

        var titleTxt=document.createElement('span');
        titleTxt.style.cssText='font-size:13px;font-weight:600;color:#f8fafc;letter-spacing:.01em;margin-right:14px;white-space:nowrap';
        titleTxt.textContent='Pro Forma Timeline'; titleBar.appendChild(titleTxt);

        var badge=document.createElement('span');
        badge.style.cssText='font-size:10px;font-weight:700;color:#a78bfa;background:rgba(139,92,246,0.15);border:1px solid rgba(139,92,246,0.3);border-radius:9999px;padding:1px 7px;margin-right:14px;white-space:nowrap';
        badge.textContent='v5 \u00b7 Nimbus Gantt'; titleBar.appendChild(badge);

        function sep(){var d=document.createElement('span');d.style.cssText='width:1px;height:20px;background:#1e293b;margin:0 10px;flex-shrink:0';return d;}

        /* View mode tabs */
        var viewDefs=[{id:'gantt',icon:'\u25a4',label:'Gantt'},{id:'list',icon:'\u2630',label:'List'}];
        var viewBtns=[];
        titleBar.appendChild(sep());
        viewDefs.forEach(function(v){
            var btn=document.createElement('button');
            btn.style.cssText='background:none;border:none;cursor:pointer;padding:4px 10px;font-size:12px;border-radius:4px;color:'+(v.id===viewMode?'#fff':'#94a3b8')+';font-weight:'+(v.id===viewMode?'600':'400')+';display:flex;align-items:center;gap:4px;height:28px;white-space:nowrap';
            btn.innerHTML='<span>'+v.icon+'</span><span>'+v.label+'</span>';
            btn.addEventListener('click',function(){
                viewMode=v.id;
                viewBtns.forEach(function(b){b.btn.style.color=b.id===viewMode?'#fff':'#94a3b8';b.btn.style.fontWeight=b.id===viewMode?'600':'400';});
                rebuildView();
            });
            viewBtns.push({id:v.id,btn:btn}); titleBar.appendChild(btn);
        });
        var titleSpacer=document.createElement('div');titleSpacer.style.flex='1';titleBar.appendChild(titleSpacer);
        var statsLabel=document.createElement('span');statsLabel.style.cssText='font-size:11px;color:#64748b;white-space:nowrap';titleBar.appendChild(statsLabel);
        container.appendChild(titleBar);

        /* ── Filter + search bar ──────────────────────────────────────── */
        var filterBar=document.createElement('div');
        filterBar.style.cssText='background:#fff;border-bottom:1px solid #e5e7eb;padding:5px 14px;display:flex;align-items:center;gap:10px;flex-shrink:0;flex-wrap:wrap';

        var fLabel=document.createElement('span');fLabel.style.cssText='font-size:11px;color:#64748b;white-space:nowrap';fLabel.textContent='View:';filterBar.appendChild(fLabel);
        var filterOpts=[{id:'active',label:'Active'},{id:'all',label:'All'},{id:'done',label:'Done'}];
        var filterBtns=[];
        filterOpts.forEach(function(f){
            var btn=document.createElement('button');
            btn.textContent=f.label;
            function styleBtn(){ var on=f.id===filter; btn.style.cssText='padding:2px 9px;font-size:11px;border-radius:10px;cursor:pointer;border:1px solid '+(on?'#3b82f6':'#e5e7eb')+';background:'+(on?'#eff6ff':'#fff')+';color:'+(on?'#2563eb':'#374151')+';font-weight:'+(on?'600':'400'); }
            styleBtn();
            btn.addEventListener('click',function(){filter=f.id;filterBtns.forEach(function(b){b.style();}); refresh();});
            filterBtns.push({style:styleBtn}); filterBar.appendChild(btn);
        });

        var fbsep=document.createElement('div');fbsep.style.cssText='width:1px;height:18px;background:#e5e7eb;flex-shrink:0';filterBar.appendChild(fbsep);

        /* Search */
        var sw=document.createElement('div');sw.style.cssText='display:flex;align-items:center;gap:4px;border:1px solid #e5e7eb;border-radius:6px;padding:2px 8px;background:#fff';
        var si=document.createElement('span');si.style.cssText='font-size:12px;color:#94a3b8';si.textContent='\uD83D\uDD0E';sw.appendChild(si);
        var sinput=document.createElement('input');sinput.type='text';sinput.placeholder='Search title\u2026';sinput.style.cssText='border:none;outline:none;font-size:11px;color:#374151;background:transparent;width:140px';
        sinput.addEventListener('input',function(){searchQ=sinput.value.trim();refresh();});
        sw.appendChild(sinput);filterBar.appendChild(sw);

        var fbspace=document.createElement('div');fbspace.style.flex='1';filterBar.appendChild(fbspace);

        /* Color legend */
        var legWrap=document.createElement('div');legWrap.style.cssText='display:flex;align-items:center;gap:8px;flex-wrap:wrap';
        var legLbl=document.createElement('span');legLbl.style.cssText='font-size:11px;color:#64748b;white-space:nowrap';legLbl.textContent='Groups:';legWrap.appendChild(legLbl);
        var legendChips=[];
        PRIORITY_BUCKETS.forEach(function(b){
            var chip=document.createElement('span');
            chip.style.cssText='display:flex;align-items:center;gap:3px;font-size:11px;color:#374151;white-space:nowrap;cursor:pointer';
            var dot=document.createElement('span');dot.style.cssText='width:9px;height:9px;border-radius:50%;background:'+b.bgTint+';display:inline-block;flex-shrink:0';
            chip.appendChild(dot);
            var txt=document.createElement('span');txt.textContent=b.label;chip.appendChild(txt);
            chip.dataset.bid=b.id; legendChips.push({bid:b.id,txt:txt}); legWrap.appendChild(chip);
        });
        filterBar.appendChild(legWrap);
        container.appendChild(filterBar);

        /* ── Zoom + controls bar ──────────────────────────────────────── */
        var ctrlBar=document.createElement('div');
        ctrlBar.style.cssText='background:#fff;border-bottom:1px solid #e5e7eb;padding:4px 14px;display:flex;align-items:center;gap:8px;flex-shrink:0';

        var zg=document.createElement('div');zg.style.cssText='display:flex;border:1px solid #d1d5db;border-radius:4px;overflow:hidden';
        var zDefs=[{label:'Day',zoom:'day'},{label:'Week',zoom:'week'},{label:'Month',zoom:'month'},{label:'Quarter',zoom:'quarter'}];
        var zBtns=[];
        zDefs.forEach(function(z,idx){
            var btn=document.createElement('button');
            var act=z.zoom===zoomLevel;
            btn.textContent=z.label;
            btn.style.cssText='padding:3px 10px;font-size:11px;font-weight:500;background:'+(act?'#1e293b':'#fff')+';color:'+(act?'#fff':'#374151')+';border:none;border-right:'+(idx<zDefs.length-1?'1px solid #d1d5db':'none')+';cursor:pointer;line-height:1.6';
            btn.addEventListener('click',function(){
                zoomLevel=z.zoom;
                zBtns.forEach(function(b){b.el.style.background=b.zoom===zoomLevel?'#1e293b':'#fff';b.el.style.color=b.zoom===zoomLevel?'#fff':'#374151';});
                if(ganttInst&&typeof ganttInst.setZoom==='function') ganttInst.setZoom(zoomLevel);
            });
            zBtns.push({el:btn,zoom:z.zoom}); zg.appendChild(btn);
        });
        ctrlBar.appendChild(zg);

        var cbLabel=document.createElement('label');cbLabel.style.cssText='display:flex;align-items:center;gap:4px;font-size:11px;color:#374151;cursor:pointer;white-space:nowrap;margin-left:8px';
        var cb=document.createElement('input');cb.type='checkbox';
        cbLabel.appendChild(cb);cbLabel.appendChild(document.createTextNode('Completed'));
        ctrlBar.appendChild(cbLabel);

        var ctrlSpacer=document.createElement('div');ctrlSpacer.style.flex='1';ctrlBar.appendChild(ctrlSpacer);
        var countLbl=document.createElement('span');countLbl.style.cssText='font-size:11px;color:#64748b;white-space:nowrap';ctrlBar.appendChild(countLbl);
        container.appendChild(ctrlBar);

        /* ── Content area + detail panel ─────────────────────────────── */
        var contentOuter=document.createElement('div');
        contentOuter.style.cssText='flex:1 1 auto;min-height:0;display:flex;overflow:hidden';
        container.appendChild(contentOuter);

        var contentEl=document.createElement('div');
        contentEl.style.cssText='flex:1 1 auto;min-height:0;position:relative;overflow:hidden';
        contentOuter.appendChild(contentEl);

        /* Detail slide-out panel */
        var detailPanel=document.createElement('div');
        detailPanel.style.cssText='width:0;flex-shrink:0;overflow:hidden;background:#fff;border-left:1px solid #e5e7eb;transition:width .2s;font-family:sans-serif;font-size:12px;position:relative';
        contentOuter.appendChild(detailPanel);

        function openDetail(taskId) {
            var raw=null;
            for(var i=0;i<allTasks.length;i++)if(allTasks[i].id===taskId){raw=allTasks[i];break;}
            if(!raw)return;
            var grpLabel='—';PRIORITY_BUCKETS.forEach(function(b){if(b.id===raw.priorityGroup)grpLabel=b.label;});
            var grpColor='#374151';PRIORITY_BUCKETS.forEach(function(b){if(b.id===raw.priorityGroup)grpColor=b.bgTint;});
            detailPanel.innerHTML='';detailPanel.style.width='240px';
            var hdr=document.createElement('div');
            hdr.style.cssText='padding:10px 12px 6px;border-bottom:1px solid #f3f4f6;display:flex;align-items:flex-start;gap:6px';
            var ttl=document.createElement('span');ttl.style.cssText='flex:1;font-weight:600;font-size:12px;color:#0f172a;line-height:1.4';ttl.textContent=raw.title||raw.name||raw.id;
            var cls=document.createElement('button');cls.textContent='\u00d7';cls.style.cssText='background:none;border:none;cursor:pointer;font-size:16px;color:#94a3b8;padding:0;line-height:1;flex-shrink:0;margin-top:-2px';
            cls.addEventListener('click',closeDetail);
            hdr.appendChild(ttl);hdr.appendChild(cls);detailPanel.appendChild(hdr);
            var body=document.createElement('div');body.style.cssText='padding:10px 12px;display:flex;flex-direction:column;gap:8px;overflow-y:auto;max-height:calc(100vh - 180px)';
            function row2(lbl,val,color){
                var r=document.createElement('div');r.style.cssText='display:flex;flex-direction:column;gap:2px';
                var l=document.createElement('span');l.style.cssText='font-size:10px;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em';l.textContent=lbl;
                var v=document.createElement('span');v.style.cssText='font-size:12px;color:'+(color||'#1f2937')+';font-weight:500';v.textContent=val||'—';
                r.appendChild(l);r.appendChild(v);body.appendChild(r);
            }
            row2('Priority',grpLabel,grpColor);row2('Stage',raw.stage);
            row2('Start',raw.startDate);row2('End',raw.endDate);
            var hrs=raw.estimatedHours?Math.round(Number(raw.estimatedHours)):0;
            var lgd=raw.loggedHours?Number(raw.loggedHours):0;
            row2('Estimated',hrs>0?hrs+'h':'—');row2('Logged',lgd>0?lgd+'h':'—');
            if(raw.developerName)row2('Developer',raw.developerName);
            if(raw.entityName)row2('Entity',raw.entityName);
            detailPanel.appendChild(body);
        }
        function closeDetail(){detailPanel.style.width='0';setTimeout(function(){detailPanel.innerHTML='';},210);}

        /* ── Stats update ────────────────────────────────────────────── */
        function updateStats() {
            var s=computeStats(allTasks);
            statsLabel.textContent=s.total+' items \u00b7 '+s.est+'h Est \u00b7 '+s.logged+'h Logged';
            legendChips.forEach(function(c){c.txt.textContent=PRIORITY_BUCKETS.filter(function(b){return b.id===c.bid;})[0].label+' ('+s.counts[c.bid]+')';});
            var vs=computeStats(applyFilter(allTasks,filter,searchQ));
            countLbl.textContent=vs.scheduled+' scheduled \u00b7 '+vs.total+' items';
        }

        /* ── Gantt init ──────────────────────────────────────────────── */
        function initGantt() {
            if(!window.NimbusGantt){
                contentEl.style.cssText='padding:20px;color:#b91c1c;font-size:13px';
                contentEl.textContent='nimbus-gantt not loaded'; return;
            }
            var NG=window.NimbusGantt, Ctor=NG.NimbusGantt, PGP=NG.PriorityGroupingPlugin, hwp=NG.hoursWeightedProgress;
            ganttEl=document.createElement('div');
            ganttEl.style.cssText='height:100%;width:100%;position:absolute;inset:0';
            contentEl.appendChild(ganttEl);

            var filtered=applyFilter(allTasks,filter,searchQ);
            if(!cb.checked) filtered=filtered.filter(function(t){return !DONE_STAGES[t.status];});
            var gtasks=buildTasks(filtered);

            ganttInst=new Ctor(ganttEl,{
                tasks:gtasks, dependencies:[], columns:GANTT_COLS, theme:V3_THEME,
                rowHeight:32, barHeight:20, headerHeight:32, gridWidth:295,
                zoomLevel:zoomLevel, showToday:true, showWeekends:true, showProgress:true,
                colorMap:STAGE_COLORS, readOnly:false,
                onTaskClick:function(task){if(task&&task.id&&!isBucketId(task.id)) openDetail(task.id);},
                onTaskDblClick:function(task){if(task&&task.id&&!isBucketId(task.id)) openDetail(task.id);},
                onTaskMove:function(task,s,e){if(task&&task.id&&!isBucketId(task.id)) onPatch({id:task.id,startDate:s,endDate:e});},
                onTaskResize:function(task,s,e){if(task&&task.id&&!isBucketId(task.id)) onPatch({id:task.id,startDate:s,endDate:e});},
            });

            if(typeof PGP==='function'){
                ganttInst.use(PGP({
                    buckets:PRIORITY_BUCKETS,
                    getBucket:function(task){return task.groupId||null;},
                    getBucketProgress:typeof hwp==='function'?hwp:undefined,
                }));
            }

            ganttInst.setData(gtasks,[]);
            try{ganttInst.expandAll();}catch(ex){}

            /* Depth shading + drag-reparent */
            if(cleanupShading) cleanupShading();
            if(cleanupDrag) cleanupDrag();
            cleanupShading=startDepthShading(ganttEl, depthMap);
            cleanupDrag=startDragReparent(ganttEl, allTasks, depthMap, onPatch);

            /* Initial scroll: 2 weeks before today */
            setTimeout(function(){
                try{
                    if(ganttInst&&ganttInst.timeScale&&ganttInst.scrollManager){
                        var ld=new Date(); ld.setDate(ld.getDate()-14);
                        var x=ganttInst.timeScale.dateToX(ld);
                        if(x>0) ganttInst.scrollManager.scrollToX(x);
                    }
                }catch(ex){}
            },600);
        }

        /* ── Refresh (filter/search/complete change) ──────────────────── */
        function refresh() {
            if(viewMode==='gantt'&&ganttInst) {
                var filtered=applyFilter(allTasks,filter,searchQ);
                if(!cb.checked) filtered=filtered.filter(function(t){return !DONE_STAGES[t.status];});
                var gtasks=buildTasks(filtered);
                if(typeof ganttInst.setData==='function'){ganttInst.setData(gtasks,[]);try{ganttInst.expandAll();}catch(ex){}}
            } else if(viewMode==='list') {
                var filtered2=applyFilter(allTasks,filter,searchQ);
                if(!cb.checked) filtered2=filtered2.filter(function(t){return !DONE_STAGES[t.status];});
                renderList(contentEl,buildTasks(filtered2));
            }
            updateStats();
        }

        /* ── View rebuild ─────────────────────────────────────────────── */
        function rebuildView() {
            if(cleanupShading){cleanupShading();cleanupShading=null;}
            if(cleanupDrag){cleanupDrag();cleanupDrag=null;}
            if(ganttInst){try{ganttInst.destroy();}catch(ex){}ganttInst=null;}
            contentEl.innerHTML='';
            if(viewMode==='gantt') initGantt();
            else renderList(contentEl, buildTasks(applyFilter(allTasks,filter,searchQ)));
            updateStats();
        }

        cb.addEventListener('change',function(){refresh();});

        /* First render */
        initGantt();
        updateStats();

        ganttRegistry.push({container:container, gantt:null, cleanup:function(){
            if(cleanupShading) cleanupShading();
            if(cleanupDrag) cleanupDrag();
            if(ganttInst){try{ganttInst.destroy();}catch(ex){}}
        }});
    }

    /* ══════════════════════════════════════════════════════════════════
       UNMOUNT
    ══════════════════════════════════════════════════════════════════ */
    function unmount(container) {
        var e=getEntry(container);
        if(e){if(e.cleanup)e.cleanup();removeEntry(container);}
        container.innerHTML='';
    }

    /* ══════════════════════════════════════════════════════════════════
       EXPORT
    ══════════════════════════════════════════════════════════════════ */
    window.DeliveryTimeline = { mount: mount, unmount: unmount };
    console.log('[DeliveryTimeline] v5 bundle loaded OK');

})();
