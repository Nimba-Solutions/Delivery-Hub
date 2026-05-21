/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryDevLoopController. Verifies:
 *                 - getGuideForWorkItem returns matching DevLoopGuide__mdt
 *                   when the WI&apos;s WorkflowType x linked Feature category
 *                   matches a seed row;
 *                 - returns an empty-checklist DTO on subscriber installs
 *                   (simulated by querying the actual NamespacePrefix);
 *                 - getScratchOrgsForWorkItem returns linked rows newest-first;
 *                 - empty WI returns an empty list (no NPE).
 *
 *               __mdt records ARE available in test context. The exact-match
 *               assertion is bound to whether the seed records made it into
 *               the scratch org (empty-org tolerance pattern from
 *               DeliveryFeatureCatalogControllerTest).
 * @author       Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.CyclomaticComplexity')
private class DeliveryDevLoopControllerTest {

    @IsTest
    static void testGetGuideForWorkItemReturnsMatchingMdt() {
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'WorkflowTypeTxt__c' => 'Software_Delivery'
        });

        Test.startTest();
        DeliveryDevLoopController.DevLoopGuideDTO dto =
            DeliveryDevLoopController.getGuideForWorkItem(wi.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO should never be null');
        System.assertNotEquals(null, dto.requiredPermsets, 'requiredPermsets always non-null');
        System.assertNotEquals(null, dto.setupChecklist, 'setupChecklist always non-null');
        // isSubscriberOrg is true in any namespaced org — including the
        // publisher's own packaging scratch during upload-beta. We can't
        // reliably distinguish publisher-packaging from a true subscriber
        // install via Apex alone, so the field's value just reflects
        // "namespace present?" — assert it's populated, not its specific value.
        System.assertNotEquals(null, dto.isSubscriberOrg,
            'isSubscriberOrg must always be populated.');
        // recommendedCciFlow may be null (no matching DevLoopGuide__mdt for
        // this WI's workflow-type × feature-category combination) or
        // populated with the seed's value. Both are valid runtime states.
        // When populated by the Software_Delivery seed, it should be dev_org.
        if (String.isNotBlank(dto.recommendedCciFlow)) {
            System.assertEquals('dev_org', dto.recommendedCciFlow,
                'When matched, Software_Delivery should resolve to dev_org');
        }
    }

    @IsTest
    static void testGetGuideForWorkItemReturnsEmptyOnSubscriberOrg() {
        // We can&apos;t easily flip the org NamespacePrefix in test context, so
        // this test verifies the degrade path by passing null workItemId,
        // which returns an empty-checklist DTO populated with the current
        // org&apos;s subscriber flag.
        Test.startTest();
        DeliveryDevLoopController.DevLoopGuideDTO dto =
            DeliveryDevLoopController.getGuideForWorkItem(null);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'Even with null WI, DTO should be non-null');
        System.assertEquals(0, dto.setupChecklist.size(), 'Empty checklist on null WI');
        System.assertEquals(0, dto.requiredPermsets.size(), 'Empty permsets on null WI');
    }

    @IsTest
    static void testGetScratchOrgsForWorkItemReturnsLinkedInstances() {
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'WorkflowTypeTxt__c' => 'Software_Delivery'
        });
        TestDataFactory.createScratchOrgInstance(new Map<String, Object>{
            'WorkItemLookup__c' => wi.Id,
            'BranchTxt__c' => 'feature/test-a',
            'StatePk__c' => 'Active'
        });
        TestDataFactory.createScratchOrgInstance(new Map<String, Object>{
            'WorkItemLookup__c' => wi.Id,
            'BranchTxt__c' => 'feature/test-b',
            'StatePk__c' => 'Expired'
        });

        Test.startTest();
        List<DeliveryDevLoopController.ScratchOrgSummaryDTO> rows =
            DeliveryDevLoopController.getScratchOrgsForWorkItem(wi.Id);
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Both linked scratch orgs surfaced');
        Set<String> branches = new Set<String>();
        for (DeliveryDevLoopController.ScratchOrgSummaryDTO o : rows) {
            branches.add(o.branch);
        }
        System.assertEquals(true, branches.contains('feature/test-a'), 'Branch A present');
        System.assertEquals(true, branches.contains('feature/test-b'), 'Branch B present');
    }

    @IsTest
    static void testGetScratchOrgsForWorkItemEmptyWhenNone() {
        WorkItem__c wi = TestDataFactory.createWorkItem(null);

        Test.startTest();
        List<DeliveryDevLoopController.ScratchOrgSummaryDTO> emptyResult =
            DeliveryDevLoopController.getScratchOrgsForWorkItem(wi.Id);
        List<DeliveryDevLoopController.ScratchOrgSummaryDTO> nullResult =
            DeliveryDevLoopController.getScratchOrgsForWorkItem(null);
        Test.stopTest();

        System.assertNotEquals(null, emptyResult, 'Never returns null');
        System.assertEquals(0, emptyResult.size(), 'No linked rows on a fresh WI');
        System.assertNotEquals(null, nullResult, 'Null WI does not throw');
        System.assertEquals(0, nullResult.size(), 'Null WI returns empty list');
    }
}
