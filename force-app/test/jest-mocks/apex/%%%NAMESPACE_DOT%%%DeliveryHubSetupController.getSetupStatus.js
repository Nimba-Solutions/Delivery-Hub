/**
 * Wire adapter mock for DeliveryHubSetupController.getSetupStatus.
 * Minimal createApexTestWireAdapter for jest render tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
const getSetupStatus = createApexTestWireAdapter(jest.fn());
module.exports = { default: getSetupStatus };
