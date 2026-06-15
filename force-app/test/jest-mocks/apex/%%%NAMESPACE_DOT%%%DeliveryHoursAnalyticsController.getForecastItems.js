/**
 * Wire adapter mock for DeliveryHoursAnalyticsController.getForecastItems.
 * Used by the c-delivery-capacity-forecast jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getForecastItems = createApexTestWireAdapter(jest.fn());
module.exports = { default: getForecastItems };
