import { createElement } from 'lwc';
import DeliveryFeatureApprovalSubmit from 'c/deliveryFeatureApprovalSubmit';
import getCatalog from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.getCatalog';
import submitRequest from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureApprovalService.submit';

// Apex methods auto-mocked via force-app/test/jest-mocks/apex/.

const FEATURE_ID_A = 'a0F000000000001',
    FEATURE_ID_B = 'a0F000000000002',
    REQUEST_ID = 'a0G000000000999';

const MOCK_CATALOG = [
    {
        featureId: FEATURE_ID_A,
        name: 'FeatureA',
        label: 'Alpha feature',
        isActive: false
    },
    {
        featureId: FEATURE_ID_B,
        name: 'FeatureB',
        label: 'Bravo feature',
        isActive: true
    },
    {
        // mdt-only row — no Feature__c yet — should be skipped from picker
        featureId: null,
        name: 'CharlieDefinition',
        label: 'Charlie (unbacked)',
        isActive: false
    }
];

function createComponent() {
    const element = createElement('c-delivery-feature-approval-submit', {
        is: DeliveryFeatureApprovalSubmit
    });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function findButtonByLabelStart(element, prefix) {
    const buttons = element.shadowRoot.querySelectorAll('lightning-button');
    return Array.from(buttons).find((b) => (b.label || '').indexOf(prefix) === 0);
}

function findComboboxByName(element, name) {
    const combos = element.shadowRoot.querySelectorAll('lightning-combobox');
    return Array.from(combos).find((c) => c.name === name);
}

function findTextareaByName(element, name) {
    const tas = element.shadowRoot.querySelectorAll('lightning-textarea');
    return Array.from(tas).find((t) => t.name === name);
}

describe('c-delivery-feature-approval-submit', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders without error', () => {
        const element = createComponent();
        expect(element).toBeTruthy();
    });

    it('renders feature combobox, action combobox, justification, and submit button when catalog loads', async () => {
        const element = createComponent();
        getCatalog.emit(MOCK_CATALOG);
        await flushPromises();

        expect(findComboboxByName(element, 'feature')).toBeDefined();
        expect(findComboboxByName(element, 'action')).toBeDefined();
        expect(findTextareaByName(element, 'justification')).toBeDefined();
        expect(findButtonByLabelStart(element, 'Submit')).toBeDefined();
    });

    it('omits catalog entries with no featureId from the picker', async () => {
        const element = createComponent();
        getCatalog.emit(MOCK_CATALOG);
        await flushPromises();

        const featureCombo = findComboboxByName(element, 'feature');
        expect(featureCombo.options).toBeDefined();
        expect(featureCombo.options.length).toBe(2);
        const values = featureCombo.options.map((o) => o.value);
        expect(values).toEqual([FEATURE_ID_A, FEATURE_ID_B]);
        expect(values.indexOf(null)).toBe(-1);
    });

    it('disables submit until all three fields are valid', async () => {
        const element = createComponent();
        getCatalog.emit(MOCK_CATALOG);
        await flushPromises();

        let submitBtn = findButtonByLabelStart(element, 'Submit');
        expect(submitBtn.disabled).toBe(true);

        // Set feature
        findComboboxByName(element, 'feature').dispatchEvent(
            new CustomEvent('change', { detail: { value: FEATURE_ID_A } })
        );
        await flushPromises();
        submitBtn = findButtonByLabelStart(element, 'Submit');
        expect(submitBtn.disabled).toBe(true);

        // Set action
        findComboboxByName(element, 'action').dispatchEvent(
            new CustomEvent('change', { detail: { value: 'Enable' } })
        );
        await flushPromises();
        submitBtn = findButtonByLabelStart(element, 'Submit');
        expect(submitBtn.disabled).toBe(true);

        // Set short justification (< 10 chars) — still disabled
        findTextareaByName(element, 'justification').dispatchEvent(
            new CustomEvent('change', { detail: { value: 'short' } })
        );
        await flushPromises();
        submitBtn = findButtonByLabelStart(element, 'Submit');
        expect(submitBtn.disabled).toBe(true);

        // Set valid justification (>= 10 chars)
        findTextareaByName(element, 'justification').dispatchEvent(
            new CustomEvent('change', { detail: { value: 'A reasonable explanation of why this is needed.' } })
        );
        await flushPromises();
        submitBtn = findButtonByLabelStart(element, 'Submit');
        expect(submitBtn.disabled).toBe(false);
    });

    it('calls submit() with the correct args and dispatches a submitted event on success', async () => {
        submitRequest.mockResolvedValue(REQUEST_ID);
        const submittedHandler = jest.fn();

        const element = createComponent();
        element.addEventListener('submitted', submittedHandler);
        getCatalog.emit(MOCK_CATALOG);
        await flushPromises();

        findComboboxByName(element, 'feature').dispatchEvent(
            new CustomEvent('change', { detail: { value: FEATURE_ID_A } })
        );
        findComboboxByName(element, 'action').dispatchEvent(
            new CustomEvent('change', { detail: { value: 'Enable' } })
        );
        findTextareaByName(element, 'justification').dispatchEvent(
            new CustomEvent('change', { detail: { value: 'We need this to unblock the QuickBooks pilot.' } })
        );
        await flushPromises();

        const submitBtn = findButtonByLabelStart(element, 'Submit');
        submitBtn.click();
        await flushPromises();
        await flushPromises();

        expect(submitRequest).toHaveBeenCalledTimes(1);
        const args = submitRequest.mock.calls[0][0];
        expect(args.featureId).toBe(FEATURE_ID_A);
        expect(args.action).toBe('Enable');
        expect(args.reason).toBe('We need this to unblock the QuickBooks pilot.');

        expect(submittedHandler).toHaveBeenCalledTimes(1);
        const detail = submittedHandler.mock.calls[0][0].detail;
        expect(detail.requestId).toBe(REQUEST_ID);
        expect(detail.featureId).toBe(FEATURE_ID_A);
        expect(detail.action).toBe('Enable');
    });

    it('clears the form on successful submit', async () => {
        submitRequest.mockResolvedValue(REQUEST_ID);

        const element = createComponent();
        getCatalog.emit(MOCK_CATALOG);
        await flushPromises();

        findComboboxByName(element, 'feature').dispatchEvent(
            new CustomEvent('change', { detail: { value: FEATURE_ID_A } })
        );
        findComboboxByName(element, 'action').dispatchEvent(
            new CustomEvent('change', { detail: { value: 'Disable' } })
        );
        findTextareaByName(element, 'justification').dispatchEvent(
            new CustomEvent('change', { detail: { value: 'Cleanup after pilot ended.' } })
        );
        await flushPromises();

        findButtonByLabelStart(element, 'Submit').click();
        await flushPromises();
        await flushPromises();

        const featureCombo = findComboboxByName(element, 'feature');
        const actionCombo = findComboboxByName(element, 'action');
        const justification = findTextareaByName(element, 'justification');
        expect(featureCombo.value).toBe('');
        expect(actionCombo.value).toBe('');
        expect(justification.value).toBe('');
    });

    it('surfaces the error message and stays enabled when submit rejects', async () => {
        submitRequest.mockRejectedValue({ body: { message: 'Approver required.' } });

        const element = createComponent();
        getCatalog.emit(MOCK_CATALOG);
        await flushPromises();

        findComboboxByName(element, 'feature').dispatchEvent(
            new CustomEvent('change', { detail: { value: FEATURE_ID_A } })
        );
        findComboboxByName(element, 'action').dispatchEvent(
            new CustomEvent('change', { detail: { value: 'Enable' } })
        );
        findTextareaByName(element, 'justification').dispatchEvent(
            new CustomEvent('change', { detail: { value: 'We need this enabled for the pilot.' } })
        );
        await flushPromises();

        findButtonByLabelStart(element, 'Submit').click();
        await flushPromises();
        await flushPromises();

        expect(submitRequest).toHaveBeenCalledTimes(1);
        // Form preserved so user can retry
        expect(findComboboxByName(element, 'feature').value).toBe(FEATURE_ID_A);
        // Inline error rendered
        expect(element.shadowRoot.textContent).toContain('Approver required.');
        // Submit re-enabled after the error
        const submitBtn = findButtonByLabelStart(element, 'Submit');
        expect(submitBtn.disabled).toBe(false);
    });

    it('renders a load-error message when the catalog wire errors', async () => {
        const element = createComponent();
        // createApexTestWireAdapter passes the first arg as `error.body`, so
        // the body shape is { message } — matches extractErrorMessage().
        getCatalog.error({ message: 'Catalog unavailable.' });
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain('Catalog unavailable.');
        // Form not rendered
        expect(findComboboxByName(element, 'feature')).toBeUndefined();
    });
});
