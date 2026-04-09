/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the configurable Executive Dashboard framework.
 *               Reads DashboardCard__mdt records and resolves data for each card.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
global with sharing class DeliveryDashboardCardController {

    @AuraEnabled(cacheable=true)
    public static List<CardConfig> getCardsForPage(String pageKey) {
        String currentProfile = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() WITH SYSTEM_MODE].Profile.Name;
        List<CardConfig> cards = new List<CardConfig>();
        for (DashboardCard__mdt card : [
            SELECT DeveloperName, TitleTxt__c, DescriptionTxt__c, CardTypePk__c,
                   IconNameTxt__c, DataSourceTxt__c, FilterJsonTxt__c,
                   SortOrderNumber__c, CardSizeTxt__c, VisibleToProfilesTxt__c,
                   ThresholdWarningNumber__c, ThresholdCriticalNumber__c
            FROM DashboardCard__mdt
            WHERE PageKeyTxt__c = :pageKey
            AND EnabledDateTime__c != NULL
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC
        ]) {
            if (String.isNotBlank(card.VisibleToProfilesTxt__c)
                && !card.VisibleToProfilesTxt__c.containsIgnoreCase(currentProfile)) {
                continue;
            }
            cards.add(mapConfig(card));
        }
        return cards;
    }

    @AuraEnabled
    public static Object getCardData(String dataSource, String filterJson) {
        switch on dataSource {
            when 'activeWorkItems' {
                return [
                    SELECT COUNT() FROM WorkItem__c
                    WHERE ActivatedDateTime__c != NULL
                    AND ArchivedDateTime__c = NULL
                    AND TemplateMarkedDateTime__c = NULL
                    WITH SYSTEM_MODE
                ];
            }
            when 'blockedItems' {
                return [
                    SELECT COUNT() FROM WorkItem__c
                    WHERE StageNamePk__c LIKE '%Blocked%'
                    AND ActivatedDateTime__c != NULL
                    AND ArchivedDateTime__c = NULL
                    AND TemplateMarkedDateTime__c = NULL
                    WITH SYSTEM_MODE
                ];
            }
            when 'hoursThisMonth' {
                Date monthStart = Date.today().toStartOfMonth();
                AggregateResult[] results = [
                    SELECT SUM(HoursLoggedNumber__c) total
                    FROM WorkLog__c
                    WHERE CreatedDate >= :monthStart
                    WITH SYSTEM_MODE
                ];
                return results.isEmpty() || results[0].get('total') == null ? 0 : results[0].get('total');
            }
            when 'completedThisWeek' {
                Date weekStart = Date.today().toStartOfWeek();
                return [
                    SELECT COUNT() FROM WorkItem__c
                    WHERE StageNamePk__c = 'Done'
                    AND LastModifiedDate >= :weekStart
                    AND TemplateMarkedDateTime__c = NULL
                    WITH SYSTEM_MODE
                ];
            }
            when 'overdueItems' {
                // Use EstimatedEndDevDate__c, the date users actually populate during scoping.
                // CalculatedETADate__c is never auto-computed by any service — its only writers
                // are the demo seeder and rare manual entry — so it produced misleading counts.
                // Also exclude terminal stages so a Done item with a stale date doesn't count.
                return [
                    SELECT COUNT()
                    FROM WorkItem__c
                    WHERE EstimatedEndDevDate__c < :Date.today()
                    AND ActivatedDateTime__c != NULL
                    AND ArchivedDateTime__c = NULL
                    AND StageNamePk__c NOT IN ('Done', 'Cancelled', 'Closed', 'Rejected')
                    WITH SYSTEM_MODE
                ];
            }
            when 'workItemsByPriority' {
                List<Map<String, Object>> data = new List<Map<String, Object>>();
                for (AggregateResult ar : [
                    SELECT PriorityPk__c label, COUNT(Id) cnt
                    FROM WorkItem__c
                    WHERE ActivatedDateTime__c != NULL
                    AND ArchivedDateTime__c = NULL
                    AND TemplateMarkedDateTime__c = NULL
                    WITH SYSTEM_MODE
                    GROUP BY PriorityPk__c
                    ORDER BY COUNT(Id) DESC
                ]) {
                    data.add(new Map<String, Object>{
                        'label' => ar.get('label'),
                        'value' => ar.get('cnt')
                    });
                }
                return data;
            }
            when 'workItemsByPhase' {
                List<Map<String, Object>> data = new List<Map<String, Object>>();
                for (AggregateResult ar : [
                    SELECT StageNamePk__c label, COUNT(Id) cnt
                    FROM WorkItem__c
                    WHERE ActivatedDateTime__c != NULL
                    AND ArchivedDateTime__c = NULL
                    AND TemplateMarkedDateTime__c = NULL
                    WITH SYSTEM_MODE
                    GROUP BY StageNamePk__c
                    ORDER BY COUNT(Id) DESC
                    LIMIT 10
                ]) {
                    data.add(new Map<String, Object>{
                        'label' => ar.get('label'),
                        'value' => ar.get('cnt')
                    });
                }
                return data;
            }
            when 'recentActivity' {
                List<Map<String, Object>> data = new List<Map<String, Object>>();
                for (ActivityLog__c log : [
                    SELECT UserIdTxt__c, ActionTypePk__c, ComponentNameTxt__c, CreatedDate
                    FROM ActivityLog__c
                    WHERE CreatedDate = LAST_N_DAYS:7
                    WITH SYSTEM_MODE
                    ORDER BY CreatedDate DESC
                    LIMIT 10
                ]) {
                    data.add(new Map<String, Object>{
                        'label' => log.ComponentNameTxt__c,
                        'value' => log.ActionTypePk__c,
                        'date' => log.CreatedDate
                    });
                }
                return data;
            }
            when 'syncHealth' {
                // SyncItem__c.StatusPk__c is a restricted picklist: Queued, Staged, Processing, Synced, Failed.
                // Prior code filtered on 'Succeeded' (not a valid value) so the count was structurally always 0.
                // Dismissed items (DismissedDateTime__c set) are excluded so admin-triaged failures
                // stop dragging the denominator down — see DeliverySyncDismissalService.
                // Staged items are ALSO excluded — they're not failures, they're items waiting for
                // a downstream client to pull via GET /sync/changes (Poll Mode). Including them
                // pulled health to 0 on orgs (like dh-prod) where lots of items target unconfigured
                // clients. Health = synced / (synced + failed + queued + processing), where the
                // denominator is "things that should have happened by now but might not have."
                Integer total = [
                    SELECT COUNT() FROM SyncItem__c
                    WHERE CreatedDate = LAST_N_DAYS:7
                    AND DismissedDateTime__c = NULL
                    AND StatusPk__c != 'Staged'
                    WITH SYSTEM_MODE
                ];
                Integer succeeded = [
                    SELECT COUNT() FROM SyncItem__c
                    WHERE StatusPk__c = 'Synced'
                    AND CreatedDate = LAST_N_DAYS:7
                    AND DismissedDateTime__c = NULL
                    WITH SYSTEM_MODE
                ];
                return total > 0 ? Math.round((Decimal.valueOf(succeeded) / total) * 100) : 100;
            }
            when 'stagedAwaitingPoll' {
                // Items in Staged status are intentionally queued for downstream clients to
                // pull via Poll Mode (GET /sync/changes). They are NOT failures. Surface
                // them as a separate metric so admins can see "X items waiting for client X
                // to poll" without confusing them with failed items.
                return [
                    SELECT COUNT() FROM SyncItem__c
                    WHERE StatusPk__c = 'Staged'
                    AND DismissedDateTime__c = NULL
                    WITH SYSTEM_MODE
                ];
            }
            when else {
                return null;
            }
        }
    }

    private static CardConfig mapConfig(DashboardCard__mdt card) {
        CardConfig cfg = new CardConfig();
        cfg.key = card.DeveloperName;
        cfg.title = card.TitleTxt__c;
        cfg.description = card.DescriptionTxt__c;
        cfg.cardType = card.CardTypePk__c;
        cfg.iconName = card.IconNameTxt__c;
        cfg.dataSource = card.DataSourceTxt__c;
        cfg.filterJson = card.FilterJsonTxt__c;
        cfg.cardSize = card.CardSizeTxt__c != null ? card.CardSizeTxt__c : 'medium';
        cfg.thresholdWarning = card.ThresholdWarningNumber__c;
        cfg.thresholdCritical = card.ThresholdCriticalNumber__c;
        return cfg;
    }

    global class CardConfig {
        @AuraEnabled public String key;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public String cardType;
        @AuraEnabled public String iconName;
        @AuraEnabled public String dataSource;
        @AuraEnabled public String filterJson;
        @AuraEnabled public String cardSize;
        @AuraEnabled public Decimal thresholdWarning;
        @AuraEnabled public Decimal thresholdCritical;
    }
}
