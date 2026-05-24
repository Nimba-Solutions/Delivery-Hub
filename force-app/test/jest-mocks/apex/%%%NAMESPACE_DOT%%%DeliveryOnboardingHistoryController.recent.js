/**
 * Wire adapter mock for DeliveryOnboardingHistoryController.recent.
 * Used by the c-delivery-onboarding-history jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const recent = createApexTestWireAdapter(jest.fn());
module.exports = { default: recent };
