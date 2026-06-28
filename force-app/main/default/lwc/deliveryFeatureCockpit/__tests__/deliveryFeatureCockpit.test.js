import { createElement } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import DeliveryFeatureCockpit from 'c/deliveryFeatureCockpit';
import getCatalog from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.getCatalog';
import isAdminApex from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.isAdmin';
import toggleFeature from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.toggleFeature';
import getHiddenHomeComponents from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents';

const HOME_PAGE_REF = { type: 'standard__namedPage', attributes: { pageName: 'home' } };

// Apex methods auto-mocked via force-app/test/jest-mocks/apex/.

// ── Test Data ──────────────────────────────────────────────────────

const FEATURE_ID_A = 'a0F000000000001';
const FEATURE_ID_B = 'a0F000000000002';

const MOCK_CATALOG = [
    {
        featureId: FEATURE_ID_A,
        name: 'FeatureA',
        label: 'Alpha feature',
        description: 'Test description',
        category: 'Core',
        maturity: 'GA',
        icon: 'standard:apps',
        isActive: false,
        settingsFieldApiName: 'EnableAlphaDateTime__c',
        docsUrl: 'https://example.test/docs/alpha'
    },
    {
        featureId: FEATURE_ID_B,
        name: 'FeatureB',
        label: 'Bravo feature',
        description: 'Bravo description',
        category: 'Core',
        maturity: 'Beta',
        icon: 'standard:apps',
        isActive: true,
        settingsFieldApiName: 'EnableBravoDateTime__c',
        docsUrl: ''
    },
    {
        // mdt-only row — no Feature__c yet — should NOT render View record button
        featureId: null,
        name: 'CharlieDefinition',
        label: 'Charlie (unbacked)',
        description: '',
        category: 'Core',
        maturity: 'Alpha',
        icon: 'standard:apps',
        isActive: false,
        settingsFieldApiName: '',
        docsUrl: ''
    }
];

// ── Helpers ────────────────────────────────────────────────────────

function createComponent() {
    const element = createElement('c-delivery-feature-cockpit', {
        is: DeliveryFeatureCockpit
    });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function findButtonsByLabel(element, label) {
    const buttons = element.shadowRoot.querySelectorAll('lightning-button');
    return Array.from(buttons).filter((b) => b.label === label);
}

// ── Tests ──────────────────────────────────────────────────────────

describe('c-delivery-feature-cockpit', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    describe('basic rendering', () => {
        it('renders the lightning-card with the Feature Cockpit title', () => {
            const element = createComponent();
            const card = element.shadowRoot.querySelector('lightning-card');
            expect(card).not.toBeNull();
            expect(card.title).toBe('Feature Cockpit');
        });

        it('renders one card per catalog row', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getCatalog.emit(MOCK_CATALOG);
            await flushPromises();

            const cards = element.shadowRoot.querySelectorAll('.feature-card');
            expect(cards.length).toBe(MOCK_CATALOG.length);
        });
    });

    describe('Flow 1 gap — catalog card navigation', () => {
        it('renders a "View record" button on cards backed by a Feature__c row', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getCatalog.emit(MOCK_CATALOG);
            await flushPromises();

            const viewButtons = findButtonsByLabel(element, 'View record');
            // Two rows have a featureId; the mdt-only Charlie row does not
            expect(viewButtons.length).toBe(2);

            const featureIds = viewButtons.map((b) => b.dataset.featureId);
            expect(featureIds).toContain(FEATURE_ID_A);
            expect(featureIds).toContain(FEATURE_ID_B);
        });

        it('does NOT render a "View record" button on mdt-only rows (no featureId)', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getCatalog.emit([MOCK_CATALOG[2]]);
            await flushPromises();

            const viewButtons = findButtonsByLabel(element, 'View record');
            expect(viewButtons.length).toBe(0);
        });

        it('invokes NavigationMixin.Navigate with the Feature__c record page when View record is clicked', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getCatalog.emit(MOCK_CATALOG);
            await flushPromises();

            // Spy on the symbol-keyed mixin method that NavigationMixin
            // installs on the element instance. sfdx-lwc-jest ships a stub
            // that defaults to a jest.fn() returning undefined.
            const navigateSpy = jest.fn();
            element[NavigationMixin.Navigate] = navigateSpy;

            const viewButtons = findButtonsByLabel(element, 'View record');
            viewButtons[0].click();
            await flushPromises();

            expect(navigateSpy).toHaveBeenCalledTimes(1);
            const ref = navigateSpy.mock.calls[0][0];
            expect(ref.type).toBe('standard__recordPage');
            expect(ref.attributes.recordId).toBe(FEATURE_ID_A);
            expect(ref.attributes.actionName).toBe('view');
            expect(ref.attributes.objectApiName).toContain('Feature__c');
        });

        it('renders the "View Docs" link only when docsUrl is populated, with rel=noopener noreferrer', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getCatalog.emit(MOCK_CATALOG);
            await flushPromises();

            const anchors = element.shadowRoot.querySelectorAll('a[target="_blank"]');
            const docAnchors = Array.from(anchors).filter(
                (a) => a.textContent.trim() === 'View Docs'
            );
            // Alpha has docsUrl; Bravo + Charlie do not → exactly 1 anchor
            expect(docAnchors.length).toBe(1);
            expect(docAnchors[0].getAttribute('rel')).toBe('noopener noreferrer');
            expect(docAnchors[0].getAttribute('href')).toBe(
                'https://example.test/docs/alpha'
            );
        });
    });

    describe('Flow 3 #1 gap — onboarding-gate toast action link', () => {
        it('dispatches a ShowToastEvent with messageData URL token on onboarding-gate failure', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getCatalog.emit(MOCK_CATALOG);
            await flushPromises();

            // Resolve GenerateUrl with a fake record-page URL so the toast
            // takes the with-link branch.
            element[NavigationMixin.GenerateUrl] = jest
                .fn()
                .mockResolvedValue(
                    '/lightning/r/Feature__c/' + FEATURE_ID_A + '/view'
                );

            // Drive the onboarding-gate failure path. The handler matches on
            // the substring "onboarding track" in the Apex error message.
            toggleFeature.mockRejectedValueOnce({
                body: { message: 'Linked onboarding track is incomplete.' }
            });

            const toastHandler = jest.fn();
            element.addEventListener('lightning__showtoast', toastHandler);

            // Alpha is inactive → Enable button present
            const enableButtons = findButtonsByLabel(element, 'Enable');
            const alphaBtn = enableButtons.find(
                (b) => b.dataset.featureId === FEATURE_ID_A
            );
            expect(alphaBtn).toBeDefined();
            alphaBtn.click();

            // Wait for toggleFeature.catch → GenerateUrl.then → toast dispatch
            await flushPromises();
            await flushPromises();
            await flushPromises();

            expect(toastHandler).toHaveBeenCalledTimes(1);
            const detail = toastHandler.mock.calls[0][0].detail;
            expect(detail.title).toBe('Onboarding required');
            expect(detail.variant).toBe('warning');
            // The action-link contract: message contains a {0} token AND
            // messageData carries a {url,label} entry.
            expect(detail.message).toContain('{0}');
            expect(Array.isArray(detail.messageData)).toBe(true);
            expect(detail.messageData.length).toBe(1);
            expect(detail.messageData[0].url).toContain(FEATURE_ID_A);
            expect(detail.messageData[0].label).toBe('Open feature record page');
        });

        it('falls back to a link-less toast when URL generation rejects', async () => {
            const element = createComponent();
            isAdminApex.emit(true);
            getCatalog.emit(MOCK_CATALOG);
            await flushPromises();

            // Force GenerateUrl to reject so the catch-fallback fires
            element[NavigationMixin.GenerateUrl] = jest
                .fn()
                .mockRejectedValue(new Error('nav unavailable'));

            toggleFeature.mockRejectedValueOnce({
                body: { message: 'You must complete the onboarding track first.' }
            });

            const toastHandler = jest.fn();
            element.addEventListener('lightning__showtoast', toastHandler);

            const enableButtons = findButtonsByLabel(element, 'Enable');
            const alphaBtn = enableButtons.find(
                (b) => b.dataset.featureId === FEATURE_ID_A
            );
            alphaBtn.click();

            await flushPromises();
            await flushPromises();
            await flushPromises();

            expect(toastHandler).toHaveBeenCalledTimes(1);
            const detail = toastHandler.mock.calls[0][0].detail;
            expect(detail.title).toBe('Onboarding required');
            expect(detail.variant).toBe('warning');
            // No messageData on the fallback toast — pure-text message
            expect(detail.messageData).toBeUndefined();
        });
    });
});

describe('c-delivery-feature-cockpit home visibility', () => {
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
        getHiddenHomeComponents.emit({ deliveryFeatureCockpit: true });
        await flushPromises();
        expect(element.shadowRoot.querySelector('lightning-card')).toBeNull();
    });
});
