/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the Activity Dashboard LWC.
 * Returns aggregate analytics from ActivityLog__c for user tracking and adoption metrics.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryActivityDashboardController {

    /** @description Wrapper for a ranked item (user or component) with its activity count. */
    public class RankedItem {
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
    }

    /** @description Wrapper for a single day's activity count. */
    public class DailyCount {
        @AuraEnabled public String dateLabel;
        @AuraEnabled public Integer count;
    }

    /**
     * @description Returns aggregate activity data: totals, top users, top components, and daily trend.
     * @return Map containing totalThisWeek, totalThisMonth, topUsers, topComponents, and dailyCounts keys.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getActivitySummary() {
        Map<String, Object> result = new Map<String, Object>();

        Date today = Date.today();
        Date weekStart = today.toStartOfWeek();
        Date monthStart = today.toStartOfMonth();
        Datetime weekStartDt = Datetime.newInstance(weekStart, Time.newInstance(0, 0, 0, 0));
        Datetime monthStartDt = Datetime.newInstance(monthStart, Time.newInstance(0, 0, 0, 0));

        // Total activity this week
        Integer totalThisWeek = [
            SELECT COUNT()
            FROM ActivityLog__c
            WHERE CreatedDate >= :weekStartDt
            WITH SYSTEM_MODE
        ];
        result.put('totalThisWeek', totalThisWeek);

        // Total activity this month
        Integer totalThisMonth = [
            SELECT COUNT()
            FROM ActivityLog__c
            WHERE CreatedDate >= :monthStartDt
            WITH SYSTEM_MODE
        ];
        result.put('totalThisMonth', totalThisMonth);

        // Top 5 most active users
        List<RankedItem> topUsers = new List<RankedItem>();
        for (AggregateResult agg : [
            SELECT UserIdTxt__c userId, COUNT(Id) cnt
            FROM ActivityLog__c
            WHERE CreatedDate >= :monthStartDt
            AND UserIdTxt__c != NULL
            WITH SYSTEM_MODE
            GROUP BY UserIdTxt__c
            ORDER BY COUNT(Id) DESC
            LIMIT 5
        ]) {
            RankedItem item = new RankedItem();
            item.label = (String) agg.get('userId');
            item.count = ((Decimal) agg.get('cnt')).intValue();
            topUsers.add(item);
        }
        result.put('topUsers', topUsers);

        // Top 5 most used components
        List<RankedItem> topComponents = new List<RankedItem>();
        for (AggregateResult agg : [
            SELECT ComponentNameTxt__c comp, COUNT(Id) cnt
            FROM ActivityLog__c
            WHERE CreatedDate >= :monthStartDt
            AND ComponentNameTxt__c != NULL
            WITH SYSTEM_MODE
            GROUP BY ComponentNameTxt__c
            ORDER BY COUNT(Id) DESC
            LIMIT 5
        ]) {
            RankedItem item = new RankedItem();
            item.label = (String) agg.get('comp');
            item.count = ((Decimal) agg.get('cnt')).intValue();
            topComponents.add(item);
        }
        result.put('topComponents', topComponents);

        // Daily activity counts for last 7 days
        Date sevenDaysAgo = today.addDays(-6);
        Datetime sevenDaysAgoDt = Datetime.newInstance(sevenDaysAgo, Time.newInstance(0, 0, 0, 0));

        Map<Date, Integer> dailyMap = new Map<Date, Integer>();
        for (Integer i = 0; i < 7; i++) {
            dailyMap.put(sevenDaysAgo.addDays(i), 0);
        }

        for (AggregateResult agg : [
            SELECT DAY_ONLY(CreatedDate) day, COUNT(Id) cnt
            FROM ActivityLog__c
            WHERE CreatedDate >= :sevenDaysAgoDt
            WITH SYSTEM_MODE
            GROUP BY DAY_ONLY(CreatedDate)
            ORDER BY DAY_ONLY(CreatedDate) ASC
        ]) {
            Date day = (Date) agg.get('day');
            Integer cnt = ((Decimal) agg.get('cnt')).intValue();
            if (dailyMap.containsKey(day)) {
                dailyMap.put(day, cnt);
            }
        }

        List<DailyCount> dailyCounts = new List<DailyCount>();
        for (Integer i = 0; i < 7; i++) {
            Date d = sevenDaysAgo.addDays(i);
            DailyCount dc = new DailyCount();
            Datetime dtForFormat = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
            dc.dateLabel = dtForFormat.format('EEE');
            dc.count = dailyMap.get(d);
            dailyCounts.add(dc);
        }
        result.put('dailyCounts', dailyCounts);

        // Top 5 most visited pages
        List<RankedItem> topPages = new List<RankedItem>();
        for (AggregateResult agg : [
            SELECT PageUrlTxt__c page, COUNT(Id) cnt
            FROM ActivityLog__c
            WHERE CreatedDate >= :monthStartDt
            AND PageUrlTxt__c != NULL
            AND ActionTypePk__c = 'Navigation'
            WITH SYSTEM_MODE
            GROUP BY PageUrlTxt__c
            ORDER BY COUNT(Id) DESC
            LIMIT 5
        ]) {
            RankedItem item = new RankedItem();
            item.label = (String) agg.get('page');
            item.count = ((Decimal) agg.get('cnt')).intValue();
            topPages.add(item);
        }
        result.put('topPages', topPages);

        return result;
    }
}
