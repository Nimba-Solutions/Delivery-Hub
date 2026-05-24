/**
 * Wire adapter mock for DeliveryWatcherDigestHistoryController.recent.
 * Used by the c-delivery-watcher-digest-history jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const recent = createApexTestWireAdapter(jest.fn());
module.exports = { default: recent };
