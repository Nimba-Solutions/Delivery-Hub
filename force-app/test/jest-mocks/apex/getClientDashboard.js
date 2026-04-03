/**
 * Mock for DeliveryHubDashboardController.getClientDashboard
 * Used as both a wire adapter and imperative call.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getClientDashboard = createApexTestWireAdapter(jest.fn());
module.exports = { default: getClientDashboard };
