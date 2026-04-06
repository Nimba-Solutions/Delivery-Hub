/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the Permission Analyzer LWC.
 * Analyzes ActivityLog__c navigation data to produce per-user and per-object
 * usage summaries and plain-English permission recommendations.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.AvoidGlobalModifier, PMD.NcssMethodCount, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
global with sharing class DeliveryPermissionAnalyzerController {

    private static final Integer ANALYSIS_DAYS = 30;
    private static final Integer LOW_OBJECT_THRESHOLD = 5;

    // ── Wrapper Classes ──────────────────────────────────────────────

    /** @description Per-user activity summary with risk assessment. */
    global class UserActivity {
        @AuraEnabled public String userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String profileName;
        @AuraEnabled public Integer totalViews;
        @AuraEnabled public Integer uniqueObjects;
        @AuraEnabled public List<String> topObjects;
        @AuraEnabled public String riskLevel; // Low, Medium, High
    }

    /** @description Aggregate object/page usage across all users. */
    global class ObjectUsage {
        @AuraEnabled public String objectName;
        @AuraEnabled public Integer totalViews;
        @AuraEnabled public Integer uniqueUsers;
    }

    /** @description Generic name + count pair used for breakdowns. */
    global class ObjectCount {
        @AuraEnabled public String name;
        @AuraEnabled public Integer count;
    }

    /** @description Single day activity count for trend charts. */
    global class DailyCount {
        @AuraEnabled public String dateLabel;
        @AuraEnabled public Integer count;
    }

    // ── Public Methods ───────────────────────────────────────────────

    /**
     * @description Builds a full permission-analysis payload: per-user summaries,
     * per-object usage, and plain-English recommendations based on the last 30 days
     * of Navigation activity logs.
     * @return Map with keys: users, objects, recommendations, totalUsers, totalLogs, analysisRange
     */
    @AuraEnabled
    global static Map<String, Object> getPermissionAnalysis() {
        Map<String, Object> result = new Map<String, Object>();
        Datetime cutoff = Datetime.now().addDays(-ANALYSIS_DAYS);

        // ── 1. Aggregate by User × Component ────────────────────────
        // Map<userId, Map<componentName, count>>
        Map<String, Map<String, Integer>> userComponentMap = new Map<String, Map<String, Integer>>();
        Integer totalLogs = 0;

        for (AggregateResult agg : [
            SELECT UserIdTxt__c userId, ComponentNameTxt__c comp, COUNT(Id) cnt
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Navigation'
              AND CreatedDate >= :cutoff
              AND UserIdTxt__c != NULL
              AND ComponentNameTxt__c != NULL
            WITH SYSTEM_MODE
            GROUP BY UserIdTxt__c, ComponentNameTxt__c
        ]) {
            String uid = (String) agg.get('userId');
            String comp = (String) agg.get('comp');
            Integer cnt = ((Decimal) agg.get('cnt')).intValue();
            totalLogs += cnt;

            if (!userComponentMap.containsKey(uid)) {
                userComponentMap.put(uid, new Map<String, Integer>());
            }
            userComponentMap.get(uid).put(comp, cnt);
        }

        // ── 2. Resolve user names + profiles ─────────────────────────
        Map<Id, User> userMap = new Map<Id, User>();
        if (!userComponentMap.isEmpty()) {
            try {
                userMap = new Map<Id, User>([
                    SELECT Id, Name, Profile.Name
                    FROM User
                    WHERE Id IN :userComponentMap.keySet()
                    WITH SYSTEM_MODE
                ]);
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'PermissionAnalyzer: failed to resolve users — ' + ex.getMessage());
            }
        }

        // ── 3. Build UserActivity list ───────────────────────────────
        List<UserActivity> users = new List<UserActivity>();
        List<String> recommendations = new List<String>();

        for (String uid : userComponentMap.keySet()) {
            Map<String, Integer> compCounts = userComponentMap.get(uid);
            UserActivity ua = new UserActivity();
            ua.userId = uid;

            // Resolve name / profile
            Id userId;
            try { userId = Id.valueOf(uid); } catch (Exception e) { userId = null; }
            if (userId != null && userMap.containsKey(userId)) {
                ua.userName = userMap.get(userId).Name;
                ua.profileName = userMap.get(userId).Profile.Name;
            } else {
                ua.userName = uid;
                ua.profileName = 'Unknown';
            }

            // Total views
            Integer totalViews = 0;
            for (Integer c : compCounts.values()) {
                totalViews += c;
            }
            ua.totalViews = totalViews;
            ua.uniqueObjects = compCounts.size();

            // Top 5 objects by frequency
            ua.topObjects = getTopKeys(compCounts, 5);

            // Risk level
            if (ua.uniqueObjects >= 15) {
                ua.riskLevel = 'High';
            } else if (ua.uniqueObjects >= 8) {
                ua.riskLevel = 'Medium';
            } else {
                ua.riskLevel = 'Low';
            }

            users.add(ua);

            // Recommendation for narrow-access users
            if (ua.uniqueObjects < LOW_OBJECT_THRESHOLD) {
                recommendations.add(
                    ua.userName + ' accessed only ' + ua.uniqueObjects +
                    ' unique object(s). Consider a restricted profile limited to: ' +
                    String.join(ua.topObjects, ', ') + '.'
                );
            }
        }

        // ── 4. Build ObjectUsage list ────────────────────────────────
        Map<String, ObjectUsage> objectMap = new Map<String, ObjectUsage>();
        for (String uid : userComponentMap.keySet()) {
            for (String comp : userComponentMap.get(uid).keySet()) {
                Integer cnt = userComponentMap.get(uid).get(comp);
                if (!objectMap.containsKey(comp)) {
                    ObjectUsage ou = new ObjectUsage();
                    ou.objectName = comp;
                    ou.totalViews = 0;
                    ou.uniqueUsers = 0;
                    objectMap.put(comp, ou);
                }
                ObjectUsage ou = objectMap.get(comp);
                ou.totalViews += cnt;
                ou.uniqueUsers += 1;
            }
        }
        List<ObjectUsage> objects = objectMap.values();

        // ── 5. Assemble result ───────────────────────────────────────
        result.put('users', users);
        result.put('objects', objects);
        result.put('recommendations', recommendations);
        result.put('totalUsers', userComponentMap.size());
        result.put('totalLogs', totalLogs);
        result.put('analysisRange', 'Last ' + ANALYSIS_DAYS + ' days');

        return result;
    }

    /**
     * @description Returns a detailed activity breakdown for a single user,
     * including object/page frequency, daily trend, and session statistics.
     * @param userId The 18-char User ID stored in ActivityLog__c.UserIdTxt__c
     * @return Map with keys: userName, profileName, totalPageViews, uniqueObjects,
     *         objectBreakdown, pageBreakdown, dailyActivity, sessions, avgSessionPages
     */
    @AuraEnabled
    global static Map<String, Object> getUserDetail(String userId) {
        Map<String, Object> result = new Map<String, Object>();
        Datetime cutoff = Datetime.now().addDays(-ANALYSIS_DAYS);

        // Resolve user info
        String userName = userId;
        String profileName = 'Unknown';
        try {
            User u = [
                SELECT Name, Profile.Name
                FROM User
                WHERE Id = :userId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            userName = u.Name;
            profileName = u.Profile.Name;
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'PermissionAnalyzer: failed to resolve user ' + userId + ' — ' + ex.getMessage());
        }
        result.put('userName', userName);
        result.put('profileName', profileName);

        // ── Object breakdown (Navigation logs) ──────────────────────
        Map<String, Integer> objectCounts = new Map<String, Integer>();
        for (AggregateResult agg : [
            SELECT ComponentNameTxt__c comp, COUNT(Id) cnt
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Navigation'
              AND UserIdTxt__c = :userId
              AND CreatedDate >= :cutoff
              AND ComponentNameTxt__c != NULL
            WITH SYSTEM_MODE
            GROUP BY ComponentNameTxt__c
            ORDER BY COUNT(Id) DESC
        ]) {
            objectCounts.put((String) agg.get('comp'), ((Decimal) agg.get('cnt')).intValue());
        }

        Integer totalPageViews = 0;
        List<ObjectCount> objectBreakdown = new List<ObjectCount>();
        for (String comp : objectCounts.keySet()) {
            Integer cnt = objectCounts.get(comp);
            totalPageViews += cnt;
            ObjectCount oc = new ObjectCount();
            oc.name = comp;
            oc.count = cnt;
            objectBreakdown.add(oc);
        }
        result.put('totalPageViews', totalPageViews);
        result.put('uniqueObjects', objectCounts.size());
        result.put('objectBreakdown', objectBreakdown);

        // ── Page URL breakdown (top 20) ─────────────────────────────
        List<ObjectCount> pageBreakdown = new List<ObjectCount>();
        for (AggregateResult agg : [
            SELECT PageUrlTxt__c url, COUNT(Id) cnt
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Navigation'
              AND UserIdTxt__c = :userId
              AND CreatedDate >= :cutoff
              AND PageUrlTxt__c != NULL
            WITH SYSTEM_MODE
            GROUP BY PageUrlTxt__c
            ORDER BY COUNT(Id) DESC
            LIMIT 20
        ]) {
            ObjectCount oc = new ObjectCount();
            oc.name = (String) agg.get('url');
            oc.count = ((Decimal) agg.get('cnt')).intValue();
            pageBreakdown.add(oc);
        }
        result.put('pageBreakdown', pageBreakdown);

        // ── Daily activity trend (last 30 days) ─────────────────────
        Map<String, Integer> dailyMap = new Map<String, Integer>();
        for (AggregateResult agg : [
            SELECT DAY_ONLY(CreatedDate) day, COUNT(Id) cnt
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Navigation'
              AND UserIdTxt__c = :userId
              AND CreatedDate >= :cutoff
            WITH SYSTEM_MODE
            GROUP BY DAY_ONLY(CreatedDate)
            ORDER BY DAY_ONLY(CreatedDate) ASC
        ]) {
            Date d = (Date) agg.get('day');
            dailyMap.put(String.valueOf(d), ((Decimal) agg.get('cnt')).intValue());
        }

        // Fill in zero-count days so the chart has a continuous series
        List<DailyCount> dailyActivity = new List<DailyCount>();
        Date startDate = Date.today().addDays(-ANALYSIS_DAYS);
        for (Integer i = 0; i <= ANALYSIS_DAYS; i++) {
            Date d = startDate.addDays(i);
            String key = String.valueOf(d);
            DailyCount dc = new DailyCount();
            dc.dateLabel = key;
            dc.count = dailyMap.containsKey(key) ? dailyMap.get(key) : 0;
            dailyActivity.add(dc);
        }
        result.put('dailyActivity', dailyActivity);

        // ── Session statistics ───────────────────────────────────────
        Set<String> sessionIds = new Set<String>();
        for (AggregateResult agg : [
            SELECT SessionIdTxt__c sid, COUNT(Id) cnt
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Navigation'
              AND UserIdTxt__c = :userId
              AND CreatedDate >= :cutoff
              AND SessionIdTxt__c != NULL
            WITH SYSTEM_MODE
            GROUP BY SessionIdTxt__c
        ]) {
            sessionIds.add((String) agg.get('sid'));
        }

        Integer sessions = sessionIds.size();
        result.put('sessions', sessions);
        result.put('avgSessionPages', sessions > 0
            ? Decimal.valueOf(totalPageViews).divide(sessions, 1, RoundingMode.HALF_UP)
            : 0);

        return result;
    }

    /**
     * @description Generates a security-audit data payload suitable for the Document Engine.
     * Currently returns the analysis data formatted for document generation;
     * the actual DeliveryDocumentController.generateDocument integration will be wired later.
     * @return Map containing the analysis data structured for document rendering.
     */
    @AuraEnabled
    global static Map<String, Object> generateSecurityReport() {
        Map<String, Object> analysis = getPermissionAnalysis();
        Map<String, Object> report = new Map<String, Object>();

        report.put('templateName', 'Security_Audit');
        report.put('generatedDate', Datetime.now().format('yyyy-MM-dd HH:mm:ss'));
        report.put('generatedBy', UserInfo.getName());
        report.put('analysisRange', analysis.get('analysisRange'));
        report.put('totalUsers', analysis.get('totalUsers'));
        report.put('totalLogs', analysis.get('totalLogs'));
        report.put('users', analysis.get('users'));
        report.put('objects', analysis.get('objects'));
        report.put('recommendations', analysis.get('recommendations'));

        return report;
    }

    // ── Private Helpers ──────────────────────────────────────────────

    /**
     * @description Returns the top N keys from a String→Integer map, sorted by value descending.
     * @param counts Map of label → count
     * @param maxItems Maximum number of keys to return
     * @return Ordered list of the highest-count keys
     */
    private static List<String> getTopKeys(Map<String, Integer> counts, Integer maxItems) {
        // Build a sortable list of pairs
        List<SortablePair> pairs = new List<SortablePair>();
        for (String key : counts.keySet()) {
            pairs.add(new SortablePair(key, counts.get(key)));
        }
        pairs.sort();

        List<String> topKeys = new List<String>();
        for (Integer i = 0; i < Math.min(maxItems, pairs.size()); i++) {
            topKeys.add(pairs[i].key);
        }
        return topKeys;
    }

    /** @description Comparable pair for descending sort by count. */
    private class SortablePair implements Comparable {
        public String key;
        public Integer count;

        /** @description Constructs a sortable pair. @param key The label. @param count The frequency. */
        public SortablePair(String key, Integer count) {
            this.key = key;
            this.count = count;
        }

        /** @description Compares by count descending. @param other The other pair. @return Negative if this is larger. */
        public Integer compareTo(Object other) {
            SortablePair o = (SortablePair) other;
            // Descending order
            return o.count - this.count;
        }
    }
}
