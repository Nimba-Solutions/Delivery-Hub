/**
 * Wire adapter mock for DeliveryTabVisibilityController.getHiddenWorkspaceTabs.
 * Used by the deliveryHubWorkspace (wire) and deliveryTabVisibilitySettingsCard
 * (imperative) jest tests to drive per-tab Delivery-workspace visibility.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getHiddenWorkspaceTabs = createApexTestWireAdapter(jest.fn());
module.exports = { default: getHiddenWorkspaceTabs };
