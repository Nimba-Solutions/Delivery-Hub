/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Self-assessment / health-check engine for Delivery Hub.
 *               Returns a list of HealthCheckResult records that the
 *               deliveryHubHealthDashboard LWC renders as cards. Generic
 *               replacement for the org-specific scratch-verify scripts.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.ApexSharingViolations,PMD.ApexDoc')
public with sharing class DeliveryHubHealthService {

    private static final Integer STALE_FAILED_DAYS = 7;
    private static final Integer ENDPOINT_REACHABILITY_LIMIT = 5;

    /**
     * @description Run every check and return their results in a stable order.
     *              Errors in any single check do not abort the run — the
     *              failing check returns a fail result with the exception
     *              message as detail.
     * @return Ordered list of HealthCheckResult.
     */
    @AuraEnabled
    public static List<DeliveryHubHealthCheckResult> runAllChecks() {
        List<DeliveryHubHealthCheckResult> out = new List<DeliveryHubHealthCheckResult>();
        out.add(safe('scheduledJobs', 'Scheduled Sync Jobs', new ScheduledJobsCheck()));
        out.add(safe('staleFailedSyncs', 'Stale Failed Syncs', new StaleFailedSyncsCheck()));
        out.add(safe('orphanedWorkItems', 'Orphaned Work Items', new OrphanedWorkItemsCheck()));
        out.add(safe('permSetCoverage', 'Permission Set Coverage', new PermSetCoverageCheck()));
        out.add(safe('endpointReachability', 'NetworkEntity Endpoints', new EndpointReachabilityCheck()));
        out.add(safe('apiKeyConfigured', 'API Key Configured', new ApiKeyCheck()));
        out.add(safe('customSettings', 'Custom Settings', new CustomSettingsCheck()));
        out.add(safe('mothershipHandshake', 'Mothership Handshake', new MothershipCheck()));
        out.add(safe('inboundWebhookProviders', 'Inbound Webhook Providers', new InboundWebhookCheck()));
        out.add(safe('sortOrderHealth', 'SortOrder Integrity', new SortOrderCheck()));
        return out;
    }

    /**
     * @description Wrapper that catches per-check exceptions so a single bug
     *              never aborts the entire dashboard load.
     * @param checkKey Stable identifier.
     * @param label Human-readable card title.
     * @param check The check implementation.
     * @return The check's result, or a fail card on uncaught exception.
     */
    @TestVisible
    private static DeliveryHubHealthCheckResult safe(String checkKey, String label, IHealthCheck check) {
        try {
            return check.run(checkKey, label);
        } catch (Exception e) {
            return DeliveryHubHealthCheckResult.fail(
                checkKey, label,
                e.getTypeName() + ': ' + e.getMessage(),
                null);
        }
    }

    /**
     * @description Contract for individual check implementations. One per
     *              category, each returning a single HealthCheckResult.
     */
    public interface IHealthCheck {
        DeliveryHubHealthCheckResult run(String checkKey, String label);
    }

    // ── Individual checks ─────────────────────────────────────────────────

    public class ScheduledJobsCheck implements IHealthCheck {
        public DeliveryHubHealthCheckResult run(String key, String label) {
            Integer count = [
                SELECT COUNT() FROM CronTrigger
                WHERE CronJobDetail.Name LIKE 'Delivery Hub Sync%'
            ];
            if (count >= 4) {
                return DeliveryHubHealthCheckResult.pass(key, label,
                    count + ' cron slots scheduled.');
            }
            if (count == 0) {
                return DeliveryHubHealthCheckResult.fail(key, label,
                    'No Delivery Hub Sync jobs scheduled. Tenant is dead until repaired.',
                    'scheduleAll');
            }
            return DeliveryHubHealthCheckResult.warn(key, label,
                'Only ' + count + ' of 4 cron slots scheduled.', 'scheduleAll');
        }
    }

    public class StaleFailedSyncsCheck implements IHealthCheck {
        public DeliveryHubHealthCheckResult run(String key, String label) {
            Datetime cutoff = Datetime.now().addDays(-STALE_FAILED_DAYS);
            Integer count = [
                SELECT COUNT() FROM SyncItem__c
                WHERE StatusPk__c = 'Failed' AND CreatedDate < :cutoff
                WITH SYSTEM_MODE
            ];
            if (count == 0) {
                return DeliveryHubHealthCheckResult.pass(key, label,
                    'No SyncItem__c rows have been Failed for over ' + STALE_FAILED_DAYS + ' days.');
            }
            return DeliveryHubHealthCheckResult.warn(key, label,
                count + ' SyncItem__c rows have been Failed for over ' + STALE_FAILED_DAYS + ' days.',
                'requeueFailedSyncs');
        }
    }

    public class OrphanedWorkItemsCheck implements IHealthCheck {
        public DeliveryHubHealthCheckResult run(String key, String label) {
            // Surface Failed SyncItems with retry exhaustion — the canonical
            // signal from the scratch-verify hotfix scripts that something
            // upstream is stuck (often parent FK, but generally any retryable
            // error that won't auto-clear).
            Integer count = [
                SELECT COUNT() FROM SyncItem__c
                WHERE StatusPk__c = 'Failed' AND RetryCountNumber__c >= 3
                WITH SYSTEM_MODE
                LIMIT 1001
            ];
            if (count == 0) {
                return DeliveryHubHealthCheckResult.pass(key, label,
                    'No Failed SyncItems with exhausted retries.');
            }
            String suffix = count > 1000 ? '1000+' : String.valueOf(count);
            return DeliveryHubHealthCheckResult.warn(key, label,
                suffix + ' Failed SyncItems have exhausted retries. Inspect ErrorLogTxt__c then requeue.',
                'requeueFailedSyncs');
        }
    }

    public class PermSetCoverageCheck implements IHealthCheck {
        public DeliveryHubHealthCheckResult run(String key, String label) {
            Integer rules = [
                SELECT COUNT() FROM UserAutoAssignConfig__mdt
                WHERE EnabledDateTime__c != null
            ];
            if (rules == 0) {
                return DeliveryHubHealthCheckResult.warn(key, label,
                    'No UserAutoAssignConfig__mdt rules enabled — new users will not get DH access automatically.',
                    null);
            }
            DeliveryHubHealthCheckResult result = DeliveryHubHealthCheckResult.pass(
                key, label,
                rules + ' auto-assign rule(s) enabled. Run the repair to backfill existing users.');
            return result.withRepair('backfillPermSets');
        }
    }

    public class EndpointReachabilityCheck implements IHealthCheck {
        public DeliveryHubHealthCheckResult run(String key, String label) {
            List<NetworkEntity__c> entities = [
                SELECT Id, Name, IntegrationEndpointUrlTxt__c
                FROM NetworkEntity__c
                WHERE StatusPk__c = 'Active'
                AND IntegrationEndpointUrlTxt__c != null
                WITH SYSTEM_MODE
                LIMIT :ENDPOINT_REACHABILITY_LIMIT
            ];
            if (entities.isEmpty()) {
                return DeliveryHubHealthCheckResult.pass(key, label,
                    'No active NetworkEntity rows with endpoints to probe.');
            }
            return DeliveryHubHealthCheckResult.pass(key, label,
                'Found ' + entities.size() + ' active NetworkEntity row(s) with endpoints. ' +
                'Use the manual handshake button on each record to verify reachability.');
        }
    }

    public class ApiKeyCheck implements IHealthCheck {
        public DeliveryHubHealthCheckResult run(String key, String label) {
            Integer total = [
                SELECT COUNT() FROM NetworkEntity__c
                WHERE StatusPk__c = 'Active' AND IntegrationEndpointUrlTxt__c != null
                WITH SYSTEM_MODE
            ];
            Integer keyed = [
                SELECT COUNT() FROM NetworkEntity__c
                WHERE StatusPk__c = 'Active'
                AND IntegrationEndpointUrlTxt__c != null
                AND ApiKeyTxt__c != null
                WITH SYSTEM_MODE
            ];
            if (total == 0) {
                return DeliveryHubHealthCheckResult.pass(key, label,
                    'No active NetworkEntity rows configured for sync.');
            }
            Integer missing = total - keyed;
            if (missing == 0) {
                return DeliveryHubHealthCheckResult.pass(key, label,
                    'All ' + total + ' active sync entities have an API key.');
            }
            return DeliveryHubHealthCheckResult.warn(key, label,
                missing + ' active sync entit(ies) have no API key configured.', null);
        }
    }

    public class CustomSettingsCheck implements IHealthCheck {
        public DeliveryHubHealthCheckResult run(String key, String label) {
            DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
            if (s.Id == null) {
                return DeliveryHubHealthCheckResult.fail(key, label,
                    'DeliveryHubSettings__c org defaults missing — install handler did not run or was rolled back.',
                    null);
            }
            if (s.EnableNotificationsDateTime__c == null) {
                return DeliveryHubHealthCheckResult.warn(key, label,
                    'EnableNotificationsDateTime__c is null — notifications disabled.', null);
            }
            return DeliveryHubHealthCheckResult.pass(key, label,
                'Org settings present and notifications enabled.');
        }
    }

    public class MothershipCheck implements IHealthCheck {
        public DeliveryHubHealthCheckResult run(String key, String label) {
            CloudNimbusGlobalSettings__mdt cfg = CloudNimbusGlobalSettings__mdt.getInstance('Default');
            if (cfg == null || String.isBlank(cfg.EndpointUrlTxt__c)) {
                return DeliveryHubHealthCheckResult.warn(key, label,
                    'CloudNimbusGlobalSettings__mdt.Default.EndpointUrlTxt__c not configured.', null);
            }
            return DeliveryHubHealthCheckResult.pass(key, label,
                'Mothership endpoint configured: ' + cfg.EndpointUrlTxt__c);
        }
    }

    public class InboundWebhookCheck implements IHealthCheck {
        public DeliveryHubHealthCheckResult run(String key, String label) {
            List<IntegrationProvider__mdt> inbound = [
                SELECT DeveloperName, EnabledDateTime__c, SignatureSecretTxt__c, RoutingRulesJsonTxt__c
                FROM IntegrationProvider__mdt
                WHERE DirectionTxt__c = 'Inbound'
            ];
            if (inbound.isEmpty()) {
                return DeliveryHubHealthCheckResult.pass(key, label,
                    'No inbound webhook providers configured (Stripe, etc.).');
            }
            Integer disabled = 0;
            Integer secretMissing = 0;
            Integer rulesMissing = 0;
            for (IntegrationProvider__mdt p : inbound) {
                if (p.EnabledDateTime__c == null) { disabled++; }
                if (String.isBlank(p.SignatureSecretTxt__c)) { secretMissing++; }
                if (String.isBlank(p.RoutingRulesJsonTxt__c)) { rulesMissing++; }
            }
            if (disabled + secretMissing + rulesMissing == 0) {
                return DeliveryHubHealthCheckResult.pass(key, label,
                    inbound.size() + ' inbound webhook provider(s) ready.');
            }
            return DeliveryHubHealthCheckResult.warn(key, label,
                inbound.size() + ' inbound provider(s); ' + disabled + ' disabled, '
                + secretMissing + ' missing secret, ' + rulesMissing + ' missing routing rules.',
                null);
        }
    }

    public class SortOrderCheck implements IHealthCheck {
        public DeliveryHubHealthCheckResult run(String key, String label) {
            Integer negativeOrders = [
                SELECT COUNT() FROM WorkItem__c
                WHERE SortOrderNumber__c < 0
                WITH SYSTEM_MODE
            ];
            if (negativeOrders == 0) {
                return DeliveryHubHealthCheckResult.pass(key, label,
                    'No WorkItems with negative SortOrderNumber__c.');
            }
            return DeliveryHubHealthCheckResult.warn(key, label,
                negativeOrders + ' WorkItem(s) have negative SortOrderNumber__c — reorder drift detected.',
                null);
        }
    }
}
