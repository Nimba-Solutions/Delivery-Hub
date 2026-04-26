/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description QuickBooks Online integration · IIntegrationSink scaffold.
 *
 *              SCAFFOLD STATE (4/26/2026): the framework hook is in place
 *              but the actual QuickBooks API implementation lives elsewhere
 *              today (subscriber-org QuickBooksJEService — MF-Prod custom
 *              code, see /mf/glen-plan-0426 Issue B context). The
 *              ownership-migration play in /mf/integration-framework-0426
 *              Phase 5 is to move that custom code INTO this provider as
 *              part of the framework rollout — MF-Prod becomes a consumer
 *              instead of holding bespoke integration code.
 *
 *              Migration approach (when scheduled):
 *                1. Inventory QuickBooksJEService methods used externally
 *                2. Define payload shapes for each (CreateJournalEntry,
 *                   CreateInvoice, RefundInvoice, etc.)
 *                3. Implement send() with case-dispatch on payload['operation']
 *                4. Set up OAuth2 via External Credential (QB needs refresh
 *                   token rotation handling — Spring '23 NC handles this
 *                   correctly)
 *                5. Migrate one MF-Prod caller per PR for bisectability
 *                6. Retire QuickBooksJEService when callers all switched
 *
 *              Until then, this scaffold returns TerminalFailure with a
 *              clear explanation so any inadvertent dispatch via the
 *              framework points the operator at the right doc page.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
public with sharing class QuickBooksProvider implements IIntegrationSink {

    /**
     * @description Push a QuickBooks operation. SCAFFOLD: returns terminal
     *              with explanation pending QB ownership migration.
     * @param payload Map with required key: operation (one of
     *                CreateJournalEntry, CreateInvoice, RefundInvoice etc).
     * @param providerConfig Resolved provider config.
     * @return IntegrationSinkResult.
     */
    public IntegrationSinkResult send(Map<String, Object> payload, IntegrationProvider__mdt providerConfig) {
        if (payload == null || !payload.containsKey('operation')) {
            return IntegrationSinkResult.terminal(
                'Payload missing required key: operation', null);
        }
        if (String.isBlank(providerConfig.NamedCredentialDevNameTxt__c)) {
            return IntegrationSinkResult.terminal(
                'QuickBooks provider has no Named Credential configured. '
                + 'OAuth2 + refresh-token rotation requires External Credential setup '
                + '(see /mf/integration-framework-0426 Phase 5 + Spring 23 NC docs).',
                null
            );
        }
        // SCAFFOLD: real impl dispatches on payload['operation'] to QB API
        // endpoints (POST /v3/company/{realmId}/journalentry, etc.). Until
        // ownership migration runs, redirect callers to the existing
        // MF-Prod QuickBooksJEService.
        return IntegrationSinkResult.terminal(
            'QuickBooksProvider.send() is a scaffold pending Phase 5 '
            + 'ownership migration. For now, MF-Prod QuickBooksJEService '
            + 'remains the integration entry point. Operation requested: '
            + String.valueOf(payload.get('operation')),
            null
        );
    }

    /**
     * @description Health-check probe. SCAFFOLD: returns false until
     *              real OAuth2 setup completes.
     * @param providerConfig Resolved provider config.
     * @return Boolean.
     */
    public Boolean validateConnection(IntegrationProvider__mdt providerConfig) {
        // SCAFFOLD: real impl GETs {NC}/v3/company/{realmId}/companyinfo/{realmId}
        // and returns 200 to indicate the OAuth tokens are still valid.
        // Until configured, false signals admin UI to surface 'config needed'.
        return false;
    }
}
