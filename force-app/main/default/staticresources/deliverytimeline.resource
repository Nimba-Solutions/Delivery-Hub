;(function () {
    'use strict';

    var ganttInstances = new Map();

    // --- Constants -----------------------------------------------------------

    var PRIORITY_BUCKETS = [
        { id: 'top-priority', label: 'NOW',      color: '#dc2626', bgTint: '#ef4444', order: 0 },
        { id: 'active',       label: 'NEXT',     color: '#d97706', bgTint: '#f59e0b', order: 1 },
        { id: 'follow-on',    label: 'PLANNED',  color: '#059669', bgTint: '#10b981', order: 2 },
        { id: 'proposed',     label: 'PROPOSED', color: '#2563eb', bgTint: '#3b82f6', order: 3 },
        { id: 'deferred',     label: 'HOLD',     color: '#94a3b8', bgTint: '#94a3b8', order: 4 },
    ];

    var V3_MATCH_THEME = {
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
        fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
        fontSize:           12,
        selectionColor:     '#3b82f6',
    };

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

    var GANTT_COLUMNS = [
        { field: 'title',      header: '', width: 200, tree: true },
        { field: 'hoursLabel', header: '', width: 70,  align: 'right' },
    ];

    // --- CSS -----------------------------------------------------------------

    var NG_CSS = [
        '.ng-grid { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif !important; font-size: 12px !important; color: #1f2937 !important; }',
        '.ng-grid table { border-collapse: collapse !important; border-spacing: 0 !important; }',
        '.ng-grid-header { background: #f3f4f6 !important; visibility: hidden !important; }',
        '.ng-grid-th { font-size: 12px !important; font-weight: 700 !important; color: #1f2937 !important; padding: 0 6px !important; border-right: none !important; }',
        '.ng-grid-cell { padding-top: 0 !important; padding-right: 6px !important; padding-bottom: 0 !important; padding-left: 6px; border-right: none !important; line-height: 32px !important; }',
        '.ng-grid-row { border: none !important; box-shadow: inset 0 -1px 0 #f3f4f6; box-sizing: border-box !important; }',
        '.ng-grid-row td { border: none !important; box-sizing: border-box !important; }',
        '.ng-grid-row:not(.ng-group-row) { cursor: grab; }',
        '.ng-grid-row:not(.ng-group-row):hover { background: rgba(59,130,246,0.04) !important; }',
        '.ng-grid-row:not(.ng-group-row):active { cursor: grabbing; }',
        '.ng-row-alt:not(.ng-group-row) { background: unset; }',
        '.ng-group-row { font-weight: 700; font-size: 11px; letter-spacing: 0.03em; box-sizing: border-box !important; box-shadow: none !important; color: #fff !important; }',
        '.ng-group-row .ng-grid-cell-text { font-weight: 700 !important; font-size: 12px !important; color: #fff !important; text-transform: uppercase; }',
        '.ng-group-row .ng-expand-icon { color: inherit !important; opacity: 0.5 !important; }',
        '.ng-grid-cell[data-field="hoursLabel"] { font-family: "SF Mono","Consolas",monospace; font-size: 10px; color: #94a3b8; font-weight: 400; }',
        '.ng-row-selected:not(.ng-group-row) { background: rgba(59,130,246,0.06) !important; box-shadow: inset 3px 0 0 #3b82f6 !important; }',
        '.ng-scroll-content > canvas { position: sticky !important; left: 0 !important; }',
        '.ng-expand-spacer { width: 0 !important; min-width: 0 !important; }',
        '.ng-expand-icon { font-size: 9px !important; opacity: 0.5 !important; color: #6b7280 !important; width: 14px !important; min-width: 14px !important; }',
        '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 28px"] { padding-left: 8px !important; }',
        '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 48px"] { padding-left: 18px !important; }',
        '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 68px"] { padding-left: 28px !important; }',
        '.ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 88px"] { padding-left: 38px !important; }',
    ].join('\n');

    // --- Helpers -------------------------------------------------------------

    function injectStyles() {
        var id = 'ng-v8-styles-dh';
        if (document.getElementById(id)) { return; }
        var s = document.createElement('style');
        s.id = id;
        s.textContent = NG_CSS;
        document.head.appendChild(s);
    }

    function buildTasks(tasks) {
        return tasks.map(function (t) {
            var hrs    = t.estimatedHours ? Math.round(Number(t.estimatedHours)) : 0;
            var logged = t.loggedHours    ? Number(t.loggedHours)               : 0;
            var pct    = hrs > 0 ? Math.round((logged / hrs) * 100) : 0;
            var hoursLabel = '';
            if (hrs > 0) {
                hoursLabel = logged > 0 ? (hrs + 'h (' + pct + '%)') : (hrs + 'h');
            }
            return {
                id:         t.id,
                title:      t.title || t.name || t.id,
                name:       t.title || t.name || t.id,
                hoursLabel: hoursLabel,
                startDate:  t.startDate || null,
                endDate:    t.endDate   || null,
                progress:   (t.loggedHours && t.estimatedHours)
                                ? Math.min(Number(t.loggedHours) / Number(t.estimatedHours), 1)
                                : 0,
                status:     t.stage    || '',
                priority:   t.priority || 'Medium',
                groupId:    t.parentWorkItemId ? null : (t.priorityGroup || null),
                parentId:   t.parentWorkItemId || undefined,
                color:      STAGE_COLORS[t.stage] || undefined,
                metadata: {
                    priorityGroup: t.parentWorkItemId ? null : t.priorityGroup,
                    hoursHigh:     hrs,
                    hoursLogged:   logged,
                },
            };
        });
    }

    function computeStats(tasks) {
        var active = tasks.filter(function (t) { return !t.isInactive; });
        var est    = active.reduce(function (s, t) { return s + (Number(t.estimatedHours) || 0); }, 0);
        var logged = active.reduce(function (s, t) { return s + (Number(t.loggedHours)    || 0); }, 0);
        var counts = {
            'top-priority': 0,
            'active':       0,
            'follow-on':    0,
            'proposed':     0,
            'deferred':     0,
        };
        active.forEach(function (t) {
            if (t.priorityGroup && Object.prototype.hasOwnProperty.call(counts, t.priorityGroup)) {
                counts[t.priorityGroup]++;
            }
        });
        return {
            items:  active.length,
            est:    Math.round(est),
            logged: Math.round(logged * 10) / 10,
            counts: counts,
        };
    }

    // --- mount ---------------------------------------------------------------

    function mount(container, props) {
        var tasks     = (props && props.tasks)   || [];
        var onPatch   = (props && props.onPatch) || function () {};
        var zoomLevel = 'week';
        var gantt     = null;

        container.style.cssText = [
            'height:100%;',
            'display:flex;',
            'flex-direction:column;',
            'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;',
            'background:#fff;',
        ].join('');

        // ---- Stats bar ------------------------------------------------------
        var stats    = computeStats(tasks);
        var statsBar = document.createElement('div');
        statsBar.style.cssText = [
            'padding:6px 12px;',
            'background:#f8fafc;',
            'border-bottom:1px solid #e5e7eb;',
            'font-size:11px;',
            'color:#64748b;',
            'display:flex;',
            'gap:16px;',
            'align-items:center;',
            'flex-shrink:0;',
            'flex-wrap:wrap;',
        ].join('');

        statsBar.innerHTML = [
            '<span><strong style="color:#0f172a">' + stats.est    + 'h</strong> Est</span>',
            '<span style="color:#6b7280">&middot;</span>',
            '<span><strong style="color:#0f172a">' + stats.logged + 'h</strong> Logged</span>',
            '<span style="color:#6b7280">&middot;</span>',
            '<span style="color:#ef4444">NOW: <strong>'      + stats.counts['top-priority'] + '</strong></span>',
            '<span style="color:#6b7280">&middot;</span>',
            '<span style="color:#f59e0b">NEXT: <strong>'     + stats.counts['active']        + '</strong></span>',
            '<span style="color:#6b7280">&middot;</span>',
            '<span style="color:#10b981">PLANNED: <strong>'  + stats.counts['follow-on']     + '</strong></span>',
            '<span style="color:#6b7280">&middot;</span>',
            '<span style="color:#3b82f6">PROPOSED: <strong>' + stats.counts['proposed']       + '</strong></span>',
            '<span style="color:#6b7280">&middot;</span>',
            '<span style="color:#94a3b8">HOLD: <strong>'     + stats.counts['deferred']       + '</strong></span>',
        ].join('');
        container.appendChild(statsBar);

        // ---- Toolbar --------------------------------------------------------
        var toolbar = document.createElement('div');
        toolbar.style.cssText = [
            'padding:4px 12px;',
            'background:#fff;',
            'border-bottom:1px solid #e5e7eb;',
            'display:flex;',
            'align-items:center;',
            'gap:8px;',
            'flex-shrink:0;',
        ].join('');

        var zoomGroup = document.createElement('div');
        zoomGroup.style.cssText = [
            'display:flex;',
            'border:1px solid #d1d5db;',
            'border-radius:4px;',
            'overflow:hidden;',
        ].join('');

        var zoomLabels  = ['Day', 'Week', 'Month', 'Quarter'];
        var zoomButtons = [];

        zoomLabels.forEach(function (z, idx) {
            var btn      = document.createElement('button');
            var isActive = (z === 'Week');
            var isLast   = (idx === zoomLabels.length - 1);
            btn.textContent  = z;
            btn.dataset.zoom = z.toLowerCase();
            btn.style.cssText = [
                'padding:3px 10px;',
                'font-size:11px;',
                'font-weight:500;',
                'background:' + (isActive ? '#1e293b' : '#fff') + ';',
                'color:'      + (isActive ? '#fff'    : '#374151') + ';',
                'border:none;',
                'border-right:' + (isLast ? 'none' : '1px solid #d1d5db') + ';',
                'cursor:pointer;',
                'line-height:1.6;',
            ].join('');
            btn.addEventListener('click', function () {
                zoomLevel = btn.dataset.zoom;
                zoomButtons.forEach(function (b) {
                    var active = (b === btn);
                    b.style.background = active ? '#1e293b' : '#fff';
                    b.style.color      = active ? '#fff'    : '#374151';
                });
                if (gantt && typeof gantt.setZoom === 'function') {
                    gantt.setZoom(zoomLevel);
                }
            });
            zoomButtons.push(btn);
            zoomGroup.appendChild(btn);
        });
        toolbar.appendChild(zoomGroup);

        var spacer = document.createElement('div');
        spacer.style.flex = '1';
        toolbar.appendChild(spacer);

        var cbLabel = document.createElement('label');
        cbLabel.style.cssText = [
            'display:flex;',
            'align-items:center;',
            'gap:4px;',
            'font-size:11px;',
            'color:#374151;',
            'cursor:pointer;',
            'white-space:nowrap;',
        ].join('');
        var cb      = document.createElement('input');
        cb.type     = 'checkbox';
        cb.style.accentColor = '#3b82f6';
        cbLabel.appendChild(cb);
        cbLabel.appendChild(document.createTextNode('Completed'));
        toolbar.appendChild(cbLabel);
        container.appendChild(toolbar);

        // ---- Gantt wrapper --------------------------------------------------
        var ganttEl = document.createElement('div');
        ganttEl.style.cssText = [
            'flex:1 1 auto;',
            'min-height:0;',
            'position:relative;',
            'overflow:hidden;',
        ].join('');
        container.appendChild(ganttEl);

        injectStyles();

        if (!window.NimbusGantt) {
            ganttEl.innerHTML = '<div style="padding:20px;color:#b91c1c;font-size:13px;">nimbus-gantt not loaded</div>';
            return;
        }

        var NG                    = window.NimbusGantt;
        var NimbusGanttCtor       = NG.NimbusGantt;
        var PriorityGroupingPlugin = NG.PriorityGroupingPlugin;
        var hoursWeightedProgress  = NG.hoursWeightedProgress;

        var ganttTasks = buildTasks(tasks);

        gantt = new NimbusGanttCtor(ganttEl, {
            tasks:        ganttTasks,
            dependencies: [],
            columns:      GANTT_COLUMNS,
            theme:        V3_MATCH_THEME,
            rowHeight:    32,
            barHeight:    20,
            headerHeight: 32,
            gridWidth:    220,
            zoomLevel:    zoomLevel,
            showToday:    true,
            showWeekends: true,
            showProgress: true,
            colorMap:     STAGE_COLORS,
            readOnly:     false,
            onTaskMove: function (task, s, e) {
                if (task && task.id && !String(task.id).startsWith('__bucket')) {
                    onPatch({ id: task.id, startDate: s, endDate: e });
                }
            },
            onTaskResize: function (task, s, e) {
                if (task && task.id && !String(task.id).startsWith('__bucket')) {
                    onPatch({ id: task.id, startDate: s, endDate: e });
                }
            },
        });

        if (typeof PriorityGroupingPlugin === 'function') {
            gantt.use(PriorityGroupingPlugin({
                buckets: PRIORITY_BUCKETS,
                getBucket: function (task) {
                    if (task.parentId && !String(task.parentId).startsWith('__bucket_header__')) {
                        return null;
                    }
                    return (task.metadata && task.metadata.priorityGroup) || task.groupId || null;
                },
                getBucketProgress: typeof hoursWeightedProgress === 'function'
                    ? hoursWeightedProgress
                    : undefined,
            }));
        }

        gantt.setData(ganttTasks, []);
        try { gantt.expandAll(); } catch (e) { /* non-fatal */ }

        // ---- Show completed toggle ------------------------------------------
        var DONE_STAGES = { 'Done': true, 'Deployed to Prod': true, 'Cancelled': true };
        cb.addEventListener('change', function () {
            var showCompleted = cb.checked;
            var filtered = showCompleted
                ? ganttTasks
                : ganttTasks.filter(function (t) { return !DONE_STAGES[t.status]; });
            if (gantt && typeof gantt.setData === 'function') {
                gantt.setData(filtered, []);
                try { gantt.expandAll(); } catch (e) { /* non-fatal */ }
            }
        });

        ganttInstances.set(container, gantt);
    }

    // --- unmount -------------------------------------------------------------

    function unmount(container) {
        var g = ganttInstances.get(container);
        if (g) {
            try { g.destroy(); } catch (e) { /* non-fatal */ }
            ganttInstances.delete(container);
        }
        container.innerHTML = '';
    }

    // --- Export --------------------------------------------------------------

    window.DeliveryTimeline = { mount: mount, unmount: unmount };
    console.log('[DeliveryTimeline] Vanilla bundle loaded OK');

})();
