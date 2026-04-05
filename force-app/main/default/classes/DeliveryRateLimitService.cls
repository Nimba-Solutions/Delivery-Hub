/**
 * @description Generic sliding-window rate limiter backed by ActivityLog__c.
 *              Counts API_Request activity logs per identifier within a configurable
 *              time window. Used by sync and public API endpoints.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryRateLimitService {

    /**
     * @description Checks whether the given identifier has exceeded the request limit
     *              within the specified time window.
     * @param identifier Unique key to rate-limit on (API key, entity ID, email, etc.)
     * @param actionSubtype Further categorisation stored in PageUrlTxt__c (e.g. 'SyncAPI', 'PublicAPI')
     * @param maxRequests Maximum number of requests allowed in the window
     * @param windowHours Size of the sliding window in hours
     * @return true if the identifier is rate-limited (i.e. has met or exceeded the max)
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static Boolean isRateLimited(String identifier, String actionSubtype, Integer maxRequests, Integer windowHours) {
        if (String.isBlank(identifier) || maxRequests == null || windowHours == null) {
            return false;
        }
        DateTime windowStart = DateTime.now().addHours(-windowHours);
        Integer recentCount = [
            SELECT COUNT()
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'API_Request'
              AND ComponentNameTxt__c = :identifier
              AND PageUrlTxt__c = :actionSubtype
              AND CreatedDate >= :windowStart
            WITH SYSTEM_MODE
        ];
        return recentCount >= maxRequests;
    }

    /**
     * @description Records an API request for rate-limiting purposes.
     *              Inserts an ActivityLog__c with ActionTypePk__c = 'API_Request'.
     * @param identifier Unique key (same value used in isRateLimited)
     * @param actionSubtype Category string (e.g. 'SyncAPI', 'PublicAPI')
     */
    public static void recordRequest(String identifier, String actionSubtype) {
        if (String.isBlank(identifier)) {
            return;
        }
        ActivityLog__c log = new ActivityLog__c(
            ActionTypePk__c = 'API_Request',
            ComponentNameTxt__c = identifier,
            PageUrlTxt__c = actionSubtype
        );
        insert log;
    }
}
