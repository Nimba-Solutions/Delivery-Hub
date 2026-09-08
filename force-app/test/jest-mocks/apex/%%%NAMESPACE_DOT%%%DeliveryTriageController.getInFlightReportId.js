/**
 * Wire adapter mock for DeliveryTriageController.getInFlightReportId.
 * Used by the deliveryInFlightQueue jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getInFlightReportId = createApexTestWireAdapter(jest.fn());
module.exports = { default: getInFlightReportId };
