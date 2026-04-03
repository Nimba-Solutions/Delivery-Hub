const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver'],
    moduleNameMapper: {
        /* ── Apex wire adapters & imperative methods ──
         * CumulusCI injects %%%NAMESPACE_DOT%%% at deploy time; in source
         * the import paths still contain the raw token.  Map each one to
         * a simple manual mock so Jest can resolve them. */
        '^@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController\\.getClientDashboard$':
            '<rootDir>/force-app/test/jest-mocks/apex/getClientDashboard',
        '^@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController\\.getReportIds$':
            '<rootDir>/force-app/test/jest-mocks/apex/getReportIds',
        '^@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService\\.getWorkflowConfig$':
            '<rootDir>/force-app/test/jest-mocks/apex/getWorkflowConfig',

        // Catch-all for any other Apex imports (namespaced or not)
        '^@salesforce/apex/(.*)$':
            '<rootDir>/force-app/test/jest-mocks/apex/$1',

        // User Id
        '^@salesforce/user/Id$':
            '<rootDir>/force-app/test/jest-mocks/salesforce/user/Id',

        // Schema fields
        '^@salesforce/schema/(.*)$':
            '<rootDir>/force-app/test/jest-mocks/salesforce/schema/$1',

        /* ── Child component stubs ── */
        '^c/deliveryInfoPopover$':
            '<rootDir>/force-app/test/jest-mocks/c/deliveryInfoPopover/deliveryInfoPopover'
    }
};
