/**
 * Imperative Apex mock for DeliveryWorkItemController.linkFilesAndSync.
 * Used by the c-delivery-ghost-recorder / ghost tracker jest tests.
 */
const linkFilesAndSync = jest.fn(() => Promise.resolve());
module.exports = { default: linkFilesAndSync };
