/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Public-safe controller for the zero-login status page.
 *               Returns only aggregate/summary data — no descriptions,
 *               comments, owner names, or internal details are exposed.
 *               Uses WITHOUT SHARING so guest users on Salesforce Sites
 *               can access the data without record-level restrictions.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryStatusPageController {

    /** @description Wrapper returned by the VF page getters */
    public class StatusPageData {
        /** @description Display name of the network entity */
        public String entityName { get; set; }
        /** @description Map of phase names to active work-item counts */
        public Map<String, Integer> phaseDistribution { get; set; }
        /** @description Map of SLA buckets (onTrack, atRisk, breached) to counts */
        public Map<String, Integer> slaHealth { get; set; }
        /** @description List of recently completed items with title and date */
        public List<Map<String, String>> recentCompletions { get; set; }
        /** @description Number of currently active work items */
        public Integer activeCount { get; set; }
        /** @description Number of completed work items */
        public Integer completedCount { get; set; }
        /** @description Formatted timestamp of the most recent activity */
        public String lastUpdated { get; set; }
        /** @description Overall health rating: Healthy, At Risk, or Critical */
        public String overallHealth { get; set; }
    }

    /**
     * @description Returns aggregate status page data scoped to a network entity.
     *              The entityToken is matched against NetworkEntity__c.Name.
     *              Only summary-level data is returned — never internal details.
     * @param entityToken URL-safe identifier matching a NetworkEntity__c Name
     * @return Map containing entityName, phaseDistribution, slaHealth,
     *         recentCompletions, activeCount, completedCount, lastUpdated, overallHealth
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getStatusPageData(String entityToken) {
        Map<String, Object> result = new Map<String, Object>();

        // --- Guard: check master toggle ---
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || settings.StatusPageEnabledBool__c != true) {
            result.put('error', 'Status page is not enabled.');
            return result;
        }

        // --- Guard: validate token ---
        if (String.isBlank(entityToken)) {
            result.put('error', 'Missing entity token.');
            return result;
        }

        // Match token against the configured token or entity Name
        List<NetworkEntity__c> entities = [
            SELECT Id, Name
            FROM NetworkEntity__c
            WHERE Name = :entityToken
            AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (entities.isEmpty()) {
            result.put('error', 'Invalid or inactive entity token.');
            return result;
        }

        NetworkEntity__c entity = entities[0];
        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');

        result.put('entityName', entity.Name);
        result.put('phaseDistribution', buildPhaseDistribution(entity.Id, terminalStages));
        result.put('activeCount', countWorkItems(entity.Id, terminalStages, false));
        result.put('completedCount', countWorkItems(entity.Id, terminalStages, true));

        Map<String, Integer> slaHealth = buildSlaHealth(entity.Id, terminalStages);
        result.put('slaHealth', slaHealth);
        result.put('overallHealth', calculateOverallHealth(slaHealth));
        result.put('recentCompletions', buildRecentCompletions(entity.Id, terminalStages));
        result.put('lastUpdated', getLastUpdatedTimestamp(entity.Id));

        return result;
    }

    /**
     * @description Aggregates active work items by workflow phase (Planning,
     *              Development, Testing, UAT, Deployment).
     * @param entityId Id of the NetworkEntity__c to scope the query
     * @param terminalStages Set of stage values considered terminal/completed
     * @return Map of phase name to count of active items in that phase
     */
    private static Map<String, Integer> buildPhaseDistribution(Id entityId, Set<String> terminalStages) {
        Map<String, String> stageToPhase = DeliveryWorkflowConfigService.getStagePhaseMap('Software_Delivery');
        Map<String, Integer> phaseCounts = new Map<String, Integer>{
            'Planning' => 0, 'Development' => 0, 'Testing' => 0,
            'UAT' => 0, 'Deployment' => 0
        };

        for (AggregateResult ar : [
            SELECT StageNamePk__c stage, Count(Id) cnt
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entityId
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
            GROUP BY StageNamePk__c
        ]) {
            String phase = stageToPhase.get((String) ar.get('stage'));
            if (phase != null && phaseCounts.containsKey(phase)) {
                phaseCounts.put(phase, phaseCounts.get(phase) + ((Decimal) ar.get('cnt')).intValue());
            }
        }
        return phaseCounts;
    }

    /**
     * @description Counts work items that are either active or completed,
     *              depending on the terminal flag.
     * @param entityId Id of the NetworkEntity__c to scope the query
     * @param terminalStages Set of stage values considered terminal/completed
     * @param terminal When true counts completed items; when false counts active items
     * @return Count of matching work items
     */
    private static Integer countWorkItems(Id entityId, Set<String> terminalStages, Boolean terminal) {
        if (terminal) {
            return [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE ClientNetworkEntityId__c = :entityId
                AND StageNamePk__c IN :terminalStages
                WITH SYSTEM_MODE
            ];
        }
        return [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entityId
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description Categorises active work items with SLA targets into
     *              onTrack, atRisk, and breached buckets.
     * @param entityId Id of the NetworkEntity__c to scope the query
     * @param terminalStages Set of stage values considered terminal/completed
     * @return Map with keys onTrack, atRisk, breached and their integer counts
     */
    private static Map<String, Integer> buildSlaHealth(Id entityId, Set<String> terminalStages) {
        Map<String, Integer> slaHealth = new Map<String, Integer>{
            'onTrack' => 0, 'atRisk' => 0, 'breached' => 0
        };

        for (WorkItem__c wi : [
            SELECT SLAStatusTxt__c
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entityId
            AND SLATargetDate__c != NULL
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
        ]) {
            String bucket = slaStatusToBucket(wi.SLAStatusTxt__c);
            if (bucket != null) {
                slaHealth.put(bucket, slaHealth.get(bucket) + 1);
            }
        }
        return slaHealth;
    }

    /**
     * @description Maps an SLA status display value to its bucket key.
     * @param status The SLAStatusTxt__c value (On Track, At Risk, Breached)
     * @return The bucket key (onTrack, atRisk, breached) or null if unrecognised
     */
    private static String slaStatusToBucket(String status) {
        if (status == 'On Track') { return 'onTrack'; }
        if (status == 'At Risk') { return 'atRisk'; }
        if (status == 'Breached') { return 'breached'; }
        return null;
    }

    /**
     * @description Derives an overall health label from SLA bucket counts.
     *              Critical when >20% breached, At Risk when >30% at-risk+breached.
     * @param slaHealth Map with keys onTrack, atRisk, breached
     * @return One of Healthy, At Risk, or Critical
     */
    private static String calculateOverallHealth(Map<String, Integer> slaHealth) {
        Integer totalSLA = slaHealth.get('onTrack') + slaHealth.get('atRisk') + slaHealth.get('breached');
        if (totalSLA == 0) {
            return 'Healthy';
        }
        Decimal breachedRatio = (Decimal) slaHealth.get('breached') / totalSLA;
        Decimal atRiskRatio = (Decimal) slaHealth.get('atRisk') / totalSLA;
        if (breachedRatio > 0.2) {
            return 'Critical';
        }
        if (atRiskRatio + breachedRatio > 0.3) {
            return 'At Risk';
        }
        return 'Healthy';
    }

    /**
     * @description Retrieves the five most recently completed work items,
     *              returning only their title and formatted completion date.
     * @param entityId Id of the NetworkEntity__c to scope the query
     * @param terminalStages Set of stage values considered terminal/completed
     * @return List of maps each containing title and completedDate strings
     */
    private static List<Map<String, String>> buildRecentCompletions(Id entityId, Set<String> terminalStages) {
        List<Map<String, String>> completions = new List<Map<String, String>>();
        for (WorkItem__c wi : [
            SELECT BriefDescriptionTxt__c, LastModifiedDate
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entityId
            AND StageNamePk__c IN :terminalStages
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 5
        ]) {
            Map<String, String> item = new Map<String, String>();
            item.put('title', wi.BriefDescriptionTxt__c);
            item.put('completedDate', wi.LastModifiedDate.format('MMM d, yyyy'));
            completions.add(item);
        }
        return completions;
    }

    /**
     * @description Returns a formatted timestamp of the most recent work-item
     *              modification for the given entity, or 'No activity' if none exist.
     * @param entityId Id of the NetworkEntity__c to scope the query
     * @return Formatted date string or 'No activity'
     */
    private static String getLastUpdatedTimestamp(Id entityId) {
        List<WorkItem__c> lastMod = [
            SELECT LastModifiedDate
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entityId
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!lastMod.isEmpty()) {
            return lastMod[0].LastModifiedDate.format('MMM d, yyyy h:mm a');
        }
        return 'No activity';
    }

    // -------------------------------------------------------------------------
    // Visualforce page support — properties used by the VF page renderer
    // -------------------------------------------------------------------------

    /** @description The entity token from the URL parameter */
    public String entityToken { get; set; }

    /** @description Cached status page data loaded once per page render */
    private StatusPageData cachedData;

    /** @description Private backing field for error message to avoid recursion */
    private String errorMsg;

    /** @description Whether data has been loaded */
    private Boolean dataLoaded = false;

    /**
     * @description Default constructor — reads entity token from URL param.
     */
    public DeliveryStatusPageController() {
        String rawToken = ApexPages.currentPage().getParameters().get('token');
        this.entityToken = String.isNotBlank(rawToken) ? String.escapeSingleQuotes(rawToken.trim()) : null;
    }

    /** @description Whether the page has an error */
    public Boolean hasError {
        get {
            ensureLoaded();
            return String.isNotBlank(errorMsg);
        }
    }

    /** @description Error message if any */
    public String errorMessage {
        get {
            ensureLoaded();
            return errorMsg;
        }
    }

    /** @description Entity display name */
    public String entityName {
        get {
            ensureLoaded();
            return cachedData != null ? cachedData.entityName : '';
        }
    }

    /** @description Overall health status */
    public String overallHealth {
        get {
            ensureLoaded();
            return cachedData != null ? cachedData.overallHealth : '';
        }
    }

    /** @description Last updated timestamp */
    public String lastUpdated {
        get {
            ensureLoaded();
            return cachedData != null ? cachedData.lastUpdated : '';
        }
    }

    /** @description Active item count */
    public Integer activeCount {
        get {
            ensureLoaded();
            return cachedData != null ? cachedData.activeCount : 0;
        }
    }

    /** @description Completed item count */
    public Integer completedCount {
        get {
            ensureLoaded();
            return cachedData != null ? cachedData.completedCount : 0;
        }
    }

    /** @description Completion rate as a percentage string */
    public String completionRate {
        get {
            ensureLoaded();
            if (cachedData == null) { return '0%'; }
            Integer total = cachedData.activeCount + cachedData.completedCount;
            if (total == 0) { return '0%'; }
            Integer rate = (cachedData.completedCount * 100) / total;
            return rate + '%';
        }
    }

    /** @description SLA on track count */
    public Integer slaOnTrack {
        get {
            ensureLoaded();
            return cachedData != null ? cachedData.slaHealth.get('onTrack') : 0;
        }
    }

    /** @description SLA at risk count */
    public Integer slaAtRisk {
        get {
            ensureLoaded();
            return cachedData != null ? cachedData.slaHealth.get('atRisk') : 0;
        }
    }

    /** @description SLA breached count */
    public Integer slaBreached {
        get {
            ensureLoaded();
            return cachedData != null ? cachedData.slaHealth.get('breached') : 0;
        }
    }

    /** @description Phase distribution map */
    public Map<String, Integer> phases {
        get {
            ensureLoaded();
            return cachedData != null ? cachedData.phaseDistribution : new Map<String, Integer>();
        }
    }

    /** @description Total items across all phases (for bar chart widths) */
    public Integer phaseTotal {
        get {
            ensureLoaded();
            if (cachedData == null) { return 0; }
            Integer total = 0;
            for (Integer c : cachedData.phaseDistribution.values()) {
                total += c;
            }
            return total;
        }
    }

    /** @description Recent completions list */
    public List<Map<String, String>> recentCompletions {
        get {
            ensureLoaded();
            return cachedData != null ? cachedData.recentCompletions : new List<Map<String, String>>();
        }
    }

    /** @description Health badge CSS color */
    public String healthColor {
        get {
            ensureLoaded();
            String h = cachedData != null ? cachedData.overallHealth : '';
            if (h == 'Healthy') { return '#04844b'; }
            if (h == 'At Risk') { return '#e8a300'; }
            if (h == 'Critical') { return '#c23934'; }
            return '#706e6b';
        }
    }

    /** @description Health badge background color */
    public String healthBgColor {
        get {
            ensureLoaded();
            String h = cachedData != null ? cachedData.overallHealth : '';
            if (h == 'Healthy') { return '#e6f7ee'; }
            if (h == 'At Risk') { return '#fef3cd'; }
            if (h == 'Critical') { return '#fce4e4'; }
            return '#f4f6f9';
        }
    }

    /**
     * @description Loads status page data once per page render.
     *              Populates cachedData or errorMsg.
     */
    private void ensureLoaded() {
        if (dataLoaded) {
            return;
        }
        dataLoaded = true;

        Map<String, Object> raw = getStatusPageData(entityToken);

        if (raw.containsKey('error')) {
            errorMsg = (String) raw.get('error');
            return;
        }

        cachedData = new StatusPageData();
        cachedData.entityName = (String) raw.get('entityName');
        cachedData.overallHealth = (String) raw.get('overallHealth');
        cachedData.lastUpdated = (String) raw.get('lastUpdated');
        cachedData.activeCount = (Integer) raw.get('activeCount');
        cachedData.completedCount = (Integer) raw.get('completedCount');

        // Phase distribution
        Map<String, Integer> rawPhases = new Map<String, Integer>();
        Object phaseObj = raw.get('phaseDistribution');
        if (phaseObj instanceof Map<String, Integer>) {
            rawPhases = (Map<String, Integer>) phaseObj;
        }
        cachedData.phaseDistribution = rawPhases;

        // SLA health
        Map<String, Integer> rawSla = new Map<String, Integer>();
        Object slaObj = raw.get('slaHealth');
        if (slaObj instanceof Map<String, Integer>) {
            rawSla = (Map<String, Integer>) slaObj;
        }
        cachedData.slaHealth = rawSla;

        // Recent completions
        List<Map<String, String>> rawRecent = new List<Map<String, String>>();
        Object recentObj = raw.get('recentCompletions');
        if (recentObj instanceof List<Map<String, String>>) {
            rawRecent = (List<Map<String, String>>) recentObj;
        }
        cachedData.recentCompletions = rawRecent;
    }
}
