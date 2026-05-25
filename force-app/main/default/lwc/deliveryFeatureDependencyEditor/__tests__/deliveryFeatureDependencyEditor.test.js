import { createElement } from 'lwc';
import DeliveryFeatureDependencyEditor from 'c/deliveryFeatureDependencyEditor';
import getDependencies from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureDepEditorController.getDependencies';
import createDependency from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureDepEditorController.createDependency';
import deleteDependency from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureDepEditorController.deleteDependency';
import isAdminApex from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.isAdmin';

// Apex methods auto-mocked via force-app/test/jest-mocks/apex/.

// ── Test Data ──────────────────────────────────────────────────────

const PARENT_ID = 'a04000000000001';
const CHILD_ID = 'a04000000000002';

const MOCK_DEPENDENCIES = [
    {
        Id: 'a05000000000010',
        BlockingFeatureLookup__c: CHILD_ID,
        BlockingFeatureLookup__r: { Name: 'BillingFeature' },
        BlockedFeatureLookup__c: PARENT_ID,
        BlockedFeatureLookup__r: { Name: 'InvoiceFeature' },
        TypePk__c: 'Hard',
        NotesTxt__c: 'Billing must be on first',
        CascadeDirectionPk__c: 'Both'
    }
];

// ── Helpers ────────────────────────────────────────────────────────

function createComponent(props = {}) {
    const element = createElement('c-delivery-feature-dependency-editor', {
        is: DeliveryFeatureDependencyEditor
    });
    element.recordId = PARENT_ID;
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function findButtonByLabel(element, label) {
    const buttons = element.shadowRoot.querySelectorAll('lightning-button');
    return Array.from(buttons).find((b) => b.label === label) || null;
}

// ── Tests ──────────────────────────────────────────────────────────

describe('c-delivery-feature-dependency-editor', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    describe('basic rendering', () => {
        it('renders the lightning-card with the expected title', () => {
            const element = createComponent();
            const card = element.shadowRoot.querySelector('lightning-card');
            expect(card).not.toBeNull();
            expect(card.title).toBe('Feature Dependencies');
        });

        it('renders empty-state copy when no rows surface', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getDependencies.emit([]);
            await flushPromises();

            const emptyParagraph = element.shadowRoot.querySelector('p.slds-text-body_small');
            expect(emptyParagraph).not.toBeNull();
            expect(emptyParagraph.textContent).toMatch(/no dependencies/i);
        });
    });

    describe('existing dependencies table', () => {
        it('renders a row per FeatureDependency__c returned by the wire', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getDependencies.emit(MOCK_DEPENDENCIES);
            await flushPromises();

            const table = element.shadowRoot.querySelector('lightning-datatable');
            expect(table).not.toBeNull();
            expect(table.data.length).toBe(1);
            expect(table.data[0].childName).toBe('BillingFeature');
            expect(table.data[0].depType).toBe('Hard');
            expect(table.data[0].notes).toBe('Billing must be on first');
        });
    });

    describe('add form validation', () => {
        it('disables Add when no child is selected', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getDependencies.emit([]);
            await flushPromises();

            const button = findButtonByLabel(element, 'Add dependency');
            expect(button).not.toBeNull();
            expect(button.disabled).toBe(true);
        });

        it('enables Add once a non-self child is selected', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getDependencies.emit([]);
            await flushPromises();

            const picker = element.shadowRoot.querySelector('lightning-record-picker');
            picker.dispatchEvent(new CustomEvent('change', {
                detail: { recordId: CHILD_ID }
            }));
            await flushPromises();

            const button = findButtonByLabel(element, 'Add dependency');
            expect(button.disabled).toBe(false);
        });

        it('keeps Add disabled when the selected child equals the parent recordId', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getDependencies.emit([]);
            await flushPromises();

            const picker = element.shadowRoot.querySelector('lightning-record-picker');
            picker.dispatchEvent(new CustomEvent('change', {
                detail: { recordId: PARENT_ID }
            }));
            await flushPromises();

            const button = findButtonByLabel(element, 'Add dependency');
            expect(button.disabled).toBe(true);
        });

        it('disables the entire form when the running user is not an admin', async () => {
            const element = createComponent();
            isAdminApex.emit(false);
            getDependencies.emit([]);
            await flushPromises();

            const picker = element.shadowRoot.querySelector('lightning-record-picker');
            expect(picker.disabled).toBe(true);

            const adminGate = element.shadowRoot.querySelector('.slds-theme_shade');
            expect(adminGate).not.toBeNull();
            expect(adminGate.textContent).toMatch(/admin/i);
        });
    });

    describe('add success', () => {
        it('calls createDependency apex with the parent + child + type', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getDependencies.emit([]);
            await flushPromises();

            const picker = element.shadowRoot.querySelector('lightning-record-picker');
            picker.dispatchEvent(new CustomEvent('change', {
                detail: { recordId: CHILD_ID }
            }));
            await flushPromises();

            const button = findButtonByLabel(element, 'Add dependency');
            button.click();
            await flushPromises();

            expect(createDependency).toHaveBeenCalledTimes(1);
            expect(createDependency).toHaveBeenCalledWith({
                parentFeatureId: PARENT_ID,
                childFeatureId: CHILD_ID,
                depType: 'Hard',
                notes: ''
            });
        });
    });

    describe('delete flow', () => {
        it('opens the confirmation modal on row delete action', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getDependencies.emit(MOCK_DEPENDENCIES);
            await flushPromises();

            const table = element.shadowRoot.querySelector('lightning-datatable');
            table.dispatchEvent(new CustomEvent('rowaction', {
                detail: {
                    action: { name: 'delete' },
                    row: { id: 'a05000000000010', childName: 'BillingFeature' }
                }
            }));
            await flushPromises();

            const dialog = element.shadowRoot.querySelector('section[role="dialog"]');
            expect(dialog).not.toBeNull();
        });

        it('calls deleteDependency apex on confirm', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getDependencies.emit(MOCK_DEPENDENCIES);
            await flushPromises();

            const table = element.shadowRoot.querySelector('lightning-datatable');
            table.dispatchEvent(new CustomEvent('rowaction', {
                detail: {
                    action: { name: 'delete' },
                    row: { id: 'a05000000000010', childName: 'BillingFeature' }
                }
            }));
            await flushPromises();

            const removeButton = findButtonByLabel(element, 'Remove');
            expect(removeButton).not.toBeNull();
            removeButton.click();
            await flushPromises();

            expect(deleteDependency).toHaveBeenCalledTimes(1);
            expect(deleteDependency).toHaveBeenCalledWith({
                dependencyId: 'a05000000000010'
            });
        });

        it('closes the confirmation modal on cancel without calling delete', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getDependencies.emit(MOCK_DEPENDENCIES);
            await flushPromises();

            const table = element.shadowRoot.querySelector('lightning-datatable');
            table.dispatchEvent(new CustomEvent('rowaction', {
                detail: {
                    action: { name: 'delete' },
                    row: { id: 'a05000000000010', childName: 'BillingFeature' }
                }
            }));
            await flushPromises();

            const cancelButton = findButtonByLabel(element, 'Cancel');
            cancelButton.click();
            await flushPromises();

            const modalTitle = element.shadowRoot.querySelector('#dep-editor-delete-title');
            expect(modalTitle).toBeNull();
            expect(deleteDependency).not.toHaveBeenCalled();
        });
    });

    describe('error handling', () => {
        it('surfaces a warning banner when the dependencies wire fails', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getDependencies.error();
            await flushPromises();

            const banner = element.shadowRoot.querySelector('.slds-theme_warning');
            expect(banner).not.toBeNull();
            // Banner surfaces SOMETHING — either the supplied body.message or
            // the LWC's "Unable to load..." fallback. We don't assert the exact
            // copy because sfdx-lwc-jest's default error() builds its own message.
            expect(banner.textContent.length).toBeGreaterThan(0);
        });
    });
});
