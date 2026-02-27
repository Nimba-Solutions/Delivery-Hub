/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Interactive SVG dependency graph visualization using a lightweight
 *              force-directed layout. SVG is built programmatically for full
 *              compatibility with LWC's template restrictions.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDependencyGraph from '@salesforce/apex/DeliveryDependencyGraphController.getDependencyGraph';
import getProjectDependencyGraph from '@salesforce/apex/DeliveryDependencyGraphController.getProjectDependencyGraph';
import getWorkflowConfig from '@salesforce/apex/DeliveryWorkflowConfigService.getWorkflowConfig';

const SVG_NS = 'http://www.w3.org/2000/svg';

// Priority -> node radius mapping
const PRIORITY_RADIUS = { High: 28, Medium: 22, Low: 18 };
const DEFAULT_RADIUS = 20;

// Force simulation constants
const REPULSION_STRENGTH = 3000;
const ATTRACTION_STRENGTH = 0.005;
const GRAVITY_STRENGTH = 0.01;
const DAMPING = 0.85;
const SIMULATION_ITERATIONS = 120;
const MIN_DISTANCE = 80;

export default class DeliveryDependencyGraph extends NavigationMixin(LightningElement) {
    @api recordId;
    @api workflowType = 'Software_Delivery';
    @api height = 400;

    @track nodes = [];
    @track edges = [];
    @track isLoading = true;
    @track errorMessage;
    @track tooltipNode = null;
    @track tooltipStyle = '';

    _stageColorMap = {};
    _svgWidth = 600;
    _svgHeight = 400;
    _viewBox = { x: 0, y: 0, w: 600, h: 400 };
    _isPanning = false;
    _panStart = { x: 0, y: 0 };
    _viewBoxStart = { x: 0, y: 0 };
    _simulationNodes = [];
    _simulationEdges = [];
    _resizeObserver;
    _svgElement;
    _svgRendered = false;

    // -------------------------------------------------------------------------
    // Wire: load workflow config for stage colors
    // -------------------------------------------------------------------------
    @wire(getWorkflowConfig, { workflowTypeName: '$workflowType' })
    wiredConfig({ data }) {
        if (data && data.stages) {
            const colorMap = {};
            for (const stage of data.stages) {
                colorMap[stage.apiValue] = stage.cardColor || '#b0c4de';
            }
            this._stageColorMap = colorMap;
            if (this._simulationNodes.length > 0) {
                this._renderSvg();
            }
        }
    }

    // -------------------------------------------------------------------------
    // Wire: load dependency graph data
    // -------------------------------------------------------------------------
    @wire(getDependencyGraph, { workItemId: '$recordId' })
    wiredGraph({ data, error }) {
        if (this.recordId) {
            this._handleGraphData(data, error);
        }
    }

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------
    connectedCallback() {
        if (!this.recordId && this.workflowType) {
            this._loadProjectGraph();
        }
    }

    renderedCallback() {
        this._measureContainer();
        if (!this._resizeObserver) {
            const container = this.template.querySelector('.graph-container');
            if (container && typeof ResizeObserver !== 'undefined') {
                this._resizeObserver = new ResizeObserver(() => {
                    this._measureContainer();
                    if (this._simulationNodes.length > 0) {
                        this._updateViewBoxAttr();
                    }
                });
                this._resizeObserver.observe(container);
            }
        }
        // Render SVG after the DOM is available
        if (this.hasGraph && !this._svgRendered) {
            this._renderSvg();
        }
    }

    disconnectedCallback() {
        if (this._resizeObserver) {
            this._resizeObserver.disconnect();
            this._resizeObserver = null;
        }
    }

    // -------------------------------------------------------------------------
    // Data loading
    // -------------------------------------------------------------------------
    _loadProjectGraph() {
        this.isLoading = true;
        getProjectDependencyGraph({ workflowType: this.workflowType })
            .then(data => this._handleGraphData(data, null))
            .catch(error => this._handleGraphData(null, error));
    }

    _handleGraphData(data, error) {
        this._svgRendered = false;
        if (data) {
            this.nodes = data.nodes || [];
            this.edges = data.edges || [];
            this.errorMessage = null;
            this.isLoading = false;
            if (this.nodes.length > 0) {
                this._runSimulation();
            }
        } else if (error) {
            this.errorMessage = this._extractError(error);
            this.isLoading = false;
        }
    }

    _extractError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An error occurred loading the dependency graph.';
    }

    // -------------------------------------------------------------------------
    // Force-directed layout simulation
    // -------------------------------------------------------------------------
    _runSimulation() {
        this._measureContainer();
        const width = this._svgWidth;
        const height = this._svgHeight;
        const cx = width / 2;
        const cy = height / 2;

        const nodeCount = this.nodes.length;
        const simNodes = this.nodes.map((n, i) => {
            const angle = (2 * Math.PI * i) / nodeCount;
            const r = Math.min(width, height) * 0.3;
            return {
                ...n,
                x: cx + r * Math.cos(angle),
                y: cy + r * Math.sin(angle),
                vx: 0,
                vy: 0,
                radius: PRIORITY_RADIUS[n.priority] || DEFAULT_RADIUS
            };
        });

        const nodeById = {};
        for (const sn of simNodes) {
            nodeById[sn.id] = sn;
        }

        const simEdges = this.edges
            .map(e => ({ source: nodeById[e.source], target: nodeById[e.target], type: e.type }))
            .filter(e => e.source && e.target);

        for (let iter = 0; iter < SIMULATION_ITERATIONS; iter++) {
            const cooling = 1 - (iter / SIMULATION_ITERATIONS) * 0.8;

            // Repulsion
            for (let i = 0; i < simNodes.length; i++) {
                for (let j = i + 1; j < simNodes.length; j++) {
                    const a = simNodes[i];
                    const b = simNodes[j];
                    let dx = b.x - a.x;
                    let dy = b.y - a.y;
                    let dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist < 1) { dist = 1; dx = (Math.random() - 0.5) * 2; dy = (Math.random() - 0.5) * 2; }
                    const force = (REPULSION_STRENGTH * cooling) / (dist * dist);
                    const fx = (dx / dist) * force;
                    const fy = (dy / dist) * force;
                    a.vx -= fx; a.vy -= fy;
                    b.vx += fx; b.vy += fy;
                }
            }

            // Attraction along edges
            for (const edge of simEdges) {
                const dx = edge.target.x - edge.source.x;
                const dy = edge.target.y - edge.source.y;
                const dist = Math.sqrt(dx * dx + dy * dy);
                if (dist > MIN_DISTANCE) {
                    const force = (dist - MIN_DISTANCE) * ATTRACTION_STRENGTH * cooling;
                    const fx = (dx / dist) * force;
                    const fy = (dy / dist) * force;
                    edge.source.vx += fx; edge.source.vy += fy;
                    edge.target.vx -= fx; edge.target.vy -= fy;
                }
            }

            // Gravity toward center
            for (const node of simNodes) {
                node.vx += (cx - node.x) * GRAVITY_STRENGTH * cooling;
                node.vy += (cy - node.y) * GRAVITY_STRENGTH * cooling;
            }

            // Apply velocities
            for (const node of simNodes) {
                node.vx *= DAMPING; node.vy *= DAMPING;
                node.x += node.vx; node.y += node.vy;
            }
        }

        this._simulationNodes = simNodes;
        this._simulationEdges = simEdges;
        this._computeViewBox();
    }

    // -------------------------------------------------------------------------
    // ViewBox
    // -------------------------------------------------------------------------
    _measureContainer() {
        const container = this.template.querySelector('.graph-container');
        if (container) {
            const rect = container.getBoundingClientRect();
            this._svgWidth = Math.max(rect.width || 600, 300);
            this._svgHeight = Math.max(this.height || 400, 200);
        }
    }

    _computeViewBox() {
        if (this._simulationNodes.length === 0) return;
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (const n of this._simulationNodes) {
            const r = n.radius + 10;
            if (n.x - r < minX) minX = n.x - r;
            if (n.y - r < minY) minY = n.y - r;
            if (n.x + r > maxX) maxX = n.x + r;
            if (n.y + r > maxY) maxY = n.y + r;
        }
        const padding = 60;
        this._viewBox = { x: minX - padding, y: minY - padding, w: (maxX - minX) + padding * 2, h: (maxY - minY) + padding * 2 };
    }

    _updateViewBoxAttr() {
        if (this._svgElement) {
            const vb = this._viewBox;
            this._svgElement.setAttribute('viewBox', `${vb.x} ${vb.y} ${vb.w} ${vb.h}`);
        }
    }

    // -------------------------------------------------------------------------
    // SVG Rendering (programmatic for full SVG feature support)
    // -------------------------------------------------------------------------
    _renderSvg() {
        const host = this.template.querySelector('.svg-host');
        if (!host) return;

        // Clear previous SVG
        host.innerHTML = '';
        this._svgRendered = true;

        const svg = document.createElementNS(SVG_NS, 'svg');
        svg.setAttribute('class', 'graph-svg');
        svg.setAttribute('xmlns', SVG_NS);
        const vb = this._viewBox;
        svg.setAttribute('viewBox', `${vb.x} ${vb.y} ${vb.w} ${vb.h}`);
        svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
        this._svgElement = svg;

        // Event listeners
        svg.addEventListener('wheel', (e) => this._onWheel(e), { passive: false });
        svg.addEventListener('mousedown', (e) => this._onPanStart(e));
        svg.addEventListener('mousemove', (e) => this._onPanMove(e));
        svg.addEventListener('mouseup', () => this._onPanEnd());
        svg.addEventListener('mouseleave', () => this._onPanEnd());

        // Defs
        const defs = document.createElementNS(SVG_NS, 'defs');

        // Arrow marker for Blocks edges
        defs.appendChild(this._createArrowMarker('arrowBlocks', '#e3716e'));
        // Arrow marker for Relates To edges
        defs.appendChild(this._createArrowMarker('arrowRelates', '#9faab5'));
        // Glow filter for current item
        defs.appendChild(this._createGlowFilter());

        svg.appendChild(defs);

        // Render edges
        for (const e of this._simulationEdges) {
            svg.appendChild(this._createEdgeElement(e));
        }

        // Render nodes
        for (const n of this._simulationNodes) {
            svg.appendChild(this._createNodeElement(n));
        }

        host.appendChild(svg);
    }

    _createArrowMarker(id, color) {
        const marker = document.createElementNS(SVG_NS, 'marker');
        marker.setAttribute('id', id);
        marker.setAttribute('viewBox', '0 0 10 10');
        marker.setAttribute('refX', '10');
        marker.setAttribute('refY', '5');
        marker.setAttribute('markerWidth', '8');
        marker.setAttribute('markerHeight', '8');
        marker.setAttribute('orient', 'auto-start-reverse');
        const path = document.createElementNS(SVG_NS, 'path');
        path.setAttribute('d', 'M 0 0 L 10 5 L 0 10 z');
        path.setAttribute('fill', color);
        marker.appendChild(path);
        return marker;
    }

    _createGlowFilter() {
        const filter = document.createElementNS(SVG_NS, 'filter');
        filter.setAttribute('id', 'currentGlow');
        filter.setAttribute('x', '-50%');
        filter.setAttribute('y', '-50%');
        filter.setAttribute('width', '200%');
        filter.setAttribute('height', '200%');
        const blur = document.createElementNS(SVG_NS, 'feGaussianBlur');
        blur.setAttribute('stdDeviation', '3');
        blur.setAttribute('result', 'blur');
        filter.appendChild(blur);
        const merge = document.createElementNS(SVG_NS, 'feMerge');
        const mn1 = document.createElementNS(SVG_NS, 'feMergeNode');
        mn1.setAttribute('in', 'blur');
        merge.appendChild(mn1);
        const mn2 = document.createElementNS(SVG_NS, 'feMergeNode');
        mn2.setAttribute('in', 'SourceGraphic');
        merge.appendChild(mn2);
        filter.appendChild(merge);
        return filter;
    }

    _createEdgeElement(e) {
        const sourceR = e.source.radius;
        const targetR = e.target.radius;
        const dx = e.target.x - e.source.x;
        const dy = e.target.y - e.source.y;
        let dist = Math.sqrt(dx * dx + dy * dy);
        if (dist === 0) dist = 1;
        const ux = dx / dist;
        const uy = dy / dist;

        const line = document.createElementNS(SVG_NS, 'line');
        line.setAttribute('x1', e.source.x + ux * sourceR);
        line.setAttribute('y1', e.source.y + uy * sourceR);
        line.setAttribute('x2', e.target.x - ux * (targetR + 6));
        line.setAttribute('y2', e.target.y - uy * (targetR + 6));

        const isBlocks = e.type === 'Blocks';
        line.setAttribute('class', isBlocks ? 'graph-edge graph-edge--blocks' : 'graph-edge graph-edge--relates');
        line.setAttribute('marker-end', isBlocks ? 'url(#arrowBlocks)' : 'url(#arrowRelates)');
        return line;
    }

    _createNodeElement(n) {
        const g = document.createElementNS(SVG_NS, 'g');
        g.setAttribute('class', n.isCurrentItem ? 'graph-node graph-node--current' : 'graph-node');
        g.setAttribute('data-id', n.id);
        if (n.isCurrentItem) {
            g.setAttribute('filter', 'url(#currentGlow)');
        }

        const circle = document.createElementNS(SVG_NS, 'circle');
        circle.setAttribute('cx', n.x);
        circle.setAttribute('cy', n.y);
        circle.setAttribute('r', n.radius);
        circle.setAttribute('fill', this._stageColorMap[n.stage] || '#b0c4de');
        circle.setAttribute('stroke', n.isCurrentItem ? '#0176d3' : '#ffffff');
        circle.setAttribute('stroke-width', n.isCurrentItem ? '3' : '1.5');
        g.appendChild(circle);

        const text = document.createElementNS(SVG_NS, 'text');
        text.setAttribute('x', n.x);
        text.setAttribute('y', n.y + n.radius + 14);
        text.setAttribute('class', 'graph-label');
        text.setAttribute('text-anchor', 'middle');
        text.textContent = this._truncateLabel(n.name);
        g.appendChild(text);

        // Event listeners on node group
        g.addEventListener('click', () => this._navigateToRecord(n.id));
        g.addEventListener('mouseenter', (evt) => this._showTooltip(evt, n));
        g.addEventListener('mouseleave', () => this._hideTooltip());

        return g;
    }

    // -------------------------------------------------------------------------
    // SVG Event handlers
    // -------------------------------------------------------------------------
    _onWheel(event) {
        event.preventDefault();
        const delta = event.deltaY > 0 ? 1.1 : 0.9;
        const vb = this._viewBox;
        const centerX = vb.x + vb.w / 2;
        const centerY = vb.y + vb.h / 2;
        const newW = vb.w * delta;
        const newH = vb.h * delta;
        if (newW < 100 || newW > 5000 || newH < 100 || newH > 5000) return;
        this._viewBox = { x: centerX - newW / 2, y: centerY - newH / 2, w: newW, h: newH };
        this._updateViewBoxAttr();
    }

    _onPanStart(event) {
        if (event.target.closest('.graph-node')) return;
        this._isPanning = true;
        this._panStart = { x: event.clientX, y: event.clientY };
        this._viewBoxStart = { x: this._viewBox.x, y: this._viewBox.y };
    }

    _onPanMove(event) {
        if (!this._isPanning || !this._svgElement) return;
        const svgRect = this._svgElement.getBoundingClientRect();
        const scaleX = this._viewBox.w / svgRect.width;
        const scaleY = this._viewBox.h / svgRect.height;
        const dx = (event.clientX - this._panStart.x) * scaleX;
        const dy = (event.clientY - this._panStart.y) * scaleY;
        this._viewBox = { ...this._viewBox, x: this._viewBoxStart.x - dx, y: this._viewBoxStart.y - dy };
        this._updateViewBoxAttr();
    }

    _onPanEnd() {
        this._isPanning = false;
    }

    _navigateToRecord(nodeId) {
        if (nodeId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: nodeId,
                    objectApiName: 'WorkItem__c',
                    actionName: 'view'
                }
            });
        }
    }

    _showTooltip(event, node) {
        this.tooltipNode = {
            name: node.name,
            title: node.title || 'No description',
            stage: node.stage || 'Unknown',
            priority: node.priority || 'None',
            owner: node.owner || 'Unassigned'
        };
        const containerRect = this.template.querySelector('.graph-container').getBoundingClientRect();
        const mouseX = event.clientX - containerRect.left;
        const mouseY = event.clientY - containerRect.top;
        const flipX = mouseX > containerRect.width * 0.6;
        const left = flipX ? mouseX - 220 : mouseX + 16;
        const top = Math.max(4, mouseY - 30);
        this.tooltipStyle = `left: ${left}px; top: ${top}px;`;
    }

    _hideTooltip() {
        this.tooltipNode = null;
    }

    // -------------------------------------------------------------------------
    // Template-bound handlers
    // -------------------------------------------------------------------------
    handleResetZoom() {
        this._computeViewBox();
        this._updateViewBoxAttr();
    }

    // -------------------------------------------------------------------------
    // Computed properties for template
    // -------------------------------------------------------------------------
    get hasGraph() {
        return this.nodes.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && this.nodes.length === 0;
    }

    get containerStyle() {
        return `height: ${this.height}px;`;
    }

    get hasTooltip() {
        return this.tooltipNode !== null;
    }

    get legendItems() {
        const seen = new Set();
        const items = [];
        for (const n of this._simulationNodes) {
            if (!seen.has(n.stage)) {
                seen.add(n.stage);
                const color = this._stageColorMap[n.stage] || '#b0c4de';
                items.push({
                    key: n.stage,
                    label: n.stage,
                    swatchStyle: `background-color: ${color};`
                });
            }
        }
        return items;
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------
    _truncateLabel(text) {
        if (!text) return '';
        return text.length > 12 ? text.substring(0, 12) : text;
    }
}
