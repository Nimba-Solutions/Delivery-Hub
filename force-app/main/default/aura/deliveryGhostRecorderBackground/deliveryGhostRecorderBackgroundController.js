/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Wires the background recorder's lifecycle to its helper.
 * @author       Cloud Nimbus LLC
 */
({
    onInit: function (component, event, helper) {
        helper.start(component);
        helper.scheduleInitialPage(component);
    },

    onLocationChange: function (component, event, helper) {
        helper.recordNavigation(component);
    },

    onDestroy: function (component, event, helper) {
        helper.stop(component);
    }
})
