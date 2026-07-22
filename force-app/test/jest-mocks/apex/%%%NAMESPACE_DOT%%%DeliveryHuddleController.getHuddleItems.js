/**
 * Wire adapter mock for DeliveryHuddleController.getHuddleItems.
 * Used by the huddle jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getHuddleItems = createApexTestWireAdapter(jest.fn());
module.exports = { default: getHuddleItems };
