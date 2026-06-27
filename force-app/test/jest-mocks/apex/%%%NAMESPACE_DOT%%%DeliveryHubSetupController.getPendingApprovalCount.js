/**
 * Wire adapter mock for DeliveryHubSetupController.getPendingApprovalCount.
 * Minimal createApexTestWireAdapter for jest render tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
const getPendingApprovalCount = createApexTestWireAdapter(jest.fn());
module.exports = { default: getPendingApprovalCount };
