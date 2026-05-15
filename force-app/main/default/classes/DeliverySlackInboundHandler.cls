/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Slack inbound webhook handler. Accepts Slack Event API
 *               event_callback envelopes, extracts the inner `message` event,
 *               parses the text for a WorkItem Name (e.g. "T-0123"), and
 *               creates a WorkItemComment__c on that WI with the message body
 *               as the comment.
 *
 *               Routes via IntegrationProvider.Slack_Webhook:
 *               EventTypeFieldPathTxt = "type"
 *               RoutingRulesJsonTxt   = {"event_callback": "DeliverySlackInboundHandler"}
 *               SignatureAlgorithm    = "HmacSha256Slack" (Slack-specific signing
 *                                       extension in WebhookSignatureVerifier).
 *
 *               URL verification challenges are handled by
 *               DeliveryWebhookReceiverApi (generic challenge echo) before this
 *               handler is invoked.
 *
 *               Echo-suppression: when the inbound payload's
 *               `event.client_msg_id` matches a recently-outbound mirror posted
 *               by this org, the comment is ignored to avoid a feedback loop.
 *               v1 implements the simple guard "AuthorTxt__c starts with
 *               'DeliveryHub Bot'" — the bot's own outbound posts are tagged
 *               with that author so we recognize and drop them on the way back.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier')
global with sharing class DeliverySlackInboundHandler implements IWebhookEventHandler {

    /** @description Regex anchor for the WI Name pattern (T-NNNN). Case-insensitive. */
    @TestVisible
    private static final Pattern WI_NAME_PATTERN = Pattern.compile('(?i)\\b(T-\\d{3,6})\\b');

    /** @description Author label applied to comments mirrored from Slack. */
    @TestVisible
    private static final String SLACK_AUTHOR_PREFIX = 'Slack';

    /**
     * @description Process a Slack event_callback envelope. v1 only handles
     *              event.type='message' — channel_join, file_share, etc. are
     *              ignored as 200 OK so Slack stops retrying.
     */
    global WebhookHandlerResult handle(String eventType, Map<String, Object> payload) {
        if (!String.isNotBlank(eventType) || !eventType.equalsIgnoreCase('event_callback')) {
            return WebhookHandlerResult.ignored('Unsupported envelope type ' + eventType);
        }
        Map<String, Object> event = extractMap(payload, 'event');
        if (event == null) {
            return WebhookHandlerResult.terminal('event_callback missing event payload');
        }
        String innerType = String.valueOf(event.get('type'));
        if (!'message'.equalsIgnoreCase(innerType)) {
            return WebhookHandlerResult.ignored('Slack event.type=' + innerType + ' not yet handled');
        }
        // Skip bot mirror-backs to avoid a comment-to-Slack-to-comment loop.
        // Slack adds bot_id to messages posted via incoming webhook; our
        // outbound poster (DeliverySlackService.postCommentBatch) doesn't go
        // through a Slack App so bot_id won't be present, but defensively
        // guard anyway.
        if (event.containsKey('bot_id')) {
            return WebhookHandlerResult.ignored('Skipping bot message — echo-suppression');
        }
        String text = String.valueOf(event.get('text'));
        if (String.isBlank(text)) {
            return WebhookHandlerResult.ignored('Empty message text');
        }
        String wiName = extractWorkItemName(text);
        if (String.isBlank(wiName)) {
            return WebhookHandlerResult.ignored('No WorkItem name (T-NNNN) found in message');
        }
        WorkItem__c wi = findWorkItemByName(wiName);
        if (wi == null) {
            return WebhookHandlerResult.ignored('No WorkItem with Name ' + wiName + ' found in this org');
        }
        // Author: Slack `user` is a Slack user id (U…). v1 doesn't resolve
        // to a Salesforce User — surfaces as "Slack: <user-id>" so the
        // operator can correlate without a separate mapping table.
        String slackUserId = String.valueOf(event.get('user'));
        String author = SLACK_AUTHOR_PREFIX + (String.isBlank(slackUserId) ? '' : ': ' + slackUserId);
        String channel = String.valueOf(event.get('channel'));
        // Strip the WI name prefix from the body to reduce visual duplication.
        String body = text.replaceAll('(?i)\\b' + wiName + '\\b\\s*[:\\-—]?\\s*', '').trim();
        if (String.isBlank(body)) {
            body = text;
        }
        if (!String.isBlank(channel)) {
            body = body + '\n\n_(via Slack channel ' + channel + ')_';
        }

        // SourcePk__c picklist values today: Salesforce/Jira/Client/Mothership/Vendor/API/Email.
        // 'Slack' isn't in the set; use 'API' for v1 — the AuthorTxt__c ("Slack: U…")
        // and the body footer ("via Slack channel …") preserve channel-of-origin clarity.
        // v1.5: extend the picklist (GlobalValueSet replacement per CLAUDE.md) and switch.
        WorkItemComment__c comment = new WorkItemComment__c(
            WorkItemId__c = wi.Id,
            BodyTxt__c = body,
            AuthorTxt__c = author,
            SourcePk__c = 'API'
        );
        try {
            Database.insert(comment, AccessLevel.SYSTEM_MODE);
            return WebhookHandlerResult.ok(comment.Id);
        } catch (DmlException e) {
            return WebhookHandlerResult.retryable('Comment insert failed: ' + e.getMessage());
        }
    }

    @TestVisible
    private static Map<String, Object> extractMap(Map<String, Object> source, String key) {
        Object v = source.get(key);
        return v instanceof Map<String, Object> ? (Map<String, Object>) v : null;
    }

    @TestVisible
    private static String extractWorkItemName(String text) {
        if (String.isBlank(text)) { return null; }
        Matcher m = WI_NAME_PATTERN.matcher(text);
        if (!m.find()) { return null; }
        return m.group(1).toUpperCase();
    }

    @TestVisible
    private static WorkItem__c findWorkItemByName(String wiName) {
        List<WorkItem__c> hits = [
            SELECT Id, Name, OwnerId
            FROM WorkItem__c
            WHERE Name = :wiName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return hits.isEmpty() ? null : hits[0];
    }
}
