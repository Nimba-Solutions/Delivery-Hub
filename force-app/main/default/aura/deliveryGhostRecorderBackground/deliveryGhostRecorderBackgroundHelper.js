/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Background Ghost Recorder logic. Mirrors c/deliveryGhostTracker
 *               rule for rule (3s same-URL debounce, Page_Duration on navigation
 *               and on tab hide, session id, context shape) because an Aura
 *               background utility item can neither import an LWC module nor
 *               render an LWC child. deliveryGhostTracker/__tests__ loads this
 *               file and runs the same scenarios against both, so the two
 *               cannot drift silently.
 *
 *               Before each log it fires PROBE_EVENT on window. A connected
 *               visible recorder answers synchronously with PRESENT_EVENT; in
 *               that case this item keeps its clock but sends nothing, so a page
 *               is never logged twice.
 * @author       Cloud Nimbus LLC
 */
({
    NAV_LOG_DEBOUNCE_MS: 3000,
    INITIAL_PAGE_DELAY_MS: 3000,
    PROBE_EVENT: 'delivery:ghostrecorder:probe',
    PRESENT_EVENT: 'delivery:ghostrecorder:present',
    states: {},

    start: function (component) {
        var helper = this;
        var key = component.getGlobalId();
        if (helper.states[key]) {
            return;
        }
        var state = {
            answered: false,
            lastLoggedTime: 0,
            lastLoggedUrl: '',
            pageArrivalTime: Date.now(),
            previousContext: null,
            sessionId: helper.generateSessionId()
        };
        state.onPresent = function () {
            state.answered = true;
        };
        state.onVisibility = $A.getCallback(function () {
            if (document.visibilityState === 'hidden' && state.pageArrivalTime > 0) {
                helper.logPageDuration(component, state, 'tab_hidden');
            }
        });
        window.addEventListener(helper.PRESENT_EVENT, state.onPresent);
        document.addEventListener('visibilitychange', state.onVisibility);
        helper.states[key] = state;
    },

    stop: function (component) {
        var key = component.getGlobalId();
        var state = this.states[key];
        if (!state) {
            return;
        }
        window.removeEventListener(this.PRESENT_EVENT, state.onPresent);
        document.removeEventListener('visibilitychange', state.onVisibility);
        delete this.states[key];
    },

    // The app's first page usually settles before this item initialises, so
    // its locationChange is missed. Log it shortly after init (giving an eager
    // visible recorder time to connect and claim it), unless a navigation was
    // already logged or LEX is still on the /lightning/app/ redirect. The page
    // clock keeps the init time, so the first Page_Duration is not short.
    scheduleInitialPage: function (component) {
        var helper = this;
        window.setTimeout($A.getCallback(function () {
            var state = helper.states[component.getGlobalId()];
            if (!state || state.lastLoggedUrl !== '' || window.location.href.indexOf('/lightning/app/') !== -1) {
                return;
            }
            var arrival = state.pageArrivalTime;
            helper.recordNavigation(component);
            state.pageArrivalTime = arrival;
        }), helper.INITIAL_PAGE_DELAY_MS);
    },

    recordNavigation: function (component) {
        try {
            var state = this.states[component.getGlobalId()];
            if (!state) {
                return;
            }
            var href = window.location.href;
            var now = Date.now();
            if (href === state.lastLoggedUrl && (now - state.lastLoggedTime) < this.NAV_LOG_DEBOUNCE_MS) {
                return;
            }

            // Log duration of the PREVIOUS page before recording the new one
            this.logPageDuration(component, state, 'navigation');

            state.lastLoggedUrl = href;
            state.lastLoggedTime = now;
            state.pageArrivalTime = now;

            var context = this.gatherContext(state);
            state.previousContext = context;
            this.send(component, state, 'Navigation', context);
        } catch (err) {
            // Never break user experience
        }
    },

    logPageDuration: function (component, state, exitType) {
        if (!state.previousContext || state.pageArrivalTime <= 0) {
            return;
        }
        var durationSec = Math.round((Date.now() - state.pageArrivalTime) / 1000);
        if (durationSec < 1) {
            return;
        }
        var ctx = Object.assign({}, state.previousContext, {
            duration: durationSec,
            exitType: exitType
        });
        this.send(component, state, 'Page_Duration', ctx);
    },

    visibleRecorderPresent: function (state) {
        state.answered = false;
        try {
            window.dispatchEvent(new CustomEvent(this.PROBE_EVENT, { detail: 'background' }));
        } catch (err) {
            return false;
        }
        return state.answered;
    },

    send: function (component, state, actionType, context) {
        try {
            if (this.visibleRecorderPresent(state)) {
                return;
            }
            var action = component.get('c.logUserActivity');
            action.setParams({
                actionType: actionType,
                contextData: JSON.stringify(context)
            });
            action.setBackground();
            $A.enqueueAction(action);
        } catch (err) {
            // Silent: never break user experience for telemetry
        }
    },

    gatherContext: function (state) {
        try {
            var parsed = this.parseUrlContext(window.location.href);
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
    },

    // Same URL rules as c/deliveryGhostTracker parseUrlContext. Aura has no
    // CurrentPageReference, so an unmatched URL is Unknown here where the LWC
    // recorder can fall back to page-reference attributes.
    parseUrlContext: function (href) {
        var recordMatch = href.match(/\/lightning\/r\/([^/]+)\/([a-zA-Z0-9]{15,18})\/view/);
        if (recordMatch) {
            return { objectName: recordMatch[1], pageLabel: recordMatch[1], recordId: recordMatch[2] };
        }
        var listMatch = href.match(/\/lightning\/o\/([^/]+)\/home/);
        if (listMatch) {
            return { objectName: listMatch[1], pageLabel: listMatch[1] + ' List', recordId: '' };
        }
        var listAltMatch = href.match(/\/lightning\/o\/([^/]+)\/list/);
        if (listAltMatch) {
            return { objectName: listAltMatch[1], pageLabel: listAltMatch[1] + ' List', recordId: '' };
        }
        if (href.indexOf('/lightning/page/home') !== -1) {
            return { objectName: 'Home', pageLabel: 'Home', recordId: '' };
        }
        if (href.indexOf('/lightning/page/chatter') !== -1) {
            return { objectName: 'Chatter', pageLabel: 'Chatter', recordId: '' };
        }
        if (href.indexOf('/lightning/setup/') !== -1) {
            return { objectName: 'Setup', pageLabel: 'Setup', recordId: '' };
        }
        var relatedMatch = href.match(/\/lightning\/r\/([^/]+)\/([a-zA-Z0-9]{15,18})\/related/);
        if (relatedMatch) {
            return { objectName: relatedMatch[1], pageLabel: relatedMatch[1] + ' Related', recordId: relatedMatch[2] };
        }
        return { objectName: 'Unknown', pageLabel: 'Unknown', recordId: '' };
    },

    generateSessionId: function () {
        try {
            return 'xxxxxxxx-xxxx-4xxx'.replace(/[x]/g, function () {
                return Math.floor(Math.random() * 16).toString(16);
            });
        } catch (err) {
            return 'unknown';
        }
    }
})
