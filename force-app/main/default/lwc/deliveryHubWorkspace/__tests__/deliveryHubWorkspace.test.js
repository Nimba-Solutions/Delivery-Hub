/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Jest coverage for deliveryHubWorkspace: a sub-tab is hidden when its
 *               DeliveryTabVisibilityController.getHiddenWorkspaceTabs entry is set, and
 *               the active tab falls back to the first VISIBLE tab when the would-be
 *               default landing tab has been hidden.
 *
 *               The workspace is a pure shell that embeds ~17 child LWCs. Rendering it in
 *               jest transitively compiles every child (and their unmockable deps, e.g.
 *               lightning/actions, plus deliveryHubBoard's %%%NAMESPACE_DOT%%% template
 *               token). We stub every child to an empty LWC so this test exercises only the
 *               shell's tab visibility / active-tab logic, with zero child-dependency churn.
 * @author       Cloud Nimbus LLC
 */
import { createElement } from 'lwc';

// Stub every child LWC the workspace embeds → only the shell renders. The factory must be
// inlined per call (babel-plugin-jest-hoist rejects a shared factory reference); the
// require('lwc') call inside the inline factory is permitted.
jest.mock('c/deliveryIntakeQueue', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryHubBoard', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryQuickRequest', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryProFormaTimeline', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryActivityFeed', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryDocumentViewer', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryGuide', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryApprovalSummaryCard', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryApprovalQueue', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryCloseOutQueue', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryCapacityForecast', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryTemplateManager', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryActivityDashboard', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryVelocityDashboard', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryPacingForecast', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliverySettingsContainer', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));
jest.mock('c/deliveryWorkflowBuilder', () => ({ __esModule: true, default: class extends require('lwc').LightningElement {} }));

// eslint-disable-next-line import/first
import DeliveryHubWorkspace from 'c/deliveryHubWorkspace';
// eslint-disable-next-line import/first
import isAdminUser from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.isAdminUser';
// eslint-disable-next-line import/first
import getHiddenWorkspaceTabs from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTabVisibilityController.getHiddenWorkspaceTabs';

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

function createComponent() {
    const element = createElement('c-delivery-hub-workspace', {
        is: DeliveryHubWorkspace
    });
    document.body.appendChild(element);
    return element;
}

function tabValues(element) {
    // lightning-tab is stubbed in jest; `value` reaches it as a property, not an attribute.
    return Array.from(element.shadowRoot.querySelectorAll('lightning-tab')).map((t) => t.value);
}

describe('c-delivery-hub-workspace', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('shows all ten non-admin tabs by default', async () => {
        const element = createComponent();
        isAdminUser.emit(false);
        getHiddenWorkspaceTabs.emit({});
        await flushPromises();

        const values = tabValues(element);
        expect(values).toContain('intake');
        expect(values).toContain('board');
        expect(values).toContain('forecast');
        expect(values.length).toBe(10); // buyer → no admin tabs
    });

    it('hides a tab when its visibility setting is set', async () => {
        const element = createComponent();
        isAdminUser.emit(false);
        getHiddenWorkspaceTabs.emit({ board: true });
        await flushPromises();

        const values = tabValues(element);
        expect(values).not.toContain('board');
        expect(values).toContain('intake');
    });

    it('falls back to the first visible tab when the buyer landing tab is hidden', async () => {
        const element = createComponent();
        // Buyers default-land on Approvals; hide it → must fall back to first visible (intake).
        isAdminUser.emit(false);
        getHiddenWorkspaceTabs.emit({ approvals: true });
        await flushPromises();

        const tabset = element.shadowRoot.querySelector('lightning-tabset');
        expect(tabset.activeTabValue).toBe('intake');
        expect(tabValues(element)).not.toContain('approvals');
    });
});
