import { LightningElement, api } from 'lwc';

export default class DeliveryGanttToolbar extends LightningElement {
    // Title and subtitle
    @api title = 'Timeline';
    @api subtitle = '';

    // Zoom controls — comma-separated list of available zoom levels
    @api zoomLevels = 'Day,Week,Month';
    @api currentZoom = 'Week';

    // Entity filter
    @api entityOptions = []; // array of {label, value}
    @api selectedEntity = '';
    @api hideEntityFilter = false;

    // Toggles (each has a show* to control visibility and a *Active for state)
    @api showDependencyToggle = false;
    @api dependenciesActive = false;

    @api showCompletedToggle = false;
    @api completedActive = false;

    @api showMyWorkToggle = false;
    @api myWorkActive = false;

    // Computed
    get zoomButtons() {
        return (this.zoomLevels || 'Day,Week,Month').split(',').map(z => ({
            label: z.trim(),
            value: z.trim(),
            variant: this.currentZoom === z.trim() ? 'brand' : 'neutral'
        }));
    }

    get showEntityCombobox() {
        return !this.hideEntityFilter && this.entityOptions && this.entityOptions.length > 2;
    }

    get depToggleVariant() { return this.dependenciesActive ? 'brand' : 'border'; }
    get depToggleTitle() { return this.dependenciesActive ? 'Hide dependencies' : 'Show dependencies'; }

    get completedToggleVariant() { return this.completedActive ? 'brand' : 'border'; }
    get completedToggleTitle() { return this.completedActive ? 'Hide completed' : 'Show completed'; }

    get myWorkToggleVariant() { return this.myWorkActive ? 'brand' : 'border'; }
    get myWorkToggleTitle() { return this.myWorkActive ? 'Show all items' : 'Show my work only'; }

    // Event handlers — all dispatch CustomEvents for parent to handle
    handleZoomClick(event) {
        const zoom = event.target.dataset.zoom || event.target.label;
        this.dispatchEvent(new CustomEvent('zoomchange', { detail: { value: zoom } }));
    }

    handleEntityChange(event) {
        this.dispatchEvent(new CustomEvent('entitychange', { detail: { value: event.detail.value } }));
    }

    handleToggleDependencies() {
        this.dispatchEvent(new CustomEvent('toggledependencies'));
    }

    handleToggleCompleted() {
        this.dispatchEvent(new CustomEvent('togglecompleted'));
    }

    handleToggleMyWork() {
        this.dispatchEvent(new CustomEvent('togglemywork'));
    }

    handleScrollToday() {
        this.dispatchEvent(new CustomEvent('scrolltoday'));
    }

    handleRefresh() {
        this.dispatchEvent(new CustomEvent('refresh'));
    }
}
