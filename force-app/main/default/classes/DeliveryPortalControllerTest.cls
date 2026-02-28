/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryPortalController.
 * Validates entity-scoped access, request submission, and comment creation.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryPortalControllerTest {

    /**
     * @description Creates test data: two NetworkEntities with work items each,
     * plus comments on one of the items.
     */
    @TestSetup
    static void setupData() {
        NetworkEntity__c entityA = new NetworkEntity__c(
            Name = 'Acme Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        NetworkEntity__c entityB = new NetworkEntity__c(
            Name = 'Globex Inc',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert new List<NetworkEntity__c>{ entityA, entityB };

        // Entity A: 2 active + 1 completed
        List<WorkItem__c> items = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Active Item 1',
                StageNamePk__c = 'In Development',
                PriorityPk__c = 'High',
                IsActiveBool__c = true,
                StatusPk__c = 'New',
                ClientNetworkEntityId__c = entityA.Id,
                DetailsTxt__c = '<p>Some <b>HTML</b> description for testing.</p>'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Active Item 2',
                StageNamePk__c = 'Ready for Client UAT',
                PriorityPk__c = 'Medium',
                IsActiveBool__c = true,
                StatusPk__c = 'New',
                ClientNetworkEntityId__c = entityA.Id
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Completed Item',
                StageNamePk__c = 'Done',
                PriorityPk__c = 'Low',
                IsActiveBool__c = false,
                StatusPk__c = 'Closed',
                ClientNetworkEntityId__c = entityA.Id
            ),
            // Entity B: 1 active (should not appear in Entity A queries)
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Other Org Item',
                StageNamePk__c = 'Backlog',
                PriorityPk__c = 'Low',
                IsActiveBool__c = true,
                StatusPk__c = 'New',
                ClientNetworkEntityId__c = entityB.Id
            )
        };
        insert items;

        // Add comments to the first item
        WorkItemComment__c c1 = new WorkItemComment__c(
            WorkItemId__c = items[0].Id,
            BodyTxt__c = 'First comment on active item 1',
            AuthorTxt__c = 'Developer',
            SourcePk__c = 'Salesforce'
        );
        WorkItemComment__c c2 = new WorkItemComment__c(
            WorkItemId__c = items[0].Id,
            BodyTxt__c = 'Second comment',
            AuthorTxt__c = 'Client User',
            SourcePk__c = 'Client'
        );
        insert new List<WorkItemComment__c>{ c1, c2 };
    }

    @IsTest
    static void testGetPortalDashboard() {
        NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Acme Corp' LIMIT 1];

        Test.startTest();
        Map<String, Object> dashboard = DeliveryPortalController.getPortalDashboard(entityA.Id);
        Test.stopTest();

        System.assertEquals('Acme Corp', (String) dashboard.get('entityName'), 'Entity name should match');
        System.assertEquals(2, (Integer) dashboard.get('activeCount'), 'Should have 2 active items');
        System.assertEquals(1, (Integer) dashboard.get('completedCount'), 'Should have 1 completed item');
        System.assertNotEquals(null, dashboard.get('phases'), 'Phase distribution should be present');
        System.assertNotEquals(null, dashboard.get('recentActivity'), 'Recent activity should be present');
    }

    @IsTest
    static void testGetPortalDashboardEntityIsolation() {
        NetworkEntity__c entityB = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Globex Inc' LIMIT 1];

        Test.startTest();
        Map<String, Object> dashboard = DeliveryPortalController.getPortalDashboard(entityB.Id);
        Test.stopTest();

        System.assertEquals(1, (Integer) dashboard.get('activeCount'), 'Globex should only see its own 1 active item');
        System.assertEquals(0, (Integer) dashboard.get('completedCount'), 'Globex should have 0 completed items');
    }

    @IsTest
    static void testGetPortalDashboardInvalidEntity() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            DeliveryPortalController.getPortalDashboard(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Network Entity ID is required'), 'Should get entity required error');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null entity');
    }

    @IsTest
    static void testGetPortalWorkItemsActive() {
        NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Acme Corp' LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> items = DeliveryPortalController.getPortalWorkItems(entityA.Id, 'active');
        Test.stopTest();

        System.assertEquals(2, items.size(), 'Should return 2 active items for Acme');
    }

    @IsTest
    static void testGetPortalWorkItemsCompleted() {
        NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Acme Corp' LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> items = DeliveryPortalController.getPortalWorkItems(entityA.Id, 'completed');
        Test.stopTest();

        System.assertEquals(1, items.size(), 'Should return 1 completed item for Acme');
    }

    @IsTest
    static void testGetPortalWorkItemsAll() {
        NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Acme Corp' LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> items = DeliveryPortalController.getPortalWorkItems(entityA.Id, null);
        Test.stopTest();

        System.assertEquals(3, items.size(), 'Should return all 3 items for Acme');
    }

    @IsTest
    static void testGetPortalWorkItemsAttention() {
        NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Acme Corp' LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> items = DeliveryPortalController.getPortalWorkItems(entityA.Id, 'attention');
        Test.stopTest();

        // Attention stages are CMT-driven; at least the query should run without error
        System.assertNotEquals(null, items, 'Should return a list (may be empty depending on CMT config)');
    }

    @IsTest
    static void testGetPortalWorkItemsEntityIsolation() {
        NetworkEntity__c entityB = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Globex Inc' LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> items = DeliveryPortalController.getPortalWorkItems(entityB.Id, null);
        Test.stopTest();

        System.assertEquals(1, items.size(), 'Globex should only see its own 1 item');
        System.assertEquals('Other Org Item', (String) items[0].get('title'), 'Should be the Globex item');
    }

    @IsTest
    static void testGetPortalWorkItemDetail() {
        WorkItem__c item = [
            SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Active Item 1' LIMIT 1
        ];

        Test.startTest();
        Map<String, Object> detail = DeliveryPortalController.getPortalWorkItemDetail(item.Id);
        Test.stopTest();

        System.assertEquals('Active Item 1', (String) detail.get('title'), 'Title should match');
        System.assertEquals('In Development', (String) detail.get('stage'), 'Stage should match');
        System.assertEquals('High', (String) detail.get('priority'), 'Priority should match');

        List<Map<String, Object>> comments = (List<Map<String, Object>>) detail.get('comments');
        System.assertEquals(2, comments.size(), 'Should have 2 comments');

        List<String> stages = (List<String>) detail.get('stages');
        System.assert(stages.size() > 0, 'Should have stage pipeline');

        Integer fileCount = (Integer) detail.get('fileCount');
        System.assertEquals(0, fileCount, 'Should have 0 files');
    }

    @IsTest
    static void testSubmitPortalRequest() {
        NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Acme Corp' LIMIT 1];

        Map<String, String> requestData = new Map<String, String>{
            'title' => 'New Feature Request',
            'description' => 'Please add dark mode support.',
            'priority' => 'High',
            'type' => 'Internal',
            'networkEntityId' => entityA.Id
        };

        Test.startTest();
        Id newItemId = DeliveryPortalController.submitPortalRequest(requestData);
        Test.stopTest();

        WorkItem__c created = [
            SELECT BriefDescriptionTxt__c, DetailsTxt__c, PriorityPk__c,
                   StageNamePk__c, IsActiveBool__c, ClientNetworkEntityId__c
            FROM WorkItem__c
            WHERE Id = :newItemId
            LIMIT 1
        ];

        System.assertEquals('[Portal] New Feature Request', created.BriefDescriptionTxt__c, 'Title should have [Portal] prefix');
        System.assertEquals('Please add dark mode support.', created.DetailsTxt__c, 'Description should match');
        System.assertEquals('High', created.PriorityPk__c, 'Priority should match');
        System.assertEquals('Backlog', created.StageNamePk__c, 'New items should start in Backlog');
        System.assertEquals(true, created.IsActiveBool__c, 'Should be active');
        System.assertEquals(entityA.Id, created.ClientNetworkEntityId__c, 'Should be linked to the entity');
    }

    @IsTest
    static void testSubmitPortalRequestMissingTitle() {
        Boolean exceptionThrown = false;

        Map<String, String> requestData = new Map<String, String>{
            'title' => '',
            'description' => 'Some description'
        };

        Test.startTest();
        try {
            DeliveryPortalController.submitPortalRequest(requestData);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Title is required'), 'Should get title required error');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for missing title');
    }

    @IsTest
    static void testSubmitPortalRequestDefaults() {
        Map<String, String> requestData = new Map<String, String>{
            'title' => 'Minimal Request'
        };

        Test.startTest();
        Id newItemId = DeliveryPortalController.submitPortalRequest(requestData);
        Test.stopTest();

        WorkItem__c created = [
            SELECT PriorityPk__c, RequestTypePk__c
            FROM WorkItem__c
            WHERE Id = :newItemId
            LIMIT 1
        ];

        System.assertEquals('Medium', created.PriorityPk__c, 'Default priority should be Medium');
        System.assertEquals('Internal', created.RequestTypePk__c, 'Default request type should be Internal');
    }

    @IsTest
    static void testAddPortalComment() {
        WorkItem__c item = [
            SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Active Item 1' LIMIT 1
        ];

        Test.startTest();
        Id commentId = DeliveryPortalController.addPortalComment(item.Id, 'This is a portal comment.');
        Test.stopTest();

        WorkItemComment__c comment = [
            SELECT BodyTxt__c, AuthorTxt__c, SourcePk__c
            FROM WorkItemComment__c
            WHERE Id = :commentId
            LIMIT 1
        ];

        System.assertEquals('This is a portal comment.', comment.BodyTxt__c, 'Comment body should match');
        System.assertEquals('Portal User', comment.AuthorTxt__c, 'Author should be Portal User');
        System.assertEquals('Client', comment.SourcePk__c, 'Source should be Client');
    }

    @IsTest
    static void testAddPortalCommentEmptyBody() {
        WorkItem__c item = [
            SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Active Item 1' LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            DeliveryPortalController.addPortalComment(item.Id, '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Comment body is required'), 'Should get body required error');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for empty comment body');
    }

    @IsTest
    static void testAddPortalCommentInvalidWorkItem() {
        Boolean exceptionThrown = false;

        // Use a fabricated Id that does not exist
        Id fakeId = WorkItem__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        try {
            DeliveryPortalController.addPortalComment(fakeId, 'Test comment');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Work item not found'), 'Should get not found error');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for invalid work item');
    }
}
