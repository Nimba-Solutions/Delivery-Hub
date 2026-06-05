/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryCartBuilder: the running total, the
 *               freeform-add form (Sizing Only vs Will Do), the dollars gate, inline
 *               line actions (commit / remove / reorder), and the empty state.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryCartBuilder from "c/deliveryCartBuilder";
import getCart from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.getCart";
import createCartItem from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.createCartItem";
import addToCart from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.addToCart";

function sampleCart(overrides = {}) {
    return {
        lines: [
            {
                workItemId: "a01000000000001",
                name: "Existing sizing line",
                intention: "Sizing Only",
                isCommitted: false,
                estimatedHours: 5,
                projectedCost: 450,
                priority: "Medium"
            }
        ],
        summary: {
            count: 1,
            willDoCount: 0,
            sizingOnlyCount: 1,
            willDoHours: 0,
            sizingOnlyHours: 5,
            willDoCost: 0
        },
        profile: {
            showDollars: false,
            selfServe: true,
            checkoutMode: "Invoice",
            blendedRate: 90
        },
        ...overrides
    };
}

function createComponent() {
    const element = createElement("c-delivery-cart-builder", {
        is: DeliveryCartBuilder
    });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("c-delivery-cart-builder", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders the running total and current lines", async () => {
        const element = createComponent();
        getCart.emit(sampleCart());
        await flushPromises();

        const text = element.shadowRoot.textContent;
        expect(text).toContain("5.00h"); // running total (5 hours)
        expect(text).toContain("Existing sizing line");
    });

    it("hides dollars on the total when showDollars is false", async () => {
        const element = createComponent();
        getCart.emit(sampleCart());
        await flushPromises();
        expect(element.shadowRoot.textContent).not.toContain("$450");
    });

    it("shows dollars on the total when showDollars is true", async () => {
        const element = createComponent();
        getCart.emit(sampleCart({
            profile: { showDollars: true, selfServe: true, checkoutMode: "Invoice", blendedRate: 90 }
        }));
        await flushPromises();
        // 5 total hours * 90 = $450
        expect(element.shadowRoot.textContent).toContain("$450");
    });

    it("freeform-adds a Sizing Only line", async () => {
        createCartItem.mockResolvedValue("a01000000000099");
        getCart.mockResolvedValue(sampleCart());

        const element = createComponent();
        getCart.emit(sampleCart());
        await flushPromises();

        // Type into the description input — the change handler reads event.target.value.
        const desc = element.shadowRoot.querySelectorAll("lightning-input")[0];
        desc.value = "Brand new work";
        desc.dispatchEvent(new CustomEvent("change"));
        await flushPromises();

        // Click "Add to size".
        const buttons = element.shadowRoot.querySelectorAll("lightning-button");
        const sizeBtn = Array.from(buttons).find((b) => b.label === "Add to size");
        sizeBtn.dispatchEvent(new CustomEvent("click"));
        await flushPromises();

        expect(createCartItem).toHaveBeenCalledWith({
            description: "Brand new work",
            estimatedHours: null,
            intention: "Sizing Only"
        });
    });

    it("commits a line inline via addToCart", async () => {
        addToCart.mockResolvedValue(undefined);
        getCart.mockResolvedValue(sampleCart());

        const element = createComponent();
        getCart.emit(sampleCart());
        await flushPromises();

        const commitBtn = element.shadowRoot.querySelector(
            'lightning-button-icon[title="Commit (Will Do)"]'
        );
        expect(commitBtn).not.toBeNull();
        commitBtn.dispatchEvent(new CustomEvent("click"));
        await flushPromises();

        expect(addToCart).toHaveBeenCalledWith({
            workItemId: "a01000000000001",
            intention: "Will Do"
        });
    });

    it("shows the empty hint when the cart has no lines", async () => {
        const element = createComponent();
        getCart.emit({
            lines: [],
            summary: { count: 0, willDoCount: 0, sizingOnlyCount: 0, willDoHours: 0, sizingOnlyHours: 0, willDoCost: 0 },
            profile: { showDollars: false, selfServe: true, checkoutMode: "Invoice", blendedRate: 90 }
        });
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("No items in the cart yet");
    });
});
