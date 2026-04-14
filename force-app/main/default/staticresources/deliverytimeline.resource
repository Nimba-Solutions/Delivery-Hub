;(function () {
    'use strict';
    /* -----------------------------------------------------------------------
     * DeliveryTimeline — Salesforce data adapter.
     * All chrome/rendering is in nimbusganttapp.resource (@nimbus-gantt/app).
     * This file only maps Apex DTOs → NormalizedTask and wires onPatch.
     * -------------------------------------------------------------------- */

    var PRIORITY_BUCKETS = [
        { id: 'top-priority', label: 'NOW',      color: '#dc2626', bgTint: '#ef4444', order: 0 },
        { id: 'active',       label: 'NEXT',     color: '#d97706', bgTint: '#f59e0b', order: 1 },
        { id: 'follow-on',    label: 'PLANNED',  color: '#059669', bgTint: '#10b981', order: 2 },
        { id: 'proposed',     label: 'PROPOSED', color: '#2563eb', bgTint: '#3b82f6', order: 3 },
        { id: 'deferred',     label: 'HOLD',     color: '#94a3b8', bgTint: '#94a3b8', order: 4 },
    ];

    var STAGE_COLORS = {
        'Backlog':'#64748b','Scoping In Progress':'#64748b','Ready for Sizing':'#3b82f6',
        'Ready for Development':'#22c55e','In Development':'#22c55e',
        'Ready for QA':'#a855f7','QA In Progress':'#a855f7',
        'Ready for Client UAT':'#14b8a6','In Client UAT':'#14b8a6',
        'Ready for UAT Sign-off':'#14b8a6','Ready for Deployment':'#f97316',
        'Deploying':'#f97316','Done':'#9ca3af','Deployed to Prod':'#9ca3af',
        'Cancelled':'#cbd5e1','Paused':'#94a3b8','On Hold':'#94a3b8','Blocked':'#ef4444',
    };

    var DONE_STAGES = { 'Done':true, 'Deployed to Prod':true, 'Cancelled':true };

    /* Map Apex DTO → NormalizedTask shape that @nimbus-gantt/app expects */
    function toNormalized(apexTask) {
        return {
            id:               apexTask.id,
            title:            apexTask.title || apexTask.name || apexTask.id,
            priorityGroup:    apexTask.priorityGroup || null,
            parentWorkItemId: apexTask.parentWorkItemId || null,
            startDate:        apexTask.startDate || null,
            endDate:          apexTask.endDate   || null,
            estimatedHours:   Number(apexTask.estimatedHours) || 0,
            loggedHours:      Number(apexTask.loggedHours)    || 0,
            stage:            apexTask.stage    || '',
            sortOrder:        Number(apexTask.sortOrder) || 0,
            isInactive:       !!apexTask.isInactive,
            developerName:    apexTask.developerName || '',
            entityName:       apexTask.entityName    || '',
        };
    }

    function mount(container, props) {
        if (!window.NimbusGanttApp) {
            var err = document.createElement('div');
            err.style.cssText = 'padding:20px;color:#b91c1c;font-family:monospace;font-size:13px';
            err.textContent = 'NimbusGanttApp not loaded — check nimbusganttapp static resource';
            container.appendChild(err);
            return;
        }

        var tasks  = ((props && props.tasks) || []).map(toNormalized);
        var onPatch = props && props.onPatch;

        window.NimbusGanttApp.mount(container, {
            tasks:    tasks,
            onPatch:  onPatch || function() {},
            config: {
                title:   'Pro Forma Timeline',
                version: 'v5 \u00b7 Nimbus Gantt',
                buckets: PRIORITY_BUCKETS,
                colorMap: STAGE_COLORS,
                features: {
                    statsPanel:    true,
                    listView:      true,
                    treemapView:   true,
                    bubbleView:    true,
                    depthShading:  true,
                    dragReparent:  true,
                    detailPanel:   true,
                    groupByToggle: true,
                },
            },
        });
    }

    function unmount(container) {
        if (window.NimbusGanttApp) window.NimbusGanttApp.unmount(container);
        else container.innerHTML = '';
    }

    window.DeliveryTimeline = { mount: mount, unmount: unmount };
    console.log('[DeliveryTimeline] adapter loaded — using NimbusGanttApp chrome');
})();
