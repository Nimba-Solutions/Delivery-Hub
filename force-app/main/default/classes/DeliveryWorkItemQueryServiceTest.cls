/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Unit tests for DeliveryWorkItemQueryService — centralized WorkItem__c query service.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkItemQueryServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        // Create a NetworkEntity for entity-scoped queries
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Query Service Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert entity;

        List<WorkItem__c> workItems = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Active item in dev',
                StageNamePk__c             = 'In Development',
                PriorityPk__c              = 'High',
                ActivatedDateTime__c       = Datetime.now(),
                EstimatedHoursNumber__c    = 20,
                ClientNetworkEntityId__c   = entity.Id
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Active item in QA',
                StageNamePk__c             = 'Ready for QA',
                PriorityPk__c              = 'Medium',
                ActivatedDateTime__c       = Datetime.now(),
                ClientNetworkEntityId__c   = entity.Id
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Active backlog item',
                StageNamePk__c             = 'Backlog',
                PriorityPk__c              = 'Low',
                ActivatedDateTime__c       = Datetime.now()
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Template item',
                StageNamePk__c             = 'Backlog',
                ActivatedDateTime__c       = Datetime.now(),
                TemplateMarkedDateTime__c  = Datetime.now()
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Inactive item',
                StageNamePk__c             = 'Done'
            )
        };
        insert workItems;

        // Deactivate the inactive item (trigger may auto-set ActivatedDateTime on insert)
        WorkItem__c inactive = [
            SELECT Id FROM WorkItem__c
            WHERE BriefDescriptionTxt__c = 'Inactive item' LIMIT 1
        ];
        inactive.ActivatedDateTime__c = null;
        update inactive;
    }

    // ── getByIds ────────────────────────────────────────────────────────

    @IsTest
    static void testGetByIdsReturnsMatchingRecords() {
        System.runAs(testUser) {
            List<WorkItem__c> all = [SELECT Id FROM WorkItem__c];
            Set<Id> allIds = new Set<Id>();
            for (WorkItem__c wi : all) {
                allIds.add(wi.Id);
            }

            Test.startTest();
            List<WorkItem__c> results = DeliveryWorkItemQueryService.getByIds(allIds);
            Test.stopTest();

            System.assertEquals(all.size(), results.size(),
                'Should return all records matching the provided Ids.');
        }
    }

    @IsTest
    static void testGetByIdsEmptySet() {
        System.runAs(testUser) {
            Test.startTest();
            List<WorkItem__c> results = DeliveryWorkItemQueryService.getByIds(new Set<Id>());
            Test.stopTest();

            System.assertEquals(0, results.size(),
                'Should return empty list for empty Id set.');
        }
    }

    @IsTest
    static void testGetByIdsNull() {
        System.runAs(testUser) {
            Test.startTest();
            List<WorkItem__c> results = DeliveryWorkItemQueryService.getByIds(null);
            Test.stopTest();

            System.assertEquals(0, results.size(),
                'Should return empty list for null Id set.');
        }
    }

    // ── getActiveByEntity ───────────────────────────────────────────────

    @IsTest
    static void testGetActiveByEntityReturnsEntityScopedItems() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [
                SELECT Id FROM NetworkEntity__c
                WHERE Name = 'Query Service Test Client' LIMIT 1
            ];

            Test.startTest();
            List<WorkItem__c> results = DeliveryWorkItemQueryService.getActiveByEntity(entity.Id);
            Test.stopTest();

            // Should return the 2 active items linked to this entity (not template, not inactive)
            System.assertEquals(2, results.size(),
                'Should return only active items for the given entity.');
            for (WorkItem__c wi : results) {
                System.assertEquals(entity.Id, wi.ClientNetworkEntityId__c,
                    'All results should belong to the specified entity.');
            }
        }
    }

    @IsTest
    static void testGetActiveByEntityNullId() {
        System.runAs(testUser) {
            Test.startTest();
            List<WorkItem__c> results = DeliveryWorkItemQueryService.getActiveByEntity(null);
            Test.stopTest();

            System.assertEquals(0, results.size(),
                'Should return empty list for null entity Id.');
        }
    }

    // ── getActiveInStages ───────────────────────────────────────────────

    @IsTest
    static void testGetActiveInStagesReturnsStageScopedItems() {
        System.runAs(testUser) {
            Set<String> stages = new Set<String>{ 'In Development', 'Ready for QA' };

            Test.startTest();
            List<WorkItem__c> results = DeliveryWorkItemQueryService.getActiveInStages(stages);
            Test.stopTest();

            System.assertEquals(2, results.size(),
                'Should return 2 active items in the specified stages.');
            for (WorkItem__c wi : results) {
                System.assert(stages.contains(wi.StageNamePk__c),
                    'Each result should be in one of the requested stages.');
            }
        }
    }

    @IsTest
    static void testGetActiveInStagesEmptySet() {
        System.runAs(testUser) {
            Test.startTest();
            List<WorkItem__c> results = DeliveryWorkItemQueryService.getActiveInStages(new Set<String>());
            Test.stopTest();

            System.assertEquals(0, results.size(),
                'Should return empty list for empty stage set.');
        }
    }

    // ── getActive ───────────────────────────────────────────────────────

    @IsTest
    static void testGetActiveReturnsOnlyActiveNonTemplateItems() {
        System.runAs(testUser) {
            Test.startTest();
            List<WorkItem__c> results = DeliveryWorkItemQueryService.getActive();
            Test.stopTest();

            // 3 active items (excludes template and inactive)
            System.assertEquals(3, results.size(),
                'Should return only active, non-template work items.');
            for (WorkItem__c wi : results) {
                System.assertNotEquals(null, wi.ActivatedDateTime__c,
                    'All results should have ActivatedDateTime__c set.');
                System.assertEquals(null, wi.TemplateMarkedDateTime__c,
                    'No results should have TemplateMarkedDateTime__c set.');
            }
        }
    }

    // ── getActiveWithBoardFields ────────────────────────────────────────

    @IsTest
    static void testGetActiveWithBoardFieldsPopulatesExtendedFields() {
        System.runAs(testUser) {
            Test.startTest();
            List<WorkItem__c> results = DeliveryWorkItemQueryService.getActiveWithBoardFields();
            Test.stopTest();

            System.assertEquals(3, results.size(),
                'Should return 3 active items with board fields.');
            // Verify board-specific fields are queryable (not null-checked since they may be null,
            // but the query should not throw)
            for (WorkItem__c wi : results) {
                System.assertNotEquals(null, wi.Id, 'Id should always be populated.');
                System.assertNotEquals(null, wi.StageNamePk__c, 'StageNamePk__c should be populated.');
                // Access board-specific fields to ensure they were included in the query
                // (accessing an un-queried field would throw SObjectException)
                Object dummy;
                dummy = wi.SortOrderNumber__c;
                dummy = wi.Epic__c;
                dummy = wi.Tags__c;
                dummy = wi.DetailsTxt__c;
                dummy = wi.EstimatedStartDevDate__c;
                dummy = wi.EstimatedEndDevDate__c;
            }
        }
    }

    // ── getActiveWithBoardFieldsByEntity ─────────────────────────────────

    @IsTest
    static void testGetActiveWithBoardFieldsByEntityReturnsScoped() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [
                SELECT Id FROM NetworkEntity__c
                WHERE Name = 'Query Service Test Client' LIMIT 1
            ];

            Test.startTest();
            List<WorkItem__c> results = DeliveryWorkItemQueryService.getActiveWithBoardFieldsByEntity(entity.Id);
            Test.stopTest();

            System.assertEquals(2, results.size(),
                'Should return 2 active entity-scoped items with board fields.');
        }
    }

    // ── Field set constants ─────────────────────────────────────────────

    @IsTest
    static void testFieldSetConstantsAreNonEmpty() {
        System.runAs(testUser) {
            System.assert(String.isNotBlank(DeliveryWorkItemQueryService.STANDARD_FIELDS),
                'STANDARD_FIELDS should be a non-empty string.');
            System.assert(String.isNotBlank(DeliveryWorkItemQueryService.BOARD_FIELDS),
                'BOARD_FIELDS should be a non-empty string.');
            System.assert(DeliveryWorkItemQueryService.BOARD_FIELDS.contains(DeliveryWorkItemQueryService.STANDARD_FIELDS),
                'BOARD_FIELDS should contain all STANDARD_FIELDS.');
        }
    }
}
