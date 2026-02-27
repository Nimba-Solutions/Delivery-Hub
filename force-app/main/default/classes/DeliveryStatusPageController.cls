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
        public String entityName { get; set; }
        public Map<String, Integer> phaseDistribution { get; set; }
        public Map<String, Integer> slaHealth { get; set; }
        public List<Map<String, String>> recentCompletions { get; set; }
        public Integer activeCount { get; set; }
        public Integer completedCount { get; set; }
        public String lastUpdated { get; set; }
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
        result.put('entityName', entity.Name);

        // --- Terminal stages ---
        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');

        // --- Phase distribution ---
        Map<String, String> stageToPhase = DeliveryWorkflowConfigService.getStagePhaseMap('Software_Delivery');
        Map<String, Integer> phaseCounts = new Map<String, Integer>{
            'Planning' => 0, 'Development' => 0, 'Testing' => 0,
            'UAT' => 0, 'Deployment' => 0
        };

        for (AggregateResult ar : [
            SELECT StageNamePk__c stage, Count(Id) cnt
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entity.Id
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
            GROUP BY StageNamePk__c
        ]) {
            String phase = stageToPhase.get((String) ar.get('stage'));
            if (phase != null && phaseCounts.containsKey(phase)) {
                phaseCounts.put(phase, phaseCounts.get(phase) + ((Decimal) ar.get('cnt')).intValue());
            }
        }
        result.put('phaseDistribution', phaseCounts);

        // --- Active count ---
        Integer activeCount = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entity.Id
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
        ];
        result.put('activeCount', activeCount);

        // --- Completed count ---
        Integer completedCount = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entity.Id
            AND StageNamePk__c IN :terminalStages
            WITH SYSTEM_MODE
        ];
        result.put('completedCount', completedCount);

        // --- SLA Health ---
        Map<String, Integer> slaHealth = new Map<String, Integer>{
            'onTrack' => 0, 'atRisk' => 0, 'breached' => 0
        };

        for (WorkItem__c wi : [
            SELECT SLAStatusTxt__c
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entity.Id
            AND SLATargetDate__c != NULL
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
        ]) {
            String status = wi.SLAStatusTxt__c;
            if (status == 'On Track') {
                slaHealth.put('onTrack', slaHealth.get('onTrack') + 1);
            } else if (status == 'At Risk') {
                slaHealth.put('atRisk', slaHealth.get('atRisk') + 1);
            } else if (status == 'Breached') {
                slaHealth.put('breached', slaHealth.get('breached') + 1);
            }
        }
        result.put('slaHealth', slaHealth);

        // --- Overall health ---
        Integer totalSLA = slaHealth.get('onTrack') + slaHealth.get('atRisk') + slaHealth.get('breached');
        String overallHealth = 'Healthy';
        if (totalSLA > 0) {
            Decimal breachedRatio = (Decimal) slaHealth.get('breached') / totalSLA;
            Decimal atRiskRatio = (Decimal) slaHealth.get('atRisk') / totalSLA;
            if (breachedRatio > 0.2) {
                overallHealth = 'Critical';
            } else if (atRiskRatio + breachedRatio > 0.3) {
                overallHealth = 'At Risk';
            }
        }
        result.put('overallHealth', overallHealth);

        // --- Recent completions (title + date only — no descriptions or owners) ---
        List<Map<String, String>> recentCompletions = new List<Map<String, String>>();
        for (WorkItem__c wi : [
            SELECT BriefDescriptionTxt__c, LastModifiedDate
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entity.Id
            AND StageNamePk__c IN :terminalStages
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 5
        ]) {
            Map<String, String> item = new Map<String, String>();
            item.put('title', wi.BriefDescriptionTxt__c);
            item.put('completedDate', wi.LastModifiedDate.format('MMM d, yyyy'));
            recentCompletions.add(item);
        }
        result.put('recentCompletions', recentCompletions);

        // --- Last updated ---
        List<WorkItem__c> lastMod = [
            SELECT LastModifiedDate
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entity.Id
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!lastMod.isEmpty()) {
            result.put('lastUpdated', lastMod[0].LastModifiedDate.format('MMM d, yyyy h:mm a'));
        } else {
            result.put('lastUpdated', 'No activity');
        }

        return result;
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
        this.entityToken = ApexPages.currentPage().getParameters().get('token');
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
