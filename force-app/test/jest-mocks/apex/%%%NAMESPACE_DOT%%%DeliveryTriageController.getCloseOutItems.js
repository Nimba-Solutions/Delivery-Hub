/**
 * Wire adapter mock for DeliveryTriageController.getCloseOutItems.
 * Used by the triage queue jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getCloseOutItems = createApexTestWireAdapter(jest.fn());
module.exports = { default: getCloseOutItems };
