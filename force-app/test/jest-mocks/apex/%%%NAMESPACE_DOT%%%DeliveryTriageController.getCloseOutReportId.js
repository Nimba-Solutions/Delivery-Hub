/**
 * Wire adapter mock for DeliveryTriageController.getCloseOutReportId.
 * Used by the triage queue jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getCloseOutReportId = createApexTestWireAdapter(jest.fn());
module.exports = { default: getCloseOutReportId };
