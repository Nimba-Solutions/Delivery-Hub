/**
 * Wire adapter mock for DeliveryApprovalSummaryController.getApprovalSummary.
 * Used by the c-delivery-approval-summary-card jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getApprovalSummary = createApexTestWireAdapter(jest.fn());
module.exports = { default: getApprovalSummary };
