/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Generic, declarative integration dispatcher. The single entry
 *              point for outbound HTTP calls driven by IntegrationProvider__mdt
 *              metadata. NO per-system Apex code in DH — subscribers configure
 *              providers via metadata records pointing at Named Credentials.
 *
 *              Pipeline:
 *                1. Resolve IntegrationProvider__mdt by DeveloperName.
 *                2. Validate enabled flag.
 *                3. Render endpoint path + request body via IntegrationTemplateEngine
 *                   (mustache-style {{var}} substitution against the payload Map).
 *                4. Build the HttpRequest (method, headers, NC reference).
 *                5. Optionally invoke a IIntegrationTemplateExtension implementation
 *                   (Stripe HMAC, AWS SigV4, gzip, etc.) to mutate the request.
 *                6. Send.
 *                7. Map the response via IntegrationResponseMapper using the
 *                   provider's status-code rules and parse expression.
 *                8. Return IntegrationDispatcherResult.
 *
 *              Subscribers call: IntegrationDispatcher.send(devName, payload).
 *              They never write per-system Apex unless they need an extension
 *              that doesn't exist yet (then they implement
 *              IIntegrationTemplateExtension and reference it via metadata).
 *
 *              Edge cases that warrant a custom extension:
 *                - Request signing (HMAC, SigV4)
 *                - OAuth2 dynamic refresh
 *                - Multipart upload
 *                - Body gzip / encoding transforms
 *
 *              Edge cases handled in metadata alone:
 *                - URL templating
 *                - Body templating with variable defaults
 *                - Header customization
 *                - Status-code rule mapping
 *                - Response field extraction (dotted-path)
 *
 *              Observability: System.debug logs every dispatch with the
 *              rendered endpoint, body length, and result. Subscribers
 *              can layer their own logging (DH ActivityLog__c, Slack,
 *              etc.) by wrapping send() in their own service.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
public with sharing class IntegrationDispatcher {

    /**
     * @description Resolve the provider, render the request, send it, return
     *              the mapped result. Captures all exceptions and surfaces
     *              them as RetryableFailure rather than throwing.
     * @param providerDeveloperName DeveloperName of an IntegrationProvider__mdt row.
     * @param payload Payload Map. Substituted into request body / endpoint path templates.
     * @return IntegrationDispatcherResult describing the outcome.
     */
    public static IntegrationDispatcherResult send(String providerDeveloperName, Map<String, Object> payload) {
        if (String.isBlank(providerDeveloperName)) {
            return IntegrationDispatcherResult.terminal(
                'providerDeveloperName is required', null, null);
        }
        Map<String, Object> safePayload = payload == null ? new Map<String, Object>() : payload;
        IntegrationProvider__mdt config;
        try {
            config = resolveProvider(providerDeveloperName);
        } catch (IntegrationDispatcherException e) {
            return IntegrationDispatcherResult.terminal(e.getMessage(), null, null);
        }
        if (config.EnabledDateTime__c == null) {
            return IntegrationDispatcherResult.terminal(
                'Provider ' + providerDeveloperName + ' is disabled (EnabledDateTime__c is null)',
                null, null);
        }
        try {
            HttpRequest req = buildRequest(config, safePayload);
            applyExtension(config, req, safePayload);
            HttpResponse res = new Http().send(req);
            IntegrationDispatcherResult result = IntegrationResponseMapper.mapResponse(
                res.getStatusCode(), res.getBody(), config);
            logDispatch(config, req, result);
            return result;
        } catch (CalloutException e) {
            return IntegrationDispatcherResult.retryable(
                'Callout exception: ' + e.getMessage(), null, null);
        } catch (Exception e) {
            return IntegrationDispatcherResult.terminal(
                e.getTypeName() + ': ' + e.getMessage(), null, null);
        }
    }

    /**
     * @description Health-check probe — sends an empty-payload GET to the
     *              configured endpoint and reports whether the response was
     *              "Sent" per the provider's rules. Useful for the admin UI.
     * @param providerDeveloperName DeveloperName of the provider to probe.
     * @return true when the dispatcher's outcome is "Sent" or 4xx (live but rejected).
     */
    public static Boolean probe(String providerDeveloperName) {
        IntegrationDispatcherResult r = send(providerDeveloperName, new Map<String, Object>());
        if (r.statusCode == 'Sent') { return true; }
        Integer code = r.httpStatusCode == null ? 0 : r.httpStatusCode;
        return code >= 200 && code < 500;
    }

    /**
     * @description Look up the IntegrationProvider__mdt by DeveloperName.
     * @param developerName CMT DeveloperName.
     * @return Resolved provider config.
     */
    @TestVisible
    private static IntegrationProvider__mdt resolveProvider(String developerName) {
        List<IntegrationProvider__mdt> hits = [
            SELECT Id, DeveloperName, NamedCredentialDevNameTxt__c, EndpointPathTxt__c,
                   HttpMethodPk__c, RequestBodyTemplateTxt__c, HeadersJsonTxt__c,
                   ResponseRulesJsonTxt__c, SuccessParseExprTxt__c,
                   SignerExtensionTxt__c, EnabledDateTime__c
            FROM IntegrationProvider__mdt
            WHERE DeveloperName = :developerName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (hits.isEmpty()) {
            throw new IntegrationDispatcherException(
                'No IntegrationProvider__mdt found for DeveloperName: ' + developerName);
        }
        return hits[0];
    }

    /**
     * @description Build the HttpRequest from provider config + rendered templates.
     * @param config Provider config.
     * @param payload Dispatch payload.
     * @return Configured HttpRequest ready for extension hook + send.
     */
    @TestVisible
    private static HttpRequest buildRequest(IntegrationProvider__mdt config, Map<String, Object> payload) {
        if (String.isBlank(config.NamedCredentialDevNameTxt__c)) {
            throw new IntegrationDispatcherException(
                'Provider ' + config.DeveloperName + ' has no Named Credential configured');
        }
        String renderedPath = IntegrationTemplateEngine.render(
            config.EndpointPathTxt__c == null ? '' : config.EndpointPathTxt__c,
            payload);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + config.NamedCredentialDevNameTxt__c + renderedPath);
        req.setMethod(String.isBlank(config.HttpMethodPk__c) ? 'POST' : config.HttpMethodPk__c);
        applyHeaders(req, config);
        if (String.isNotBlank(config.RequestBodyTemplateTxt__c)) {
            String body = IntegrationTemplateEngine.render(config.RequestBodyTemplateTxt__c, payload);
            req.setBody(body);
        }
        req.setTimeout(30000);
        return req;
    }

    /**
     * @description Merge default JSON headers with the provider's HeadersJsonTxt__c overrides.
     * @param req HttpRequest to mutate.
     * @param config Provider config.
     */
    @TestVisible
    private static void applyHeaders(HttpRequest req, IntegrationProvider__mdt config) {
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        if (String.isBlank(config.HeadersJsonTxt__c)) {
            return;
        }
        try {
            Map<String, Object> headers = (Map<String, Object>) JSON.deserializeUntyped(
                config.HeadersJsonTxt__c);
            for (String name : headers.keySet()) {
                req.setHeader(name, String.valueOf(headers.get(name)));
            }
        } catch (Exception e) {
            // Bad JSON in headers is a config error, but don't fail the
            // dispatch — log and proceed with defaults. Admin UI surfaces
            // the rendered request including header set for debugging.
            System.debug(LoggingLevel.WARN,
                '[IntegrationDispatcher] Bad HeadersJsonTxt__c on '
                + config.DeveloperName + ': ' + e.getMessage());
        }
    }

    /**
     * @description Optionally invoke the configured IIntegrationTemplateExtension
     *              to mutate the request before send (signing, encoding, etc.).
     * @param config Provider config.
     * @param req HttpRequest to potentially mutate.
     * @param payload Original dispatch payload (passed for extension context).
     */
    @TestVisible
    private static void applyExtension(IntegrationProvider__mdt config, HttpRequest req, Map<String, Object> payload) {
        if (String.isBlank(config.SignerExtensionTxt__c)) {
            return;
        }
        // Try 1-arg first — handles both inner classes ('OuterClass.InnerClass')
        // and same-namespace classes. Fall back to 2-arg only when 1-arg fails,
        // for cross-namespace ('namespace.ClassName') subscriber-Apex providers.
        Type t = Type.forName(config.SignerExtensionTxt__c);
        if (t == null && config.SignerExtensionTxt__c.contains('.')) {
            List<String> parts = config.SignerExtensionTxt__c.split('\\.');
            t = Type.forName(parts[0], parts[1]);
        }
        if (t == null) {
            throw new IntegrationDispatcherException(
                'Cannot resolve SignerExtensionTxt__c class: ' + config.SignerExtensionTxt__c);
        }
        Object instance = t.newInstance();
        if (!(instance instanceof IIntegrationTemplateExtension)) {
            throw new IntegrationDispatcherException(
                'Class ' + config.SignerExtensionTxt__c
                + ' does not implement IIntegrationTemplateExtension');
        }
        ((IIntegrationTemplateExtension) instance).applyTo(req, payload, config);
    }

    /**
     * @description System.debug observability for every dispatch. Subscribers
     *              who want richer logging wrap send() in their own service.
     * @param config Provider config that drove this dispatch.
     * @param req The HttpRequest that was sent.
     * @param result The mapped result.
     */
    @TestVisible
    private static void logDispatch(IntegrationProvider__mdt config, HttpRequest req, IntegrationDispatcherResult result) {
        String endpoint = req.getEndpoint();
        Integer bodyLen = req.getBody() == null ? 0 : req.getBody().length();
        System.debug(LoggingLevel.INFO,
            '[IntegrationDispatcher] provider=' + config.DeveloperName
            + ' method=' + req.getMethod()
            + ' endpoint=' + endpoint
            + ' bodyBytes=' + bodyLen
            + ' result=' + result.statusCode
            + ' http=' + result.httpStatusCode
            + ' msg=' + result.statusMessage);
    }
}
