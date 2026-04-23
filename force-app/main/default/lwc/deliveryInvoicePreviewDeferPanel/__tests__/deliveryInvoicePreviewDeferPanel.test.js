import { createElement } from 'lwc';
import DeliveryInvoicePreviewDeferPanel from 'c/deliveryInvoicePreviewDeferPanel';
import getWorkLogsForEntityPeriod from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocDeferralService.getWorkLogsForEntityPeriod';
import deferWorkLogs from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocDeferralService.deferWorkLogs';

// Apex methods auto-mocked via force-app/test/jest-mocks/apex/.

const MOCK_LOGS = [
    {
        Id: 'a09000000000001',
        WorkDateDate__c: '2026-04-10',
        HoursLoggedNumber__c: 2,
        WorkDescriptionTxt__c: 'QuickBooks integration #0',
        StatusPk__c: 'Approved'
    },
    {
        Id: 'a09000000000002',
        WorkDateDate__c: '2026-04-11',
        HoursLoggedNumber__c: 3,
        WorkDescriptionTxt__c: 'QuickBooks integration #1',
        StatusPk__c: 'Approved'
    }
];

function createComponent(props = {}) {
    const element = createElement('c-delivery-invoice-preview-defer-panel', {
        is: DeliveryInvoicePreviewDeferPanel
    });
    Object.assign(element, {
        networkEntityId: 'a01000000000001',
        periodStart: '2026-04-01',
        periodEnd: '2026-04-30',
        ...props
    });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe('c-delivery-invoice-preview-defer-panel', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('disables the defer button when no rows selected', async () => {
        const element = createComponent();
        getWorkLogsForEntityPeriod.emit(MOCK_LOGS);
        await flushPromises();

        const buttons = element.shadowRoot.querySelectorAll('lightning-button');
        const deferBtn = Array.from(buttons).find(
            (b) => b.label === 'Defer Selected to Milestone Date'
        );
        expect(deferBtn).toBeDefined();
        expect(deferBtn.disabled).toBe(true);
    });

    it('calls deferWorkLogs when confirm clicked with selection + milestone date', async () => {
        deferWorkLogs.mockResolvedValue(1);

        const element = createComponent();
        getWorkLogsForEntityPeriod.emit(MOCK_LOGS);
        // Two flushes: one for wire data, one for the if:true template branch.
        await flushPromises();
        await flushPromises();

        // Drive selection through the change handler directly — jsdom doesn't
        // surface lightning-input internals, so the "currentTarget.dataset"
        // contract is what we need to satisfy.
        const select = element.shadowRoot.querySelector('lightning-input[data-id="a09000000000001"]');
        expect(select).not.toBeNull();
        select.checked = true;
        select.dispatchEvent(new CustomEvent('change'));
        await flushPromises();

        // Open the modal
        const buttons = element.shadowRoot.querySelectorAll('lightning-button');
        const deferBtn = Array.from(buttons).find(
            (b) => b.label === 'Defer Selected to Milestone Date'
        );
        expect(deferBtn.disabled).toBe(false);
        deferBtn.click();
        await flushPromises();

        // Set the milestone date — find date input by its label (jsdom doesn't
        // surface lightning-input "type" as an attribute selector).
        const inputs = element.shadowRoot.querySelectorAll('lightning-input');
        const dateInput = Array.from(inputs).find((i) => i.label === 'Milestone Date');
        expect(dateInput).toBeDefined();
        dateInput.dispatchEvent(
            new CustomEvent('change', { detail: { value: '2026-06-15' } })
        );
        await flushPromises();

        // Click Confirm Defer
        const allButtons = element.shadowRoot.querySelectorAll('lightning-button');
        const confirmBtn = Array.from(allButtons).find(
            (b) => b.label === 'Confirm Defer'
        );
        confirmBtn.click();
        await flushPromises();

        expect(deferWorkLogs).toHaveBeenCalledTimes(1);
        const callArgs = deferWorkLogs.mock.calls[0][0];
        expect(callArgs.workLogIds).toEqual(['a09000000000001']);
        expect(callArgs.milestoneDate).toBe('2026-06-15');
    });
});
