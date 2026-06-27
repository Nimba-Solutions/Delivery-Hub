/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryGettingStarted's Home-page visibility gate:
 *               renders by default, and renders nothing on Home when an admin hides it.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import DeliveryGettingStarted from 'c/deliveryGettingStarted';
import getHiddenHomeComponents from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents';

// getSetupStatus is consumed imperatively here (it is @wire elsewhere, so the shared
// mock is a wire adapter); override it as a resolved promise for connectedCallback.
jest.mock(
    '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSetupController.getSetupStatus',
    () => ({ default: jest.fn().mockResolvedValue({ isConnected: false, isMothership: false }) }),
    { virtual: true }
);

const HOME_PAGE_REF = { type: 'standard__namedPage', attributes: { pageName: 'home' } };

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function createComponent() {
    const element = createElement('c-delivery-getting-started', { is: DeliveryGettingStarted });
    document.body.appendChild(element);
    return element;
}

describe('c-delivery-getting-started home visibility', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders by default when not hidden', async () => {
        const element = createComponent();
        await flushPromises();
        expect(element.shadowRoot.querySelector('.gs-root')).not.toBeNull();
    });

    it('renders nothing on Home when hidden in Settings', async () => {
        const element = createComponent();
        CurrentPageReference.emit(HOME_PAGE_REF);
        getHiddenHomeComponents.emit({ deliveryGettingStarted: true });
        await flushPromises();
        expect(element.shadowRoot.querySelector('.gs-root')).toBeNull();
    });
});
