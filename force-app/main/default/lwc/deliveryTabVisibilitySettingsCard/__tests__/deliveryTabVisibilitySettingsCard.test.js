/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryTabVisibilitySettingsCard: renders eleven
 *               "Show in Delivery tab" toggles (all on by default), and persists a hide
 *               when a toggle is switched off.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from 'lwc';
import DeliveryTabVisibilitySettingsCard from 'c/deliveryTabVisibilitySettingsCard';
import setHiddenWorkspaceTabs from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTabVisibilityController.setHiddenWorkspaceTabs';

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function createComponent() {
    const element = createElement('c-delivery-tab-visibility-settings-card', {
        is: DeliveryTabVisibilitySettingsCard
    });
    document.body.appendChild(element);
    return element;
}

describe('c-delivery-tab-visibility-settings-card', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders eleven Show-in-Delivery-tab toggles, all on by default', async () => {
        const element = createComponent();
        await flushPromises();

        const toggles = element.shadowRoot.querySelectorAll('lightning-input');
        expect(toggles.length).toBe(11);
        toggles.forEach((t) => expect(t.checked).toBe(true));
    });

    it('persists a hide when a toggle is switched off', async () => {
        setHiddenWorkspaceTabs.mockResolvedValue({ board: true });
        const element = createComponent();
        await flushPromises();

        const toggle = element.shadowRoot.querySelector('lightning-input[data-key="board"]');
        expect(toggle).not.toBeNull();
        toggle.checked = false;
        toggle.dispatchEvent(new CustomEvent('change'));
        await flushPromises();

        expect(setHiddenWorkspaceTabs).toHaveBeenCalledTimes(1);
        const arg = setHiddenWorkspaceTabs.mock.calls[0][0];
        expect(arg.hidden.board).toBe(true);
    });
});
