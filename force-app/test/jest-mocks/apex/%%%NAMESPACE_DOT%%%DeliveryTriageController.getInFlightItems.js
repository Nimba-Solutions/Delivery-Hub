/**
 * Wire adapter mock for DeliveryTriageController.getInFlightItems.
 * Used by the deliveryInFlightQueue jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getInFlightItems = createApexTestWireAdapter(jest.fn());
module.exports = { default: getInFlightItems };
