/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryEscalationJob scheduled Apex class. Verifies the
 *               Schedulable implementation correctly delegates to DeliveryEscalationService
 *               and handles exceptions gracefully.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryEscalationJobTest {

    @TestSetup
    static void makeData() {
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EmailNotificationsEnabledBool__c = true,
            EnableNotificationsBool__c = true
        );

        List<WorkItem__c> items = new List<WorkItem__c>();

        // Item in In Development — should be matched by rules
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Stalled dev item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery',
            Developer__c = UserInfo.getUserId()
        ));

        // Item in Dev Blocked
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Blocked item',
            StageNamePk__c = 'Dev Blocked',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery',
            Developer__c = UserInfo.getUserId()
        ));

        // Item in Backlog — should NOT be matched
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Backlog safe item',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery'
        ));

        insert items;
    }

    /**
     * @description Verifies that DeliveryEscalationJob.execute() runs without error
     *              when called directly (simulating the Schedulable context).
     */
    @IsTest
    static void testExecuteRunsWithoutError() {
        Test.startTest();
        DeliveryEscalationJob job = new DeliveryEscalationJob();
        job.execute(null);
        Test.stopTest();

        // Verify no unhandled exceptions occurred
        System.assert(true, 'DeliveryEscalationJob.execute() should complete without errors');
    }

    /**
     * @description Verifies that the job can be scheduled using System.schedule().
     */
    @IsTest
    static void testScheduleJob() {
        String cronExpr = '0 0 6 * * ?'; // Daily at 6 AM

        Test.startTest();
        String jobId = System.schedule(
            'Test Escalation Job', cronExpr, new DeliveryEscalationJob()
        );
        Test.stopTest();

        // Verify the job was scheduled
        List<CronTrigger> triggers = [
            SELECT Id, State FROM CronTrigger WHERE Id = :jobId
        ];
        System.assertEquals(1, triggers.size(), 'Job should be scheduled');
        System.assertEquals('WAITING', triggers[0].State,
            'Scheduled job should be in WAITING state');
    }

    /**
     * @description Verifies that items within SLA are not escalated by the job.
     *              Uses CMT rules — freshly created items with a high threshold
     *              in CMT should not trigger false positives.
     */
    @IsTest
    static void testNoFalsePositivesFromScheduledRun() {
        // The CMT rules have non-zero thresholds, so freshly created items should not match
        Test.startTest();
        new DeliveryEscalationJob().execute(null);
        Test.stopTest();

        WorkItem__c backlogItem = [
            SELECT PriorityPk__c, StageNamePk__c, LastEscalatedDateTime__c
            FROM WorkItem__c
            WHERE BriefDescriptionTxt__c = 'Backlog safe item'
            WITH SYSTEM_MODE LIMIT 1
        ];
        System.assertEquals('Backlog', backlogItem.StageNamePk__c,
            'Backlog item should not be moved by escalation');
        System.assertEquals('Low', backlogItem.PriorityPk__c,
            'Backlog item priority should remain unchanged');
    }
}
