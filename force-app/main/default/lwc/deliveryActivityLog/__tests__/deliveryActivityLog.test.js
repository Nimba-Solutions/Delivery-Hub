import { createElement } from 'lwc';
import DeliveryActivityLog from 'c/deliveryActivityLog';
import recent from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityLogController.recent';

const MOCK_ROWS = [
    {
        id: 'a0L000000000001',
        activityDateTime: '2026-05-22T12:00:00.000Z',
        userId: '005000000000001',
        userName: 'Glen Bradford',
        actionType: 'Feature_Toggle',
        componentName: 'deliveryFeatureCockpit',
        recordId: 'a07000000000001',
        pageUrl: '/lightning/n/Delivery_Hub_Settings',
        detailsTxt: '{"feature":"InvoiceSync","action":"enable"}'
    },
    {
        id: 'a0L000000000002',
        activityDateTime: '2026-05-22T11:00:00.000Z',
        userId: '005000000000002',
        userName: 'Mahi Test',
        actionType: 'Navigation',
        componentName: 'deliveryHubBoard',
        recordId: null,
        pageUrl: '/lightning/page/home',
        detailsTxt: ''
    }
];

function createComponent(props = {}) {
    const element = createElement('c-delivery-activity-log', {
        is: DeliveryActivityLog
    });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe('c-delivery-activity-log', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    describe('rendering', () => {
        it('renders without error', () => {
            const element = createComponent();
            expect(element).toBeTruthy();
        });

        it('shows the org-wide header when no recordId is set', () => {
            const element = createComponent();
            const card = element.shadowRoot.querySelector('lightning-card');
            expect(card.title).toContain('org-wide');
        });

        it('shows the record-scoped header when recordId is set', () => {
            const element = createComponent({ recordId: 'a07000000000001' });
            const card = element.shadowRoot.querySelector('lightning-card');
            expect(card.title).toContain('this record');
        });
    });

    describe('wire integration', () => {
        it('renders rows from the wire adapter', async () => {
            const element = createComponent();
            recent.emit(MOCK_ROWS);
            await flushPromises();

            const table = element.shadowRoot.querySelector('lightning-datatable');
            expect(table).not.toBeNull();
            expect(table.data.length).toBe(2);
        });

        it('shows empty state when wire returns []', async () => {
            const element = createComponent();
            recent.emit([]);
            await flushPromises();

            const empty = element.shadowRoot.querySelector('p');
            expect(empty).not.toBeNull();
            expect(empty.textContent).toContain('No activity');
        });

        it('shows error message when wire errors', async () => {
            const element = createComponent();
            recent.error();
            await flushPromises();

            const alert = element.shadowRoot.querySelector('.slds-notify_alert');
            expect(alert).not.toBeNull();
            // Either the body.message (when present) or the fallback string —
            // both prove the wire-error branch fired and rendered the alert.
            expect(alert.textContent.length).toBeGreaterThan(0);
        });
    });

    describe('sorting', () => {
        it('starts sorted by activityDateTime desc', async () => {
            const element = createComponent();
            recent.emit(MOCK_ROWS);
            await flushPromises();

            const dt = element.shadowRoot.querySelector('lightning-datatable');
            expect(dt).not.toBeNull();
            expect(dt.sortedBy).toBe('activityDateTime');
            expect(dt.sortedDirection).toBe('desc');
        });

        it('re-sorts when onsort fires', async () => {
            const element = createComponent();
            recent.emit(MOCK_ROWS);
            await flushPromises();

            const dt = element.shadowRoot.querySelector('lightning-datatable');
            dt.dispatchEvent(
                new CustomEvent('sort', {
                    detail: { fieldName: 'actionType', sortDirection: 'asc' }
                })
            );
            await flushPromises();

            const afterSort = element.shadowRoot.querySelector('lightning-datatable');
            expect(afterSort.sortedBy).toBe('actionType');
            expect(afterSort.sortedDirection).toBe('asc');
            // 'Feature_Toggle' (F) > 'Navigation' (N) alphabetically? F < N -> Feature_Toggle first asc.
            expect(afterSort.data[0].actionType).toBe('Feature_Toggle');
        });
    });

    describe('refresh', () => {
        it('renders a refresh button in the card actions slot', () => {
            const element = createComponent();
            const refreshBtn = element.shadowRoot.querySelector('lightning-button-icon');
            expect(refreshBtn).not.toBeNull();
            expect(refreshBtn.iconName).toBe('utility:refresh');
        });
    });
});
