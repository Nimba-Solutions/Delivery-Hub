/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryCartCheckout: Will Do vs Sizing Only
 *               sectioning, the hours/$ gate on profile.showDollars, the summary
 *               header, the checkout-mode-driven button label, row navigation, and
 *               empty/error states.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from "lwc";
import DeliveryCartCheckout from "c/deliveryCartCheckout";
import getCart from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.getCart";
import checkout from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCartService.checkout";

function sampleCart(overrides = {}) {
    return {
        lines: [
            {
                workItemId: "a01000000000001",
                name: "Build the thing",
                intention: "Will Do",
                isCommitted: true,
                estimatedHours: 12,
                projectedCost: 1080,
                priority: "High",
                priorityGroup: "NOW",
                stage: "Backlog",
                developerName: "Dev One",
                estimatedStart: null,
                estimatedEnd: null
            },
            {
                workItemId: "a01000000000002",
                name: "Maybe explore this",
                intention: "Sizing Only",
                isCommitted: false,
                estimatedHours: 5,
                projectedCost: 450,
                priority: "Medium",
                priorityGroup: "NEXT",
                stage: "Backlog",
                developerName: null,
                estimatedStart: null,
                estimatedEnd: null
            }
        ],
        summary: {
            count: 2,
            willDoCount: 1,
            sizingOnlyCount: 1,
            willDoHours: 12,
            sizingOnlyHours: 5,
            willDoCost: 1080
        },
        profile: {
            showDollars: false,
            selfServe: false,
            checkoutMode: "Invoice",
            blendedRate: 90
        },
        ...overrides
    };
}

function createComponent() {
    const element = createElement("c-delivery-cart-checkout", {
        is: DeliveryCartCheckout
    });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("c-delivery-cart-checkout", () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it("renders Will Do and Sizing Only sections from the wire", async () => {
        const element = createComponent();
        getCart.emit(sampleCart());
        await flushPromises();

        const text = element.shadowRoot.textContent;
        expect(text).toContain("Will Do — committed");
        expect(text).toContain("Sizing Only — exploring");
        expect(text).toContain("Build the thing");
        expect(text).toContain("Maybe explore this");
    });

    it("hides dollars when profile.showDollars is false", async () => {
        const element = createComponent();
        getCart.emit(sampleCart());
        await flushPromises();

        const text = element.shadowRoot.textContent;
        expect(text).not.toContain("$1,080");
        expect(text).toContain("12.0h"); // hours still shown
    });

    it("shows dollars when profile.showDollars is true", async () => {
        const element = createComponent();
        getCart.emit(sampleCart({
            profile: { showDollars: true, selfServe: false, checkoutMode: "Invoice", blendedRate: 90 }
        }));
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("$1,080");
    });

    it("labels the checkout button per checkout mode", async () => {
        const element = createComponent();
        getCart.emit(sampleCart({
            profile: { showDollars: false, selfServe: true, checkoutMode: "Stripe", blendedRate: 90 }
        }));
        await flushPromises();

        const button = element.shadowRoot.querySelector("lightning-button");
        expect(button.label).toBe("Checkout & Pay");
    });

    it("invokes checkout and surfaces the result message", async () => {
        checkout.mockResolvedValue({ activatedCount: 1, checkoutMode: "Invoice", message: "Lines activated." });
        getCart.mockResolvedValue(sampleCart());

        const element = createComponent();
        getCart.emit(sampleCart());
        await flushPromises();

        const button = element.shadowRoot.querySelector("lightning-button");
        button.dispatchEvent(new CustomEvent("click"));
        await flushPromises();
        await flushPromises();

        expect(checkout).toHaveBeenCalled();
        expect(element.shadowRoot.textContent).toContain("Lines activated.");
    });

    it("shows the empty state for an empty cart", async () => {
        const element = createComponent();
        getCart.emit({ lines: [], summary: { count: 0, willDoCount: 0, sizingOnlyCount: 0, willDoHours: 0, sizingOnlyHours: 0, willDoCost: 0 }, profile: { showDollars: false, checkoutMode: "Invoice" } });
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain("The cart is empty");
    });

    it("shows an error when the wire errors", async () => {
        const element = createComponent();
        getCart.error();
        await flushPromises();

        expect(element.shadowRoot.querySelector(".cart-error")).not.toBeNull();
    });
});
