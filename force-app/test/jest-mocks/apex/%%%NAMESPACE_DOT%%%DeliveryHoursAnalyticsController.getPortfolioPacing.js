/**
 * Wire adapter mock for DeliveryHoursAnalyticsController.getPortfolioPacing.
 * Used by the c-delivery-pacing-forecast jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getPortfolioPacing = createApexTestWireAdapter(jest.fn());
module.exports = { default: getPortfolioPacing };
