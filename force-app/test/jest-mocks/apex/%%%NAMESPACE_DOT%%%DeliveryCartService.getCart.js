/**
 * Wire adapter mock for DeliveryCartService.getCart.
 * Used by the c-delivery-cart-checkout and c-delivery-cart-builder jest tests.
 */
const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getCart = createApexTestWireAdapter(jest.fn());
module.exports = { default: getCart };
