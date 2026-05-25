/**
 * Mock for DeliveryFeatureCatalogController.isAdmin (wire).
 * Used by deliveryFeatureDependencyEditor (and potentially other LWCs that
 * reuse the central DH admin gate).
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const isAdmin = createApexTestWireAdapter(jest.fn());
module.exports = { default: isAdmin };
