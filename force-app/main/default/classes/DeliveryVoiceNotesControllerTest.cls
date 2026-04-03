/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryVoiceNotesController. Validates single and batch
 *               work item creation from voice transcripts, date parsing, truncation,
 *               and error handling.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryVoiceNotesControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void testCreateSingleWorkItemFromVoice() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryVoiceNotesController.VoiceNoteResult result =
                DeliveryVoiceNotesController.createWorkItemFromVoice(
                    'Customer needs safety helmets and gloves by next week',
                    'Safety equipment order',
                    'High',
                    null,
                    null,
                    null
                );
            Test.stopTest();

            System.assertNotEquals(null, result.recordId, 'Record Id should be returned');
            System.assertNotEquals(null, result.recordName, 'Auto-number name should be returned');

            WorkItem__c wi = [
                SELECT BriefDescriptionTxt__c, DetailsTxt__c, PriorityPk__c,
                       StageNamePk__c, StatusPk__c, ActivatedDateTime__c
                FROM WorkItem__c
                WHERE Id = :result.recordId
                LIMIT 1
            ];

            System.assertEquals('Safety equipment order', wi.BriefDescriptionTxt__c,
                'Brief description should use the provided title');
            System.assert(wi.DetailsTxt__c.contains('[Voice Note]'),
                'Details should contain Voice Note tag');
            System.assertEquals('High', wi.PriorityPk__c, 'Priority should match');
            System.assertEquals('Backlog', wi.StageNamePk__c, 'Stage should be Backlog');
            System.assertEquals('New', wi.StatusPk__c, 'Status should be New');
            System.assertNotEquals(null, wi.ActivatedDateTime__c, 'Should be activated');
        }
    }

    @IsTest
    static void testCreateWorkItemWithDateParsing() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryVoiceNotesController.VoiceNoteResult result =
                DeliveryVoiceNotesController.createWorkItemFromVoice(
                    'Follow up with client about fluid solutions order',
                    null,
                    'Medium',
                    '2026-04-15',
                    null,
                    null
                );
            Test.stopTest();

            WorkItem__c wi = [
                SELECT EstimatedStartDevDate__c, BriefDescriptionTxt__c
                FROM WorkItem__c
                WHERE Id = :result.recordId
                LIMIT 1
            ];

            System.assertEquals(Date.valueOf('2026-04-15'), wi.EstimatedStartDevDate__c,
                'Estimated start date should be parsed from the ISO string');
            System.assert(wi.BriefDescriptionTxt__c.startsWith('Follow up'),
                'Brief description should derive from transcript when title is blank');
        }
    }

    @IsTest
    static void testCreateWorkItemInvalidDateSkipped() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryVoiceNotesController.VoiceNoteResult result =
                DeliveryVoiceNotesController.createWorkItemFromVoice(
                    'Need to call vendor tomorrow',
                    null,
                    'Low',
                    'not-a-date',
                    null,
                    null
                );
            Test.stopTest();

            WorkItem__c wi = [
                SELECT EstimatedStartDevDate__c
                FROM WorkItem__c
                WHERE Id = :result.recordId
                LIMIT 1
            ];

            System.assertEquals(null, wi.EstimatedStartDevDate__c,
                'Invalid date should be silently skipped');
        }
    }

    @IsTest
    static void testCreateWorkItemTruncatesLongTranscript() {
        System.runAs(testUser) {
            String longText = 'A'.repeat(200);

            Test.startTest();
            DeliveryVoiceNotesController.VoiceNoteResult result =
                DeliveryVoiceNotesController.createWorkItemFromVoice(
                    longText, null, 'Medium', null, null, null
                );
            Test.stopTest();

            WorkItem__c wi = [
                SELECT BriefDescriptionTxt__c, DetailsTxt__c
                FROM WorkItem__c
                WHERE Id = :result.recordId
                LIMIT 1
            ];

            System.assertEquals(100, wi.BriefDescriptionTxt__c.length(),
                'Brief description should be truncated to 100 chars');
            System.assert(wi.DetailsTxt__c.contains(longText),
                'Full transcript should be in Details');
        }
    }

    @IsTest
    static void testCreateWorkItemBlankTranscriptThrows() {
        System.runAs(testUser) {
            Boolean threw = false;
            Test.startTest();
            try {
                DeliveryVoiceNotesController.createWorkItemFromVoice('', null, 'Medium', null, null, null);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assert(threw, 'Should throw AuraHandledException for blank transcript');
        }
    }

    @IsTest
    static void testCreateWorkItemNullTranscriptThrows() {
        System.runAs(testUser) {
            Boolean threw = false;
            Test.startTest();
            try {
                DeliveryVoiceNotesController.createWorkItemFromVoice(null, null, 'Medium', null, null, null);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assert(threw, 'Should throw AuraHandledException for null transcript');
        }
    }

    @IsTest
    static void testCreateWorkItemDefaultPriority() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryVoiceNotesController.VoiceNoteResult result =
                DeliveryVoiceNotesController.createWorkItemFromVoice(
                    'Quick note about warehouse inventory',
                    null,
                    null,
                    null,
                    null,
                    null
                );
            Test.stopTest();

            WorkItem__c wi = [
                SELECT PriorityPk__c
                FROM WorkItem__c
                WHERE Id = :result.recordId
                LIMIT 1
            ];

            System.assertEquals('Medium', wi.PriorityPk__c,
                'Null priority should default to Medium');
        }
    }

    @IsTest
    static void testBatchCreateWorkItems() {
        System.runAs(testUser) {
            List<Map<String, String>> segments = new List<Map<String, String>>{
                new Map<String, String>{ 'text' => 'Order safety helmets', 'startDate' => '2026-04-10' },
                new Map<String, String>{ 'text' => 'Schedule fluid delivery', 'startDate' => '' },
                new Map<String, String>{ 'text' => 'Follow up on invoice' }
            };

            Test.startTest();
            List<DeliveryVoiceNotesController.VoiceNoteResult> results =
                DeliveryVoiceNotesController.createBatchWorkItems(
                    JSON.serialize(segments), 'High'
                );
            Test.stopTest();

            System.assertEquals(3, results.size(), 'Should create 3 work items');

            for (DeliveryVoiceNotesController.VoiceNoteResult r : results) {
                System.assertNotEquals(null, r.recordId, 'Each result should have a record Id');
                System.assertNotEquals(null, r.recordName, 'Each result should have a name');
            }

            // Verify first item has parsed date
            WorkItem__c first = [
                SELECT EstimatedStartDevDate__c
                FROM WorkItem__c
                WHERE Id = :results[0].recordId
                LIMIT 1
            ];
            System.assertEquals(Date.valueOf('2026-04-10'), first.EstimatedStartDevDate__c,
                'First segment should have parsed date');
        }
    }

    @IsTest
    static void testBatchCreateSkipsBlankSegments() {
        System.runAs(testUser) {
            List<Map<String, String>> segments = new List<Map<String, String>>{
                new Map<String, String>{ 'text' => 'Valid note' },
                new Map<String, String>{ 'text' => '' },
                new Map<String, String>{ 'text' => '   ' }
            };

            Test.startTest();
            List<DeliveryVoiceNotesController.VoiceNoteResult> results =
                DeliveryVoiceNotesController.createBatchWorkItems(
                    JSON.serialize(segments), 'Medium'
                );
            Test.stopTest();

            System.assertEquals(1, results.size(),
                'Should only create 1 work item, skipping blank segments');
        }
    }

    @IsTest
    static void testBatchCreateEmptySegmentsThrows() {
        System.runAs(testUser) {
            Boolean threw = false;
            Test.startTest();
            try {
                DeliveryVoiceNotesController.createBatchWorkItems('', 'Medium');
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assert(threw, 'Should throw for blank segments input');
        }
    }

    @IsTest
    static void testBatchCreateAllBlankSegmentsThrows() {
        System.runAs(testUser) {
            List<Map<String, String>> segments = new List<Map<String, String>>{
                new Map<String, String>{ 'text' => '' },
                new Map<String, String>{ 'text' => '  ' }
            };

            Boolean threw = false;
            Test.startTest();
            try {
                DeliveryVoiceNotesController.createBatchWorkItems(
                    JSON.serialize(segments), 'Low'
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assert(threw, 'Should throw when all segments are blank');
        }
    }

    @IsTest
    static void testGetEntityNames() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, String>> entities = DeliveryVoiceNotesController.getEntityNames();
            Test.stopTest();

            System.assertNotEquals(null, entities, 'Should return a list');
        }
    }

    @IsTest
    static void testCreateWorkItemWithEntityAndActionType() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryVoiceNotesController.VoiceNoteResult result =
                DeliveryVoiceNotesController.createWorkItemFromVoice(
                    'Urgent bug fix for the login page',
                    'Login page broken',
                    'High',
                    null,
                    null,
                    'Bug Fix'
                );
            Test.stopTest();

            WorkItem__c wi = [
                SELECT RequestTypePk__c
                FROM WorkItem__c
                WHERE Id = :result.recordId
                LIMIT 1
            ];

            System.assertEquals('Bug Fix', wi.RequestTypePk__c,
                'Action type should be set as request type');
        }
    }

    @IsTest
    static void testBatchCreateDefaultPriority() {
        System.runAs(testUser) {
            List<Map<String, String>> segments = new List<Map<String, String>>{
                new Map<String, String>{ 'text' => 'Test item with default priority' }
            };

            Test.startTest();
            List<DeliveryVoiceNotesController.VoiceNoteResult> results =
                DeliveryVoiceNotesController.createBatchWorkItems(
                    JSON.serialize(segments), null
                );
            Test.stopTest();

            WorkItem__c wi = [
                SELECT PriorityPk__c
                FROM WorkItem__c
                WHERE Id = :results[0].recordId
                LIMIT 1
            ];

            System.assertEquals('Medium', wi.PriorityPk__c,
                'Null priority in batch should default to Medium');
        }
    }
}
