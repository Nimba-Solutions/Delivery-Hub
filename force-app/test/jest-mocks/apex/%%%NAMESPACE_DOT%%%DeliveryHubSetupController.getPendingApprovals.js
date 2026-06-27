/**
 * Wire adapter mock for DeliveryHubSetupController.getPendingApprovals.
 * Minimal createApexTestWireAdapter for jest render tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
const getPendingApprovals = createApexTestWireAdapter(jest.fn());
module.exports = { default: getPendingApprovals };
