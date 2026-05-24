/**
 * Mock for DeliveryFeatureCatalogController.getCatalog (wire).
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getCatalog = createApexTestWireAdapter(jest.fn());
module.exports = { default: getCatalog };
