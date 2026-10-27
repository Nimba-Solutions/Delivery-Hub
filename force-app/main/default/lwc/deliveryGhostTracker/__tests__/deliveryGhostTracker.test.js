/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Parity + handshake tests for the two Ghost Recorder engines:
 *                 - c/deliveryGhostTracker (LWC, used by the visible recorder)
 *                 - aura/deliveryGhostRecorderBackground helper (Aura background
 *                   utility item, which cannot import LWC modules)
 *               The same navigation script is played against both and the logged
 *               rows must match field for field (session id aside). Also proves
 *               the background item stays quiet while an LWC recorder is
 *               attached, and resumes when it leaves.
 * @author       Cloud Nimbus LLC
 */
import { attach, detach, recordNavigation } from "c/deliveryGhostTracker";
import logActivity from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGhostController.logUserActivity";

const fs = require("fs");
const path = require("path");

const HELPER_PATH = path.resolve(
    __dirname,
    "../../../aura/deliveryGhostRecorderBackground/deliveryGhostRecorderBackgroundHelper.js"
);
const PAGE_REF = { type: "standard__recordPage", attributes: {} };
const ACCOUNT_ID = "001000000000001AAA";
const CONTACT_ID = "003000000000001AAA";

let now = 1_700_000_000_000;
let auraSent = [];

function loadHelper() {
    // eslint-disable-next-line no-new-func
    return new Function(`return (${fs.readFileSync(HELPER_PATH, "utf8")}
);`)();
}

function fakeComponent(id) {
    return {
        get: () => {
            const action = {
                params: null,
                setBackground: jest.fn(),
                setParams: (p) => {
                    action.params = p;
                }
            };
            return action;
        },
        getGlobalId: () => id
    };
}

function rows(list) {
    return list.map(({ actionType, contextData }) => {
        const ctx = JSON.parse(contextData);
        delete ctx.sessionId;
        return { actionType, ...ctx };
    });
}

function lwcRows() {
    return rows(logActivity.mock.calls.map((args) => args[0]));
}

function auraRows() {
    return rows(auraSent);
}

function go(url) {
    window.history.pushState({}, "", url);
}

function hideTab() {
    jest.spyOn(document, "visibilityState", "get").mockReturnValue("hidden");
    document.dispatchEvent(new Event("visibilitychange"));
    jest.spyOn(document, "visibilityState", "get").mockReturnValue("visible");
}

const SCRIPT = [
    { url: "/lightning/page/home", wait: 2000 },
    { url: `/lightning/r/Account/${ACCOUNT_ID}/view`, wait: 1000 },
    { url: `/lightning/r/Account/${ACCOUNT_ID}/view`, wait: 6000 },
    { url: "/lightning/o/Opportunity/list", wait: 400 },
    { url: "/lightning/o/Case/home", wait: 9000 },
    { url: `/lightning/r/Contact/${CONTACT_ID}/related/Cases/view`, wait: 3000 },
    { url: "/lightning/setup/SetupOneHome/home", wait: 5000 },
    { hide: true, wait: 0 },
    { url: "/lightning/page/chatter", wait: 1000 }
];

function play(onNavigate) {
    SCRIPT.forEach((step) => {
        if (step.hide) {
            hideTab();
        } else {
            go(step.url);
            onNavigate();
        }
        now += step.wait;
    });
}

describe("ghost recorder engines", () => {
    let helper;

    beforeEach(() => {
        now = 1_700_000_000_000;
        auraSent = [];
        jest.spyOn(Date, "now").mockImplementation(() => now);
        global.$A = {
            enqueueAction: (action) => auraSent.push(action.params),
            getCallback: (fn) => fn
        };
        helper = loadHelper();
        go("/lightning/page/home");
    });

    afterEach(() => {
        jest.restoreAllMocks();
        logActivity.mockClear();
        delete global.$A;
    });

    it("LWC tracker and Aura background helper log identical rows", () => {
        const consumer = {};
        attach(consumer);
        play(() => recordNavigation(consumer, PAGE_REF));
        detach(consumer);
        const expected = lwcRows();

        const cmp = fakeComponent("bg-1");
        now = 1_700_000_000_000;
        helper.start(cmp);
        play(() => helper.recordNavigation(cmp));
        helper.stop(cmp);

        expect(expected.length).toBeGreaterThan(8);
        expect(auraRows()).toEqual(expected);
        expect(auraSent.every((p) => /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}$/u.test(JSON.parse(p.contextData).sessionId)))
            .toBe(true);
    });

    it("background helper stays quiet while an LWC recorder is attached, resumes after", () => {
        const cmp = fakeComponent("bg-2");
        helper.start(cmp);
        const visible = {};
        attach(visible);

        go(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        recordNavigation(visible, PAGE_REF);
        helper.recordNavigation(cmp);
        now += 5000;
        go(`/lightning/r/Contact/${CONTACT_ID}/view`);
        recordNavigation(visible, PAGE_REF);
        helper.recordNavigation(cmp);
        now += 3000;
        hideTab();

        expect(lwcRows().map((r) => r.actionType)).toEqual(["Navigation", "Page_Duration", "Navigation", "Page_Duration"]);
        expect(auraSent).toHaveLength(0);

        detach(visible);
        now += 5000;
        go("/lightning/page/home");
        helper.recordNavigation(cmp);
        expect(auraRows()).toEqual([
            expect.objectContaining({ actionType: "Page_Duration", duration: 8, exitType: "navigation", objectName: "Contact" }),
            expect.objectContaining({ actionType: "Navigation", objectName: "Home" })
        ]);
        helper.stop(cmp);
    });

    it("background helper stops listening after destroy", () => {
        const cmp = fakeComponent("bg-3");
        helper.start(cmp);
        go(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        helper.recordNavigation(cmp);
        helper.stop(cmp);
        now += 5000;
        hideTab();
        helper.recordNavigation(cmp);
        expect(auraSent).toHaveLength(1);
    });

    it("background helper logs the first page after init, timed from init", () => {
        jest.useFakeTimers({ doNotFake: ["Date"] });
        try {
            const cmp = fakeComponent("bg-4");
            helper.start(cmp);
            helper.scheduleInitialPage(cmp);
            now += 3000;
            jest.advanceTimersByTime(3000);
            expect(auraRows()).toEqual([expect.objectContaining({ actionType: "Navigation", objectName: "Home" })]);
            now += 5000;
            go(`/lightning/r/Account/${ACCOUNT_ID}/view`);
            helper.recordNavigation(cmp);
            expect(auraRows()[1]).toEqual(expect.objectContaining({ actionType: "Page_Duration", duration: 8, objectName: "Home" }));
            helper.stop(cmp);
        } finally {
            jest.useRealTimers();
        }
    });

    it("background helper leaves the first page to a visible recorder that connected meanwhile", () => {
        jest.useFakeTimers({ doNotFake: ["Date"] });
        try {
            const cmp = fakeComponent("bg-5");
            helper.start(cmp);
            helper.scheduleInitialPage(cmp);
            const visible = {};
            attach(visible);
            recordNavigation(visible, PAGE_REF);
            jest.advanceTimersByTime(3000);
            expect(auraSent).toHaveLength(0);
            expect(lwcRows()).toHaveLength(1);
            detach(visible);
            helper.stop(cmp);
        } finally {
            jest.useRealTimers();
        }
    });

    it("background helper skips the first-page log on the /lightning/app/ redirect", () => {
        jest.useFakeTimers({ doNotFake: ["Date"] });
        try {
            go("/lightning/app/c__DeliveryHub");
            const cmp = fakeComponent("bg-6");
            helper.start(cmp);
            helper.scheduleInitialPage(cmp);
            jest.advanceTimersByTime(3000);
            expect(auraSent).toHaveLength(0);
            helper.stop(cmp);
        } finally {
            jest.useRealTimers();
        }
    });
});
