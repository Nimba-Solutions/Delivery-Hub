/**
 * Imperative Apex mock for DeliveryGhostController.logUserActivity.
 * Used by the c-delivery-ghost-recorder / ghost tracker jest tests.
 */
const logUserActivity = jest.fn(() => Promise.resolve());
module.exports = { default: logUserActivity };
