;(function () {
    'use strict';
    /* -----------------------------------------------------------------------
     * DeliveryTimeline — v10 Salesforce data adapter.
     * Delegates all rendering to window.NimbusGanttApp (nimbus-gantt v10
     * template framework). Maps Apex DTOs → NormalizedTask and passes the
     * cloudnimbus template CSS URL through overrides.stylesheet.url so
     * ensureTemplateCss() can inject styles INTO the container (Strategy C).
     * -------------------------------------------------------------------- */

    function toNormalized(t) {
        return {
            id:               t.id,
            title:            t.title || t.name || t.id,
            priorityGroup:    t.priorityGroup || null,
            parentWorkItemId: t.parentWorkItemId || null,
            startDate:        t.startDate || null,
            endDate:          t.endDate   || null,
            estimatedHours:   Number(t.estimatedHours) || 0,
            loggedHours:      Number(t.loggedHours)    || 0,
            stage:            t.stage || '',
            sortOrder:        Number(t.sortOrder) || 0,
            isInactive:       !!t.isInactive,
            developerName:    t.developerName || '',
            entityName:       t.entityName    || '',
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

        var tasks = ((props && props.tasks) || []).map(toNormalized);
        var onPatch = (props && props.onPatch) || function () {};
        var cssUrl  = (props && props.cssUrl)  || null;

        window.NimbusGanttApp.mount(container, {
            template: 'cloudnimbus',
            tasks:    tasks,
            onPatch:  onPatch,
            overrides: cssUrl ? { stylesheet: { url: cssUrl } } : undefined,
            engine:   window.NimbusGantt,
        });
    }

    function unmount(container) {
        if (window.NimbusGanttApp) window.NimbusGanttApp.unmount(container);
        else container.innerHTML = '';
    }

    window.DeliveryTimeline = { mount: mount, unmount: unmount };
    console.log('[DeliveryTimeline] v10 adapter loaded — template=cloudnimbus');
})();
