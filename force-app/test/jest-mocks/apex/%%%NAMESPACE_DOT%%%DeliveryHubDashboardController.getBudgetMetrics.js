/**
 * Wire adapter mock for DeliveryHubDashboardController.getBudgetMetrics.
 * Minimal createApexTestWireAdapter for jest render tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
const getBudgetMetrics = createApexTestWireAdapter(jest.fn());
module.exports = { default: getBudgetMetrics };
