/**
 * Mock for DeliveryFeatureCatalogController.toggleFeature (imperative).
 * Default resolves to null; tests override with mockResolvedValue /
 * mockRejectedValue to drive happy- and gate-failure paths.
 */
module.exports = { default: jest.fn(() => Promise.resolve(null)) };
