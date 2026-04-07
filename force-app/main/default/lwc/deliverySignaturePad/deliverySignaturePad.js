/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Canvas-backed signature pad for drawn signatures. Supports
 *               mouse + touch, exposes a public `getSignatureData()` API
 *               that returns the base64-encoded PNG bytes (no data: prefix).
 *               Adapted from the Mobilization Funding signatureDataCmp; rewritten
 *               to use instance state and bound class fields instead of module
 *               globals + setTimeout binding hacks.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api } from 'lwc';

const STROKE_COLOR = '#0c2340';
const STROKE_WIDTH = 1.75;
const CANVAS_WIDTH = 560;
const CANVAS_HEIGHT = 200;

export default class DeliverySignaturePad extends LightningElement {
    @api label = 'Draw your signature';

    _ctx = null;
    _canvas = null;
    _isDown = false;
    _prevX = 0;
    _prevY = 0;
    _currX = 0;
    _currY = 0;
    _hasInk = false;
    _initialized = false;

    renderedCallback() {
        if (this._initialized) {
            return;
        }
        const canvas = this.template.querySelector('canvas');
        if (!canvas) {
            return;
        }
        this._canvas = canvas;
        this._canvas.width = CANVAS_WIDTH;
        this._canvas.height = CANVAS_HEIGHT;
        this._ctx = canvas.getContext('2d');
        if (!this._ctx) {
            return;
        }
        // Mouse
        canvas.addEventListener('mousedown', this.handleDown);
        canvas.addEventListener('mousemove', this.handleMove);
        canvas.addEventListener('mouseup', this.handleUp);
        canvas.addEventListener('mouseleave', this.handleUp);
        // Touch — passive:false so preventDefault works inside the handler
        canvas.addEventListener('touchstart', this.handleTouchStart, { passive: false });
        canvas.addEventListener('touchmove', this.handleTouchMove, { passive: false });
        canvas.addEventListener('touchend', this.handleTouchEnd, { passive: false });
        this._initialized = true;
    }

    /**
     * @description Public API. Returns the base64-encoded PNG bytes (with the
     *              data: URL prefix stripped). Returns null if the user hasn't
     *              drawn anything.
     */
    @api
    getSignatureData() {
        if (!this._hasInk || !this._ctx || !this._canvas) {
            return null;
        }
        // Force a white background so the saved PNG isn't transparent —
        // looks cleaner when stamped onto a printed document.
        this._ctx.globalCompositeOperation = 'destination-over';
        this._ctx.fillStyle = '#ffffff';
        this._ctx.fillRect(0, 0, this._canvas.width, this._canvas.height);
        this._ctx.globalCompositeOperation = 'source-over';
        const dataUrl = this._canvas.toDataURL('image/png');
        return dataUrl.replace(/^data:image\/png;base64,/, '');
    }

    /**
     * @description Public API. Resets the canvas. Call from the parent when
     *              the user wants to redraw.
     */
    @api
    clear() {
        if (!this._ctx || !this._canvas) {
            return;
        }
        this._ctx.clearRect(0, 0, this._canvas.width, this._canvas.height);
        this._hasInk = false;
        this.dispatchEvent(new CustomEvent('signaturechange', { detail: { hasInk: false } }));
    }

    /**
     * @description Public API. True when the canvas has any drawn ink.
     */
    @api
    get hasInk() {
        return this._hasInk;
    }

    handleClearClick = () => {
        this.clear();
    };

    handleDown = (event) => {
        if (!this._ctx) {
            return;
        }
        this._isDown = true;
        this.updateCoordinate(event.clientX, event.clientY);
        // Draw a single dot so a single tap is captured.
        this._ctx.beginPath();
        this._ctx.fillStyle = STROKE_COLOR;
        this._ctx.fillRect(this._currX - STROKE_WIDTH / 2, this._currY - STROKE_WIDTH / 2, STROKE_WIDTH, STROKE_WIDTH);
        this._ctx.closePath();
        this.markInked();
    };

    handleMove = (event) => {
        if (!this._isDown || !this._ctx) {
            return;
        }
        this.updateCoordinate(event.clientX, event.clientY);
        this._ctx.beginPath();
        this._ctx.moveTo(this._prevX, this._prevY);
        this._ctx.lineTo(this._currX, this._currY);
        this._ctx.strokeStyle = STROKE_COLOR;
        this._ctx.lineWidth = STROKE_WIDTH;
        this._ctx.lineCap = 'round';
        this._ctx.lineJoin = 'round';
        this._ctx.stroke();
        this._ctx.closePath();
        this.markInked();
    };

    handleUp = () => {
        this._isDown = false;
    };

    handleTouchStart = (event) => {
        if (event.cancelable) {
            event.preventDefault();
        }
        const t = event.touches[0];
        if (t) {
            this.handleDown({ clientX: t.clientX, clientY: t.clientY });
        }
    };

    handleTouchMove = (event) => {
        if (event.cancelable) {
            event.preventDefault();
        }
        const t = event.touches[0];
        if (t) {
            this.handleMove({ clientX: t.clientX, clientY: t.clientY });
        }
    };

    handleTouchEnd = (event) => {
        if (event.cancelable) {
            event.preventDefault();
        }
        this.handleUp();
    };

    updateCoordinate(clientX, clientY) {
        const rect = this._canvas.getBoundingClientRect();
        // Account for CSS scaling — canvas is rendered at a fixed pixel size
        // but the rendered DOM rect can be smaller on tight layouts.
        const scaleX = this._canvas.width / rect.width;
        const scaleY = this._canvas.height / rect.height;
        this._prevX = this._currX;
        this._prevY = this._currY;
        this._currX = (clientX - rect.left) * scaleX;
        this._currY = (clientY - rect.top) * scaleY;
    }

    markInked() {
        if (!this._hasInk) {
            this._hasInk = true;
            this.dispatchEvent(new CustomEvent('signaturechange', { detail: { hasInk: true } }));
        }
    }
}
