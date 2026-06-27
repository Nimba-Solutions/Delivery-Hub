/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryHubSetup's Home-page visibility gate. The
 *               "Powered by" footer is the always-present anchor: it renders by default
 *               and disappears entirely on Home when an admin hides the whole widget.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import DeliveryHubSetup from 'c/deliveryHubSetup';
import getHiddenHomeComponents from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents';

const HOME_PAGE_REF = { type: 'standard__namedPage', attributes: { pageName: 'home' } };

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function createComponent() {
    const element = createElement('c-delivery-hub-setup', { is: DeliveryHubSetup });
    document.body.appendChild(element);
    return element;
}

describe('c-delivery-hub-setup home visibility', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders by default when not hidden', async () => {
        const element = createComponent();
        await flushPromises();
        expect(element.shadowRoot.querySelector('.hs-powered-by')).not.toBeNull();
    });

    it('renders nothing on Home when hidden in Settings', async () => {
        const element = createComponent();
        CurrentPageReference.emit(HOME_PAGE_REF);
        getHiddenHomeComponents.emit({ deliveryHubSetup: true });
        await flushPromises();
        expect(element.shadowRoot.querySelector('.hs-powered-by')).toBeNull();
    });
});
