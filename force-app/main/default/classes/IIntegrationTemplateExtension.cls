/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Plug-in extension point for transforming HTTP requests before
 *              dispatch. The most common use case is request signing
 *              (HMAC-SHA256 for Stripe webhooks, AWS SigV4, etc.) but
 *              implementations can also gzip-encode the body, swap
 *              Content-Type, add timestamp headers, or anything else that
 *              must happen with full visibility into the rendered request.
 *
 *              Subscribers register an extension by:
 *                1. Implementing this interface in their own Apex class.
 *                2. Putting the class name into the
 *                   IntegrationProvider__mdt.SignerExtensionTxt__c field
 *                   (cross-namespace supported via "ns.ClassName" syntax).
 *
 *              The framework calls applyTo(request, payload, providerConfig)
 *              after the request body + headers are rendered but before the
 *              callout is sent. Implementations mutate the HttpRequest in
 *              place — typically setHeader('X-Signature', computed_hmac).
 *
 *              No edge cases ship in DH today. As subscribers (or Cloud
 *              Nimbus's own dh-prod) hit specific provider needs, the
 *              extension lives in their org/repo, not in DH.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
public interface IIntegrationTemplateExtension {

    /**
     * @description Mutate the HttpRequest before dispatch. Called once per
     *              callout, after body/headers are rendered. Throws to abort
     *              the dispatch (Dispatcher captures and surfaces as Terminal).
     * @param req The fully-rendered HttpRequest about to be sent.
     * @param payload The original dispatch payload (read-only · don't mutate).
     * @param providerConfig The IntegrationProvider__mdt row driving this dispatch.
     */
    void applyTo(HttpRequest req, Map<String, Object> payload, IntegrationProvider__mdt providerConfig);
}
