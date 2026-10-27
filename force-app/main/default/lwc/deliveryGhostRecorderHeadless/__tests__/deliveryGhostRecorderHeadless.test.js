/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for the headless Ghost Recorder (hosted by the Aura
 *               deliveryGhostRecorderBackground utility item) and the shared
 *               deliveryGhostTracker: renders nothing, logs the same Navigation /
 *               Page_Duration shape as the visible recorder, and never
 *               double-logs when the visible recorder is mounted in the same tab.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import DeliveryGhostRecorderHeadless from "c/deliveryGhostRecorderHeadless";
import DeliveryGhostRecorder from "c/deliveryGhostRecorder";
import { attach, detach, recordNavigation } from "c/deliveryGhostTracker";
import logActivity from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGhostController.logUserActivity";

const ACCOUNT_ID = "001000000000001AAA";
const CONTACT_ID = "003000000000001AAA";
const CASE_ID = "500000000000001AAA";
const SESSION_ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}$/u;
const PAGE_REF = { type: "standard__recordPage", attributes: {} };
const NAV_KEYS = ["browser", "objectName", "pageLabel", "recordId", "sessionId", "url"];

let now = 1_700_000_000_000;

function calls(actionType) {
    return logActivity.mock.calls
        .map((args) => args[0])
        .filter((arg) => arg.actionType === actionType)
        .map((arg) => JSON.parse(arg.contextData));
}

function mountHeadless() {
    const element = createElement("c-delivery-ghost-recorder-headless", { is: DeliveryGhostRecorderHeadless });
    document.body.appendChild(element);
    return element;
}

function mountVisible() {
    const element = createElement("c-delivery-ghost-recorder", { is: DeliveryGhostRecorder });
    document.body.appendChild(element);
    return element;
}

function navigate(path) {
    window.history.pushState({}, "", path);
    CurrentPageReference.emit({ type: "standard__recordPage", attributes: {} });
}

describe("c-delivery-ghost-recorder-headless", () => {
    beforeEach(() => {
        now = 1_700_000_000_000;
        jest.spyOn(Date, "now").mockImplementation(() => now);
        window.history.pushState({}, "", "/lightning/page/home");
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.restoreAllMocks();
        logActivity.mockClear();
    });

    it("renders nothing", () => {
        const element = mountHeadless();
        expect(element.shadowRoot.childNodes).toHaveLength(0);
    });

    it("logs Navigation and Page_Duration with the visible recorder's shape", () => {
        mountHeadless();
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        now += 6000;
        navigate(`/lightning/r/Contact/${CONTACT_ID}/view`);

        const nav = calls("Navigation");
        expect(nav).toHaveLength(2);
        expect(Object.keys(nav[0]).sort()).toEqual(NAV_KEYS);
        expect(nav[0]).toMatchObject({ objectName: "Account", recordId: ACCOUNT_ID });
        expect(nav[0].sessionId).toMatch(SESSION_ID_PATTERN);

        const durations = calls("Page_Duration");
        expect(durations).toHaveLength(1);
        expect(Object.keys(durations[0]).sort()).toEqual([...NAV_KEYS, "duration", "exitType"].sort());
        expect(durations[0]).toMatchObject({ duration: 6, exitType: "navigation", objectName: "Account" });
    });

    it("logs tab_hidden duration", () => {
        mountHeadless();
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        now += 9000;
        jest.spyOn(document, "visibilityState", "get").mockReturnValue("hidden");
        document.dispatchEvent(new Event("visibilitychange"));
        expect(calls("Page_Duration")).toEqual([
            expect.objectContaining({ duration: 9, exitType: "tab_hidden" })
        ]);
    });

    it("does not double-log when the visible recorder is mounted too", () => {
        mountHeadless();
        mountVisible();
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        now += 5000;
        navigate(`/lightning/r/Contact/${CONTACT_ID}/view`);
        now += 5000;
        navigate(`/lightning/r/Case/${CASE_ID}/view`);

        const nav = calls("Navigation");
        expect(nav.map((c) => c.objectName)).toEqual(["Account", "Contact", "Case"]);
        expect(new Set(nav.map((c) => c.sessionId)).size).toBe(1);
        expect(calls("Page_Duration")).toHaveLength(2);

        now += 5000;
        jest.spyOn(document, "visibilityState", "get").mockReturnValue("hidden");
        document.dispatchEvent(new Event("visibilitychange"));
        expect(calls("Page_Duration")).toHaveLength(3);
    });

    it("a recorder that joins later does not re-log the current page", () => {
        // Drive the shared tracker directly: the jest wire stub broadcasts every
        // emit to all components, so a per-consumer "first emission" replay
        // (what LEX does when a lazily-loaded utility panel wires up) is only
        // expressible at the module level.
        const background = {};
        const visible = {};
        attach(background);
        window.history.pushState({}, "", `/lightning/r/Account/${ACCOUNT_ID}/view`);
        recordNavigation(background, PAGE_REF);
        now += 60000;
        attach(visible);
        recordNavigation(visible, PAGE_REF);
        expect(calls("Navigation")).toHaveLength(1);
        expect(calls("Page_Duration")).toHaveLength(0);

        now += 5000;
        window.history.pushState({}, "", `/lightning/r/Contact/${CONTACT_ID}/view`);
        recordNavigation(visible, PAGE_REF);
        expect(calls("Navigation")).toHaveLength(2);
        expect(calls("Page_Duration")).toEqual([
            expect.objectContaining({ duration: 65, objectName: "Account" })
        ]);
        detach(visible);
        detach(background);
    });

    it("keeps logging when the visible recorder leaves, and stops when the last one leaves", () => {
        mountHeadless();
        const visible = mountVisible();
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        const sessionId = calls("Navigation")[0].sessionId;

        document.body.removeChild(visible);
        now += 4000;
        navigate(`/lightning/r/Contact/${CONTACT_ID}/view`);
        const nav = calls("Navigation");
        expect(nav).toHaveLength(2);
        expect(nav[1].sessionId).toBe(sessionId);

        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        now += 4000;
        jest.spyOn(document, "visibilityState", "get").mockReturnValue("hidden");
        document.dispatchEvent(new Event("visibilitychange"));
        expect(calls("Page_Duration")).toHaveLength(1);
    });
});
