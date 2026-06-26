/**
 * Wire adapter mock for DeliveryTriageController.getIntakeItems.
 * Used by the triage queue jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getIntakeItems = createApexTestWireAdapter(jest.fn());
module.exports = { default: getIntakeItems };
