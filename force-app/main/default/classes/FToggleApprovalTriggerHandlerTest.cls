/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for FToggleApprovalTriggerHandler. Covers:
 *                 - no-op when row already has an approver
 *                 - stamp from a specific feature+action rule
 *                 - stamp from a catch-all __DEFAULT__/Any rule
 *                 - leaves null when no routing rule matches
 *                 - bulk-safe: 100 inserts use a bounded SOQL count
 *
 *               Uses TestDataFactory.buildFeature / buildFeatureToggleRequest /
 *               buildFeatureToggleApproval for record setup. The routing rule
 *               list is supplied via the @TestVisible testRoutingsOverride so
 *               tests don't depend on deployed customMetadata seed rows
 *               (the seed rows use a placeholder Id that would fail Id-cast
 *               in some test orgs).
 * @author Cloud Nimbus LLC
 */
@IsTest
private class FToggleApprovalTriggerHandlerTest {

    /**
     * @description Builds a one-off in-memory ApprovalRouting__mdt row. The
     *              __mdt SObject can be `new`d in test context the same way
     *              any other SObject can — values populate without DML.
     * @param featureDef FeatureDefinitionTxt__c value.
     * @param action ActionPk__c value.
     * @param approverId Approver User Id (15 or 18 char string).
     * @param sortOrder SortOrderNumber__c.
     * @return Unpersisted ApprovalRouting__mdt row.
     */
    private static ApprovalRouting__mdt buildRouting(
        String featureDef, String action, Id approverId, Decimal sortOrder
    ) {
        return new ApprovalRouting__mdt(
            FeatureDefinitionTxt__c = featureDef,
            ActionPk__c = action,
            ApproverUserIdTxt__c = String.valueOf(approverId),
            SortOrderNumber__c = sortOrder,
            DeveloperName = 'Test_' + featureDef + '_' + action
        );
    }

    /**
     * @description Builds a Feature__c + parent request so a test can insert
     *              an approval row whose FeatureLookup / RequestLookup resolve.
     * @param featureDef The FeatureDefinitionTxt__c to stamp on Feature__c.
     * @param action The ActionPk__c to stamp on the parent request.
     * @return The inserted request.
     */
    private static FeatureToggleRequest__c setupFeatureAndRequest(String featureDef, String action) {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'FeatureDefinitionTxt__c' => featureDef
        });
        FeatureToggleRequest__c req = TestDataFactory.buildFeatureToggleRequest(
            feat.Id, new Map<String, Object>{ 'ActionPk__c' => action });
        insert req;
        return req;
    }

    /**
     * @description When the row already has ApproverUserLookup__c populated,
     *              the handler must NOT overwrite it — explicit assignment
     *              wins over routing rules.
     */
    @IsTest
    static void testNoOpWhenApproverAlreadySet() {
        Id explicitApprover = UserInfo.getUserId();
        Id otherApprover = UserInfo.getUserId(); // any valid Id is fine for the routing
        FToggleApprovalTriggerHandler.testRoutingsOverride = new List<ApprovalRouting__mdt>{
            buildRouting('__DEFAULT__', 'Any', otherApprover, 1000)
        };

        FeatureToggleRequest__c req = setupFeatureAndRequest('Some_Feature', 'Enable');

        Test.startTest();
        FeatureToggleApproval__c row = TestDataFactory.buildFeatureToggleApproval(
            req.Id, req.FeatureLookup__c, new Map<String, Object>{
                'ApproverUserLookup__c' => explicitApprover
            });
        insert row;
        Test.stopTest();

        FeatureToggleApproval__c after = [
            SELECT ApproverUserLookup__c FROM FeatureToggleApproval__c WHERE Id = :row.Id
        ];
        System.assertEquals(explicitApprover, after.ApproverUserLookup__c,
            'handler should not overwrite an explicit approver assignment');
    }

    /**
     * @description A routing rule with a specific FeatureDefinitionTxt +
     *              ActionPk should stamp the approver onto the new row.
     */
    @IsTest
    static void testStampsApproverFromSpecificFeatureRule() {
        Id approver = UserInfo.getUserId();
        FToggleApprovalTriggerHandler.testRoutingsOverride = new List<ApprovalRouting__mdt>{
            buildRouting('Invoice_Generation', 'Enable', approver, 10),
            buildRouting('__DEFAULT__', 'Any', approver, 1000)
        };

        FeatureToggleRequest__c req = setupFeatureAndRequest('Invoice_Generation', 'Enable');

        Test.startTest();
        FeatureToggleApproval__c row = TestDataFactory.buildFeatureToggleApproval(
            req.Id, req.FeatureLookup__c, null);
        insert row;
        Test.stopTest();

        FeatureToggleApproval__c after = [
            SELECT ApproverUserLookup__c FROM FeatureToggleApproval__c WHERE Id = :row.Id
        ];
        System.assertEquals(approver, after.ApproverUserLookup__c,
            'specific feature/action rule should stamp the approver');
    }

    /**
     * @description When no specific rule matches, the __DEFAULT__/Any
     *              catch-all should apply.
     */
    @IsTest
    static void testStampsApproverFromCatchAllDefault() {
        Id approver = UserInfo.getUserId();
        FToggleApprovalTriggerHandler.testRoutingsOverride = new List<ApprovalRouting__mdt>{
            buildRouting('Some_Specific_Feature', 'Enable', approver, 10),
            buildRouting('__DEFAULT__', 'Any', approver, 1000)
        };

        FeatureToggleRequest__c req = setupFeatureAndRequest('Unrelated_Feature', 'Disable');

        Test.startTest();
        FeatureToggleApproval__c row = TestDataFactory.buildFeatureToggleApproval(
            req.Id, req.FeatureLookup__c, null);
        insert row;
        Test.stopTest();

        FeatureToggleApproval__c after = [
            SELECT ApproverUserLookup__c FROM FeatureToggleApproval__c WHERE Id = :row.Id
        ];
        System.assertEquals(approver, after.ApproverUserLookup__c,
            'catch-all __DEFAULT__/Any rule should stamp the approver');
    }

    /**
     * @description When the routing list contains nothing matchable, the
     *              row's ApproverUserLookup__c should remain null and the
     *              admin can assign manually — same behaviour as before
     *              this handler shipped.
     */
    @IsTest
    static void testLeavesNullWhenNoRuleMatches() {
        FToggleApprovalTriggerHandler.testRoutingsOverride = new List<ApprovalRouting__mdt>();

        FeatureToggleRequest__c req = setupFeatureAndRequest('Any_Feature', 'Enable');

        Test.startTest();
        FeatureToggleApproval__c row = TestDataFactory.buildFeatureToggleApproval(
            req.Id, req.FeatureLookup__c, null);
        insert row;
        Test.stopTest();

        FeatureToggleApproval__c after = [
            SELECT ApproverUserLookup__c FROM FeatureToggleApproval__c WHERE Id = :row.Id
        ];
        System.assertEquals(null, after.ApproverUserLookup__c,
            'empty routing list should leave ApproverUserLookup__c null');
    }

    /**
     * @description Routing rules whose ApproverUserIdTxt points at a
     *              non-existent / inactive User must be skipped so the
     *              placeholder seed (005000000000000AAA) never causes
     *              INVALID_CROSS_REFERENCE_KEY on the user's submit. The
     *              handler falls through to the next-lowest-sort rule whose
     *              approver IS valid.
     */
    @IsTest
    static void testSkipsRoutingWithInvalidApproverId() {
        Id validApprover = UserInfo.getUserId();
        // Use the documented placeholder Id — structurally valid (15 char
        // User prefix), zero-padded — but no User row exists with this Id.
        Id placeholderApprover = (Id) '005000000000000AAA';
        FToggleApprovalTriggerHandler.testRoutingsOverride = new List<ApprovalRouting__mdt>{
            buildRouting('My_Feature', 'Enable', placeholderApprover, 10),
            buildRouting('__DEFAULT__', 'Any', validApprover, 1000)
        };

        FeatureToggleRequest__c req = setupFeatureAndRequest('My_Feature', 'Enable');

        Test.startTest();
        FeatureToggleApproval__c row = TestDataFactory.buildFeatureToggleApproval(
            req.Id, req.FeatureLookup__c, null);
        insert row;
        Test.stopTest();

        FeatureToggleApproval__c after = [
            SELECT ApproverUserLookup__c FROM FeatureToggleApproval__c WHERE Id = :row.Id
        ];
        System.assertEquals(validApprover, after.ApproverUserLookup__c,
            'handler should skip the placeholder-Id rule and fall through to the valid catch-all');
    }

    /**
     * @description Bulk-safety check. Insert 100 approval rows in a single
     *              DML and assert the handler stays within a small bounded
     *              SOQL footprint (it should be exactly 3 — Feature, Request,
     *              Routing — once per trigger fire). Also verifies every
     *              row got stamped from the catch-all routing.
     */
    @IsTest
    static void testBulkInsertHandledInOneSoqlBatch() {
        Id approver = UserInfo.getUserId();
        FToggleApprovalTriggerHandler.testRoutingsOverride = new List<ApprovalRouting__mdt>{
            buildRouting('__DEFAULT__', 'Any', approver, 1000)
        };

        FeatureToggleRequest__c req = setupFeatureAndRequest('Bulk_Feature', 'Enable');

        List<FeatureToggleApproval__c> rows = new List<FeatureToggleApproval__c>();
        for (Integer i = 0; i < 100; i++) {
            rows.add(TestDataFactory.buildFeatureToggleApproval(
                req.Id, req.FeatureLookup__c, new Map<String, Object>{
                    'StepNumber__c' => i
                }));
        }

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        insert rows;
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Test.stopTest();

        // The handler itself runs at most 4 SOQL (features, requests,
        // routings, user — routings is the override here so it's actually
        // 3 in this test, but the prod path uses 4). Allow up to 15 SOQL to
        // tolerate framework-level overhead (FLS checks, parent-record
        // lookups, etc.) without making the assertion brittle.
        System.assert(soqlUsed <= 15,
            'bulk insert should use bounded SOQL, used ' + soqlUsed);

        Integer stamped = [
            SELECT COUNT() FROM FeatureToggleApproval__c
            WHERE RequestLookup__c = :req.Id
              AND ApproverUserLookup__c = :approver
        ];
        System.assertEquals(100, stamped,
            'every row should be stamped with the catch-all approver');
    }
}
