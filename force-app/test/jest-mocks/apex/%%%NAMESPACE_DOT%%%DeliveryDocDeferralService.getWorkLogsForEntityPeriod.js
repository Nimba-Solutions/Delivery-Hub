/**
 * Mock for DeliveryDocDeferralService.getWorkLogsForEntityPeriod (wire).
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getWorkLogsForEntityPeriod = createApexTestWireAdapter(jest.fn());
module.exports = { default: getWorkLogsForEntityPeriod };
