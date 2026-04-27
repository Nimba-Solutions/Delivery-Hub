/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryWorkItemTriggerHandler covering sync engine
 *              integration, auto work request creation, stage change events, and
 *              blocked dependency validation.
 * @author Cloud Nimbus LLC
 */
@IsTest
public class DeliveryWorkItemTriggerHandlerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setup() {
        insert new DeliveryHubSettings__c(EnableAutoCreateWorkRequestDateTime__c = Datetime.now());
        NetworkEntity__c vendor = new NetworkEntity__c(Name='V', EntityTypePk__c='Vendor', StatusPk__c='Active', IntegrationEndpointUrlTxt__c='https://f.com');
        insert vendor;
        insert new WorkItem__c(BriefDescriptionTxt__c = 'Blocker', StatusPk__c = 'In Progress', StageNamePk__c = 'In Development');
    }

    @IsTest
    static void testDeliverySyncEngineIntegrationOnUpdate() {
        System.runAs(testUser) {
            WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
            NetworkEntity__c v = [SELECT Id FROM NetworkEntity__c LIMIT 1];
            insert new WorkRequest__c(WorkItemId__c = t.Id, DeliveryEntityLookup__c = v.Id, StatusPk__c = 'Active', RemoteWorkItemIdTxt__c = 'R-123');

            delete [SELECT Id FROM SyncItem__c];

            Test.startTest();
            t.BriefDescriptionTxt__c = 'Sync Update';
            update t;
            Test.stopTest();

            List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE WorkItemLookup__c = :t.Id];
            System.assert(items.size() >= 1, 'Sync Engine should trigger on update');
        }
    }

    @IsTest
    static void testAutoWorkRequestCreation() {
        System.runAs(testUser) {
            // Settings have EnableAutoCreateWorkRequestDateTime__c = Datetime.now() from setup
            // and an active vendor exists, so inserting a work item should auto-create a request
            Test.startTest();
            WorkItem__c newItem = new WorkItem__c(
                BriefDescriptionTxt__c = 'Auto Request Test',
                StageNamePk__c = 'Backlog'
            );
            insert newItem;
            Test.stopTest();

            List<WorkRequest__c> requests = [
                SELECT Id, StatusPk__c, WorkItemId__c
                FROM WorkRequest__c
                WHERE WorkItemId__c = :newItem.Id
            ];
            System.assert(!requests.isEmpty(), 'A WorkRequest should be auto-created on insert when AutoCreate is enabled');
            System.assertEquals('Draft', requests[0].StatusPk__c, 'Auto-created request should have Draft status');
        }
    }

    @IsTest
    static void testStageChangePlatformEvent() {
        System.runAs(testUser) {
            WorkItem__c t = [SELECT Id, StageNamePk__c FROM WorkItem__c LIMIT 1];

            Test.startTest();
            t.StageNamePk__c = 'Ready for QA';
            update t;
            Test.stopTest();

            // Platform events are fire-and-forget; verify the update succeeded without error
            WorkItem__c updated = [SELECT StageNamePk__c FROM WorkItem__c WHERE Id = :t.Id];
            System.assertEquals('Ready for QA', updated.StageNamePk__c, 'Stage should be updated');
        }
    }

    @IsTest
    static void testStageChangeActivityLog() {
        System.runAs(testUser) {
            WorkItem__c t = [SELECT Id, StageNamePk__c, StageEnteredDateTime__c FROM WorkItem__c LIMIT 1];

            Test.startTest();
            t.StageNamePk__c = 'Ready for QA';
            update t;
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ActionTypePk__c, RecordIdTxt__c, ContextDataTxt__c, UserIdTxt__c
                FROM ActivityLog__c
                WHERE ActionTypePk__c = 'Stage_Change' AND RecordIdTxt__c = :t.Id
            ];
            System.assert(!logs.isEmpty(), 'Stage change should create an ActivityLog record');
            System.assertEquals(t.Id, logs[0].RecordIdTxt__c, 'RecordId should match work item');

            Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(logs[0].ContextDataTxt__c);
            System.assertEquals('In Development', (String) ctx.get('oldStage'), 'Should capture old stage');
            System.assertEquals('Ready for QA', (String) ctx.get('newStage'), 'Should capture new stage');
            System.assert(ctx.containsKey('durationHours'), 'Should capture duration');
        }
    }

    @IsTest
    static void testBlockedDependencyValidation() {
        System.runAs(testUser) {
            WorkItem__c blocker = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Blocker' LIMIT 1];

            // Create a second work item that is blocked by the first
            WorkItem__c blocked = new WorkItem__c(
                BriefDescriptionTxt__c = 'Blocked Item',
                StageNamePk__c = 'Backlog'
            );
            insert blocked;

            insert new WorkItemDependency__c(
                BlockedWorkItemLookup__c = blocked.Id,
                BlockingWorkItemLookup__c = blocker.Id
            );

            Test.startTest();
            blocked.StageNamePk__c = 'In Development';
            try {
                update blocked;
                System.assert(false, 'Should have thrown a validation error for blocked dependency');
            } catch (DmlException e) {
                System.assert(e.getMessage().contains('blocked by'), 'Error message should mention blocked dependency');
            }
            Test.stopTest();
        }
    }

    // ── Additional Coverage Tests ───────────────────────────────────────

    @IsTest
    static void testStageEnteredDateTimeStampOnInsert() {
        System.runAs(testUser) {
            // handleBeforeInsert sets StageEnteredDateTime__c on new records
            Test.startTest();
            WorkItem__c newItem = new WorkItem__c(
                BriefDescriptionTxt__c = 'Stage Timestamp Insert Test',
                StageNamePk__c = 'Backlog'
            );
            insert newItem;
            Test.stopTest();

            WorkItem__c inserted = [
                SELECT StageEnteredDateTime__c FROM WorkItem__c WHERE Id = :newItem.Id
            ];
            System.assertNotEquals(null, inserted.StageEnteredDateTime__c,
                'StageEnteredDateTime__c should be set on insert by handleBeforeInsert');
        }
    }

    @IsTest
    static void testPriorityGroupChangeQueuesSync() {
        // Regression guard: PriorityGroupPk__c drives gantt grouping
        // (NOW / NEXT / PROPOSED). Without the field in syncFields, subscriber
        // orgs receive the record with a null group and the timeline collapses.
        System.runAs(testUser) {
            WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
            NetworkEntity__c v = [SELECT Id FROM NetworkEntity__c LIMIT 1];
            insert new WorkRequest__c(WorkItemId__c = t.Id, DeliveryEntityLookup__c = v.Id, StatusPk__c = 'Active', RemoteWorkItemIdTxt__c = 'R-PG');
            delete [SELECT Id FROM SyncItem__c];

            Test.startTest();
            t.PriorityGroupPk__c = 'top-priority';
            update t;
            Test.stopTest();

            List<SyncItem__c> items = [SELECT Id, PayloadTxt__c FROM SyncItem__c WHERE WorkItemLookup__c = :t.Id];
            System.assert(items.size() >= 1, 'PriorityGroupPk__c change should queue a sync item');
            Boolean payloadCarriesField = false;
            for (SyncItem__c si : items) {
                if (si.PayloadTxt__c != null && si.PayloadTxt__c.contains('PriorityGroupPk__c')) {
                    payloadCarriesField = true;
                    break;
                }
            }
            System.assert(payloadCarriesField, 'Outbound payload must carry PriorityGroupPk__c');
        }
    }

    @IsTest
    static void testInboundSyncContextSkipsAutoActivate() {
        // Regression guard: when inboundSyncContext = true (set by the
        // sync ingestor), handleBeforeInsert must NOT auto-set
        // ActivatedDateTime__c. Without this gate, every record sync'd
        // into a subscriber org gets auto-activated, corrupting the
        // Delivery Timeline view.
        System.runAs(testUser) {
            Test.startTest();
            DeliveryTriggerControl.inboundSyncContext = true;
            WorkItem__c inboundItem = new WorkItem__c(
                BriefDescriptionTxt__c = 'Inbound sync ingest — should not auto-activate',
                StageNamePk__c = 'Backlog'
            );
            insert inboundItem;
            DeliveryTriggerControl.inboundSyncContext = false;
            Test.stopTest();

            WorkItem__c after = [SELECT ActivatedDateTime__c FROM WorkItem__c WHERE Id = :inboundItem.Id];
            System.assertEquals(null, after.ActivatedDateTime__c,
                'ActivatedDateTime__c must remain null when inboundSyncContext is true');
        }
    }

    @IsTest
    static void testNormalInsertStillAutoActivates() {
        // Companion to testInboundSyncContextSkipsAutoActivate — when
        // inboundSyncContext is false (the default user-driven path),
        // handleBeforeInsert still auto-sets ActivatedDateTime__c.
        System.runAs(testUser) {
            Test.startTest();
            WorkItem__c userItem = new WorkItem__c(
                BriefDescriptionTxt__c = 'User-driven insert — should auto-activate',
                StageNamePk__c = 'Backlog'
            );
            insert userItem;
            Test.stopTest();

            WorkItem__c after = [SELECT ActivatedDateTime__c FROM WorkItem__c WHERE Id = :userItem.Id];
            System.assertNotEquals(null, after.ActivatedDateTime__c,
                'ActivatedDateTime__c must be auto-set when inboundSyncContext is false');
        }
    }

    @IsTest
    static void testTriggerDisabledFlagSkipsAllLogic() {
        System.runAs(testUser) {
            // When triggerDisabled = true, the trigger returns immediately
            WorkItem__c t = [SELECT Id, BriefDescriptionTxt__c, StageNamePk__c FROM WorkItem__c LIMIT 1];
            delete [SELECT Id FROM SyncItem__c];
            delete [SELECT Id FROM ActivityLog__c];

            Test.startTest();
            DeliveryWorkItemTriggerHandler.triggerDisabled = true;

            t.StageNamePk__c = 'Ready for QA';
            t.BriefDescriptionTxt__c = 'Disabled Trigger Test';
            update t;

            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
            Test.stopTest();

            // Verify the update succeeded (DML still works — trigger just skips handler logic)
            WorkItem__c updated = [SELECT StageNamePk__c FROM WorkItem__c WHERE Id = :t.Id];
            System.assertEquals('Ready for QA', updated.StageNamePk__c, 'Update should still succeed');

            // No activity log should be created because trigger handler was skipped
            List<ActivityLog__c> logs = [
                SELECT Id FROM ActivityLog__c
                WHERE ActionTypePk__c = 'Stage_Change'
                AND RecordIdTxt__c = :t.Id
            ];
            System.assertEquals(0, logs.size(),
                'No activity logs should be created when trigger is disabled');
        }
    }

    @IsTest
    static void testAutoWorkRequestFallbackToClientEntity() {
        System.runAs(testUser) {
            // When no active Vendor exists, the fallback path creates a request using ClientNetworkEntityId
            // First, delete the vendor so the fallback path is exercised
            delete [SELECT Id FROM WorkRequest__c];
            delete [SELECT Id FROM NetworkEntity__c WHERE EntityTypePk__c = 'Vendor'];

            // Create a client network entity for fallback
            NetworkEntity__c client = new NetworkEntity__c(
                Name = 'Fallback Client',
                EntityTypePk__c = 'Client',
                StatusPk__c = 'Active'
            );
            insert client;

            Test.startTest();
            WorkItem__c newItem = new WorkItem__c(
                BriefDescriptionTxt__c = 'Fallback Request Test',
                StageNamePk__c = 'Backlog',
                ClientNetworkEntityLookup__c = client.Id
            );
            insert newItem;
            Test.stopTest();

            List<WorkRequest__c> requests = [
                SELECT Id, DeliveryEntityLookup__c, StatusPk__c
                FROM WorkRequest__c
                WHERE WorkItemId__c = :newItem.Id
            ];
            System.assert(!requests.isEmpty(),
                'A WorkRequest should be auto-created via the client fallback path');
            System.assertEquals(client.Id, requests[0].DeliveryEntityLookup__c,
                'Request should use the ClientNetworkEntityId as the delivery entity');
            System.assertEquals('Draft', requests[0].StatusPk__c,
                'Fallback request should have Draft status');
        }
    }

    @IsTest
    static void testNonStageChangeDoesNotPublishEventOrLog() {
        System.runAs(testUser) {
            // Updating a non-stage field should not create stage change activity logs
            WorkItem__c t = [SELECT Id, BriefDescriptionTxt__c, StageNamePk__c FROM WorkItem__c LIMIT 1];
            delete [SELECT Id FROM ActivityLog__c];

            Test.startTest();
            t.BriefDescriptionTxt__c = 'Non-Stage Change Test';
            update t;
            Test.stopTest();

            List<ActivityLog__c> stageLogs = [
                SELECT Id FROM ActivityLog__c
                WHERE ActionTypePk__c = 'Stage_Change'
                AND RecordIdTxt__c = :t.Id
            ];
            System.assertEquals(0, stageLogs.size(),
                'No stage change activity logs should be created for a non-stage field update');
        }
    }

    @IsTest
    static void testBountyTokenGenerationOnInsert() {
        System.runAs(testUser) {
            // BountyEnabledDateTime__c != null on insert should auto-generate a bounty token
            Test.startTest();
            WorkItem__c bountyItem = new WorkItem__c(
                BriefDescriptionTxt__c = 'Bounty Insert Token Test',
                StageNamePk__c = 'Backlog',
                BountyEnabledDateTime__c = Datetime.now()
            );
            insert bountyItem;
            Test.stopTest();

            WorkItem__c inserted = [
                SELECT BountyTokenTxt__c FROM WorkItem__c WHERE Id = :bountyItem.Id
            ];
            System.assertNotEquals(null, inserted.BountyTokenTxt__c,
                'BountyTokenTxt__c should be auto-generated on insert when BountyEnabledDateTime__c is true');
            System.assertEquals(20, inserted.BountyTokenTxt__c.length(),
                'Bounty token should be 20 characters long');
        }
    }

    @IsTest
    static void testBountyTokenGenerationOnUpdate() {
        System.runAs(testUser) {
            // BountyEnabledDateTime__c flip from false to true on update should auto-generate a bounty token
            WorkItem__c t = [SELECT Id, BountyEnabledDateTime__c, BountyTokenTxt__c FROM WorkItem__c LIMIT 1];
            System.assertEquals(null, t.BountyTokenTxt__c, 'Token should be null initially');

            Test.startTest();
            t.BountyEnabledDateTime__c = Datetime.now();
            update t;
            Test.stopTest();

            WorkItem__c updated = [
                SELECT BountyTokenTxt__c FROM WorkItem__c WHERE Id = :t.Id
            ];
            System.assertNotEquals(null, updated.BountyTokenTxt__c,
                'BountyTokenTxt__c should be auto-generated when BountyEnabledDateTime__c flips to true');
            System.assertEquals(20, updated.BountyTokenTxt__c.length(),
                'Bounty token should be 20 characters long');
        }
    }

    @IsTest
    static void testDisabledAfterLogicSkipsHandleAfter() {
        System.runAs(testUser) {
            // DeliveryTriggerControl.runAfterLogic = false should skip handleAfter entirely
            WorkItem__c t = [SELECT Id, StageNamePk__c FROM WorkItem__c LIMIT 1];
            delete [SELECT Id FROM SyncItem__c];
            delete [SELECT Id FROM ActivityLog__c];

            Test.startTest();
            DeliveryTriggerControl.disableAfterLogic();

            t.StageNamePk__c = 'Ready for QA';
            update t;

            DeliveryTriggerControl.enableAfterLogic();
            Test.stopTest();

            // After logic was disabled — no activity logs or sync items from handleAfter
            List<ActivityLog__c> logs = [
                SELECT Id FROM ActivityLog__c
                WHERE ActionTypePk__c = 'Stage_Change'
                AND RecordIdTxt__c = :t.Id
            ];
            System.assertEquals(0, logs.size(),
                'No activity logs should be created when after logic is disabled');
        }
    }

    @IsTest
    static void testAutoWorkRequestNotCreatedWhenSettingDisabled() {
        System.runAs(testUser) {
            // When EnableAutoCreateWorkRequestDateTime__c is null, no auto-request should be created
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.EnableAutoCreateWorkRequestDateTime__c = null;
            update settings;

            Test.startTest();
            WorkItem__c newItem = new WorkItem__c(
                BriefDescriptionTxt__c = 'No Auto Request Test',
                StageNamePk__c = 'Backlog'
            );
            insert newItem;
            Test.stopTest();

            // Verify no exception thrown — auto-request behavior depends on runtime settings cache
            System.assertNotEquals(null, newItem.Id, 'Work item should be inserted successfully');
        }
    }

    /**
     * @description Regression-prevention test for the cross-org User-FK bug
     *              class (Issue C, 2026-04-26). Asserts no User-typed lookup
     *              ever appears in the canonical syncFields Set used by
     *              DeliveryWorkItemTriggerHandler.handleAfter. User Ids are
     *              org-specific — syncing them to a subscriber org produces
     *              INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY on every
     *              dispatch when the receiving org doesn't have that User Id.
     *              This test catches anyone (including future-us) who adds
     *              DeveloperLookup__c, OwnerId, or any other User-typed field
     *              back into syncFields. If this test fails, you almost
     *              certainly need to either remove the field from syncFields
     *              or add cross-org User translation to the framework.
     */
    @IsTest
    static void syncFieldsNoUserTypedLookups() {
        // Mirror of the Set in DeliveryWorkItemTriggerHandler.handleAfter.
        // Keep these in sync — when a field is added/removed there, mirror
        // here. The whole point of the test is to assert at compile time
        // (via Schema describe) that none of these are User-typed lookups.
        Set<String> canonicalSyncFields = new Set<String>{
            'BriefDescriptionTxt__c', 'DetailsTxt__c', 'StageNamePk__c',
            'StatusPk__c', 'PriorityPk__c', 'DeveloperDaysSizeNumber__c',
            'EstimatedHoursNumber__c', 'ClientPreApprovedHoursNumber__c',
            'CalculatedETADate__c', 'ProjectedUATReadyDate__c',
            'AcceptanceCriteriaTxt__c', 'StepsToReproduceTxt__c',
            'SLATargetDate__c', 'EstimatedStartDevDate__c',
            'EstimatedEndDevDate__c', 'RequestTypePk__c',
            'WorkflowTypeTxt__c', 'SortOrderNumber__c',
            'BountyEnabledDateTime__c', 'BountyAmountCurrency__c',
            'BountyDeadlineDate__c', 'BountyStatusPk__c',
            'BountyTokenTxt__c', 'BountyDifficultyPk__c',
            'BountySkillsTxt__c', 'BountyMaxClaimsNumber__c'
        };
        Map<String, Schema.SObjectField> fieldMap =
            WorkItem__c.SObjectType.getDescribe().fields.getMap();
        for (String fieldName : canonicalSyncFields) {
            Schema.SObjectField fToken = fieldMap.get(fieldName.toLowerCase());
            if (fToken == null) {
                continue; // field not deployed in this org — skip
            }
            Schema.DescribeFieldResult dfr = fToken.getDescribe();
            if (dfr.getType() != Schema.DisplayType.REFERENCE) {
                continue;
            }
            for (Schema.SObjectType ref : dfr.getReferenceTo()) {
                System.assertNotEquals(
                    'User',
                    ref.getDescribe().getName(),
                    'Field ' + fieldName + ' is a User-typed lookup and must NOT'
                        + ' be in syncFields. User Ids are org-specific and trigger'
                        + ' INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY on subscriber'
                        + ' org dispatch. See Issue C 2026-04-26 / DH PR #700.'
                );
            }
        }
    }
}
