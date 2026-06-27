/**
 * Wire adapter mock for DeliveryHomeVisibilityController.getHiddenHomeComponents.
 * Used by the home-page LWC jest tests to drive per-component Home visibility.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getHiddenHomeComponents = createApexTestWireAdapter(jest.fn());
module.exports = { default: getHiddenHomeComponents };
