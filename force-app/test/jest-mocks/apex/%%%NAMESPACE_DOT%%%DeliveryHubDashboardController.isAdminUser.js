/**
 * Wire adapter mock for DeliveryHubDashboardController.isAdminUser.
 * Used by the deliveryHubWorkspace jest tests to drive admin-only tab gating.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const isAdminUser = createApexTestWireAdapter(jest.fn());
module.exports = { default: isAdminUser };
