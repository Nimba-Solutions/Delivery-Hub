/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryHomeVisibilitySettingsCard: renders six
 *               "Show on Home" toggles (all on by default), and persists a hide when a
 *               toggle is switched off.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from 'lwc';
import DeliveryHomeVisibilitySettingsCard from 'c/deliveryHomeVisibilitySettingsCard';
import setHiddenHomeComponents from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.setHiddenHomeComponents';

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function createComponent() {
    const element = createElement('c-delivery-home-visibility-settings-card', {
        is: DeliveryHomeVisibilitySettingsCard
    });
    document.body.appendChild(element);
    return element;
}

describe('c-delivery-home-visibility-settings-card', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders six Show-on-Home toggles, all on by default', async () => {
        const element = createComponent();
        await flushPromises();

        const toggles = element.shadowRoot.querySelectorAll('lightning-input');
        expect(toggles.length).toBe(6);
        toggles.forEach((t) => expect(t.checked).toBe(true));
    });

    it('persists a hide when a toggle is switched off', async () => {
        setHiddenHomeComponents.mockResolvedValue({ deliveryPacingForecast: true });
        const element = createComponent();
        await flushPromises();

        const toggle = element.shadowRoot.querySelector('lightning-input[data-key="deliveryPacingForecast"]');
        expect(toggle).not.toBeNull();
        toggle.checked = false;
        toggle.dispatchEvent(new CustomEvent('change'));
        await flushPromises();

        expect(setHiddenHomeComponents).toHaveBeenCalledTimes(1);
        const arg = setHiddenHomeComponents.mock.calls[0][0];
        expect(arg.hidden.deliveryPacingForecast).toBe(true);
    });
});
