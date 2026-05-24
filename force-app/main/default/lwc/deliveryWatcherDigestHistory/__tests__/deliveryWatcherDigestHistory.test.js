import { createElement } from 'lwc';
import DeliveryWatcherDigestHistory from 'c/deliveryWatcherDigestHistory';
import recent from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWatcherDigestHistoryController.recent';

const MOCK_ROWS = [
    {
        id: 'a0M000000000001',
        name: 'WD-0001',
        runDateTime: '2026-05-22T12:00:00.000Z',
        status: 'Success',
        runMode: 'Scheduled',
        signalCounts: 'SLA:0,Stuck:0,AR:1',
        runDurationMs: 250,
        recipientUserIds: '005000000000001',
        slackDelivered: true,
        notes: 'All clear; 1 A/R aging signal.',
        errorMessage: null
    },
    {
        id: 'a0M000000000002',
        name: 'WD-0002',
        runDateTime: '2026-05-21T12:00:00.000Z',
        status: 'Partial',
        runMode: 'Scheduled',
        signalCounts: 'SLA:2,Stuck:0,AR:0',
        runDurationMs: 1200,
        recipientUserIds: null,
        slackDelivered: false,
        notes: 'Stuck-stage stub threw.',
        errorMessage: 'StuckStubException: not implemented'
    }
];

function createComponent(props = {}) {
    const element = createElement('c-delivery-watcher-digest-history', {
        is: DeliveryWatcherDigestHistory
    });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe('c-delivery-watcher-digest-history', () => {
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

        it('renders the Watcher Digest History header', () => {
            const element = createComponent();
            const card = element.shadowRoot.querySelector('lightning-card');
            expect(card.title).toBe('Watcher Digest History');
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

        it('renders the empty state when no rows', async () => {
            const element = createComponent();
            recent.emit([]);
            await flushPromises();

            const empty = element.shadowRoot.querySelector('p');
            expect(empty).not.toBeNull();
            expect(empty.textContent).toContain('No Watcher digests');
        });

        it('renders error when wire errors', async () => {
            const element = createComponent();
            recent.error();
            await flushPromises();

            const alert = element.shadowRoot.querySelector('.slds-notify_alert');
            expect(alert).not.toBeNull();
            expect(alert.textContent.length).toBeGreaterThan(0);
        });
    });

    describe('sorting', () => {
        it('starts sorted by runDateTime desc', async () => {
            const element = createComponent();
            recent.emit(MOCK_ROWS);
            await flushPromises();

            const dt = element.shadowRoot.querySelector('lightning-datatable');
            expect(dt.sortedBy).toBe('runDateTime');
            expect(dt.sortedDirection).toBe('desc');
        });

        it('re-sorts when onsort fires', async () => {
            const element = createComponent();
            recent.emit(MOCK_ROWS);
            await flushPromises();

            const dt = element.shadowRoot.querySelector('lightning-datatable');
            dt.dispatchEvent(
                new CustomEvent('sort', {
                    detail: { fieldName: 'status', sortDirection: 'asc' }
                })
            );
            await flushPromises();

            const after = element.shadowRoot.querySelector('lightning-datatable');
            expect(after.sortedBy).toBe('status');
            expect(after.sortedDirection).toBe('asc');
            // 'Partial' < 'Success' alphabetically -> Partial first asc.
            expect(after.data[0].status).toBe('Partial');
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
