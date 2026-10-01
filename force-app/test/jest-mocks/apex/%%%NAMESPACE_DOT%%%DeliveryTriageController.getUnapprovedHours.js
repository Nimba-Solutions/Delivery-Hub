/**
 * Wire adapter mock for DeliveryTriageController.getUnapprovedHours.
 * Used by the deliveryUnapprovedHoursQueue jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getUnapprovedHours = createApexTestWireAdapter(jest.fn());
module.exports = { default: getUnapprovedHours };
