/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the Stage History LWC. Queries ActivityLog__c
 *               records with ActionTypePk__c = 'Stage_Change' to build a
 *               chronological stage transition timeline for a Work Item.
 * @author Cloud Nimbus LLC
 */
global with sharing class DeliveryStageHistoryController {

    /**
     * @description Returns a list of stage change events for a given Work Item,
     *              sorted newest-first. Each entry includes old/new stage, the
     *              user who made the change, and the duration spent in the prior stage.
     * @param workItemId The Id of the WorkItem__c record.
     * @return List of Maps with keys: id, timestamp, userId, userName, oldStage,
     *         newStage, durationHours, workItemName.
     */
    @AuraEnabled(cacheable=true)
    global static List<Map<String, Object>> getStageHistory(Id workItemId) {
        if (workItemId == null) {
            return new List<Map<String, Object>>();
        }

        List<ActivityLog__c> logs = [
            SELECT Id, CreatedDate, UserIdTxt__c, ContextDataTxt__c
            FROM ActivityLog__c
            WHERE RecordIdTxt__c = :workItemId
              AND ActionTypePk__c = 'Stage_Change'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];

        if (logs.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        // Collect user Ids for name resolution
        Set<Id> userIds = collectUserIds(logs);
        Map<Id, String> userNameMap = resolveUserNames(userIds);

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (ActivityLog__c log : logs) {
            results.add(buildEntry(log, userNameMap));
        }
        return results;
    }

    // ── Private helpers ──────────────────────────────────────────────────

    private static Set<Id> collectUserIds(List<ActivityLog__c> logs) {
        Set<Id> userIds = new Set<Id>();
        for (ActivityLog__c log : logs) {
            if (String.isNotBlank(log.UserIdTxt__c)) {
                try {
                    userIds.add((Id) log.UserIdTxt__c);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.FINE, 'Skipping invalid user Id: ' + log.UserIdTxt__c);
                }
            }
        }
        return userIds;
    }

    private static Map<Id, String> resolveUserNames(Set<Id> userIds) {
        Map<Id, String> nameMap = new Map<Id, String>();
        if (!userIds.isEmpty()) {
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds WITH SYSTEM_MODE]) {
                nameMap.put(u.Id, u.Name);
            }
        }
        return nameMap;
    }

    private static Map<String, Object> buildEntry(
        ActivityLog__c log,
        Map<Id, String> userNameMap
    ) {
        Map<String, Object> entry = new Map<String, Object>{
            'id'            => log.Id,
            'timestamp'     => log.CreatedDate,
            'userId'        => log.UserIdTxt__c,
            'userName'      => resolveUserName(log.UserIdTxt__c, userNameMap),
            'oldStage'      => '',
            'newStage'      => '',
            'durationHours' => null,
            'workItemName'  => ''
        };

        if (String.isNotBlank(log.ContextDataTxt__c)) {
            try {
                Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(
                    log.ContextDataTxt__c
                );
                if (ctx.containsKey('oldStage')) {
                    entry.put('oldStage', ctx.get('oldStage'));
                }
                if (ctx.containsKey('newStage')) {
                    entry.put('newStage', ctx.get('newStage'));
                }
                if (ctx.containsKey('durationHours')) {
                    entry.put('durationHours', ctx.get('durationHours'));
                }
                if (ctx.containsKey('workItemName')) {
                    entry.put('workItemName', ctx.get('workItemName'));
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.FINE, 'Malformed context JSON for log ' + log.Id + ': ' + ex.getMessage());
            }
        }

        return entry;
    }

    private static String resolveUserName(String userIdTxt, Map<Id, String> userNameMap) {
        if (String.isNotBlank(userIdTxt) && userIdTxt instanceof Id && userNameMap.containsKey(userIdTxt)) {
            return userNameMap.get(userIdTxt);
        }
        return 'System';
    }
}
