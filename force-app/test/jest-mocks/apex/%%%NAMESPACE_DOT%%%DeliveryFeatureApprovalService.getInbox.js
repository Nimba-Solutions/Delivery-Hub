/**
 * Wire adapter mock for DeliveryFeatureApprovalService.getInbox.
 * Minimal createApexTestWireAdapter for jest render tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
const getInbox = createApexTestWireAdapter(jest.fn());
module.exports = { default: getInbox };
