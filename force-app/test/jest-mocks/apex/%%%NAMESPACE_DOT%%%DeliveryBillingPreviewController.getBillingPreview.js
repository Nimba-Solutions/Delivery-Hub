/**
 * Wire adapter mock for DeliveryBillingPreviewController.getBillingPreview.
 * Used by the c-delivery-billing-preview jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getBillingPreview = createApexTestWireAdapter(jest.fn());
module.exports = { default: getBillingPreview };
