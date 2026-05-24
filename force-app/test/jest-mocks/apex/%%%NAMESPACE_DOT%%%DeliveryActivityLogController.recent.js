/**
 * Wire adapter mock for DeliveryActivityLogController.recent.
 * Used by the c-delivery-activity-log jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const recent = createApexTestWireAdapter(jest.fn());
module.exports = { default: recent };
