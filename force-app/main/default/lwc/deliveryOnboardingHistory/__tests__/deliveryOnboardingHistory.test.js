import { createElement } from 'lwc';
import DeliveryOnboardingHistory from 'c/deliveryOnboardingHistory';
import recent from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryOnboardingHistoryController.recent';

const MOCK_ROWS = [
    {
        id: 'a0N000000000001',
        name: 'Invoice_Generation — Glen',
        userId: '005000000000001',
        userName: 'Glen Bradford',
        track: 'Invoice_Generation',
        status: 'Completed',
        startedDateTime: '2026-05-21T10:00:00.000Z',
        completedDateTime: '2026-05-22T10:30:00.000Z',
        quizAttempts: 1,
        quizScore: 5,
        quizLastAttemptDateTime: '2026-05-22T10:25:00.000Z'
    },
    {
        id: 'a0N000000000002',
        name: 'Invoice_Generation — Mahi',
        userId: '005000000000002',
        userName: 'Mahi Test',
        track: 'Invoice_Generation',
        status: 'In Progress',
        startedDateTime: '2026-05-22T11:00:00.000Z',
        completedDateTime: null,
        quizAttempts: 0,
        quizScore: null,
        quizLastAttemptDateTime: null
    }
];

function createComponent(props = {}) {
    const element = createElement('c-delivery-onboarding-history', {
        is: DeliveryOnboardingHistory
    });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe('c-delivery-onboarding-history', () => {
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

        it('shows the user-scoped header when recordId is set', () => {
            const element = createComponent({ recordId: '005000000000001' });
            const card = element.shadowRoot.querySelector('lightning-card');
            expect(card.title).toContain('this user');
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
            expect(empty.textContent).toContain('No onboarding progress');
        });

        it('shows error when wire errors', async () => {
            const element = createComponent();
            recent.error();
            await flushPromises();

            const alert = element.shadowRoot.querySelector('.slds-notify_alert');
            expect(alert).not.toBeNull();
            expect(alert.textContent.length).toBeGreaterThan(0);
        });
    });

    describe('sorting', () => {
        it('starts sorted by completedDateTime desc', async () => {
            const element = createComponent();
            recent.emit(MOCK_ROWS);
            await flushPromises();

            const dt = element.shadowRoot.querySelector('lightning-datatable');
            expect(dt.sortedBy).toBe('completedDateTime');
            expect(dt.sortedDirection).toBe('desc');
        });

        it('re-sorts when onsort fires', async () => {
            const element = createComponent();
            recent.emit(MOCK_ROWS);
            await flushPromises();

            const dt = element.shadowRoot.querySelector('lightning-datatable');
            dt.dispatchEvent(
                new CustomEvent('sort', {
                    detail: { fieldName: 'userName', sortDirection: 'asc' }
                })
            );
            await flushPromises();

            const after = element.shadowRoot.querySelector('lightning-datatable');
            expect(after.sortedBy).toBe('userName');
            expect(after.sortedDirection).toBe('asc');
            expect(after.data[0].userName).toBe('Glen Bradford');
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
