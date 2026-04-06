/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryRecurringItemService.
 * Covers recurring item processing, template cloning, next date calculations,
 * scheduler integration, and board exclusion of templates.
 * @author Cloud Nimbus LLC
 */
@IsTest
public class DeliveryRecurringItemServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        DeliveryTriggerControl.disableAfterLogic();

        List<WorkItem__c> items = new List<WorkItem__c>{
            // Recurring weekly item
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Weekly Standup Notes',
                DetailsTxt__c = 'Capture standup notes',
                PriorityPk__c = 'Medium',
                StageNamePk__c = 'Backlog',
                WorkflowTypeTxt__c = 'Software_Delivery',
                ActivatedDateTime__c = Datetime.now(),
                RecurringEnabledDateTime__c = Datetime.now(),
                TemplateMarkedDateTime__c = null,
                RecurrenceScheduleTxt__c = 'Weekly',
                RecurrenceDayTxt__c = 'Monday',
                NextRecurrenceDate__c = Date.today(),
                TagsTxt__c = 'standup,recurring',
                EstimatedHoursNumber__c = 1
            ),
            // Recurring monthly item
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Monthly Report',
                DetailsTxt__c = 'Generate monthly report',
                PriorityPk__c = 'High',
                StageNamePk__c = 'Backlog',
                WorkflowTypeTxt__c = 'Software_Delivery',
                ActivatedDateTime__c = Datetime.now(),
                RecurringEnabledDateTime__c = Datetime.now(),
                TemplateMarkedDateTime__c = null,
                RecurrenceScheduleTxt__c = 'Monthly',
                RecurrenceDayTxt__c = '15',
                NextRecurrenceDate__c = Date.today(),
                TagsTxt__c = 'report,monthly',
                EstimatedHoursNumber__c = 4
            ),
            // Recurring quarterly item
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Quarterly Review',
                PriorityPk__c = 'Low',
                StageNamePk__c = 'Backlog',
                WorkflowTypeTxt__c = 'Software_Delivery',
                ActivatedDateTime__c = Datetime.now(),
                RecurringEnabledDateTime__c = Datetime.now(),
                TemplateMarkedDateTime__c = null,
                RecurrenceScheduleTxt__c = 'Quarterly',
                RecurrenceDayTxt__c = '1',
                NextRecurrenceDate__c = Date.today()
            ),
            // Template item
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Bug Fix Template',
                DetailsTxt__c = 'Standard bug fix process',
                PriorityPk__c = 'High',
                StageNamePk__c = 'Backlog',
                WorkflowTypeTxt__c = 'Software_Delivery',
                ActivatedDateTime__c = Datetime.now(),
                TemplateMarkedDateTime__c = Datetime.now(),
                RecurringEnabledDateTime__c = null,
                TagsTxt__c = 'bug,template',
                EstimatedHoursNumber__c = 8,
                DeveloperDaysSizeNumber__c = 2
            ),
            // Normal active item (not template, not recurring)
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Normal Work Item',
                StageNamePk__c = 'Backlog',
                WorkflowTypeTxt__c = 'Software_Delivery',
                ActivatedDateTime__c = Datetime.now(),
                TemplateMarkedDateTime__c = null,
                RecurringEnabledDateTime__c = null
            ),
            // Future recurring item (should NOT be processed today)
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Future Recurring',
                StageNamePk__c = 'Backlog',
                WorkflowTypeTxt__c = 'Software_Delivery',
                ActivatedDateTime__c = Datetime.now(),
                RecurringEnabledDateTime__c = Datetime.now(),
                TemplateMarkedDateTime__c = null,
                RecurrenceScheduleTxt__c = 'Weekly',
                RecurrenceDayTxt__c = 'Friday',
                NextRecurrenceDate__c = Date.today().addDays(30)
            )
        };
        insert items;

        DeliveryTriggerControl.enableAfterLogic();
    }

    // -------------------------------------------------------------------------
    // processRecurringItems tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testProcessRecurringItemsCreatesClones() {
        System.runAs(testUser) {
            // 3 recurring items have NextRecurrenceDate__c <= today
            Integer countBefore = [SELECT COUNT() FROM WorkItem__c WHERE RecurringEnabledDateTime__c = null AND TemplateMarkedDateTime__c = null];

            Test.startTest();
            DeliveryRecurringItemService.processRecurringItems();
            Test.stopTest();

            // Should have created 3 new cloned items
            Integer countAfter = [SELECT COUNT() FROM WorkItem__c WHERE RecurringEnabledDateTime__c = null AND TemplateMarkedDateTime__c = null];
            System.assertEquals(countBefore + 3, countAfter, 'Should have created 3 clones from recurring items');

            // Verify cloned fields on the weekly item clone
            WorkItem__c weeklyClone = [
                SELECT BriefDescriptionTxt__c, PriorityPk__c, TagsTxt__c, TemplateSourceId__c,
                       RecurringEnabledDateTime__c, TemplateMarkedDateTime__c, ActivatedDateTime__c
                FROM WorkItem__c
                WHERE TemplateSourceId__c != null
                AND BriefDescriptionTxt__c = 'Weekly Standup Notes'
                AND RecurringEnabledDateTime__c = null
                LIMIT 1
            ];
            System.assertEquals('Medium', weeklyClone.PriorityPk__c, 'Priority should be cloned');
            System.assertEquals('standup,recurring', weeklyClone.TagsTxt__c, 'Tags should be cloned');
            System.assertEquals(null, weeklyClone.RecurringEnabledDateTime__c, 'Clone should not be recurring');
            System.assertEquals(null, weeklyClone.TemplateMarkedDateTime__c, 'Clone should not be a template');
            System.assertNotEquals(null, weeklyClone.ActivatedDateTime__c, 'Clone should be active');
            System.assertNotEquals(null, weeklyClone.TemplateSourceId__c, 'TemplateSourceId should be set');
        }
    }

    @IsTest
    static void testProcessRecurringItemsAdvancesNextDate() {
        System.runAs(testUser) {
            WorkItem__c weeklyBefore = [
                SELECT NextRecurrenceDate__c
                FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Weekly Standup Notes'
                AND RecurringEnabledDateTime__c != null
            ];
            Date originalDate = weeklyBefore.NextRecurrenceDate__c;

            Test.startTest();
            DeliveryRecurringItemService.processRecurringItems();
            Test.stopTest();

            WorkItem__c weeklyAfter = [
                SELECT NextRecurrenceDate__c
                FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Weekly Standup Notes'
                AND RecurringEnabledDateTime__c != null
            ];
            System.assert(weeklyAfter.NextRecurrenceDate__c > originalDate, 'Next recurrence date should be advanced');
        }
    }

    @IsTest
    static void testProcessRecurringItemsDoesNotProcessFutureItems() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryRecurringItemService.processRecurringItems();
            Test.stopTest();

            // Future recurring item should not have been cloned
            WorkItem__c futureItem = [
                SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Future Recurring' LIMIT 1
            ];
            Integer futureClones = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE TemplateSourceId__c = :futureItem.Id
            ];
            System.assertEquals(0, futureClones, 'Future recurring items should not be processed');
        }
    }

    @IsTest
    static void testProcessRecurringItemsCreatesActivityLogs() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryRecurringItemService.processRecurringItems();
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ComponentNameTxt__c, ContextDataTxt__c
                FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryRecurringItemService'
            ];
            Integer recurringLogCount = 0;
            for (ActivityLog__c log : logs) {
                if (log.ContextDataTxt__c != null && log.ContextDataTxt__c.contains('recurring_clone')) {
                    recurringLogCount++;
                }
            }
            System.assertEquals(3, recurringLogCount, 'Should log 3 recurring clone activities');
        }
    }

    // -------------------------------------------------------------------------
    // cloneFromTemplate tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testCloneFromTemplateBasic() {
        System.runAs(testUser) {
            WorkItem__c template = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Bug Fix Template'];

            Test.startTest();
            Id newId = DeliveryRecurringItemService.cloneFromTemplate(template.Id, null);
            Test.stopTest();

            System.assertNotEquals(null, newId, 'Should return a new record Id');

            WorkItem__c clone = [
                SELECT BriefDescriptionTxt__c, PriorityPk__c, TagsTxt__c, EstimatedHoursNumber__c,
                       DeveloperDaysSizeNumber__c, TemplateSourceId__c, TemplateMarkedDateTime__c,
                       ActivatedDateTime__c
                FROM WorkItem__c
                WHERE Id = :newId
            ];
            System.assertEquals('Bug Fix Template', clone.BriefDescriptionTxt__c, 'Title should be cloned');
            System.assertEquals('High', clone.PriorityPk__c, 'Priority should be cloned');
            System.assertEquals('bug,template', clone.TagsTxt__c, 'Tags should be cloned');
            System.assertEquals(8, clone.EstimatedHoursNumber__c, 'Estimated hours should be cloned');
            System.assertEquals(2, clone.DeveloperDaysSizeNumber__c, 'Developer days should be cloned');
            System.assertEquals(template.Id, clone.TemplateSourceId__c, 'Source Id should reference the template');
            System.assertEquals(null, clone.TemplateMarkedDateTime__c, 'Clone should not be a template');
            System.assertNotEquals(null, clone.ActivatedDateTime__c, 'Clone should be active');
        }
    }

    @IsTest
    static void testCloneFromTemplateWithOverrides() {
        System.runAs(testUser) {
            WorkItem__c template = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Bug Fix Template'];
            Map<String, Object> overrides = new Map<String, Object>{
                'BriefDescriptionTxt__c' => 'Login Page Bug',
                'PriorityPk__c' => 'Low',
                'TagsTxt__c' => 'login,urgent'
            };

            Test.startTest();
            Id newId = DeliveryRecurringItemService.cloneFromTemplate(template.Id, overrides);
            Test.stopTest();

            WorkItem__c clone = [
                SELECT BriefDescriptionTxt__c, PriorityPk__c, TagsTxt__c, EstimatedHoursNumber__c
                FROM WorkItem__c
                WHERE Id = :newId
            ];
            System.assertEquals('Login Page Bug', clone.BriefDescriptionTxt__c, 'Title should be overridden');
            System.assertEquals('Low', clone.PriorityPk__c, 'Priority should be overridden');
            System.assertEquals('login,urgent', clone.TagsTxt__c, 'Tags should be overridden');
            System.assertEquals(8, clone.EstimatedHoursNumber__c, 'Non-overridden fields should keep template values');
        }
    }

    @IsTest
    static void testCloneFromTemplateNullId() {
        System.runAs(testUser) {
            try {
                Test.startTest();
                DeliveryRecurringItemService.cloneFromTemplate(null, null);
                Test.stopTest();
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage() != null, 'Should have error message');
            }
        }
    }

    @IsTest
    static void testCloneFromTemplateCreatesActivityLog() {
        System.runAs(testUser) {
            WorkItem__c template = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Bug Fix Template'];

            Test.startTest();
            DeliveryRecurringItemService.cloneFromTemplate(template.Id, null);
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c
                FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryRecurringItemService'
            ];
            Integer templateLogCount = 0;
            for (ActivityLog__c log : logs) {
                if (log.ContextDataTxt__c != null && log.ContextDataTxt__c.contains('template_clone')) {
                    templateLogCount++;
                }
            }
            System.assertEquals(1, templateLogCount, 'Should log template clone activity');
        }
    }

    // -------------------------------------------------------------------------
    // getTemplates tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testGetTemplates() {
        System.runAs(testUser) {
            Test.startTest();
            List<WorkItem__c> templates = DeliveryRecurringItemService.getTemplates();
            Test.stopTest();

            System.assertEquals(1, templates.size(), 'Should return 1 template');
            System.assertEquals('Bug Fix Template', templates[0].BriefDescriptionTxt__c);
        }
    }

    // -------------------------------------------------------------------------
    // calculateNextDate tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testCalculateNextDateWeekly() {
        System.runAs(testUser) {
            // Use a known Monday (2026-02-23 is a Monday)
            Date baseDate = Date.newInstance(2026, 2, 23);
            Date result = DeliveryRecurringItemService.calculateNextDate('Weekly', 'Monday', baseDate);
            // Next Monday after 2026-02-23 is 2026-03-02
            System.assertEquals(Date.newInstance(2026, 3, 2), result, 'Weekly Monday should advance 7 days');
        }
    }

    @IsTest
    static void testCalculateNextDateBiweekly() {
        System.runAs(testUser) {
            Date baseDate = Date.newInstance(2026, 2, 23); // Monday
            Date result = DeliveryRecurringItemService.calculateNextDate('Biweekly', 'Monday', baseDate);
            // Next Monday + extra week = 2026-03-09
            System.assertEquals(Date.newInstance(2026, 3, 9), result, 'Biweekly Monday should advance 14 days');
        }
    }

    @IsTest
    static void testCalculateNextDateMonthly() {
        System.runAs(testUser) {
            Date baseDate = Date.newInstance(2026, 1, 15);
            Date result = DeliveryRecurringItemService.calculateNextDate('Monthly', '15', baseDate);
            System.assertEquals(Date.newInstance(2026, 2, 15), result, 'Monthly on 15th should go to next month 15th');
        }
    }

    @IsTest
    static void testCalculateNextDateQuarterly() {
        System.runAs(testUser) {
            Date baseDate = Date.newInstance(2026, 1, 1);
            Date result = DeliveryRecurringItemService.calculateNextDate('Quarterly', '1', baseDate);
            System.assertEquals(Date.newInstance(2026, 4, 1), result, 'Quarterly on 1st should advance 3 months');
        }
    }

    @IsTest
    static void testCalculateNextDateNullSchedule() {
        System.runAs(testUser) {
            Date result = DeliveryRecurringItemService.calculateNextDate(null, 'Monday', Date.today());
            System.assertEquals(null, result, 'Null schedule should return null');
        }
    }

    @IsTest
    static void testCalculateNextDateNullDate() {
        System.runAs(testUser) {
            Date result = DeliveryRecurringItemService.calculateNextDate('Weekly', 'Monday', null);
            System.assertEquals(null, result, 'Null fromDate should return null');
        }
    }

    @IsTest
    static void testCalculateNextDateInvalidDay() {
        System.runAs(testUser) {
            Date baseDate = Date.newInstance(2026, 2, 23);
            Date result = DeliveryRecurringItemService.calculateNextDate('Weekly', 'InvalidDay', baseDate);
            // Should fallback to +7 days
            System.assertEquals(baseDate.addDays(7), result, 'Invalid day name should fall back to 7-day advance');
        }
    }

    @IsTest
    static void testCalculateNextDateMonthlyHighDay() {
        System.runAs(testUser) {
            Date baseDate = Date.newInstance(2026, 1, 31);
            Date result = DeliveryRecurringItemService.calculateNextDate('Monthly', '31', baseDate);
            // Day capped at 28 to avoid month-boundary issues
            System.assertEquals(Date.newInstance(2026, 2, 28), result, 'Day > 28 should be capped to 28');
        }
    }

    // -------------------------------------------------------------------------
    // Board exclusion of templates test
    // -------------------------------------------------------------------------

    @IsTest
    static void testBoardExcludesTemplates() {
        System.runAs(testUser) {
            Test.startTest();
            List<WorkItem__c> boardItems = DeliveryWorkItemController.getWorkItems('Software_Delivery');
            Test.stopTest();

            // Verify the template is not in the results
            Set<String> descriptions = new Set<String>();
            for (WorkItem__c wi : boardItems) {
                descriptions.add(wi.BriefDescriptionTxt__c);
            }
            System.assert(!descriptions.contains('Bug Fix Template'), 'Bug Fix Template should be excluded from board');
        }
    }

    // -------------------------------------------------------------------------
    // Scheduler integration test
    // -------------------------------------------------------------------------

    @IsTest
    static void testSchedulerIntegration() {
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new SchedulerMockResponse());

            Integer countBefore = [SELECT COUNT() FROM WorkItem__c WHERE TemplateSourceId__c != null];

            Test.startTest();
            String cronExp = '0 0 0 15 3 ? 2040';
            String jobId = System.schedule('TestRecurringScheduler', cronExp, new DeliveryHubScheduler());
            Test.stopTest();

            CronTrigger ct = [SELECT Id, State FROM CronTrigger WHERE Id = :jobId];
            System.assertNotEquals(null, ct, 'Scheduled job should exist');
        }
    }

    /**
     * @description Mock HTTP response for scheduler test.
     */
    public class SchedulerMockResponse implements HttpCalloutMock {
        /**
         * @description Returns a valid sync response.
         * @param req The HTTP request.
         * @return HttpResponse The mock response.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[]');
            return res;
        }
    }
}
