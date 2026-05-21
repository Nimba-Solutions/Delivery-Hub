/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Reusable @IsTest factory for the highest-pain sObjects in the repo.
 *
 *               CONTRACT
 *               --------
 *               Every public method:
 *                 (a) auto-populates required Master-Detail parents (no NPE / no
 *                     REQUIRED_FIELD_MISSING in packaging-org context — the
 *                     upload-beta scratch is materially stricter than feature-test);
 *                 (b) emits safe, allowlist-compliant picklist values
 *                     (defaults verified against the field's restricted valueSet
 *                     so the row passes DeliveryPicklistIntegrityService and any
 *                     restricted SF picklist gate);
 *                 (c) anchors dates / datetimes on Date.today() / Datetime.now()
 *                     so rolling-window / weekly-bucket assertions don't silently
 *                     fail when a test runs across a week boundary
 *                     (see feedback_anchor_rolling_window_tests_on_today.md);
 *                 (d) accepts a Map<String,Object> overrides to let callers
 *                     tweak any field without forking the helper;
 *                 (e) when a WorkLog__c is requested, auto-mints the per-WI
 *                     WorkRequest__c bridge required by RequestId__c
 *                     (Master-Detail per feedback_worklog_requestid_master_detail.md).
 *
 *               This class is annotated @IsTest so it never ships in the package.
 *               It is intentionally additive — existing private createTestXxx
 *               helpers inside individual test classes stay in place. New tests
 *               (and opportunistic migrations) use this; full-repo retrofit is
 *               a separate PR.
 *
 *               PHASE 1 SCOPE — sObjects covered
 *                 NetworkEntity__c, WorkItem__c, WorkRequest__c, WorkLog__c,
 *                 WorkItemComment__c, SyncItem__c
 *
 *               Future phases: DeliveryDocument__c, ActivityLog__c, BountyClaim__c,
 *               DeliveryDependency__c — add as test-pain surfaces them.
 *
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.ExcessiveParameterList,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity')
@IsTest
public class TestDataFactory {

    // ────────────────────────────────────────────────────────────────────
    // INTERNAL STATE — per-test-method caches so a single test can stack
    // calls without spawning duplicate parents.
    // ────────────────────────────────────────────────────────────────────

    /** Cached WorkRequest bridge per WorkItem Id (for WorkLog inserts). */
    private static Map<Id, Id> bridgeByWi = new Map<Id, Id>();

    /** Cached default vendor NetworkEntity (for tests that just need ANY vendor). */
    private static NetworkEntity__c defaultVendorCache;

    /** Cached default client NetworkEntity (for tests that just need ANY client). */
    private static NetworkEntity__c defaultClientCache;

    /** Increments to keep generated names / tokens unique within a test run. */
    private static Integer uniquenessCounter = 0;

    /**
     * @description Reset all caches. Test methods normally don't need this —
     *              static state is wiped between test method runs anyway —
     *              but if a single method builds two independent record
     *              trees and wants distinct vendor/client, call this between.
     */
    public static void resetCache() {
        bridgeByWi = new Map<Id, Id>();
        defaultVendorCache = null;
        defaultClientCache = null;
        uniquenessCounter = 0;
    }

    private static String uniq(String base) {
        uniquenessCounter++;
        return base + '-' + String.valueOf(uniquenessCounter) + '-' + String.valueOf(Math.mod(Crypto.getRandomLong(), 1000000));
    }

    // ────────────────────────────────────────────────────────────────────
    // NetworkEntity__c
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) a NetworkEntity__c with safe defaults.
     *              EntityTypePk__c='Vendor', StatusPk__c='Active'. Override
     *              any field via the map.
     */
    public static NetworkEntity__c buildNetworkEntity(Map<String, Object> overrides) {
        NetworkEntity__c e = new NetworkEntity__c(
            Name = uniq('TDF Entity'),
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://example.test'
        );
        applyOverrides(e, overrides);
        return e;
    }

    /** @description Build + insert a NetworkEntity__c with defaults + overrides. */
    public static NetworkEntity__c createNetworkEntity(Map<String, Object> overrides) {
        NetworkEntity__c e = buildNetworkEntity(overrides);
        insert e;
        return e;
    }

    /**
     * @description Bulk variant. Returns N inserted NetworkEntity__c records.
     *              Names are auto-uniquified; overrides apply to every row.
     */
    public static List<NetworkEntity__c> createNetworkEntities(Integer count, Map<String, Object> overrides) {
        List<NetworkEntity__c> rows = new List<NetworkEntity__c>();
        for (Integer i = 0; i < count; i++) {
            rows.add(buildNetworkEntity(overrides));
        }
        insert rows;
        return rows;
    }

    /** @description Get-or-create a default Vendor entity. Cached per test method. */
    public static NetworkEntity__c defaultVendor() {
        if (defaultVendorCache == null) {
            defaultVendorCache = createNetworkEntity(new Map<String, Object>{
                'Name' => uniq('TDF Vendor'),
                'EntityTypePk__c' => 'Vendor'
            });
        }
        return defaultVendorCache;
    }

    /** @description Get-or-create a default Client entity. Cached per test method. */
    public static NetworkEntity__c defaultClient() {
        if (defaultClientCache == null) {
            defaultClientCache = createNetworkEntity(new Map<String, Object>{
                'Name' => uniq('TDF Client'),
                'EntityTypePk__c' => 'Client'
            });
        }
        return defaultClientCache;
    }

    // ────────────────────────────────────────────────────────────────────
    // WorkItem__c
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) a WorkItem__c with safe defaults.
     *              BriefDescriptionTxt__c set, StatusPk__c='Active',
     *              StageNamePk__c='Backlog', ActivatedDateTime__c=now().
     */
    public static WorkItem__c buildWorkItem(Map<String, Object> overrides) {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = uniq('TDF WorkItem'),
            StatusPk__c = 'Active',
            StageNamePk__c = 'Backlog',
            ActivatedDateTime__c = Datetime.now()
        );
        applyOverrides(wi, overrides);
        return wi;
    }

    /**
     * @description Build + insert a WorkItem__c. By default brackets the DML
     *              with DeliveryWorkItemTriggerHandler.triggerDisabled=true so
     *              the test isn't measuring auto-WR / sync side-effects unless
     *              it wants to. Pass {'_runTriggers' => true} in overrides
     *              to opt back into the trigger.
     */
    public static WorkItem__c createWorkItem(Map<String, Object> overrides) {
        Boolean runTriggers = false;
        if (overrides != null && overrides.containsKey('_runTriggers')) {
            runTriggers = (Boolean) overrides.get('_runTriggers');
            overrides.remove('_runTriggers');
        }
        WorkItem__c wi = buildWorkItem(overrides);
        if (runTriggers) {
            insert wi;
        } else {
            Boolean prev = DeliveryWorkItemTriggerHandler.triggerDisabled;
            DeliveryWorkItemTriggerHandler.triggerDisabled = true;
            try {
                insert wi;
            } finally {
                DeliveryWorkItemTriggerHandler.triggerDisabled = prev;
            }
        }
        return wi;
    }

    /**
     * @description Bulk variant. Returns N inserted WorkItem__c with unique
     *              brief descriptions. Triggers are bypassed by default for
     *              speed; opt back in via {'_runTriggers'=>true}.
     */
    public static List<WorkItem__c> createWorkItems(Integer count, Map<String, Object> overrides) {
        Boolean runTriggers = false;
        if (overrides != null && overrides.containsKey('_runTriggers')) {
            runTriggers = (Boolean) overrides.get('_runTriggers');
            overrides.remove('_runTriggers');
        }
        List<WorkItem__c> rows = new List<WorkItem__c>();
        for (Integer i = 0; i < count; i++) {
            rows.add(buildWorkItem(overrides));
        }
        if (runTriggers) {
            insert rows;
        } else {
            Boolean prev = DeliveryWorkItemTriggerHandler.triggerDisabled;
            DeliveryWorkItemTriggerHandler.triggerDisabled = true;
            try {
                insert rows;
            } finally {
                DeliveryWorkItemTriggerHandler.triggerDisabled = prev;
            }
        }
        return rows;
    }

    // ────────────────────────────────────────────────────────────────────
    // WorkRequest__c — required Master-Detail parent of WorkLog__c
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) a WorkRequest__c. Caller MUST supply
     *              workItemId via overrides or parentId arg — WorkItemId__c
     *              is a required Master-Detail to WorkItem__c.
     */
    public static WorkRequest__c buildWorkRequest(Id workItemId, Map<String, Object> overrides) {
        WorkRequest__c wr = new WorkRequest__c(
            WorkItemId__c = workItemId,
            StatusPk__c = 'Active'
        );
        applyOverrides(wr, overrides);
        return wr;
    }

    /** @description Build + insert a WorkRequest__c. */
    public static WorkRequest__c createWorkRequest(Id workItemId, Map<String, Object> overrides) {
        WorkRequest__c wr = buildWorkRequest(workItemId, overrides);
        insert wr;
        return wr;
    }

    // ────────────────────────────────────────────────────────────────────
    // WorkLog__c — has TWO required parents:
    //   WorkItemLookup__c (lookup, optional but conventional)
    //   RequestId__c     (Master-Detail to WorkRequest__c, REQUIRED in
    //                     packaging-org context — see PR #770 feedback)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) a WorkLog__c. Auto-mints a per-WorkItem
     *              WorkRequest__c bridge on first call and caches it so
     *              stacked log inserts for the same WI share one bridge.
     *              workDate defaults to Date.today() — anchor on today so
     *              rolling-window math doesn't drag the current bucket to 0
     *              (see feedback_anchor_rolling_window_tests_on_today.md).
     */
    public static WorkLog__c buildWorkLog(Id workItemId, Decimal hours, Date workDate, Map<String, Object> overrides) {
        Id requestId = bridgeByWi.get(workItemId);
        if (requestId == null) {
            WorkRequest__c bridge = new WorkRequest__c(
                WorkItemId__c = workItemId,
                StatusPk__c = 'Active'
            );
            insert bridge;
            requestId = bridge.Id;
            bridgeByWi.put(workItemId, requestId);
        }
        WorkLog__c log = new WorkLog__c(
            WorkItemLookup__c = workItemId,
            RequestId__c = requestId,
            HoursLoggedNumber__c = hours == null ? 1 : hours,
            WorkDateDate__c = workDate == null ? Date.today() : workDate,
            WorkDescriptionTxt__c = 'TDF work log'
        );
        applyOverrides(log, overrides);
        return log;
    }

    /** @description Build + insert a single WorkLog__c. */
    public static WorkLog__c createWorkLog(Id workItemId, Decimal hours, Date workDate, Map<String, Object> overrides) {
        WorkLog__c log = buildWorkLog(workItemId, hours, workDate, overrides);
        insert log;
        return log;
    }

    /**
     * @description Convenience: weekly logs anchored on today, walking
     *              backward N weeks. The MOST RECENT log lands on
     *              Date.today() so rolling-window velocity math includes
     *              the current bucket. Hours list is consumed
     *              newest-to-oldest: hours[0] → today, hours[1] → -7d, ...
     */
    public static List<WorkLog__c> createWeeklyWorkLogs(Id workItemId, List<Decimal> hoursNewestFirst) {
        List<WorkLog__c> rows = new List<WorkLog__c>();
        if (hoursNewestFirst == null || hoursNewestFirst.isEmpty()) {
            return rows;
        }
        Date today = Date.today();
        for (Integer i = 0; i < hoursNewestFirst.size(); i++) {
            rows.add(buildWorkLog(workItemId, hoursNewestFirst.get(i), today.addDays(-7 * i), null));
        }
        insert rows;
        return rows;
    }

    /**
     * @description Bulk-insert a flat list of logs for a single WI. Each
     *              log gets `hoursPerLog` hours at `Date.today()`. Use this
     *              for capacity / sum-rollup tests that don't care about
     *              date distribution.
     */
    public static List<WorkLog__c> createWorkLogs(Id workItemId, Integer count, Decimal hoursPerLog) {
        List<WorkLog__c> rows = new List<WorkLog__c>();
        for (Integer i = 0; i < count; i++) {
            rows.add(buildWorkLog(workItemId, hoursPerLog, Date.today(), null));
        }
        insert rows;
        return rows;
    }

    // ────────────────────────────────────────────────────────────────────
    // WorkItemComment__c — Master-Detail to WorkItem__c via WorkItemId__c
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) a WorkItemComment__c. workItemId required
     *              (Master-Detail). Defaults SourcePk__c='Salesforce'.
     */
    public static WorkItemComment__c buildWorkItemComment(Id workItemId, String body, Map<String, Object> overrides) {
        WorkItemComment__c c = new WorkItemComment__c(
            WorkItemId__c = workItemId,
            BodyTxt__c = body == null ? 'TDF comment' : body,
            SourcePk__c = 'Salesforce',
            AuthorTxt__c = 'TDF'
        );
        applyOverrides(c, overrides);
        return c;
    }

    /** @description Build + insert a WorkItemComment__c. */
    public static WorkItemComment__c createWorkItemComment(Id workItemId, String body, Map<String, Object> overrides) {
        WorkItemComment__c c = buildWorkItemComment(workItemId, body, overrides);
        insert c;
        return c;
    }

    /**
     * @description Bulk variant. Returns N inserted comments on the same WI
     *              with auto-numbered bodies.
     */
    public static List<WorkItemComment__c> createWorkItemComments(Id workItemId, Integer count, Map<String, Object> overrides) {
        List<WorkItemComment__c> rows = new List<WorkItemComment__c>();
        for (Integer i = 0; i < count; i++) {
            rows.add(buildWorkItemComment(workItemId, 'TDF comment ' + String.valueOf(i + 1), overrides));
        }
        insert rows;
        return rows;
    }

    // ────────────────────────────────────────────────────────────────────
    // SyncItem__c — sync ledger. No required MD; just safe picklist defaults.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) a SyncItem__c. Defaults:
     *              ObjectTypePk__c='WorkItem__c', StatusPk__c='Queued',
     *              DirectionPk__c='Outbound', ChangeTypeTxt__c='record_change'.
     */
    public static SyncItem__c buildSyncItem(Map<String, Object> overrides) {
        SyncItem__c s = new SyncItem__c(
            ObjectTypePk__c = 'WorkItem__c',
            StatusPk__c = 'Queued',
            DirectionPk__c = 'Outbound',
            ChangeTypeTxt__c = 'record_change',
            PayloadTxt__c = '{}'
        );
        applyOverrides(s, overrides);
        return s;
    }

    /** @description Build + insert a SyncItem__c. */
    public static SyncItem__c createSyncItem(Map<String, Object> overrides) {
        SyncItem__c s = buildSyncItem(overrides);
        insert s;
        return s;
    }

    /** @description Bulk-insert N SyncItem__c rows. */
    public static List<SyncItem__c> createSyncItems(Integer count, Map<String, Object> overrides) {
        List<SyncItem__c> rows = new List<SyncItem__c>();
        for (Integer i = 0; i < count; i++) {
            rows.add(buildSyncItem(overrides));
        }
        insert rows;
        return rows;
    }

    // ────────────────────────────────────────────────────────────────────
    // Feature__c — Layer 4 feature cockpit runtime state. No required MD;
    // FeatureDefinitionTxt__c is just a Text/externalId that points at the
    // matching package-shipped FeatureDefinition__mdt DeveloperName.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) a Feature__c with safe defaults.
     *              Name + FeatureDefinitionTxt__c are uniquified, EnabledDateTime__c
     *              defaults to Datetime.now(). Override any field via the map
     *              (in particular, callers usually pass a matching __mdt
     *              DeveloperName via 'FeatureDefinitionTxt__c').
     */
    public static Feature__c buildFeature(Map<String, Object> overrides) {
        String defName = uniq('TestFeature');
        Feature__c f = new Feature__c(
            Name = defName,
            FeatureDefinitionTxt__c = defName,
            EnabledDateTime__c = Datetime.now()
        );
        applyOverrides(f, overrides);
        return f;
    }

    /** @description Build + insert a Feature__c with defaults + overrides. */
    public static Feature__c createFeature(Map<String, Object> overrides) {
        Feature__c f = buildFeature(overrides);
        insert f;
        return f;
    }

    /**
     * @description Bulk variant. Returns N inserted Feature__c records with
     *              unique names + FeatureDefinitionTxt__c values. Overrides
     *              apply to every row (but Name + FeatureDefinitionTxt__c
     *              are uniquified per row before overrides land).
     */
    public static List<Feature__c> createFeatures(Integer count, Map<String, Object> overrides) {
        List<Feature__c> rows = new List<Feature__c>();
        for (Integer i = 0; i < count; i++) {
            rows.add(buildFeature(overrides));
        }
        insert rows;
        return rows;
    }

    // ────────────────────────────────────────────────────────────────────
    // FeatureDependency__c — junction object between Feature__c records.
    // BlockingFeatureLookup__c and BlockedFeatureLookup__c are required
    // Lookups (deleteConstraint=Restrict). TypePk + CascadeDirectionPk are
    // restricted GVS-backed picklists; defaults below are allowlist-safe.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) a FeatureDependency__c. Both feature lookups
     *              required. Defaults: TypePk='Hard', CascadeDirection='Both'.
     */
    public static FeatureDependency__c buildFeatureDependency(Id blockingId, Id blockedId, Map<String, Object> overrides) {
        FeatureDependency__c dep = new FeatureDependency__c(
            BlockingFeatureLookup__c = blockingId,
            BlockedFeatureLookup__c = blockedId,
            TypePk__c = 'Hard',
            CascadeDirectionPk__c = 'Both'
        );
        applyOverrides(dep, overrides);
        return dep;
    }

    /** @description Build + insert a FeatureDependency__c with safe defaults. */
    public static FeatureDependency__c newFeatureDependency(Id blockingId, Id blockedId) {
        return createFeatureDependency(blockingId, blockedId, null);
    }

    /** @description Build + insert a FeatureDependency__c with overrides. */
    public static FeatureDependency__c createFeatureDependency(Id blockingId, Id blockedId, Map<String, Object> overrides) {
        FeatureDependency__c dep = buildFeatureDependency(blockingId, blockedId, overrides);
        insert dep;
        return dep;
    }

    // ────────────────────────────────────────────────────────────────────
    // FeatureToggleRequest__c / FeatureToggleApproval__c — PR 7 approval
    // framework. Request requires a Feature__c parent (Lookup, required).
    // Approval requires both a request and feature parent (Lookups, required).
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) a FeatureToggleRequest__c with safe defaults.
     *              ActionPk__c='Enable', StatusPk__c='Pending',
     *              RequestedByUserLookup__c=running user,
     *              RequestedDateTime__c=now. featureId required (Lookup).
     * @param featureId Feature__c parent.
     * @param overrides Optional field overrides.
     * @return Unpersisted FeatureToggleRequest__c.
     */
    public static FeatureToggleRequest__c buildFeatureToggleRequest(Id featureId, Map<String, Object> overrides) {
        FeatureToggleRequest__c req = new FeatureToggleRequest__c(
            FeatureLookup__c = featureId,
            ActionPk__c = 'Enable',
            StatusPk__c = 'Pending',
            RequestedByUserLookup__c = UserInfo.getUserId(),
            RequestedDateTime__c = Datetime.now()
        );
        applyOverrides(req, overrides);
        return req;
    }

    /**
     * @description Build + insert a FeatureToggleRequest__c with safe defaults.
     * @param featureId Feature__c parent.
     * @return Inserted FeatureToggleRequest__c.
     */
    public static FeatureToggleRequest__c newFeatureToggleRequest(Id featureId) {
        FeatureToggleRequest__c req = buildFeatureToggleRequest(featureId, null);
        insert req;
        return req;
    }

    /**
     * @description Build (no DML) a FeatureToggleApproval__c with safe defaults.
     *              StepNumber__c=1, StatusPk__c='Pending',
     *              RequiredDateTime__c=now. Both parent ids required.
     * @param requestId FeatureToggleRequest__c parent.
     * @param featureId Feature__c referenced by the approval row.
     * @param overrides Optional field overrides.
     * @return Unpersisted FeatureToggleApproval__c.
     */
    public static FeatureToggleApproval__c buildFeatureToggleApproval(Id requestId, Id featureId, Map<String, Object> overrides) {
        FeatureToggleApproval__c row = new FeatureToggleApproval__c(
            RequestLookup__c = requestId,
            FeatureLookup__c = featureId,
            StepNumber__c = 1,
            StatusPk__c = 'Pending',
            RequiredDateTime__c = Datetime.now()
        );
        applyOverrides(row, overrides);
        return row;
    }

    /**
     * @description Build + insert a FeatureToggleApproval__c with safe defaults.
     * @param requestId FeatureToggleRequest__c parent.
     * @param featureId Feature__c referenced by the approval row.
     * @return Inserted FeatureToggleApproval__c.
     */
    public static FeatureToggleApproval__c newFeatureToggleApproval(Id requestId, Id featureId) {
        FeatureToggleApproval__c row = buildFeatureToggleApproval(requestId, featureId, null);
        insert row;
        return row;
    }

    // ────────────────────────────────────────────────────────────────────
    // OnboardingProgress__c — runtime per-user per-track state (PR 3).
    // No required Master-Detail; UserLookup__c defaults to the running user.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) an OnboardingProgress__c with safe defaults.
     *              TrackTxt__c is uniquified, UserLookup__c=running user,
     *              StartedDateTime__c=now, QuizAttemptsNumber__c=0.
     */
    public static OnboardingProgress__c buildOnboardingProgress(Map<String, Object> overrides) {
        String trackName = uniq('TDF_Track');
        OnboardingProgress__c p = new OnboardingProgress__c(
            Name = trackName + ' — TDF',
            TrackTxt__c = trackName,
            UserLookup__c = UserInfo.getUserId(),
            StartedDateTime__c = Datetime.now(),
            QuizAttemptsNumber__c = 0
        );
        applyOverrides(p, overrides);
        return p;
    }

    /** @description Build + insert an OnboardingProgress__c. */
    public static OnboardingProgress__c newOnboardingProgress(Map<String, Object> overrides) {
        OnboardingProgress__c p = buildOnboardingProgress(overrides);
        insert p;
        return p;
    }

    // ScratchOrgInstance__c — Layer 6 dev-loop mirror row. No required
    // Master-Detail; both Lookups (WorkItem + Feature) are optional. Name
    // defaults to the OrgIdTxt__c so tests can pick rows out without
    // knowing the SF id.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) a ScratchOrgInstance__c with safe defaults.
     *              OrgIdTxt__c + Name are uniquified, StatePk__c='Active',
     *              CciFlowTxt__c='dev_org', LastSyncDateTime__c=now,
     *              ExpiresDateTime__c=now+7d, LoginUrl__c=https://example.test.
     * @param overrides Optional field overrides.
     * @return Unpersisted ScratchOrgInstance__c.
     */
    public static ScratchOrgInstance__c buildScratchOrgInstance(Map<String, Object> overrides) {
        // uniq() may return a shorter string than 15 chars (counter-only suffix).
        // Pad with non-numeric placeholder chars before truncating so substring
        // never throws StringException. Using letters here so PMD doesn't flag
        // the zero-padding as a hardcoded Id literal.
        String orgId = (uniq('00DT0') + 'xxxxxxxxxxxxxxx').substring(0, 15);
        ScratchOrgInstance__c soi = new ScratchOrgInstance__c(
            Name = orgId,
            OrgIdTxt__c = orgId,
            BranchTxt__c = uniq('feature/tdf'),
            LoginUrl__c = 'https://example.test/login',
            StatePk__c = 'Active',
            CciFlowTxt__c = 'dev_org',
            LastSyncDateTime__c = Datetime.now(),
            ExpiresDateTime__c = Datetime.now().addDays(7)
        );
        applyOverrides(soi, overrides);
        return soi;
    }

    /**
     * @description Build + insert a ScratchOrgInstance__c with safe defaults.
     * @return Inserted row.
     */
    public static ScratchOrgInstance__c newScratchOrgInstance() {
        ScratchOrgInstance__c soi = buildScratchOrgInstance(null);
        insert soi;
        return soi;
    }

    /**
     * @description Build + insert a ScratchOrgInstance__c with overrides.
     * @param overrides Field overrides applied on top of defaults.
     * @return Inserted row.
     */
    public static ScratchOrgInstance__c createScratchOrgInstance(Map<String, Object> overrides) {
        ScratchOrgInstance__c soi = buildScratchOrgInstance(overrides);
        insert soi;
        return soi;
    }

    // ────────────────────────────────────────────────────────────────────
    // DatasetTemplate__c / DatasetTemplateAssignment__c — Layer 7 data
    // seeding templates. DatasetTemplate__c has no required parent (Feature
    // and NetworkEntity lookups are optional, SetNull). Assignment requires
    // a DatasetTemplate__c parent (Lookup, required, Restrict on delete).
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build (no DML) a DatasetTemplate__c with safe defaults.
     *              Name uniquified, ApexScriptPathTxt__c defaults to the
     *              legacy whole-org loader path.
     * @param overrides Optional field overrides.
     * @return Unpersisted DatasetTemplate__c.
     */
    public static DatasetTemplate__c buildDatasetTemplate(Map<String, Object> overrides) {
        DatasetTemplate__c t = new DatasetTemplate__c(
            Name = uniq('TDF Dataset'),
            DescriptionTxt__c = 'TDF placeholder dataset template',
            ApexScriptPathTxt__c = 'scripts/load-demo-data.apex',
            RecordCountEstimateNumber__c = 10
        );
        applyOverrides(t, overrides);
        return t;
    }

    /**
     * @description Build + insert a DatasetTemplate__c with safe defaults.
     * @return Inserted DatasetTemplate__c.
     */
    public static DatasetTemplate__c newDatasetTemplate() {
        return createDatasetTemplate(null);
    }

    /**
     * @description Build + insert a DatasetTemplate__c with overrides.
     * @param overrides Optional field overrides.
     * @return Inserted DatasetTemplate__c.
     */
    public static DatasetTemplate__c createDatasetTemplate(Map<String, Object> overrides) {
        DatasetTemplate__c t = buildDatasetTemplate(overrides);
        insert t;
        return t;
    }

    /**
     * @description Build (no DML) a DatasetTemplateAssignment__c with safe
     *              defaults. templateId is required (Lookup, Restrict).
     *              Defaults: LoadedDateTime__c=now,
     *              LoadedByUserLookup__c=running user, OutcomePk__c='Success',
     *              RecordsLoadedNumber__c=0.
     * @param templateId DatasetTemplate__c parent.
     * @param overrides Optional field overrides.
     * @return Unpersisted DatasetTemplateAssignment__c.
     */
    public static DatasetTemplateAssignment__c buildDatasetTemplateAssignment(
        Id templateId, Map<String, Object> overrides
    ) {
        DatasetTemplateAssignment__c a = new DatasetTemplateAssignment__c(
            DatasetTemplateLookup__c = templateId,
            LoadedDateTime__c = Datetime.now(),
            LoadedByUserLookup__c = UserInfo.getUserId(),
            OutcomePk__c = 'Success',
            RecordsLoadedNumber__c = 0
        );
        applyOverrides(a, overrides);
        return a;
    }

    /**
     * @description Build + insert a DatasetTemplateAssignment__c with safe defaults.
     * @param templateId DatasetTemplate__c parent.
     * @return Inserted DatasetTemplateAssignment__c.
     */
    public static DatasetTemplateAssignment__c newDatasetTemplateAssignment(Id templateId) {
        DatasetTemplateAssignment__c a = buildDatasetTemplateAssignment(templateId, null);
        insert a;
        return a;
    }

    // ────────────────────────────────────────────────────────────────────
    // INTERNAL — apply Map<String,Object> overrides onto an SObject.
    // Skips null map. Generic enough to handle any field type the caller
    // throws at it (Decimal, Date, Datetime, Id, String, Boolean).
    // ────────────────────────────────────────────────────────────────────

    private static void applyOverrides(SObject record, Map<String, Object> overrides) {
        if (overrides == null || overrides.isEmpty()) {
            return;
        }
        for (String fieldName : overrides.keySet()) {
            record.put(fieldName, overrides.get(fieldName));
        }
    }
}
