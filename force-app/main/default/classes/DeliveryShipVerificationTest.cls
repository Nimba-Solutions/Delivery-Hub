/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for the Deploy-to-Prod ship-verification rails (PR3 of
 *               the work-approval queue): entering 'Deployed to Prod' assigns
 *               the configured approver as the verifier (before-update, no
 *               extra DML) and pings them via the notification queueable
 *               (after-update). Apex tests cannot assert
 *               Messaging.CustomNotification.send() directly (the managed
 *               test runner short-circuits delivery — see
 *               DeliveryNotificationServiceTest); the contract asserted here
 *               is the trackable side effect (verifier assignment) plus the
 *               notification path completing without exception. Non-deploy
 *               stage changes and blank / malformed
 *               DeliveryHubSettings__c.ApproverUserIdTxt__c values must all
 *               no-op silently.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryShipVerificationTest {

    private static final String STAGE_DEPLOYING = 'Deploying';
    private static final String STAGE_DEPLOYED = 'Deployed to Prod';

    /**
     * @description Writes ApproverUserIdTxt__c on the org-default settings.
     * @param value User id string, or null to blank the setting.
     */
    private static void setApproverSetting(String value) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.ApproverUserIdTxt__c = value;
        upsert settings;
    }

    /**
     * @description Seeds a WorkItem__c parked at the given stage (insert
     *              trigger side effects bypassed; later updates run live).
     * @param stage StageNamePk__c value.
     * @return The inserted item.
     */
    private static WorkItem__c seedItemAt(String stage) {
        return TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => stage
        });
    }

    /**
     * @description Stage change INTO 'Deployed to Prod' with a configured
     *              approver: the item is handed to the approver
     *              (DeveloperLookup__c) for verification and the notification
     *              path runs to completion without exception.
     */
    @IsTest
    static void testDeployStageEntryAssignsVerifierAndNotifies() {
        setApproverSetting(String.valueOf(UserInfo.getUserId()));
        WorkItem__c wi = seedItemAt(STAGE_DEPLOYING);

        Test.startTest();
        update new WorkItem__c(Id = wi.Id, StageNamePk__c = STAGE_DEPLOYED);
        Test.stopTest();

        WorkItem__c after = [
            SELECT StageNamePk__c, DeveloperLookup__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(STAGE_DEPLOYED, after.StageNamePk__c,
            'stage update should land');
        System.assertEquals(UserInfo.getUserId(), after.DeveloperLookup__c,
            'entering the deploy stage should assign the configured approver as verifier');
    }

    /**
     * @description Bulk: several items entering the deploy stage in ONE
     *              transaction all get the verifier assigned; the
     *              notification fans into a single summarized ping (no
     *              per-row exception, no per-row queueable storm).
     */
    @IsTest
    static void testBulkDeployStageEntryAssignsAllRows() {
        setApproverSetting(String.valueOf(UserInfo.getUserId()));
        List<WorkItem__c> items = new List<WorkItem__c>{
            seedItemAt(STAGE_DEPLOYING), seedItemAt(STAGE_DEPLOYING), seedItemAt(STAGE_DEPLOYING)
        };
        List<WorkItem__c> updates = new List<WorkItem__c>();
        for (WorkItem__c wi : items) {
            updates.add(new WorkItem__c(Id = wi.Id, StageNamePk__c = STAGE_DEPLOYED));
        }

        Test.startTest();
        update updates;
        Test.stopTest();

        for (WorkItem__c after : [
            SELECT DeveloperLookup__c FROM WorkItem__c WHERE Id IN :items
        ]) {
            System.assertEquals(UserInfo.getUserId(), after.DeveloperLookup__c,
                'every newly-deployed row gets the verifier');
        }
    }

    /**
     * @description Non-deploy stage change must not assign anyone and must
     *              not fire the ship path — even with an approver configured.
     */
    @IsTest
    static void testNonDeployStageChangeDoesNothing() {
        setApproverSetting(String.valueOf(UserInfo.getUserId()));
        WorkItem__c wi = seedItemAt('In Development');

        Test.startTest();
        update new WorkItem__c(Id = wi.Id, StageNamePk__c = 'Ready for QA');
        Test.stopTest();

        WorkItem__c after = [
            SELECT DeveloperLookup__c FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(null, after.DeveloperLookup__c,
            'non-deploy stage changes must never reassign the item');
    }

    /**
     * @description Already-deployed rows do not re-fire: updating an
     *              unrelated field on a 'Deployed to Prod' item leaves
     *              assignment untouched.
     */
    @IsTest
    static void testAlreadyDeployedRowDoesNotReFire() {
        setApproverSetting(String.valueOf(UserInfo.getUserId()));
        WorkItem__c wi = seedItemAt(STAGE_DEPLOYED);

        Test.startTest();
        update new WorkItem__c(Id = wi.Id, BriefDescriptionTxt__c = 'touched');
        Test.stopTest();

        WorkItem__c after = [
            SELECT DeveloperLookup__c FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(null, after.DeveloperLookup__c,
            'stage did not CHANGE TO deployed — no assignment');
    }

    /**
     * @description Blank ApproverUserIdTxt__c: deploy-stage entry completes
     *              with no assignment and no exception (the documented
     *              skip-silently behavior).
     */
    @IsTest
    static void testBlankApproverSettingSkipsSilently() {
        setApproverSetting(null);
        WorkItem__c wi = seedItemAt(STAGE_DEPLOYING);

        Test.startTest();
        update new WorkItem__c(Id = wi.Id, StageNamePk__c = STAGE_DEPLOYED);
        Test.stopTest();

        WorkItem__c after = [
            SELECT StageNamePk__c, DeveloperLookup__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(STAGE_DEPLOYED, after.StageNamePk__c,
            'the stage move itself must never be blocked by the ship rails');
        System.assertEquals(null, after.DeveloperLookup__c,
            'blank approver setting = no assignment');
    }

    /**
     * @description Malformed ApproverUserIdTxt__c (not an id): resolver
     *              returns null, everything skips silently, the DML succeeds.
     */
    @IsTest
    static void testMalformedApproverSettingSkipsSilently() {
        setApproverSetting('not-a-user-id');
        WorkItem__c wi = seedItemAt(STAGE_DEPLOYING);

        Test.startTest();
        update new WorkItem__c(Id = wi.Id, StageNamePk__c = STAGE_DEPLOYED);
        Test.stopTest();

        WorkItem__c after = [
            SELECT DeveloperLookup__c FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(null, after.DeveloperLookup__c,
            'malformed approver setting = no assignment, no exception');
    }

    /**
     * @description Service-level null safety: null / empty id lists are the
     *              documented no-ops and must never throw or enqueue.
     */
    @IsTest
    static void testNotifyDeployedToProdNullSafety() {
        Test.startTest();
        Integer asyncBefore = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        DeliveryNotificationService.notifyDeployedToProd(null);
        DeliveryNotificationService.notifyDeployedToProd(new List<Id>());
        setApproverSetting(null);
        DeliveryNotificationService.notifyDeployedToProd(
            new List<Id>{ TestDataFactory.createWorkItem(null).Id });
        Integer asyncAfter = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        Test.stopTest();

        System.assertEquals(asyncBefore, asyncAfter,
            'null list, empty list, and blank setting must not enqueue a notification');
    }
}
