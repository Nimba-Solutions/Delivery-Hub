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
 *
 *               Internal structure: handle() is a thin dispatcher. Per-envelope
 *               and per-event-type branches live in private helpers
 *               (handleEventCallback / handleMessageEvent / isBotMessage /
 *               createCommentFromMessage) so each method's cyclomatic stays
 *               small and individual flow steps are independently readable
 *               and testable.
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
     * @description Process a Slack envelope. Acts as a thin dispatcher — the
     *              only branch is the envelope-type gate; everything else is
     *              delegated to per-event-type helpers. v1 only handles
     *              event.type='message' under an event_callback envelope; all
     *              other envelopes return 200 OK ignored so Slack stops
     *              retrying.
     * @param eventType The outer Slack envelope type (expects 'event_callback').
     * @param payload   The full Slack Event API payload as a parsed Map.
     * @return WebhookHandlerResult — ok with the inserted comment Id, ignored
     *         with a skip reason, terminal for malformed envelopes, or
     *         retryable when DML fails transiently.
     */
    global WebhookHandlerResult handle(String eventType, Map<String, Object> payload) {
        if (!isEventCallback(eventType)) {
            return WebhookHandlerResult.ignored('Unsupported envelope type ' + eventType);
        }
        return handleEventCallback(payload);
    }

    /**
     * @description Predicate: is the outer envelope an event_callback? Slack
     *              also sends url_verification on initial subscription setup,
     *              but that's intercepted earlier by DeliveryWebhookReceiverApi
     *              so this handler only ever sees event_callback envelopes in
     *              steady state.
     * @param eventType The outer envelope type from the routing dispatcher.
     * @return true when the envelope is event_callback (case-insensitive).
     */
    private static Boolean isEventCallback(String eventType) {
        return String.isNotBlank(eventType) && eventType.equalsIgnoreCase('event_callback');
    }

    /**
     * @description Handle a Slack event_callback envelope. Validates the inner
     *              event block exists, then delegates to handleMessageEvent for
     *              actual processing.
     * @param payload The full Slack Event API payload as a parsed Map.
     * @return terminal when the envelope is malformed, otherwise whatever
     *         handleMessageEvent returns.
     */
    private static WebhookHandlerResult handleEventCallback(Map<String, Object> payload) {
        Map<String, Object> event = extractMap(payload, 'event');
        if (event == null) {
            return WebhookHandlerResult.terminal('event_callback missing event payload');
        }
        return handleMessageEvent(event);
    }

    /**
     * @description Process the inner Slack message event. Rejects non-message
     *              inner types, bot echoes, and empty text up front, then
     *              delegates to createCommentFromMessage for the actual
     *              WI-name extraction + comment insert.
     * @param event The inner event map from the event_callback envelope.
     * @return ignored when the message should be skipped, otherwise whatever
     *         createCommentFromMessage returns.
     */
    private static WebhookHandlerResult handleMessageEvent(Map<String, Object> event) {
        String innerType = String.valueOf(event.get('type'));
        if (!'message'.equalsIgnoreCase(innerType)) {
            return WebhookHandlerResult.ignored('Slack event.type=' + innerType + ' not yet handled');
        }
        if (isBotMessage(event)) {
            return WebhookHandlerResult.ignored('Skipping bot message — echo-suppression');
        }
        String text = String.valueOf(event.get('text'));
        if (String.isBlank(text)) {
            return WebhookHandlerResult.ignored('Empty message text');
        }
        return createCommentFromMessage(event, text);
    }

    /**
     * @description Predicate: did this Slack message originate from a bot?
     *              Slack adds bot_id to messages posted via incoming webhook;
     *              our outbound poster doesn't go through a Slack App so bot_id
     *              normally won't be present, but defensively guard anyway so
     *              we don't loop on our own outbound mirrors when the
     *              transport changes.
     * @param event The inner Slack message event.
     * @return true when the message should be dropped as a bot echo.
     */
    private static Boolean isBotMessage(Map<String, Object> event) {
        return event.containsKey('bot_id');
    }

    /**
     * @description Extract the T-NNNN WorkItem name from the message text and
     *              create the mirrored WorkItemComment__c. Returns ignored
     *              when no T-NNNN match is found or the WI doesn't exist in
     *              this org.
     * @param event The inner Slack message event (used for author + channel).
     * @param text  The raw Slack message text (pre-validated non-blank).
     * @return ok with the inserted comment Id on success, ignored when no WI
     *         is found, retryable on transient DML failure.
     */
    private static WebhookHandlerResult createCommentFromMessage(Map<String, Object> event, String text) {
        String wiName = extractWorkItemName(text);
        if (String.isBlank(wiName)) {
            return WebhookHandlerResult.ignored('No WorkItem name (T-NNNN) found in message');
        }
        WorkItem__c wi = findWorkItemByName(wiName);
        if (wi == null) {
            return WebhookHandlerResult.ignored('No WorkItem with Name ' + wiName + ' found in this org');
        }
        return insertSlackComment(wi.Id, buildAuthor(event), buildBody(text, wiName, event));
    }

    /**
     * @description Build the comment AuthorTxt — Slack `user` is a Slack user id
     *              (U…). v1 doesn't resolve to a Salesforce User; surfaces as
     *              "Slack: <user-id>" so the operator can correlate without a
     *              separate mapping table.
     * @param event The inner Slack message event.
     * @return Author label, always prefixed with SLACK_AUTHOR_PREFIX so
     *         outbound mirror-skip in DeliverySlackService can match it.
     */
    private static String buildAuthor(Map<String, Object> event) {
        String slackUserId = String.valueOf(event.get('user'));
        return SLACK_AUTHOR_PREFIX + (String.isBlank(slackUserId) ? '' : ': ' + slackUserId);
    }

    /**
     * @description Strip the WI name prefix from the body to reduce visual
     *              duplication, then append a channel footer so the operator
     *              can see which Slack channel the comment came from.
     * @param text   The raw Slack message text.
     * @param wiName The matched WorkItem Name (T-NNNN) to strip from the body.
     * @param event  The inner event (for `channel` footer).
     * @return The cleaned-up comment body suitable for WorkItemComment.BodyTxt__c.
     */
    private static String buildBody(String text, String wiName, Map<String, Object> event) {
        String body = text.replaceAll('(?i)\\b' + wiName + '\\b\\s*[:\\-—]?\\s*', '').trim();
        if (String.isBlank(body)) {
            body = text;
        }
        String channel = String.valueOf(event.get('channel'));
        if (!String.isBlank(channel)) {
            body = body + '\n\n_(via Slack channel ' + channel + ')_';
        }
        return body;
    }

    /**
     * @description Insert the mirrored comment under SYSTEM_MODE. SourcePk__c
     *              picklist today: Salesforce/Jira/Client/Mothership/Vendor/API/Email.
     *              'Slack' isn't in the set; use 'API' for v1 — the AuthorTxt
     *              ("Slack: U…") and the body footer preserve channel-of-origin
     *              clarity. v1.5: extend the picklist (GlobalValueSet per
     *              CLAUDE.md) and switch.
     * @param workItemId Parent WorkItem Id resolved from the T-NNNN match.
     * @param author     Pre-built author label from buildAuthor().
     * @param body       Pre-built comment body from buildBody().
     * @return ok with the inserted comment Id, retryable when DML fails.
     */
    private static WebhookHandlerResult insertSlackComment(Id workItemId, String author, String body) {
        WorkItemComment__c comment = new WorkItemComment__c(
            WorkItemId__c = workItemId,
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

    /**
     * @description Safely extract a nested Map value by key, returning null
     *              when the key is missing or the value isn't a Map.
     * @param source The parent Map.
     * @param key    The key to look up.
     * @return The nested Map, or null when absent / wrong type.
     */
    @TestVisible
    private static Map<String, Object> extractMap(Map<String, Object> source, String key) {
        Object v = source.get(key);
        return v instanceof Map<String, Object> ? (Map<String, Object>) v : null;
    }

    /**
     * @description Find the first T-NNNN WorkItem Name match in the message
     *              text. Returns the uppercase form for downstream lookups.
     * @param text The raw Slack message text.
     * @return Uppercase T-NNNN string, or null when no match is found.
     */
    @TestVisible
    private static String extractWorkItemName(String text) {
        if (String.isBlank(text)) { return null; }
        Matcher m = WI_NAME_PATTERN.matcher(text);
        if (!m.find()) { return null; }
        return m.group(1).toUpperCase();
    }

    /**
     * @description Resolve a WorkItem__c by Name. Returns null when no record
     *              with the given Name exists in this org (e.g. the T-NNNN
     *              was typed in Slack but the WI lives only on another org in
     *              the daisy chain).
     * @param wiName The exact Name to look up (case-sensitive in SOQL).
     * @return The matching WorkItem__c (Id, Name, OwnerId), or null when not found.
     */
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
