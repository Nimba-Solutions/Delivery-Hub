/**
 * Wire adapter mock for DeliveryWorkApprovalService.getPendingForApprover.
 * Used by the c-delivery-approval-queue jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getPendingForApprover = createApexTestWireAdapter(jest.fn());
module.exports = { default: getPendingForApprover };
