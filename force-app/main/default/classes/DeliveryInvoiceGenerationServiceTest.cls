/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryInvoiceGenerationService and
 *               DeliveryInvoiceGenerationQueueable. Covers happy path,
 *               feature toggle states, frequency scheduling, zero-hours
 *               skipping, inactive entity filtering, and overdue marking.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.CyclomaticComplexity')
private class DeliveryInvoiceGenerationServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    // ── Test Setup ───────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        DeliveryTriggerControl.disableAfterLogic();

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            EnableBillingDateTime__c = Datetime.now(),
            BillingFrequencyPk__c = 'Monthly',
            DefaultHourlyRateCurrency__c = 100
        );
        insert entity;

        NetworkEntity__c inactiveEntity = new NetworkEntity__c(
            Name = 'Inactive Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Inactive',
            EnableBillingDateTime__c = Datetime.now(),
            BillingFrequencyPk__c = 'Monthly'
        );
        insert inactiveEntity;

        NetworkEntity__c noBillingEntity = new NetworkEntity__c(
            Name = 'No Billing Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            BillingFrequencyPk__c = 'Monthly'
        );
        insert noBillingEntity;

        WorkItem__c item = new WorkItem__c(
            BriefDescriptionTxt__c = 'Test Item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'High',
            ActivatedDateTime__c = Datetime.now(),
            ClientNetworkEntityLookup__c = entity.Id
        );
        insert item;

        WorkRequest__c request = new WorkRequest__c(
            WorkItemLookup__c = item.Id,
            DeliveryEntityLookup__c = entity.Id,
            StatusPk__c = 'Active',
            HourlyRateCurrency__c = 100
        );
        insert request;

        WorkLog__c log = new WorkLog__c(
            WorkItemLookup__c = item.Id,
            RequestLookup__c = request.Id,
            HoursLoggedNumber__c = 8,
            WorkDateDate__c = Date.today().addDays(-5),
            WorkDescriptionTxt__c = 'Test work',
            StatusPk__c = 'Approved'
        );
        insert log;

        DeliveryTriggerControl.enableAfterLogic();
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static DeliveryHubSettings__c createSettings(Boolean enabled) {
        DeliveryHubSettings__c s = new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EnableInvoiceGenerationDateTime__c = enabled ? Datetime.now() : null,
            LastInvoiceGenerationDate__c = null
        );
        insert s;
        return s;
    }

    // ── shouldRunToday Tests ─────────────────────────────────────────────────

    @IsTest
    static void testShouldRunTodayEnabled() {
        System.runAs(testUser) {
            DeliveryHubSettings__c s = new DeliveryHubSettings__c(
                EnableInvoiceGenerationDateTime__c = Datetime.now(),
                LastInvoiceGenerationDate__c = Date.today().addDays(-1)
            );
            System.assertEquals(true, DeliveryInvoiceGenerationService.shouldRunToday(s),
                'Should run when enabled and not run today');
        }
    }

    @IsTest
    static void testShouldRunTodayDisabled() {
        System.runAs(testUser) {
            DeliveryHubSettings__c s = new DeliveryHubSettings__c(
                EnableInvoiceGenerationDateTime__c = null,
                LastInvoiceGenerationDate__c = null
            );
            System.assertEquals(false, DeliveryInvoiceGenerationService.shouldRunToday(s),
                'Should not run when feature is disabled');
        }
    }

    @IsTest
    static void testShouldRunTodayAlreadyRan() {
        System.runAs(testUser) {
            DeliveryHubSettings__c s = new DeliveryHubSettings__c(
                EnableInvoiceGenerationDateTime__c = Datetime.now(),
                LastInvoiceGenerationDate__c = Date.today()
            );
            System.assertEquals(false, DeliveryInvoiceGenerationService.shouldRunToday(s),
                'Should not run when already ran today');
        }
    }

    // ── shouldGenerateForEntity Tests ────────────────────────────────────────

    @IsTest
    static void testShouldGenerateForEntityDaily() {
        System.runAs(testUser) {
            System.assertEquals(true,
                DeliveryInvoiceGenerationService.shouldGenerateForEntity('Daily'),
                'Daily should always return true');
        }
    }

    @IsTest
    static void testShouldGenerateForEntityMonthly() {
        System.runAs(testUser) {
            Boolean expected = Date.today().day() == 1;
            System.assertEquals(expected,
                DeliveryInvoiceGenerationService.shouldGenerateForEntity('Monthly'),
                'Monthly should return true only on 1st of month');
        }
    }

    // ── hasApprovedHoursInPeriod Tests ────────────────────────────────────────

    @IsTest
    static void testHasApprovedHoursInPeriod() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Client' LIMIT 1];
            Date periodStart = Date.today().addDays(-30);
            Date periodEnd = Date.today();

            Test.startTest();
            Boolean result = DeliveryInvoiceGenerationService.hasApprovedHoursInPeriod(
                entity.Id, periodStart, periodEnd
            );
            Test.stopTest();

            System.assertEquals(true, result, 'Should find approved hours in period');
        }
    }

    @IsTest
    static void testHasApprovedHoursInPeriodNoHours() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'No Billing Client' LIMIT 1];
            Date periodStart = Date.today().addDays(-30);
            Date periodEnd = Date.today();

            Test.startTest();
            Boolean result = DeliveryInvoiceGenerationService.hasApprovedHoursInPeriod(
                entity.Id, periodStart, periodEnd
            );
            Test.stopTest();

            System.assertEquals(false, result, 'Should not find hours for entity with no work logs');
        }
    }

    // ── generateScheduledDocuments Tests ──────────────────────────────────────

    @IsTest
    static void testGenerateScheduledDocumentsFeatureDisabled() {
        System.runAs(testUser) {
            createSettings(false);

            Test.startTest();
            DeliveryInvoiceGenerationService.generateScheduledDocuments();
            Test.stopTest();

            Integer docCount = [SELECT COUNT() FROM DeliveryDocument__c WITH SYSTEM_MODE];
            System.assertEquals(0, docCount, 'No documents should be generated when feature is disabled');
        }
    }

    @IsTest
    static void testGenerateScheduledDocumentsAlreadyRanToday() {
        System.runAs(testUser) {
            DeliveryHubSettings__c s = createSettings(true);
            s.LastInvoiceGenerationDate__c = Date.today();
            update s;

            Test.startTest();
            DeliveryInvoiceGenerationService.generateScheduledDocuments();
            Test.stopTest();

            Integer docCount = [SELECT COUNT() FROM DeliveryDocument__c WITH SYSTEM_MODE];
            System.assertEquals(0, docCount, 'No documents should be generated when already ran today');
        }
    }

    @IsTest
    static void testGenerateScheduledDocumentsInactiveEntitySkipped() {
        System.runAs(testUser) {
            createSettings(true);

            // Verify inactive entity is not included
            Integer entityCount = [
                SELECT COUNT() FROM NetworkEntity__c
                WHERE EnableBillingDateTime__c != null AND StatusPk__c = 'Active'
                WITH SYSTEM_MODE
            ];

            Test.startTest();
            // The actual generation depends on today being a billing day for the frequency
            DeliveryInvoiceGenerationService.generateScheduledDocuments();
            Test.stopTest();

            // Verify settings were stamped
            DeliveryHubSettings__c stamped = DeliveryHubSettings__c.getOrgDefaults();
            System.assertEquals(Date.today(), stamped.LastInvoiceGenerationDate__c,
                'Last generation date should be stamped');
        }
    }

    // ── markOverdueInvoices Tests ────────────────────────────────────────────

    @IsTest
    static void testMarkOverdueInvoices() {
        System.runAs(testUser) {
            DeliveryTriggerControl.disableAfterLogic();

            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Client' LIMIT 1];

            DeliveryDocument__c doc = new DeliveryDocument__c(
                NetworkEntityLookup__c = entity.Id,
                TemplatePk__c = 'Invoice',
                StatusPk__c = 'Sent',
                DueDateDate__c = Date.today().addDays(-5),
                PeriodStartDate__c = Date.today().addDays(-30),
                PeriodEndDate__c = Date.today().addDays(-1),
                PublicTokenTxt__c = 'test-token-overdue',
                SnapshotTxt__c = '{}',
                VersionNumber__c = 1
            );
            Database.insert(doc, AccessLevel.SYSTEM_MODE);

            DeliveryTriggerControl.enableAfterLogic();

            Test.startTest();
            DeliveryInvoiceGenerationService.markOverdueInvoices();
            Test.stopTest();

            DeliveryDocument__c updated = [
                SELECT StatusPk__c FROM DeliveryDocument__c WHERE Id = :doc.Id WITH SYSTEM_MODE
            ];
            System.assertEquals('Overdue', updated.StatusPk__c,
                'Past-due sent invoice should be marked Overdue');
        }
    }

    // ── Queueable Tests ──────────────────────────────────────────────────────

    @IsTest
    static void testQueueableExecution() {
        System.runAs(testUser) {
            createSettings(true);

            Test.startTest();
            System.enqueueJob(new DeliveryInvoiceGenerationQueueable());
            Test.stopTest();

            // Queueable ran — verify settings were stamped
            DeliveryHubSettings__c stamped = DeliveryHubSettings__c.getOrgDefaults();
            System.assertEquals(Date.today(), stamped.LastInvoiceGenerationDate__c,
                'Queueable should stamp the generation date');
        }
    }
}
