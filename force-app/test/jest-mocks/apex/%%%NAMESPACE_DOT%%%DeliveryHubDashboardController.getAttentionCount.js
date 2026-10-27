/**
 * Wire adapter mock for DeliveryHubDashboardController.getAttentionCount.
 * Used by the c-delivery-ghost-recorder jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getAttentionCount = createApexTestWireAdapter(jest.fn());
module.exports = { default: getAttentionCount };
