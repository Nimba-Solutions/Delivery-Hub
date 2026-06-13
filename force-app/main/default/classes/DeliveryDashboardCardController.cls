/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the configurable Executive Dashboard framework.
 *               Reads DashboardCard__mdt records and resolves data for each card.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc, PMD.AvoidGlobalModifier')
global with sharing class DeliveryDashboardCardController {

    /** @description Terminal stages excluded from active-scope card counts (CMT-driven cross-type union). */
    private static Set<String> terminalStages {
        get {
            if (terminalStages == null) {
                terminalStages = DeliveryWorkflowConfigService.getAllTerminalStageValues();
            }
            return terminalStages;
        }
        set;
    }

    @AuraEnabled(cacheable=true)
    global static List<CardConfig> getCardsForPage(String pageKey) {
        String currentProfile = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() WITH SYSTEM_MODE].Profile.Name;
        List<CardConfig> cards = new List<CardConfig>();
        for (DashboardCard__mdt card : [
            SELECT DeveloperName, TitleTxt__c, DescriptionTxt__c, CardTypePk__c,
                   IconNameTxt__c, DataSourceTxt__c, FilterJsonTxt__c,
                   SortOrderNumber__c, CardSizeTxt__c, VisibleToProfilesTxt__c,
                   ThresholdWarningNumber__c, ThresholdCriticalNumber__c,
                   ClickThroughUrlTxt__c, InfoPopoverTxt__c
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
    global static Object getCardData(String dataSource, String filterJson) {
        switch on dataSource {
            when 'activeWorkItems' {
                // Canonical "active" definition, shared with System Pulse
                // (DeliveryHubDashboardController.getBudgetMetrics.activeRequests):
                // activated + non-archived + non-template + NON-TERMINAL stage.
                // Pre-fix this count was missing the terminal-stage exclusion, so
                // Done/Cancelled items still counted as "Active" and the Exec
                // Dashboard disagreed with System Pulse (155 vs 110 on live data).
                Set<String> terminalStages =
                    DeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');
                return [
                    SELECT COUNT() FROM WorkItem__c
                    WHERE ActivatedDateTime__c != NULL
                    AND ArchivedDateTime__c = NULL
                    AND TemplateMarkedDateTime__c = NULL
                    AND StageNamePk__c NOT IN :terminalStages
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
                // Hours WORKED this month, keyed on WorkDateDate__c (when the work
                // actually happened) with a CreatedDate fallback for legacy rows
                // where the work date was never captured — the exact semantics of
                // System Pulse's "Hours Performed This Month" and the Monthly_Hours
                // report. Pre-fix this card summed by CreatedDate (entry time),
                // which silently diverged from both whenever entries were backdated.
                Date monthStart = Date.today().toStartOfMonth();
                DateTime monthStartDt = DateTime.newInstance(monthStart, Time.newInstance(0, 0, 0, 0));
                AggregateResult[] results = [
                    SELECT SUM(HoursLoggedNumber__c) total
                    FROM WorkLog__c
                    WHERE (WorkDateDate__c >= :monthStart)
                       OR (WorkDateDate__c = NULL AND CreatedDate >= :monthStartDt)
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
                    AND StageNamePk__c NOT IN :terminalStages
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
            when 'hoursByMonthLast6' {
                // Bar chart series: each bar = one calendar month, value = sum of hours
                // logged that month (by WorkDateDate__c — when the work was actually done,
                // matching what Jose's report uses). Rolling last-6-months window so the
                // dashboard tile shows a familiar shape: April | May | June | ... at a glance.
                Date sixMonthsAgo = Date.today().addMonths(-5).toStartOfMonth();
                Map<String, Decimal> monthly = new Map<String, Decimal>();
                List<String> orderedKeys = new List<String>();
                Date cursor = sixMonthsAgo;
                for (Integer i = 0; i < 6; i++) {
                    String k = cursor.year() + '-' + String.valueOf(cursor.month()).leftPad(2, '0');
                    monthly.put(k, 0);
                    orderedKeys.add(k);
                    cursor = cursor.addMonths(1);
                }
                for (AggregateResult ar : [
                    SELECT CALENDAR_YEAR(WorkDateDate__c) yr,
                           CALENDAR_MONTH(WorkDateDate__c) mo,
                           SUM(HoursLoggedNumber__c) total
                    FROM WorkLog__c
                    WHERE WorkDateDate__c >= :sixMonthsAgo
                    WITH SYSTEM_MODE
                    GROUP BY CALENDAR_YEAR(WorkDateDate__c), CALENDAR_MONTH(WorkDateDate__c)
                ]) {
                    Integer yr = (Integer) ar.get('yr');
                    Integer mo = (Integer) ar.get('mo');
                    String k = yr + '-' + String.valueOf(mo).leftPad(2, '0');
                    if (monthly.containsKey(k)) {
                        Object total = ar.get('total');
                        monthly.put(k, total != null ? (Decimal) total : 0);
                    }
                }
                List<String> monthLabels = new List<String>{
                    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                };
                List<Map<String, Object>> data = new List<Map<String, Object>>();
                for (String k : orderedKeys) {
                    List<String> parts = k.split('-');
                    Integer mIdx = Integer.valueOf(parts[1]) - 1;
                    data.add(new Map<String, Object>{
                        'label' => monthLabels[mIdx],
                        'value' => monthly.get(k)
                    });
                }
                return data;
            }
            when 'projectHealthPills' {
                // Top N Active WIs ranked by overrun ratio. Each row gets two
                // traffic-light pills — On-Schedule (vs ETA) and On-Budget
                // (estimated vs actual hours). Industry-standard PSA pattern,
                // renamed from SPI/CPI per Mission Control / Kantata convention.
                //
                // On-Budget ratio = EstimatedHoursNumber / max(TotalLoggedHoursSum, 1).
                //   >= 1.0 → green, 0.8-1.0 → yellow, < 0.8 → red.
                //
                // On-Schedule ratio (cheap proxy) = days remaining to ETA /
                //   estimated days remaining (linear burn). Falls back to
                //   "no estimate" when ETA or hours fields are blank.
                List<Map<String, Object>> data = new List<Map<String, Object>>();
                for (WorkItem__c wi : [
                    SELECT Id, BriefDescriptionTxt__c, EstimatedHoursNumber__c,
                           TotalLoggedHoursSum__c, CalculatedETADate__c,
                           EstimatedEndDevDate__c, StageNamePk__c
                    FROM WorkItem__c
                    WHERE ActivatedDateTime__c != NULL
                    AND ArchivedDateTime__c = NULL
                    AND TemplateMarkedDateTime__c = NULL
                    AND StageNamePk__c NOT IN :terminalStages
                    AND EstimatedHoursNumber__c != NULL
                    AND EstimatedHoursNumber__c > 0
                    WITH SYSTEM_MODE
                    LIMIT 50
                ]) {
                    Decimal logged = wi.TotalLoggedHoursSum__c != null ? wi.TotalLoggedHoursSum__c : 0;
                    Decimal estimated = wi.EstimatedHoursNumber__c;
                    Decimal budgetRatio = logged > 0 ? (estimated / logged) : 1;
                    String budgetClass = budgetRatio >= 1 ? 'success' : (budgetRatio >= 0.8 ? 'warning' : 'danger');
                    String budgetLabel = (budgetRatio * 100).setScale(0) + '%';
                    Date etaDate = wi.CalculatedETADate__c != null ? wi.CalculatedETADate__c : wi.EstimatedEndDevDate__c;
                    String scheduleClass = 'neutral';
                    String scheduleLabel = '—';
                    if (etaDate != null) {
                        Integer daysLeft = Date.today().daysBetween(etaDate);
                        if (daysLeft >= 0) {
                            scheduleClass = daysLeft >= 7 ? 'success' : (daysLeft >= 0 ? 'warning' : 'danger');
                            scheduleLabel = daysLeft + 'd left';
                        } else {
                            scheduleClass = 'danger';
                            scheduleLabel = (-daysLeft) + 'd over';
                        }
                    }
                    data.add(new Map<String, Object>{
                        'id' => wi.Id,
                        'label' => wi.BriefDescriptionTxt__c != null ? wi.BriefDescriptionTxt__c : 'Untitled',
                        'estimated' => estimated,
                        'logged' => logged,
                        'budgetClass' => budgetClass,
                        'budgetLabel' => budgetLabel,
                        'scheduleClass' => scheduleClass,
                        'scheduleLabel' => scheduleLabel,
                        'sortKey' => budgetRatio
                    });
                }
                // Sort by budget ratio ascending (worst first), keep top 10
                data.sort(new HoursAnalyticsRowComparator());
                if (data.size() > 10) {
                    List<Map<String, Object>> trimmed = new List<Map<String, Object>>();
                    for (Integer i = 0; i < 10; i++) {
                        trimmed.add(data[i]);
                    }
                    data = trimmed;
                }
                return data;
            }
            when else {
                return null;
            }
        }
    }

    private class HoursAnalyticsRowComparator implements Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> a, Map<String, Object> b) {
            Decimal aKey = (Decimal) a.get('sortKey');
            Decimal bKey = (Decimal) b.get('sortKey');
            if (aKey == bKey) {
                return 0;
            }
            return aKey < bKey ? -1 : 1;
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
        cfg.clickThroughUrl = resolveClickThroughUrl(card.ClickThroughUrlTxt__c);
        cfg.infoPopover = card.InfoPopoverTxt__c;
        return cfg;
    }

    /**
     * @description Resolves a stored click-through value to a live URL.
     *              Supports two shorthand forms so DashboardCard__mdt records
     *              can be cross-org-portable (report IDs differ per org):
     *                report:DeveloperName  → /lightning/r/Report/<id>/view
     *                list:Object__c.ListViewName → /lightning/o/<obj>/list?filterName=<name>
     *              Anything else is returned as-is (literal URL pass-through).
     *              Returns null when the shorthand can't be resolved (e.g.,
     *              report doesn't exist in this org) so the LWC simply renders
     *              the card as non-clickable instead of breaking.
     */
    private static String resolveClickThroughUrl(String stored) {
        if (String.isBlank(stored)) {
            return null;
        }
        if (stored.startsWith('report:')) {
            String devName = stored.substring(7).trim();
            List<Report> matches = [
                SELECT Id FROM Report WHERE DeveloperName = :devName WITH SYSTEM_MODE LIMIT 1
            ];
            return matches.isEmpty() ? null : '/lightning/r/Report/' + matches[0].Id + '/view';
        }
        if (stored.startsWith('list:')) {
            String spec = stored.substring(5).trim();
            Integer dotIx = spec.indexOf('.');
            if (dotIx <= 0 || dotIx == spec.length() - 1) {
                return null;
            }
            String objName = spec.substring(0, dotIx);
            String listName = spec.substring(dotIx + 1);
            return '/lightning/o/' + objName + '/list?filterName=' + listName;
        }
        return stored;
    }

    global class CardConfig {
        @AuraEnabled global String key;
        @AuraEnabled global String title;
        @AuraEnabled global String description;
        @AuraEnabled global String cardType;
        @AuraEnabled global String iconName;
        @AuraEnabled global String dataSource;
        @AuraEnabled global String filterJson;
        @AuraEnabled global String cardSize;
        @AuraEnabled global Decimal thresholdWarning;
        @AuraEnabled global Decimal thresholdCritical;
        @AuraEnabled global String clickThroughUrl;
        @AuraEnabled global String infoPopover;
    }
}
