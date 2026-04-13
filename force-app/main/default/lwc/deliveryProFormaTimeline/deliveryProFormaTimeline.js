/**
 * @name         Delivery Hub — deliveryProFormaTimeline
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Thin Salesforce shell for the cloudnimbusllc.com v8 delivery timeline.
 *               Fetches WorkItem__c data via Apex, loads the React bundle as a static
 *               resource, and mounts the full v8 UI (toolbar, gantt, sidebar, audit,
 *               canvas views) into a container div. Write-backs (drag/sort/bucket/dates)
 *               route back to Apex via the onPatch callback.
 * @author Cloud Nimbus LLC
 */
import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import DELIVERY_TIMELINE from '@salesforce/resourceUrl/deliverytimeline';
import getProFormaTimelineData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getProFormaTimelineData';
import updateWorkItemDates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemDates';
import updateWorkItemSortOrder from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemSortOrder';
import updateWorkItemPriorityGroup from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemPriorityGroup';
import updateWorkItemParent from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemParent';

export default class DeliveryProFormaTimeline extends LightningElement {

    _scriptLoaded = false;
    _mounted = false;
    _tasks = [];

    async connectedCallback() {
        try {
            await loadScript(this, DELIVERY_TIMELINE);
            this._scriptLoaded = true;
            await this._loadAndMount();
        } catch (error) {
            this._showError('Failed to load delivery timeline', error);
        }
    }

    disconnectedCallback() {
        if (this._mounted) {
            try {
                const container = this.template.querySelector('.timeline-container');
                if (container && window.DeliveryTimeline) {
                    window.DeliveryTimeline.unmount(container);
                }
            } catch (e) { /* swallow */ }
            this._mounted = false;
        }
    }

    async _loadAndMount() {
        try {
            const data = await getProFormaTimelineData({ showCompleted: false });
            this._tasks = data || [];
            // Give DOM a tick to render the container
            await new Promise(resolve => setTimeout(resolve, 0));
            this._mount();
        } catch (error) {
            this._showError('Failed to load work items', error);
        }
    }

    _mount() {
        const container = this.template.querySelector('.timeline-container');
        if (!container || !window.DeliveryTimeline) return;

        // Map Apex DTOs to SFTask shape the React bundle expects
        const tasks = this._tasks.map(r => ({
            id: r.id,
            title: r.title || r.name,
            priorityGroup: r.priorityGroup || 'follow-on',
            stage: r.stage || '',
            priority: r.priority || 'Medium',
            startDate: r.startDate || null,
            endDate: r.endDate || null,
            estimatedHours: Number(r.estimatedHours) || 0,
            loggedHours: Number(r.loggedHours) || 0,
            developerName: r.developerName || '',
            entityName: r.entityName || '',
            parentWorkItemId: r.parentWorkItemId || null,
            sortOrder: Number(r.sortOrder) || 0,
            isInactive: !!r.isInactive,
        }));

        window.DeliveryTimeline.mount(container, {
            tasks,
            onPatch: (patch) => this._handlePatch(patch),
        });
        this._mounted = true;
    }

    async _handlePatch(patch) {
        const { id, sortOrder, priorityGroup, parentId, startDate, endDate } = patch;
        const ops = [];

        if (sortOrder !== undefined) {
            ops.push(updateWorkItemSortOrder({ workItemId: id, sortOrder }));
        }
        if (priorityGroup !== undefined) {
            ops.push(updateWorkItemPriorityGroup({ workItemId: id, priorityGroup }));
        }
        if ('parentId' in patch) {
            ops.push(updateWorkItemParent({ workItemId: id, parentId: parentId || '' }));
        }
        if (startDate !== undefined || endDate !== undefined) {
            ops.push(updateWorkItemDates({
                workItemId: id,
                startDate: startDate || null,
                endDate: endDate || null,
            }));
        }

        try {
            await Promise.all(ops);
        } catch (error) {
            this._showError('Failed to save change', error);
        }
    }

    _showError(prefix, error) {
        const msg = (error && error.body && error.body.message) || (error && error.message) || 'Unknown error';
        // eslint-disable-next-line no-console
        console.error('[deliveryProFormaTimeline]', prefix, error);
        this.dispatchEvent(new ShowToastEvent({
            title: prefix, message: msg, variant: 'error',
        }));
    }
}
