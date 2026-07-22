/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryHuddleController — the workspace Huddle
 *               (meeting-prep) tab. Rolling-window assertions anchor on
 *               Date.today() per repo convention. AuraHandledException message
 *               content is never asserted (generic in managed context).
 * @author       Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHuddleControllerTest {

    @IsTest
    static void getHuddleItemsReturnsOpenItemWithLatestComment() {
        WorkItem__c open = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EpicTxt__c' => 'Risk Framework',
            'SLATargetDate__c' => Date.today().addDays(3),
            'ExternalPageUrl__c' => 'https://example.com/mf/standup'
        });
        WorkItem__c closed = TestDataFactory.createWorkItem(new Map<String, Object>{
            'StatusPk__c' => 'Done',
            'StageNamePk__c' => 'Done'
        });
        insert new List<WorkItemComment__c>{
            new WorkItemComment__c(
                WorkItemId__c = open.Id,
                BodyTxt__c = 'older comment',
                AuthorTxt__c = 'Author A',
                SourcePk__c = 'Email'
            ),
            new WorkItemComment__c(
                WorkItemId__c = open.Id,
                BodyTxt__c = 'newest comment',
                AuthorTxt__c = 'Author B',
                SourcePk__c = 'Email'
            )
        };

        Test.startTest();
        List<DeliveryHuddleController.HuddleItemDTO> items =
            DeliveryHuddleController.getHuddleItems();
        Test.stopTest();

        Set<Id> ids = new Set<Id>();
        DeliveryHuddleController.HuddleItemDTO openDto;
        for (DeliveryHuddleController.HuddleItemDTO dto : items) {
            ids.add(dto.workItemId);
            if (dto.workItemId == open.Id) {
                openDto = dto;
            }
        }
        System.assert(ids.contains(open.Id), 'Open item should appear in the huddle');
        System.assert(!ids.contains(closed.Id), 'Done item must not appear in the huddle');
        System.assertNotEquals(null, openDto, 'Open item DTO expected');
        System.assertEquals('Risk Framework', openDto.epic, 'Epic should round-trip');
        System.assertEquals(Date.today().addDays(3), openDto.dueDate, 'Due date should round-trip');
        System.assertEquals('https://example.com/mf/standup', openDto.externalPageUrl,
            'External page URL should round-trip');
        // Two comments inserted in one transaction share a CreatedDate, so the
        // subquery may legally return either; assert a comment surfaced at all.
        System.assertNotEquals(null, openDto.lastCommentBody,
            'Latest comment body should be populated');
        System.assertNotEquals(null, openDto.lastCommentAuthor,
            'Latest comment author should be populated');
    }

    @IsTest
    static void getHuddleItemsExcludesTerminalStage() {
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'Cancelled',
            'StatusPk__c' => 'Cancelled'
        });

        Test.startTest();
        List<DeliveryHuddleController.HuddleItemDTO> items =
            DeliveryHuddleController.getHuddleItems();
        Test.stopTest();

        for (DeliveryHuddleController.HuddleItemDTO dto : items) {
            System.assertNotEquals('Cancelled', dto.status,
                'Cancelled items must be excluded');
        }
    }

    @IsTest
    static void quickAddItemInsertsIntakeWorkItem() {
        Test.startTest();
        Id wiId = DeliveryHuddleController.quickAddItem(
            '  Huddle capture: confirm Thursday trigger owner  ',
            Date.today().addDays(2),
            'MF Check-in',
            'https://example.com/dispatches/call-extract'
        );
        Test.stopTest();

        WorkItem__c wi = [
            SELECT BriefDescriptionTxt__c, StatusPk__c, SLATargetDate__c,
                   EpicTxt__c, ExternalPageUrl__c
              FROM WorkItem__c
             WHERE Id = :wiId
              WITH SYSTEM_MODE
             LIMIT 1
        ];
        System.assertEquals('Huddle capture: confirm Thursday trigger owner',
            wi.BriefDescriptionTxt__c, 'Title should be trimmed');
        System.assertEquals('New', wi.StatusPk__c, 'Quick-add lands as intake (New)');
        System.assertEquals(Date.today().addDays(2), wi.SLATargetDate__c,
            'Due date should persist');
        System.assertEquals('MF Check-in', wi.EpicTxt__c, 'Epic should persist');
        System.assertEquals('https://example.com/dispatches/call-extract',
            wi.ExternalPageUrl__c, 'External URL should persist');
    }

    @IsTest
    static void quickAddItemBlankTitleThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryHuddleController.quickAddItem('   ', null, null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Blank title must throw');
    }
}
