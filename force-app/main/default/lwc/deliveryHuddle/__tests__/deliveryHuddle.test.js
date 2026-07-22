/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryHuddle: wire-driven rows grouped by
 *               epic (Ungrouped last), overdue/stale badge derivation, latest
 *               comment line, filter chips slicing the list, quick-add gating
 *               and the create call shape.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryHuddle from "c/deliveryHuddle";
import getHuddleItems from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHuddleController.getHuddleItems";
import quickAddItem from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHuddleController.quickAddItem";

const DAY = 86400000;

function isoDaysFromNow(days) {
    return new Date(Date.now() + days * DAY).toISOString();
}

function dateOnlyDaysFromNow(days) {
    return new Date(Date.now() + days * DAY).toISOString().slice(0, 10);
}

function sampleItems() {
    return [
        {
            workItemId: "a00000000000001AAA",
            name: "T-0001",
            title: "Confirm Thursday trigger owner",
            status: "Active",
            stage: "Backlog",
            epic: "MF Check-in",
            ownerName: "Glen Bradford",
            dueDate: dateOnlyDaysFromNow(-2),
            externalPageUrl: "https://example.com/mf/standup",
            lastModified: isoDaysFromNow(-1),
            stageEntered: isoDaysFromNow(-3),
            createdDate: isoDaysFromNow(-5),
            lastCommentBody: "Jose thinks it is his",
            lastCommentAuthor: "Glen",
            lastCommentDate: isoDaysFromNow(-1)
        },
        {
            workItemId: "a00000000000002AAA",
            name: "T-0002",
            title: "Old forgotten item",
            status: "Active",
            stage: "Backlog",
            epic: null,
            ownerName: null,
            dueDate: null,
            externalPageUrl: null,
            // lastModified is recent (simulates the hourly ETA-service re-stamp)
            // but human signals are a month old — the item must still read stale.
            lastModified: isoDaysFromNow(0),
            stageEntered: isoDaysFromNow(-30),
            createdDate: isoDaysFromNow(-40),
            lastCommentBody: null,
            lastCommentAuthor: null,
            lastCommentDate: null
        }
    ];
}

function createComponent() {
    const element = createElement("c-delivery-huddle", { is: DeliveryHuddle });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function findButtonByLabel(element, label) {
    return Array.from(element.shadowRoot.querySelectorAll("lightning-button")).find(
        (b) => b.label === label
    );
}

function findInputByLabel(element, label) {
    return Array.from(element.shadowRoot.querySelectorAll("lightning-input")).find(
        (i) => i.label === label
    );
}

describe("c-delivery-huddle", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders items grouped by epic with Ungrouped last, badges and comment line", async () => {
        const element = createComponent();
        getHuddleItems.emit(sampleItems());
        await flushPromises();

        const text = element.shadowRoot.textContent;
        expect(text).toContain("T-0001");
        expect(text).toContain("Confirm Thursday trigger owner");
        expect(text).toContain("Glen · 1d ago: Jose thinks it is his");
        expect(text).toContain("No comments yet");

        const headings = Array.from(
            element.shadowRoot.querySelectorAll(".slds-text-heading_small")
        ).map((h) => h.textContent);
        expect(headings.length).toBe(2);
        expect(headings[0]).toContain("MF Check-in");
        expect(headings[1]).toContain("Ungrouped");

        // Overdue badge on item one; Stale badge on item two even though its
        // lastModified is fresh (system-job touches must not mask staleness).
        expect(text).toContain("Overdue 2d");
        expect(text).toContain("Stale");
        expect(text).toContain("activity 30d ago");
    });

    it("filter chips slice the list", async () => {
        const element = createComponent();
        getHuddleItems.emit(sampleItems());
        await flushPromises();

        const staleChip = findButtonByLabel(element, "Stale (1)");
        expect(staleChip).toBeTruthy();
        staleChip.click();
        await flushPromises();

        const text = element.shadowRoot.textContent;
        expect(text).toContain("Old forgotten item");
        expect(text).not.toContain("Confirm Thursday trigger owner");
    });

    it("quick-add is gated on title and calls apex with the drafted values", async () => {
        quickAddItem.mockResolvedValue("a00000000000003AAA");
        const element = createComponent();
        getHuddleItems.emit(sampleItems());
        await flushPromises();

        const addButton = findButtonByLabel(element, "Add");
        expect(addButton.disabled).toBe(true);

        const titleInput = findInputByLabel(element, "Capture a work item");
        titleInput.value = "New huddle capture";
        titleInput.dispatchEvent(new CustomEvent("change"));
        const epicInput = findInputByLabel(element, "Epic / group");
        epicInput.value = "MF Check-in";
        epicInput.dispatchEvent(new CustomEvent("change"));
        await flushPromises();

        expect(addButton.disabled).toBe(false);
        addButton.click();
        await flushPromises();

        expect(quickAddItem).toHaveBeenCalledWith({
            title: "New huddle capture",
            dueDate: null,
            epic: "MF Check-in",
            externalPageUrl: null
        });
    });
});
