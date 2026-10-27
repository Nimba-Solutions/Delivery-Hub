/**
 * Imperative Apex mock for DeliveryGhostController.createQuickRequest.
 * Used by the c-delivery-ghost-recorder / ghost tracker jest tests.
 */
const createQuickRequest = jest.fn(() => Promise.resolve());
module.exports = { default: createQuickRequest };
