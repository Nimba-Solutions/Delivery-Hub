/**
 * Mock for DeliveryWorkflowConfigService.getWorkflowConfig
 * Used as a wire adapter.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getWorkflowConfig = createApexTestWireAdapter(jest.fn());
module.exports = { default: getWorkflowConfig };
