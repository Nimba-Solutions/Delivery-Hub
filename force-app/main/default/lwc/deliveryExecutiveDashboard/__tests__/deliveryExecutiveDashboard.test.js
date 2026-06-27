/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryExecutiveDashboard's Home-page visibility gate:
 *               renders by default, and renders nothing on Home when an admin hides it.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import DeliveryExecutiveDashboard from 'c/deliveryExecutiveDashboard';
import getHiddenHomeComponents from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents';

const HOME_PAGE_REF = { type: 'standard__namedPage', attributes: { pageName: 'home' } };

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function createComponent() {
    const element = createElement('c-delivery-executive-dashboard', { is: DeliveryExecutiveDashboard });
    document.body.appendChild(element);
    return element;
}

describe('c-delivery-executive-dashboard home visibility', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders by default when not hidden', async () => {
        const element = createComponent();
        await flushPromises();
        expect(element.shadowRoot.querySelector('lightning-card')).not.toBeNull();
    });

    it('renders nothing on Home when hidden in Settings', async () => {
        const element = createComponent();
        CurrentPageReference.emit(HOME_PAGE_REF);
        getHiddenHomeComponents.emit({ deliveryExecutiveDashboard: true });
        await flushPromises();
        expect(element.shadowRoot.querySelector('lightning-card')).toBeNull();
    });
});
