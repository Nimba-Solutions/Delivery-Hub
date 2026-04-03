import { createElement } from 'lwc';
import DeliveryClientDashboard from 'c/deliveryClientDashboard';
import getClientDashboard from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getClientDashboard';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';
import { getRecord } from 'lightning/uiRecordApi';

// ── Test Data ──────────────────────────────────────────────────────

const MOCK_WORKFLOW_CONFIG = {
    stages: [
        { apiValue: 'Planning', phase: 'Planning', isTerminal: false, sortOrder: 1 },
        { apiValue: 'Approval', phase: 'Approval', isTerminal: false, sortOrder: 2 },
        { apiValue: 'Development', phase: 'Development', isTerminal: false, sortOrder: 3 },
        { apiValue: 'Testing', phase: 'Testing', isTerminal: false, sortOrder: 4 },
        { apiValue: 'UAT', phase: 'UAT', isTerminal: false, sortOrder: 5 },
        { apiValue: 'Deployment', phase: 'Deployment', isTerminal: false, sortOrder: 6 },
        { apiValue: 'Complete', phase: 'Complete', isTerminal: true, sortOrder: 7 }
    ]
};

const MOCK_DASHBOARD_DATA = {
    attentionWorkItems: [
        {
            id: 'a01000000000001',
            name: 'WI-001',
            title: 'Fix login bug',
            stage: 'Development',
            priority: 'High',
            urgency: 'high',
            daysInStage: 3,
            attentionScore: 8
        },
        {
            id: 'a01000000000002',
            name: 'WI-002',
            title: 'Add search feature',
            stage: 'Approval',
            priority: 'Medium',
            urgency: 'medium',
            daysInStage: 1,
            attentionScore: 5
        }
    ],
    phases: [
        { label: 'Planning', count: 2 },
        { label: 'Approval', count: 1 },
        { label: 'Development', count: 3 },
        { label: 'Testing', count: 0 },
        { label: 'UAT', count: 0 },
        { label: 'Deployment', count: 1 }
    ],
    recentWorkItems: [
        {
            id: 'a01000000000003',
            name: 'WI-003',
            title: 'Update dashboard',
            stage: 'Development',
            lastModified: '2 hours ago',
            isComment: false
        }
    ],
    thisWeek: {
        completed: 5,
        moved: 8,
        hoursLogged: 32,
        blocked: 1
    },
    announcements: ['System maintenance scheduled for Friday']
};

const MOCK_USER_RECORD = {
    fields: {
        FirstName: { value: 'Glen' }
    }
};

// ── Helpers ────────────────────────────────────────────────────────

function createComponent(props = {}) {
    const element = createElement('c-delivery-client-dashboard', {
        is: DeliveryClientDashboard
    });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

// ── Tests ──────────────────────────────────────────────────────────

describe('c-delivery-client-dashboard', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    // ── Rendering ──────────────────────────────────────────────────

    describe('basic rendering', () => {
        it('renders without error', () => {
            const element = createComponent();
            expect(element).toBeTruthy();
        });

        it('shows loading spinner initially', () => {
            const element = createComponent();
            const spinner = element.shadowRoot.querySelector('lightning-spinner');
            expect(spinner).not.toBeNull();
        });
    });

    // ── Greeting Section ───────────────────────────────────────────

    describe('greeting section', () => {
        it('displays greeting element', () => {
            const element = createComponent();
            const greeting = element.shadowRoot.querySelector('.cd-greeting');
            expect(greeting).not.toBeNull();
        });

        it('shows greeting line text', () => {
            const element = createComponent();
            const greetingLine = element.shadowRoot.querySelector('.cd-greeting-line');
            expect(greetingLine).not.toBeNull();
            // Should contain "Good morning", "Good afternoon", or "Good evening"
            expect(greetingLine.textContent).toMatch(/Good (morning|afternoon|evening)/);
        });

        it('shows user first name in greeting after wire resolves', async () => {
            const element = createComponent();

            // Emit user record data
            getRecord.emit(MOCK_USER_RECORD);
            await flushPromises();

            const greetingLine = element.shadowRoot.querySelector('.cd-greeting-line');
            expect(greetingLine.textContent).toContain('Glen');
        });

        it('shows caught-up message when no attention items', async () => {
            const element = createComponent();

            getWorkflowConfig.emit(MOCK_WORKFLOW_CONFIG);
            getClientDashboard.emit({
                ...MOCK_DASHBOARD_DATA,
                attentionWorkItems: []
            });
            await flushPromises();

            const greetingLine = element.shadowRoot.querySelector('.cd-greeting-line');
            expect(greetingLine.textContent).toContain('caught up');
        });

        it('shows attention count in greeting when items exist', async () => {
            const element = createComponent();

            getWorkflowConfig.emit(MOCK_WORKFLOW_CONFIG);
            getClientDashboard.emit(MOCK_DASHBOARD_DATA);
            await flushPromises();

            const greetingLine = element.shadowRoot.querySelector('.cd-greeting-line');
            expect(greetingLine.textContent).toContain('2 items need your attention');
        });
    });

    // ── Collapsible Sections ───────────────────────────────────────

    describe('collapsible sections', () => {
        it('renders the In Flight section', async () => {
            const element = createComponent();

            getWorkflowConfig.emit(MOCK_WORKFLOW_CONFIG);
            getClientDashboard.emit(MOCK_DASHBOARD_DATA);
            await flushPromises();

            const cards = element.shadowRoot.querySelectorAll('lightning-card');
            const titles = Array.from(cards).map((c) => c.title);
            expect(titles).toContain("What's In Flight");
        });

        it('renders the Recently Updated section', async () => {
            const element = createComponent();

            getWorkflowConfig.emit(MOCK_DASHBOARD_DATA);
            getClientDashboard.emit(MOCK_DASHBOARD_DATA);
            await flushPromises();

            const cards = element.shadowRoot.querySelectorAll('lightning-card');
            const titles = Array.from(cards).map((c) => c.title);
            expect(titles).toContain('Recently Updated');
        });

        it('renders the This Week section when data exists', async () => {
            const element = createComponent();

            getWorkflowConfig.emit(MOCK_WORKFLOW_CONFIG);
            getClientDashboard.emit(MOCK_DASHBOARD_DATA);
            await flushPromises();

            const cards = element.shadowRoot.querySelectorAll('lightning-card');
            const titles = Array.from(cards).map((c) => c.title);
            expect(titles).toContain('This Week');
        });

        it('renders phase tiles inside In Flight section', async () => {
            const element = createComponent();

            getWorkflowConfig.emit(MOCK_WORKFLOW_CONFIG);
            getClientDashboard.emit(MOCK_DASHBOARD_DATA);
            await flushPromises();

            const phaseTiles = element.shadowRoot.querySelectorAll('.phase-tile');
            // 6 non-terminal phases from the config
            expect(phaseTiles.length).toBe(6);
        });

        it('hides sections via public properties', () => {
            const element = createComponent({
                hideAttentionSection: true,
                hideInFlightSection: true,
                hideRecentSection: true,
                hideThisWeekSection: true
            });

            const cards = element.shadowRoot.querySelectorAll('lightning-card');
            expect(cards.length).toBe(0);

            const greeting = element.shadowRoot.querySelector('.cd-greeting');
            expect(greeting).toBeNull();
        });
    });

    // ── Attention Items ────────────────────────────────────────────

    describe('attention items', () => {
        it('renders attention work items from wire data', async () => {
            const element = createComponent();

            getWorkflowConfig.emit(MOCK_WORKFLOW_CONFIG);
            getClientDashboard.emit(MOCK_DASHBOARD_DATA);
            await flushPromises();

            // Find the Needs Your Attention card by its title property
            const cards = element.shadowRoot.querySelectorAll('lightning-card');
            const attentionCard = Array.from(cards).find(
                (c) => c.title === 'Needs Your Attention'
            );
            expect(attentionCard).toBeDefined();

            const items = element.shadowRoot.querySelectorAll('.attention-item');
            expect(items.length).toBe(2);
        });

        it('shows caught-up pill when no attention items', async () => {
            const element = createComponent();

            getWorkflowConfig.emit(MOCK_WORKFLOW_CONFIG);
            getClientDashboard.emit({
                ...MOCK_DASHBOARD_DATA,
                attentionWorkItems: []
            });
            await flushPromises();

            const caughtUp = element.shadowRoot.querySelector('.cd-caught-up-pill');
            expect(caughtUp).not.toBeNull();
        });
    });

    // ── Wire Error Handling ────────────────────────────────────────

    describe('wire error handling', () => {
        it('stops loading on dashboard error', async () => {
            const element = createComponent();

            getClientDashboard.error();
            await flushPromises();

            // Spinner should be gone after error
            const spinner = element.shadowRoot.querySelector('lightning-spinner');
            expect(spinner).toBeNull();
        });
    });
});
