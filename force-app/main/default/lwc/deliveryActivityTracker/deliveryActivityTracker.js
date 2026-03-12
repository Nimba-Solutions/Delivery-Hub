/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import userId from '@salesforce/user/Id';
import logActivity from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityTrackerController.logActivity';

const DEBOUNCE_MS = 5000;
const SESSION_KEY = 'delivery_activity_session_id';

export default class DeliveryActivityTracker extends LightningElement {
    _lastLoggedKey = '';
    _lastLoggedTime = 0;
    _sessionId;
    _currentUserId = userId;

    connectedCallback() {
        this._sessionId = this._getOrCreateSessionId();
    }

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (!pageRef) {
            return;
        }
        this._processNavigation(pageRef);
    }

    /**
     * Extracts page info from the CurrentPageReference and logs it,
     * applying debounce to avoid duplicate entries from rapid navigation.
     */
    _processNavigation(pageRef) {
        const attrs = pageRef.attributes || {};
        const state = pageRef.state || {};

        const objectApiName = attrs.objectApiName || state.objectApiName || '';
        const recordId = attrs.recordId || '';
        const actionName = attrs.actionName || '';
        const pageName = attrs.pageName || '';

        // Build a readable component/page name
        const componentName = this._resolveComponentName(pageRef, objectApiName, pageName, actionName);

        // Debounce: skip if same page logged within threshold
        const dedupeKey = `${componentName}|${recordId}`;
        const now = Date.now();
        if (dedupeKey === this._lastLoggedKey && (now - this._lastLoggedTime) < DEBOUNCE_MS) {
            return;
        }
        this._lastLoggedKey = dedupeKey;
        this._lastLoggedTime = now;

        // Build context JSON
        const contextData = JSON.stringify({
            url: window.location.href,
            objectApiName: objectApiName,
            recordId: recordId,
            actionName: actionName,
            timestamp: new Date().toISOString(),
            appName: this._resolveAppName(),
            pageType: pageRef.type,
            pageName: pageName
        });

        // Fire-and-forget
        logActivity({
            actionType: 'Navigation',
            componentName: componentName,
            recordId: recordId,
            contextData: contextData,
            sessionId: this._sessionId
        }).catch(err => {
            // Activity tracking must never disrupt the user experience
            // eslint-disable-next-line no-console
            console.debug('ActivityTracker: log failed', err);
        });
    }

    /**
     * Determines a human-readable name for the current page.
     */
    _resolveComponentName(pageRef, objectApiName, pageName, actionName) {
        const pageType = pageRef.type;

        if (pageType === 'standard__recordPage' && objectApiName) {
            const suffix = actionName ? ` (${actionName})` : '';
            return objectApiName + suffix;
        }
        if (pageType === 'standard__objectPage' && objectApiName) {
            return objectApiName + ' List';
        }
        if (pageType === 'standard__namedPage' && pageName) {
            return pageName;
        }
        if (pageType === 'standard__navItemPage') {
            const attrs = pageRef.attributes || {};
            return attrs.apiName || 'NavItem';
        }
        if (pageType === 'standard__app') {
            return 'App';
        }
        if (objectApiName) {
            return objectApiName;
        }
        return pageType || 'Unknown';
    }

    /**
     * Best-effort extraction of the current Lightning app name from the URL.
     */
    _resolveAppName() {
        try {
            const path = window.location.pathname;
            const match = path.match(/\/lightning\/app\/([^/]+)/);
            return match ? match[1] : '';
        } catch (_e) {
            return '';
        }
    }

    /**
     * Returns an existing session ID from sessionStorage, or creates and stores a new one.
     */
    _getOrCreateSessionId() {
        try {
            let sid = sessionStorage.getItem(SESSION_KEY);
            if (!sid) {
                sid = typeof crypto !== 'undefined' && crypto.randomUUID
                    ? crypto.randomUUID()
                    : 'sid-' + Date.now() + '-' + Math.random().toString(36).substring(2, 10);
                sessionStorage.setItem(SESSION_KEY, sid);
            }
            return sid;
        } catch (_e) {
            // sessionStorage may be unavailable in some contexts
            return 'sid-' + Date.now() + '-' + Math.random().toString(36).substring(2, 10);
        }
    }
}
