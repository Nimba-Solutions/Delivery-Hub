/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Posts stage-change and test notifications to Slack via Incoming Webhooks.
 *              Stage-change messages are sent asynchronously (@future) from trigger context.
 *              The test-connection method runs synchronously from an LWC user action.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
global with sharing class DeliverySlackService {

    // ── Public API ───────────────────────────────────────────────────────────

    /**
     * @description Asynchronously posts a stage-change notification to Slack.
     *              Reads the webhook URL from org-default Custom Settings.
     *              No-ops silently if Slack is not configured.
     * @param workItemNameToStage Map of Work Item Name → new stage label
     */
    @future(callout=true)
    public static void postStageChanges(Map<String, String> workItemNameToStage) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.SlackWebhookUrlTxt__c)) {
            return;
        }
        post(settings.SlackWebhookUrlTxt__c, buildStagePayload(workItemNameToStage));
    }

    /**
     * @description Asynchronously posts a rich approval-request message to Slack with
     *              a deep link back to the work item in Salesforce.
     *              No-ops silently if Slack is not configured.
     *              Accepts a JSON string with keys: workItemId, workItemName, workItemTitle, newStage.
     * @param approvalContextJson JSON containing work item approval context
     */
    @future(callout=true)
    public static void postApprovalRequest(String approvalContextJson) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.SlackWebhookUrlTxt__c)) {
            return;
        }
        Map<String, String> ctx = (Map<String, String>) JSON.deserialize(approvalContextJson, Map<String, String>.class);
        post(settings.SlackWebhookUrlTxt__c, buildApprovalPayload(ctx));
    }

    /**
     * @description Asynchronously posts a connection-approval notification to Slack
     *              when a new NetworkEntity arrives with Pending Approval status.
     *              Accepts a JSON string with keys: entityName, recordUrl.
     * @param approvalContextJson JSON containing connection approval context
     */
    @future(callout=true)
    public static void postConnectionApprovalRequest(String approvalContextJson) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.SlackWebhookUrlTxt__c)) {
            return;
        }
        Map<String, String> ctx = (Map<String, String>) JSON.deserialize(approvalContextJson, Map<String, String>.class);
        post(settings.SlackWebhookUrlTxt__c, buildConnectionApprovalPayload(ctx));
    }

    /**
     * @description Posts a batch of newly-inserted WorkItemComment__c records to
     *              the configured Slack channel. Called from
     *              DeliveryWorkItemCommentTriggerHandler.handleAfterInsert when
     *              EnableSlackCommentSyncDateTime__c is set on org defaults.
     *
     *              Pure-callout, @future so the trigger isn't blocked on the
     *              HTTP roundtrip. Re-queries the comments by Id (you can't pass
     *              SObjects to @future) and joins the parent WI Name for the
     *              channel-visible header line.
     * @param commentIds Set of WorkItemComment__c Ids inserted in the same tx
     */
    @future(callout=true)
    public static void postCommentBatch(Set<Id> commentIds) {
        if (commentIds == null || commentIds.isEmpty()) {
            return;
        }
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (!isCommentSyncEnabled(settings)) {
            return;
        }
        List<WorkItemComment__c> outbound = filterOutboundComments(queryCommentBatch(commentIds));
        if (outbound.isEmpty()) {
            return;
        }
        post(settings.SlackWebhookUrlTxt__c, buildCommentBatchPayload(outbound));
    }

    /**
     * @description Three-way gate: comment-sync feature opted in AND webhook URL configured.
     * @param settings Org-default DeliveryHubSettings__c row (may be null).
     * @return true when postCommentBatch should proceed to the callout.
     */
    private static Boolean isCommentSyncEnabled(DeliveryHubSettings__c settings) {
        return settings != null
            && settings.EnableSlackCommentSyncDateTime__c != null
            && String.isNotBlank(settings.SlackWebhookUrlTxt__c);
    }

    /**
     * @description Re-query the batched comments with parent WI Name + BriefDescription
     *              for channel rendering. @future can't accept SObjects so we requery by Id.
     * @param commentIds Ids of comments inserted in the originating transaction.
     * @return Hydrated comment rows; empty list when nothing matches.
     */
    private static List<WorkItemComment__c> queryCommentBatch(Set<Id> commentIds) {
        return [
            SELECT Id, BodyTxt__c, AuthorTxt__c, SourcePk__c,
                   WorkItemId__r.Name, WorkItemId__r.BriefDescriptionTxt__c, WorkItemId__c
            FROM WorkItemComment__c
            WHERE Id IN :commentIds
            WITH SYSTEM_MODE
            LIMIT 200
        ];
    }

    /**
     * @description Drop mirrors-from-Slack to avoid the comment-back-to-Slack loop.
     *              DeliverySlackInboundHandler tags inbound mirrors with AuthorTxt__c
     *              starting "Slack" — filter those out before posting back.
     * @param rows Hydrated comment rows from queryCommentBatch.
     * @return Comments that did NOT originate from Slack.
     */
    private static List<WorkItemComment__c> filterOutboundComments(List<WorkItemComment__c> rows) {
        List<WorkItemComment__c> outbound = new List<WorkItemComment__c>();
        for (WorkItemComment__c c : rows) {
            if (c.AuthorTxt__c != null && c.AuthorTxt__c.startsWithIgnoreCase('Slack')) {
                continue;
            }
            outbound.add(c);
        }
        return outbound;
    }

    /**
     * @description Asynchronously posts the Watcher v1 daily digest to Slack.
     *              Reuses the SlackWebhookUrlTxt__c webhook. Payload is the
     *              JSON-serialised Block Kit map produced by
     *              DeliveryWatcherDigestFormatter.buildBlockKit — pre-injected
     *              with `channel` when WatcherDigestSlackChannelTxt__c is set
     *              on org defaults. No-ops silently when Slack isn't
     *              configured (mirrors postStageChanges).
     * @param payloadJson Pre-serialised Block Kit JSON.
     */
    @future(callout=true)
    public static void postWatcherDigest(String payloadJson) {
        if (String.isBlank(payloadJson)) {
            return;
        }
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.SlackWebhookUrlTxt__c)) {
            return;
        }
        post(settings.SlackWebhookUrlTxt__c, payloadJson);
    }

    /**
     * @description Tests the provided Slack webhook by posting a confirmation message.
     *              Called directly from the settings LWC via user action (no DML context).
     * @param webhookUrl The Slack Incoming Webhook URL to test
     * @return String 'Success' on 200, otherwise an error description
     */
    @AuraEnabled
    global static String testWebhook(String webhookUrl) {
        if (String.isBlank(webhookUrl)) {
            throw new AuraHandledException('Please enter a Slack Webhook URL first.');
        }
        String payload = JSON.serialize(new Map<String, Object>{
            'text' => ':white_check_mark: *Delivery Hub* is now connected to this Slack channel.'
        });
        HttpResponse res = post(webhookUrl, payload);
        if (res != null && res.getStatusCode() == 200) {
            return 'Success';
        }
        Integer code = res != null ? res.getStatusCode() : 0;
        return 'Failed (' + code + '): check your webhook URL and try again.';
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    /**
     * @description Sends a JSON payload to the given Slack Incoming Webhook URL.
     * @param url  The Slack webhook endpoint
     * @param body The serialised JSON payload
     * @return HttpResponse or null if the callout threw
     */
    private static HttpResponse post(String url, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);
        req.setTimeout(10000);
        try {
            return new Http().send(req);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, '[DeliverySlackService] callout failed: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Builds a Slack Block Kit payload listing work item stage changes.
     * @param workItemNameToStage Map of work item Name → new stage
     * @return Serialised JSON string
     */
    private static String buildStagePayload(Map<String, String> workItemNameToStage) {
        List<String> lines = new List<String>();
        for (String name : workItemNameToStage.keySet()) {
            lines.add('\u2022 *' + name + '* \u2192 `' + workItemNameToStage.get(name) + '`');
        }
        String text = ':arrows_counterclockwise: *Work Item Stage Update*\n' + String.join(lines, '\n');
        return JSON.serialize(new Map<String, Object>{
            'blocks' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => text
                    }
                }
            }
        });
    }

    /**
     * @description Builds a rich Slack Block Kit payload for client-action stages
     *              with a deep link button back to the work item in Salesforce.
     * @param ctx Map with keys: workItemId, workItemName, workItemTitle, newStage
     * @return Serialised JSON string
     */
    private static String buildApprovalPayload(Map<String, String> ctx) {
        String workItemId = ctx.get('workItemId');
        String workItemName = ctx.get('workItemName');
        String workItemTitle = ctx.get('workItemTitle');
        String newStage = ctx.get('newStage');

        String orgUrl = Url.getOrgDomainUrl().toExternalForm();
        String recordUrl = orgUrl + '/lightning/r/WorkItem__c/' + workItemId + '/view';
        String title = String.isNotBlank(workItemTitle) ? workItemTitle : 'Work Item';

        String headerText = ':bell: *Action Required: ' + workItemName + '*';
        String bodyText = '*' + title + '*\nThis work item has moved to `' + newStage
            + '` and needs your review.\nPlease open it in Salesforce to approve, reject, or provide feedback.';

        List<Object> blocks = new List<Object>{
            new Map<String, Object>{
                'type' => 'header',
                'text' => new Map<String, Object>{
                    'type' => 'plain_text',
                    'text' => 'Action Required: ' + workItemName
                }
            },
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => bodyText
                }
            },
            new Map<String, Object>{
                'type' => 'actions',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'Open in Salesforce'
                        },
                        'url' => recordUrl,
                        'style' => 'primary'
                    }
                }
            },
            new Map<String, Object>{
                'type' => 'context',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => ':clock3: Moved at ' + Datetime.now().format('MMM d, h:mm a')
                    }
                }
            }
        };

        return JSON.serialize(new Map<String, Object>{
            'text' => headerText,
            'blocks' => blocks
        });
    }

    /**
     * @description Builds a Slack Block Kit payload that renders a batch of new
     *              WorkItem comments — one section per comment with the WI Name,
     *              author, and body. Channel members see all comments from this
     *              transaction in one message instead of fan-out.
     * @param comments WorkItemComment__c rows with WorkItemId__r.Name resolved
     * @return Serialised JSON string
     */
    private static String buildCommentBatchPayload(List<WorkItemComment__c> comments) {
        String orgUrl = Url.getOrgDomainUrl().toExternalForm();
        List<Object> blocks = new List<Object>();
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => ':speech_balloon: *' + comments.size() + ' new comment'
                    + (comments.size() == 1 ? '' : 's') + ' on Delivery Hub work items*'
            }
        });
        for (WorkItemComment__c c : comments) {
            String wiName = c.WorkItemId__r != null ? c.WorkItemId__r.Name : 'WorkItem';
            String wiTitle = c.WorkItemId__r != null && String.isNotBlank(c.WorkItemId__r.BriefDescriptionTxt__c)
                ? c.WorkItemId__r.BriefDescriptionTxt__c : wiName;
            String author = String.isNotBlank(c.AuthorTxt__c) ? c.AuthorTxt__c : 'Unknown';
            String body = c.BodyTxt__c == null ? '' : c.BodyTxt__c;
            String recordUrl = orgUrl + '/lightning/r/WorkItemComment__c/' + c.Id + '/view';
            String line = '*<' + recordUrl + '|' + wiName + '>* — ' + wiTitle
                + '\n_' + author + '_: ' + body;
            blocks.add(new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => line
                }
            });
        }
        return JSON.serialize(new Map<String, Object>{
            'blocks' => blocks
        });
    }

    /**
     * @description Builds a Slack Block Kit payload for a new pending connection request.
     * @param ctx Map with keys: entityName, recordUrl
     * @return Serialised JSON string
     */
    private static String buildConnectionApprovalPayload(Map<String, String> ctx) {
        String entityName = ctx.get('entityName');
        String recordUrl = ctx.get('recordUrl');

        String headerText = ':bell: *New Connection Request: ' + entityName + '*';
        String bodyText = '*' + entityName + '* has requested a connection to your Delivery Hub.'
            + '\nThe connection is currently *Pending Approval*. Please review and approve or reject in Salesforce.';

        List<Object> blocks = new List<Object>{
            new Map<String, Object>{
                'type' => 'header',
                'text' => new Map<String, Object>{
                    'type' => 'plain_text',
                    'text' => 'New Connection Request'
                }
            },
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => bodyText
                }
            },
            new Map<String, Object>{
                'type' => 'actions',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'Review in Salesforce'
                        },
                        'url' => recordUrl,
                        'style' => 'primary'
                    }
                }
            },
            new Map<String, Object>{
                'type' => 'context',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => ':clock3: Received at ' + Datetime.now().format('MMM d, h:mm a')
                    }
                }
            }
        };

        return JSON.serialize(new Map<String, Object>{
            'text' => headerText,
            'blocks' => blocks
        });
    }
}
