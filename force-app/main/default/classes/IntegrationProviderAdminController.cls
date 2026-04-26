/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Apex controller for the integrationProviderAdmin LWC. Read-only
 *              listing of IntegrationProvider__mdt records plus a probe action
 *              that runs validateConnection() against a chosen provider.
 *
 *              SCAFFOLD STATE (4/26/2026): scope is intentionally minimal.
 *              The 'subtract Glen from API integrations' admin UI from
 *              /mf/integration-framework-0426 Phase 6 needs full CRUD over
 *              providers, secret management, payload preview, error replay,
 *              etc. — that's a bigger product surface called out as risk R5
 *              in the master plan. This scaffold gives admins read-only
 *              visibility plus the connection-probe action; full UI is a
 *              follow-on engagement.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
public with sharing class IntegrationProviderAdminController {

    /**
     * @description DTO returned to the LWC for each provider row.
     */
    public class ProviderRow {
        /** @description CMT DeveloperName. */
        @AuraEnabled public String developerName { get; set; }
        /** @description Apex class implementing the provider interface. */
        @AuraEnabled public String apexClassName { get; set; }
        /** @description Named Credential DeveloperName referenced by this provider. */
        @AuraEnabled public String namedCredentialDevName { get; set; }
        /** @description Endpoint path appended to the NC host. */
        @AuraEnabled public String endpointPath { get; set; }
        /** @description Sink / Source / Bidirectional. */
        @AuraEnabled public String typeValue { get; set; }
        /** @description True when EnabledDateTime__c is set. */
        @AuraEnabled public Boolean enabled { get; set; }
        /** @description Enabled-since DateTime, when set. */
        @AuraEnabled public Datetime enabledSince { get; set; }
    }

    /**
     * @description List all IntegrationProvider__mdt records sorted by
     *              DeveloperName. Caller-side renders the table.
     * @return List of ProviderRow.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProviderRow> listProviders() {
        try {
            List<IntegrationProvider__mdt> records = [
                SELECT Id, DeveloperName, ApexClassNameTxt__c, NamedCredentialDevNameTxt__c,
                       EndpointPathTxt__c, TypePk__c, EnabledDateTime__c
                FROM IntegrationProvider__mdt
                WITH SYSTEM_MODE
                ORDER BY DeveloperName ASC
            ];
            List<ProviderRow> rows = new List<ProviderRow>();
            for (IntegrationProvider__mdt r : records) {
                ProviderRow row = new ProviderRow();
                row.developerName = r.DeveloperName;
                row.apexClassName = r.ApexClassNameTxt__c;
                row.namedCredentialDevName = r.NamedCredentialDevNameTxt__c;
                row.endpointPath = r.EndpointPathTxt__c;
                row.typeValue = r.TypePk__c;
                row.enabled = r.EnabledDateTime__c != null;
                row.enabledSince = r.EnabledDateTime__c;
                rows.add(row);
            }
            return rows;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Run the dispatcher's connection probe against a provider.
     *              Useful for admin to verify auth / Named Credential / endpoint
     *              are wired correctly without sending a real payload.
     * @param providerDeveloperName DeveloperName of the provider to probe.
     * @return true when the provider's validateConnection() returned true.
     */
    @AuraEnabled
    public static Boolean probeProvider(String providerDeveloperName) {
        try {
            return IntegrationDispatcher.probeConnection(providerDeveloperName);
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }
}
