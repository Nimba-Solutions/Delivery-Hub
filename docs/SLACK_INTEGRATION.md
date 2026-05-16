# Slack Comment Sync

Two-way bridge between WorkItemComment__c records and a Slack channel. Operator opts in per org via `DeliveryHubSettings__c.EnableSlackCommentSyncDateTime__c`. Default off.

## What it does

- **Outbound** — every new `WorkItemComment__c` insert is fanned out to the configured Slack channel via incoming webhook. Each callout posts a single batched Block Kit message containing all comments from the same transaction (WI Name → record link → author → body).
- **Inbound** — Slack messages that mention a WorkItem Name (e.g. `T-0123`) are mirrored back as comments on that WI. AuthorTxt is tagged `Slack: <user-id>`, SourcePk is `API`, and the body carries a footer `(via Slack channel C…)` so operators can trace the source.

## Loop prevention

The inbound handler tags every mirrored comment with `AuthorTxt__c = "Slack: …"`. The outbound trigger handler (`DeliveryWorkItemCommentTriggerHandler.postCommentsToSlack`) skips any comment whose author starts with `"Slack"`. That single discriminator breaks the inbound → outbound → inbound loop without a recursion guard or de-dup table.

## Setup

### 1. Create a Slack app

In Slack:
1. Go to https://api.slack.com/apps → **Create New App** → **From Scratch**
2. Name it (e.g. "Delivery Hub Sync"), pick the workspace.
3. Under **Incoming Webhooks**: enable, **Add New Webhook to Workspace**, pick the channel. Copy the webhook URL.
4. Under **Event Subscriptions**: enable. **Request URL** = your Salesforce Site URL + `/services/apexrest/deliveryhub/v1/webhook/Slack_Webhook` (see step 3 for Site setup). Save — Slack will POST a URL-verification challenge, which the generic challenge-echo path in `DeliveryWebhookReceiverApi` handles automatically. Once verified, **Subscribe to bot events** → add `message.channels` (or `message.groups` for private channels).
5. **OAuth & Permissions** → install to workspace, copy the signing secret from **Basic Information** → App Credentials.

### 2. Configure Salesforce

```apex
DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
s.SlackWebhookUrlTxt__c = 'https://hooks.slack.com/services/...';   // outbound
s.EnableSlackCommentSyncDateTime__c = DateTime.now();                // opt in
update s;
```

Then update the inbound provider's signing secret. Custom Metadata can't be updated via Apex once packaged, so on a subscriber org use **Setup → Custom Metadata Types → Integration Provider → Manage Records → Slack Webhook → Edit** and paste the signing secret into `Signature Secret`. Set `Enabled DateTime` to a non-null value to activate the inbound route.

### 3. Expose the inbound endpoint

The `@RestResource` URL `/services/apexrest/deliveryhub/v1/webhook/Slack_Webhook` only resolves from outside the org when exposed via a Salesforce Site:

1. **Setup → Sites → New Site** (or reuse the one already serving the public Delivery Hub API)
2. **Public Access Settings** → grant the Site Guest User Apex class access to `DeliveryWebhookReceiverApi` and read access to `IntegrationProvider__mdt`
3. The full Slack-facing URL is `<your-site-url>/services/apexrest/deliveryhub/v1/webhook/Slack_Webhook` — paste this into the Slack app's Event Subscriptions Request URL field

### 4. Test outbound

Insert a `WorkItemComment__c` and watch your Slack channel:

```apex
insert new WorkItemComment__c(
    WorkItemId__c = '<a real WI Id>',
    BodyTxt__c = 'Outbound sync smoke test',
    AuthorTxt__c = UserInfo.getName()
);
```

### 5. Test inbound

Post in the Slack channel where the app is installed:

```
T-0123 - quick test from Slack
```

A `WorkItemComment__c` should land on T-0123 within ~5s.

## Security

- **HMAC-SHA256 signature verification** on every inbound request, using Slack's `v0:<timestamp>:<body>` signing base. Implemented in `WebhookSignatureVerifier.verifySlack`. Replay protection: timestamps older than 5 minutes are rejected.
- **No bot-user auth needed** for inbound — Slack signs each event with the signing secret, no per-user token.
- **Outbound** uses Slack incoming webhooks (long-lived URL credential, scope-locked to one channel). Rotate the URL in Slack if compromised; paste the new URL into `SlackWebhookUrlTxt__c`.

## Known limits (v1)

- **Single channel per org.** All outbound comments go to the channel bound to `SlackWebhookUrlTxt__c`. Per-WorkItem or per-NetworkEntity channel routing is on the v1.5 roadmap.
- **WorkItem lookup is by Name only** (`T-NNNN` pattern). Slack thread routing and `<https://...|T-0123>` linkbacks are v1.5.
- **No Slack-User → Salesforce-User mapping.** Inbound author tags as `Slack: <user-id>`. v1.5 will support a `SlackUserMapping__mdt` lookup.
- **No reaction → status sync.** Adding a reaction in Slack does not flip a WI stage. Future feature.
- **Outbound payload includes the record-page URL.** Subscriber-org users without WI read permission will hit Login on click — handle via your existing permission set assignments.

## Disabling

```apex
DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
s.EnableSlackCommentSyncDateTime__c = null;   // outbound off
update s;
```

For inbound, set the IntegrationProvider record's `EnabledDateTime__c` to null in **Setup → Custom Metadata Types → Integration Provider → Slack Webhook**.

## Files

- `classes/DeliverySlackService.cls` — outbound poster (`postCommentBatch`)
- `classes/DeliverySlackInboundHandler.cls` — inbound `IWebhookEventHandler`
- `classes/DeliveryWorkItemCommentTriggerHandler.cls` — trigger hook
- `classes/WebhookSignatureVerifier.cls` — Slack signing extension (`verifySlack`)
- `classes/DeliveryWebhookReceiverApi.cls` — generic challenge echo (URL verification)
- `customMetadata/IntegrationProvider.Slack_Webhook.md-meta.xml` — inbound config
- `objects/DeliveryHubSettings__c/fields/EnableSlackCommentSyncDateTime__c.field-meta.xml` — opt-in flag
- `objects/WorkItemComment__c/fields/SourcePk__c.field-meta.xml` — currently uses `'API'` for Slack-origin comments; extend with `'Slack'` value in v1.5 when migrating to GlobalValueSet

## Reference

- Slack Events API: https://api.slack.com/apis/connections/events-api
- Slack signing secrets: https://api.slack.com/authentication/verifying-requests-from-slack
- Slack Block Kit: https://api.slack.com/block-kit
