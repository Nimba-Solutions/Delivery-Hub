/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryOverdueReminderService covering reminder level
 *               evaluation, schedule parsing, cooldown logic, email building,
 *               and queueable execution.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryOverdueReminderServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setup() {
        DeliveryTriggerControl.disableAfterLogic();

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableOverdueRemindersDateTime__c = Datetime.now();
        settings.OverdueReminderScheduleTxt__c = '1,7,14,30';
        settings.DocumentCcEmailTxt__c = 'admin@example.com';
        upsert settings;

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Reminder Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            ContactEmailTxt__c = 'client@example.com'
        );
        insert entity;

        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Test Vendor Co',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active'
        );
        insert vendor;

        DeliveryTriggerControl.enableAfterLogic();
    }

    // ── parseSchedule Tests ──────────────────────────────────────────────

    @IsTest
    static void testParseScheduleDefault() {
        System.runAs(testUser) {
            List<Integer> schedule = DeliveryOverdueReminderService.parseSchedule(null);
            System.assertEquals(4, schedule.size(), 'Default schedule should have 4 entries');
            System.assertEquals(1, schedule[0], 'First threshold should be 1');
            System.assertEquals(30, schedule[3], 'Last threshold should be 30');
        }
    }

    @IsTest
    static void testParseScheduleCustom() {
        System.runAs(testUser) {
            List<Integer> schedule = DeliveryOverdueReminderService.parseSchedule('3,10,21');
            System.assertEquals(3, schedule.size(), 'Custom schedule should have 3 entries');
            System.assertEquals(3, schedule[0], 'First threshold should be 3');
            System.assertEquals(21, schedule[2], 'Last threshold should be 21');
        }
    }

    @IsTest
    static void testParseScheduleBlankFallsToDefault() {
        System.runAs(testUser) {
            List<Integer> schedule = DeliveryOverdueReminderService.parseSchedule('');
            System.assertEquals(4, schedule.size(), 'Blank schedule should fall back to default');
        }
    }

    @IsTest
    static void testParseScheduleInvalidEntries() {
        System.runAs(testUser) {
            List<Integer> schedule = DeliveryOverdueReminderService.parseSchedule('abc,5,xyz,10');
            System.assertEquals(2, schedule.size(), 'Should skip invalid entries');
            System.assertEquals(5, schedule[0], 'First valid entry should be 5');
            System.assertEquals(10, schedule[1], 'Second valid entry should be 10');
        }
    }

    // ── shouldSendReminder Tests ─────────────────────────────────────────

    @IsTest
    static void testShouldSendReminderLevel1() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = new DeliveryDocument__c();
            doc.DueDateDate__c = Date.today().addDays(-2);
            doc.OverdueReminderCountNumber__c = 0;
            doc.LastOverdueReminderDateTime__c = null;

            List<Integer> schedule = new List<Integer>{ 1, 7, 14, 30 };
            Integer level = DeliveryOverdueReminderService.shouldSendReminder(doc, schedule);
            System.assertEquals(1, level, 'Should return level 1 for 2 days overdue with 0 reminders sent');
        }
    }

    @IsTest
    static void testShouldSendReminderLevel2() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = new DeliveryDocument__c();
            doc.DueDateDate__c = Date.today().addDays(-10);
            doc.OverdueReminderCountNumber__c = 1;
            doc.LastOverdueReminderDateTime__c = Datetime.now().addDays(-3);

            List<Integer> schedule = new List<Integer>{ 1, 7, 14, 30 };
            Integer level = DeliveryOverdueReminderService.shouldSendReminder(doc, schedule);
            System.assertEquals(2, level, 'Should return level 2 for 10 days overdue with 1 reminder sent');
        }
    }

    @IsTest
    static void testShouldSendReminderLevel4Escalation() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = new DeliveryDocument__c();
            doc.DueDateDate__c = Date.today().addDays(-45);
            doc.OverdueReminderCountNumber__c = 3;
            doc.LastOverdueReminderDateTime__c = Datetime.now().addDays(-10);

            List<Integer> schedule = new List<Integer>{ 1, 7, 14, 30 };
            Integer level = DeliveryOverdueReminderService.shouldSendReminder(doc, schedule);
            System.assertEquals(4, level, 'Should return level 4 (escalation) for 45 days overdue');
        }
    }

    @IsTest
    static void testShouldSendReminderAlreadySentAtLevel() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = new DeliveryDocument__c();
            doc.DueDateDate__c = Date.today().addDays(-5);
            doc.OverdueReminderCountNumber__c = 1;
            doc.LastOverdueReminderDateTime__c = Datetime.now().addDays(-2);

            List<Integer> schedule = new List<Integer>{ 1, 7, 14, 30 };
            Integer level = DeliveryOverdueReminderService.shouldSendReminder(doc, schedule);
            System.assertEquals(0, level, 'Should return 0 when already sent at current level');
        }
    }

    @IsTest
    static void testShouldSendReminderCooldownActive() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = new DeliveryDocument__c();
            doc.DueDateDate__c = Date.today().addDays(-10);
            doc.OverdueReminderCountNumber__c = 1;
            doc.LastOverdueReminderDateTime__c = Datetime.now().addHours(-12);

            List<Integer> schedule = new List<Integer>{ 1, 7, 14, 30 };
            Integer level = DeliveryOverdueReminderService.shouldSendReminder(doc, schedule);
            System.assertEquals(0, level, 'Should return 0 when cooldown is active (< 24 hours)');
        }
    }

    @IsTest
    static void testShouldSendReminderNotYetOverdue() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = new DeliveryDocument__c();
            doc.DueDateDate__c = Date.today().addDays(5);
            doc.OverdueReminderCountNumber__c = 0;

            List<Integer> schedule = new List<Integer>{ 1, 7, 14, 30 };
            Integer level = DeliveryOverdueReminderService.shouldSendReminder(doc, schedule);
            System.assertEquals(0, level, 'Should return 0 when document is not yet overdue');
        }
    }

    @IsTest
    static void testShouldSendReminderNullDueDate() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = new DeliveryDocument__c();
            doc.DueDateDate__c = null;
            doc.OverdueReminderCountNumber__c = 0;

            List<Integer> schedule = new List<Integer>{ 1, 7, 14, 30 };
            Integer level = DeliveryOverdueReminderService.shouldSendReminder(doc, schedule);
            System.assertEquals(0, level, 'Should return 0 when due date is null');
        }
    }

    // ── processOverdueReminders Tests ────────────────────────────────────

    @IsTest
    static void testProcessOverdueRemindersHappyPath() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE EntityTypePk__c = 'Client' LIMIT 1];

            DeliveryTriggerControl.disableAfterLogic();
            DeliveryDocument__c doc = new DeliveryDocument__c(
                NetworkEntityLookup__c = entity.Id,
                TemplatePk__c = 'Invoice',
                StatusPk__c = 'Overdue',
                DueDateDate__c = Date.today().addDays(-5),
                PeriodStartDate__c = Date.today().addDays(-30),
                PeriodEndDate__c = Date.today().addDays(-1),
                PublicTokenTxt__c = 'test-overdue-happy',
                SnapshotTxt__c = '{}',
                VersionNumber__c = 1,
                TotalCurrency__c = 1500.00,
                OverdueReminderCountNumber__c = 0
            );
            Database.insert(doc, AccessLevel.SYSTEM_MODE);
            DeliveryTriggerControl.enableAfterLogic();

            Test.startTest();
            DeliveryOverdueReminderService.processOverdueReminders();
            Test.stopTest();

            DeliveryDocument__c updated = [
                SELECT OverdueReminderCountNumber__c, OverdueReminderLevelPk__c,
                       LastOverdueReminderDateTime__c
                FROM DeliveryDocument__c WHERE Id = :doc.Id
            ];
            System.assertEquals(1, updated.OverdueReminderCountNumber__c,
                'Reminder count should be incremented');
            System.assertEquals('Reminder_1', updated.OverdueReminderLevelPk__c,
                'Reminder level should be set to Reminder_1');
            System.assertNotEquals(null, updated.LastOverdueReminderDateTime__c,
                'Last reminder date should be stamped');
        }
    }

    @IsTest
    static void testProcessOverdueRemindersFeatureDisabled() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.EnableOverdueRemindersDateTime__c = null;
            upsert settings;

            Test.startTest();
            DeliveryOverdueReminderService.processOverdueReminders();
            Test.stopTest();

            // No exception thrown — feature disabled silently
            System.assert(true, 'Should return silently when feature is disabled');
        }
    }

    // ── Queueable Test ──────────────────────────────────────────────────

    @IsTest
    static void testQueueableExecution() {
        System.runAs(testUser) {
            Test.startTest();
            System.enqueueJob(new DeliveryOverdueReminderQueueable());
            Test.stopTest();

            System.assert(true, 'Queueable should execute without error');
        }
    }
}
