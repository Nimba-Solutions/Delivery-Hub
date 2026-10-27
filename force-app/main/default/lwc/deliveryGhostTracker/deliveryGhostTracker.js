/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Shared Ghost Recorder activity tracker. One tracker per browser
 *               window, used by every component that records navigation:
 *                 - deliveryGhostRecorder          (visible utility / page card)
 *                 - deliveryGhostRecorderHeadless  (hosted by the Aura
 *                   deliveryGhostRecorderBackground utility-bar background item)
 *
 *               Each component calls attach() on connect, recordNavigation() from
 *               its CurrentPageReference wire, and detach() on disconnect. Because
 *               all state lives here (module scope, mirrored on window as a
 *               backstop), two recorders in the same tab share one session id,
 *               one debounce and one Page_Duration clock — a utility bar that
 *               carries both the visible and the background recorder logs each
 *               page once, not twice.
 *
 *               Logged rows are unchanged from the original recorder:
 *                 Navigation     {browser, objectName, pageLabel, recordId, sessionId, url}
 *                 Page_Duration  the previous page's Navigation context + {duration, exitType}
 *               via DeliveryGhostController.logUserActivity (gated server-side
 *               by DeliveryHubSettings__c.EnableActivityLoggingDateTime__c).
 * @author       Cloud Nimbus LLC
 */
import logActivity from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGhostController.logUserActivity';

export const NAV_LOG_DEBOUNCE_MS = 3000;
const MS_PER_SECOND = 1000;
const HEX_RADIX = 16;
const SESSION_ID_RANDOM_RANGE = 16;
const WINDOW_STATE_KEY = '__deliveryGhostTrackerState';

function freshState() {
    return {
        consumers: new Map(),
        currentPageRef: null,
        lastLoggedTime: 0,
        lastLoggedUrl: '',
        pageArrivalTime: 0,
        previousContext: null,
        sessionId: ''
    };
}

/* Window-level backstop: if this module were ever evaluated twice in one tab,
 * both copies still find the same state object, so the dedupe holds. */
function resolveState() {
    try {
        if (!window[WINDOW_STATE_KEY]) {
            window[WINDOW_STATE_KEY] = freshState();
        }
        return window[WINDOW_STATE_KEY];
    } catch (err) {
        return freshState();
    }
}

let state = resolveState();

function send(actionType, context) {
    try {
        logActivity({
            actionType,
            contextData: JSON.stringify(context)
        }).catch(() => {
            // Silent — never break user experience for telemetry
        });
    } catch (err) {
        // Never break user experience
    }
}

export function generateSessionId() {
    try {
        return 'xxxxxxxx-xxxx-4xxx'.replace(/[x]/gu, () =>
            (Math.random() * SESSION_ID_RANDOM_RANGE | 0).toString(HEX_RADIX) // eslint-disable-line no-bitwise
        );
    } catch (err) {
        return 'unknown';
    }
}

export function getSessionId() {
    return state.sessionId;
}

export function parseUrlContext(pageRef) {
    const href = window.location.href;
    // Pattern: /lightning/r/{objectApiName}/{recordId}/view
    const recordMatch = href.match(/\/lightning\/r\/([^/]+)\/([a-zA-Z0-9]{15,18})\/view/u);
    if (recordMatch) {
        return { objectName: recordMatch[1], pageLabel: recordMatch[1], recordId: recordMatch[2] };
    }
    // Pattern: /lightning/o/{objectApiName}/home (list view)
    const listMatch = href.match(/\/lightning\/o\/([^/]+)\/home/u);
    if (listMatch) {
        return { objectName: listMatch[1], pageLabel: `${listMatch[1]} List`, recordId: '' };
    }
    // Pattern: /lightning/o/{objectApiName}/list
    const listAltMatch = href.match(/\/lightning\/o\/([^/]+)\/list/u);
    if (listAltMatch) {
        return { objectName: listAltMatch[1], pageLabel: `${listAltMatch[1]} List`, recordId: '' };
    }
    // Pattern: /lightning/page/home
    if (href.includes('/lightning/page/home')) {
        return { objectName: 'Home', pageLabel: 'Home', recordId: '' };
    }
    // Pattern: /lightning/page/chatter
    if (href.includes('/lightning/page/chatter')) {
        return { objectName: 'Chatter', pageLabel: 'Chatter', recordId: '' };
    }
    // Pattern: /lightning/setup/...
    if (href.includes('/lightning/setup/')) {
        return { objectName: 'Setup', pageLabel: 'Setup', recordId: '' };
    }
    // Pattern: /lightning/r/{objectApiName}/{recordId}/related/...
    const relatedMatch = href.match(/\/lightning\/r\/([^/]+)\/([a-zA-Z0-9]{15,18})\/related/u);
    if (relatedMatch) {
        return { objectName: relatedMatch[1], pageLabel: `${relatedMatch[1]} Related`, recordId: relatedMatch[2] };
    }
    // Fallback: try CurrentPageReference attributes
    const ref = pageRef === undefined ? state.currentPageRef : pageRef;
    const attrs = ref?.attributes || {};
    return {
        objectName: attrs.objectApiName || attrs.name || 'Unknown',
        pageLabel: attrs.objectApiName || attrs.name || 'Unknown',
        recordId: attrs.recordId || ''
    };
}

export function gatherContext() {
    try {
        const parsed = parseUrlContext();
        return {
            browser: navigator.userAgent,
            objectName: parsed.objectName,
            pageLabel: parsed.pageLabel,
            recordId: parsed.recordId,
            sessionId: state.sessionId,
            url: window.location.href
        };
    } catch (err) {
        return {
            browser: '',
            objectName: 'Unknown',
            pageLabel: 'Unknown',
            recordId: '',
            sessionId: '',
            url: window.location.href || ''
        };
    }
}

function logPageDuration(exitType) {
    if (!state.previousContext || state.pageArrivalTime <= 0) {
        return;
    }
    const durationSec = Math.round((Date.now() - state.pageArrivalTime) / MS_PER_SECOND);
    if (durationSec < 1) {
        return;
    }
    const ctx = Object.assign({}, state.previousContext, {
        duration: durationSec,
        exitType
    });
    send('Page_Duration', ctx);
}

function handleVisibilityChange() {
    if (document.visibilityState === 'hidden' && state.pageArrivalTime > 0) {
        logPageDuration('tab_hidden');
    }
}

/**
 * Register a recorder component. The first consumer in a tab starts the
 * session (id + page clock + tab-hide listener); later ones join it.
 * @param {object} consumer the component instance (any unique object)
 */
export function attach(consumer) {
    state = resolveState();
    if (state.consumers.has(consumer)) {
        return;
    }
    if (state.consumers.size === 0) {
        state.sessionId = generateSessionId();
        state.pageArrivalTime = Date.now();
        document.addEventListener('visibilitychange', handleVisibilityChange);
    }
    state.consumers.set(consumer, { seenFirstPageRef: false });
}

/**
 * Unregister a recorder component. When the last one leaves, the session
 * ends and all state resets — exactly like a single recorder disconnecting.
 * @param {object} consumer the component instance passed to attach()
 */
export function detach(consumer) {
    if (!state.consumers.delete(consumer)) {
        return;
    }
    if (state.consumers.size === 0) {
        document.removeEventListener('visibilitychange', handleVisibilityChange);
        const consumers = state.consumers;
        Object.assign(state, freshState(), { consumers });
    }
}

/**
 * Feed a CurrentPageReference emission. Logs Page_Duration for the page being
 * left, then a Navigation row for the new one, with a 3s same-URL debounce.
 * A consumer that joins an already-running session does not re-log the page
 * the session already logged (its wire's initial emission is a replay).
 * @param {object} consumer the component instance passed to attach()
 * @param {object} pageRef  the CurrentPageReference value
 */
export function recordNavigation(consumer, pageRef) {
    try {
        const entry = state.consumers.get(consumer);
        if (!entry) {
            return;
        }
        if (pageRef) {
            state.currentPageRef = pageRef;
        }
        const href = window.location.href;
        const now = Date.now();
        const isJoinReplay = !entry.seenFirstPageRef
            && state.consumers.size > 1
            && state.lastLoggedUrl !== ''
            && href === state.lastLoggedUrl;
        entry.seenFirstPageRef = true;
        if (isJoinReplay) {
            return;
        }
        if (href === state.lastLoggedUrl && (now - state.lastLoggedTime) < NAV_LOG_DEBOUNCE_MS) {
            return;
        }

        // Log duration of the PREVIOUS page before recording the new one
        logPageDuration('navigation');

        state.lastLoggedUrl = href;
        state.lastLoggedTime = now;
        state.pageArrivalTime = now;

        const context = gatherContext();
        state.previousContext = context;
        send('Navigation', context);
    } catch (err) {
        // Never break user experience
    }
}
