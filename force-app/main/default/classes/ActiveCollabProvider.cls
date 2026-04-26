/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Active Collab integration · bidirectional. Implements both
 *              IIntegrationSink (push CN-logged time TO AC) and
 *              IIntegrationSource (pull AC time entries + accept AC webhooks
 *              about task changes). Configured as Type=Bidirectional in the
 *              IntegrationProvider__mdt record.
 *
 *              SCAFFOLD STATE (4/26/2026): the provider class is wired into
 *              the framework but the actual AC API implementations are
 *              stubbed pending Active Collab API credentials from Danny.
 *              Per /mf/ac-bridge-0426 design doc · Glen committed to this
 *              integration 4/26 morning. Stub bodies return structured
 *              results so the framework's dispatch + retry plumbing can be
 *              tested end-to-end with this class as the target.
 *
 *              When the AC API is wired (post-Danny hand-off), this class
 *              gets:
 *                - send() implementation: POST to AC time-entries API,
 *                  store AC entry ID on IntegrationItem__c.RemoteRecordIdTxt__c
 *                - fetch() implementation: GET AC time entries since cursor
 *                  filtered to MF-tagged projects (per Concern C3 in design
 *                  doc — privacy boundary)
 *                - acceptWebhook() implementation: parse AC's webhook
 *                  payload (per AC API webhook docs), normalize to
 *                  delivery__WorkLog__c shape
 *
 *              See /mf/ac-bridge-0426 for the 10 risks + 10 things to
 *              extract from Danny + data shape + 4-phase implementation
 *              sequence. This scaffold is the framework hook for that work.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
public with sharing class ActiveCollabProvider implements IIntegrationSink, IIntegrationSource {

    /**
     * @description Push a Cloud-Nimbus-logged time entry TO Active Collab.
     *              SCAFFOLD: returns terminal-with-explanation pending API hookup.
     * @param payload Map with required keys: workItemTNumber (T-NNNN), hours,
     *                description, workDate, resourceName.
     * @param providerConfig Resolved provider config.
     * @return IntegrationSinkResult.
     */
    public IntegrationSinkResult send(Map<String, Object> payload, IntegrationProvider__mdt providerConfig) {
        if (payload == null) {
            return IntegrationSinkResult.terminal('Payload is null', null);
        }
        if (String.isBlank(providerConfig.NamedCredentialDevNameTxt__c)) {
            return IntegrationSinkResult.terminal(
                'ActiveCollab provider has no Named Credential configured. '
                + 'Configuration pending Danny AC API access (see /mf/ac-bridge-0426).',
                null
            );
        }
        // SCAFFOLD: when AC API is live, the implementation here POSTs to
        // {NC}/api/v1/projects/{project}/time-records with the payload mapped
        // to AC's time-entry shape. Until then we surface a clear terminal
        // result so callers see what's missing without retry storms.
        return IntegrationSinkResult.terminal(
            'ActiveCollab send() not yet implemented — pending AC API credentials. '
            + 'Provider class is framework-compliant; awaiting impl.',
            null
        );
    }

    /**
     * @description Pull AC time entries since cursor.
     *              SCAFFOLD: returns no-new-data pending API hookup.
     * @param cursor Last-fetch cursor token (timestamp string).
     * @param providerConfig Resolved provider config.
     * @return IntegrationPullResult.
     */
    public IntegrationPullResult fetch(String cursor, IntegrationProvider__mdt providerConfig) {
        if (String.isBlank(providerConfig.NamedCredentialDevNameTxt__c)) {
            return IntegrationPullResult.retryable(
                'ActiveCollab provider has no Named Credential configured. '
                + 'Configuration pending Danny AC API access.'
            );
        }
        // SCAFFOLD: when AC API is live, the implementation here GETs
        // {NC}/api/v1/time-records?since={cursor}&projects={MF-tagged}
        // and maps each entry to a Map<String,Object> with WorkLog-shaped
        // keys. Until then return no-new-data so the framework's polling
        // loop runs cleanly without surfacing fake records.
        return IntegrationPullResult.noNewData();
    }

    /**
     * @description Accept inbound AC webhook (e.g. time-entry created/updated).
     *              SCAFFOLD: acknowledges with no records pending API hookup.
     * @param headers Pre-validated HTTP headers.
     * @param body Raw request body string.
     * @param providerConfig Resolved provider config.
     * @return IntegrationWebhookResult.
     */
    public IntegrationWebhookResult acceptWebhook(Map<String, String> headers, String body, IntegrationProvider__mdt providerConfig) {
        // SCAFFOLD: when AC webhooks are configured (Phase 2B of /mf/ac-bridge-0426),
        // this method parses AC's webhook payload format, extracts time-entry
        // events (created/updated/deleted), and returns IntegrationWebhookResult
        // with normalized records. Until then we acknowledge to keep webhook
        // testing infrastructure healthy.
        return IntegrationWebhookResult.acknowledged(new List<Map<String, Object>>());
    }

    /**
     * @description Health-check probe.
     *              SCAFFOLD: returns false until configured.
     * @param providerConfig Resolved provider config.
     * @return Boolean.
     */
    public Boolean validateConnection(IntegrationProvider__mdt providerConfig) {
        // SCAFFOLD: real impl GETs {NC}/api/v1/info or similar lightweight
        // endpoint. Returns true on 200, false otherwise. Until configured,
        // false signals the admin UI to surface "configuration needed".
        return false;
    }
}
