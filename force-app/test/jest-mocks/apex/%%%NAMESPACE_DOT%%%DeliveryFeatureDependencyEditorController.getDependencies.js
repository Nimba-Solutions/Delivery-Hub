/**
 * Mock for DeliveryFeatureDependencyEditorController.getDependencies (wire).
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getDependencies = createApexTestWireAdapter(jest.fn());
module.exports = { default: getDependencies };
