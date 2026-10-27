/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for the visible deliveryGhostRecorder's activity
 *               logging: Navigation payload shape, the 3s same-URL debounce,
 *               Page_Duration on navigation and on tab hide, and the
 *               CurrentPageReference fallback for unmatched URLs. Written
 *               against the pre-refactor component so the shared tracker
 *               extraction is proven behaviour-preserving.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import DeliveryGhostRecorder from "c/deliveryGhostRecorder";
import logActivity from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGhostController.logUserActivity";

const ACCOUNT_ID = "001000000000001AAA";
const CONTACT_ID = "003000000000001AAA";
const SESSION_ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}$/u;

let now = 1_700_000_000_000;

function setUrl(path) {
    window.history.pushState({}, "", path);
}

function calls(actionType) {
    return logActivity.mock.calls
        .map((args) => args[0])
        .filter((arg) => arg.actionType === actionType)
        .map((arg) => JSON.parse(arg.contextData));
}

function mount() {
    const element = createElement("c-delivery-ghost-recorder", { is: DeliveryGhostRecorder });
    document.body.appendChild(element);
    return element;
}

function navigate(path, pageRef) {
    setUrl(path);
    CurrentPageReference.emit(pageRef || { type: "standard__recordPage", attributes: {} });
}

describe("c-delivery-ghost-recorder activity logging", () => {
    beforeEach(() => {
        now = 1_700_000_000_000;
        jest.spyOn(Date, "now").mockImplementation(() => now);
        setUrl("/lightning/page/home");
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.restoreAllMocks();
        logActivity.mockClear();
    });

    it("logs a Navigation row with the full context shape", () => {
        mount();
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);

        const nav = calls("Navigation");
        expect(nav).toHaveLength(1);
        expect(Object.keys(nav[0]).sort()).toEqual(
            ["browser", "objectName", "pageLabel", "recordId", "sessionId", "url"]
        );
        expect(nav[0]).toMatchObject({
            objectName: "Account",
            pageLabel: "Account",
            recordId: ACCOUNT_ID,
            url: `http://localhost/lightning/r/Account/${ACCOUNT_ID}/view`
        });
        expect(nav[0].sessionId).toMatch(SESSION_ID_PATTERN);
        expect(nav[0].browser).toBe(navigator.userAgent);
    });

    it("skips a repeat of the same URL inside the 3s debounce, logs it after", () => {
        mount();
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        now += 1000;
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        expect(calls("Navigation")).toHaveLength(1);

        now += 5000;
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        expect(calls("Navigation")).toHaveLength(2);
    });

    it("logs Page_Duration for the previous page on navigation", () => {
        mount();
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        now += 7000;
        navigate(`/lightning/r/Contact/${CONTACT_ID}/view`);

        const durations = calls("Page_Duration");
        expect(durations).toHaveLength(1);
        expect(durations[0]).toMatchObject({
            duration: 7,
            exitType: "navigation",
            objectName: "Account",
            recordId: ACCOUNT_ID
        });
        const nav = calls("Navigation");
        expect(nav).toHaveLength(2);
        expect(nav[1].objectName).toBe("Contact");
        expect(nav[1].sessionId).toBe(nav[0].sessionId);
        expect(durations[0].sessionId).toBe(nav[0].sessionId);
    });

    it("does not log Page_Duration under one second", () => {
        mount();
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        now += 400;
        navigate(`/lightning/r/Contact/${CONTACT_ID}/view`);
        expect(calls("Page_Duration")).toHaveLength(0);
        expect(calls("Navigation")).toHaveLength(2);
    });

    it("logs Page_Duration with exitType tab_hidden when the tab is hidden", () => {
        mount();
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        now += 12000;
        jest.spyOn(document, "visibilityState", "get").mockReturnValue("hidden");
        document.dispatchEvent(new Event("visibilitychange"));

        const durations = calls("Page_Duration");
        expect(durations).toHaveLength(1);
        expect(durations[0]).toMatchObject({ duration: 12, exitType: "tab_hidden", objectName: "Account" });
    });

    it("parses list views and falls back to page reference attributes", () => {
        mount();
        navigate("/lightning/o/Opportunity/list");
        now += 4000;
        navigate("/lightning/n/delivery__Some_Tab", {
            type: "standard__navItemPage",
            attributes: { apiName: "delivery__Some_Tab", objectApiName: "WorkItem__c" }
        });

        const nav = calls("Navigation");
        expect(nav[0]).toMatchObject({ objectName: "Opportunity", pageLabel: "Opportunity List", recordId: "" });
        expect(nav[1]).toMatchObject({ objectName: "WorkItem__c", pageLabel: "WorkItem__c", recordId: "" });
    });

    it("stops listening for tab hide after disconnect", () => {
        const element = mount();
        navigate(`/lightning/r/Account/${ACCOUNT_ID}/view`);
        document.body.removeChild(element);
        now += 5000;
        jest.spyOn(document, "visibilityState", "get").mockReturnValue("hidden");
        document.dispatchEvent(new Event("visibilitychange"));
        expect(calls("Page_Duration")).toHaveLength(0);
    });
});
