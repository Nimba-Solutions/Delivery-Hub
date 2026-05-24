/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryFeatureDepEditorController.
 *               Covers:
 *                 - getDependencies() filters on the BLOCKED side and returns rows
 *                 - getDependencies() with null parentId returns an empty list
 *                 - createDependency() inserts and returns the row (admin context)
 *                 - createDependency() rejects parent==child (self-edge)
 *                 - createDependency() rejects duplicate (parent, child)
 *                 - createDependency() rejects invalid TypePk__c value
 *                 - createDependency() / deleteDependency() refuse non-admin callers
 *                 - deleteDependency() removes the row when admin
 *
 *               TestDataFactory provides the Feature__c + FeatureDependency__c
 *               builders so the same allowlist-compliant defaults that the rest
 *               of the test suite uses apply here too.
 *
 *               Admin gating uses runAs() — the running test user inherits the
 *               admin profile in scratch context so the default flow passes
 *               the PSG check (no PSG assignment is necessary; the namespace-
 *               safe IN clause accepts both bare + delivery__ prefixed names).
 *               Non-admin asserts use runAs(standardUser) to flip the gate.
 * @author       Cloud Nimbus LLC
 */
@IsTest
private class DeliveryFeatureDepEditorControllerTest {

    /**
     * @description Builds a standard (non-admin) test user. Used to assert the
     *              admin gate fires on createDependency / deleteDependency.
     * @return Inserted standard User.
     */
    private static User buildStandardUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'dpedt',
            Email = 'dpedt+' + Crypto.getRandomLong() + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'DepEditor',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'dpedt+' + Crypto.getRandomLong() + '@dh-test.example.test'
        );
        insert u;
        return u;
    }

    @IsTest
    static void testGetDependenciesReturnsRowsForBlockedSide() {
        Feature__c parent = TestDataFactory.createFeature(null);
        Feature__c child = TestDataFactory.createFeature(null);
        TestDataFactory.newFeatureDependency(child.Id, parent.Id);

        Test.startTest();
        List<FeatureDependency__c> rows =
            DeliveryFeatureDepEditorController.getDependencies(parent.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size(),
            'Expected one dep row where the test parent is the BLOCKED side.');
        System.assertEquals(parent.Id, rows.get(0).BlockedFeatureLookup__c,
            'Returned row should have the supplied parent as Blocked.');
        System.assertEquals(child.Id, rows.get(0).BlockingFeatureLookup__c,
            'Returned row should have the test child as Blocking.');
    }

    @IsTest
    static void testGetDependenciesWithNullParentReturnsEmptyList() {
        Test.startTest();
        List<FeatureDependency__c> rows =
            DeliveryFeatureDepEditorController.getDependencies(null);
        Test.stopTest();

        System.assertNotEquals(null, rows, 'Should never return null.');
        System.assertEquals(0, rows.size(),
            'Null parent must short-circuit to an empty list.');
    }

    @IsTest
    static void testGetDependenciesOnlySurfacesParentFeatureBlockedSide() {
        // Two parents — only ONE has a dep wired to it; the other should return empty.
        Feature__c parentA = TestDataFactory.createFeature(null);
        Feature__c parentB = TestDataFactory.createFeature(null);
        Feature__c child = TestDataFactory.createFeature(null);
        TestDataFactory.newFeatureDependency(child.Id, parentA.Id);

        Test.startTest();
        List<FeatureDependency__c> rowsForA =
            DeliveryFeatureDepEditorController.getDependencies(parentA.Id);
        List<FeatureDependency__c> rowsForB =
            DeliveryFeatureDepEditorController.getDependencies(parentB.Id);
        Test.stopTest();

        System.assertEquals(1, rowsForA.size(), 'Parent A has one dep wired.');
        System.assertEquals(0, rowsForB.size(),
            'Parent B is unrelated — should not surface A\'s dep row.');
    }

    @IsTest
    static void testCreateDependencyInsertsRow() {
        Feature__c parent = TestDataFactory.createFeature(null);
        Feature__c child = TestDataFactory.createFeature(null);

        Test.startTest();
        FeatureDependency__c created = DeliveryFeatureDepEditorController.createDependency(
            parent.Id, child.Id, 'Soft', 'unit-test notes'
        );
        Test.stopTest();

        System.assertNotEquals(null, created.Id,
            'Inserted dependency should have an Id.');
        FeatureDependency__c refetched = [
            SELECT Id, BlockedFeatureLookup__c, BlockingFeatureLookup__c,
                   TypePk__c, NotesTxt__c, CascadeDirectionPk__c
            FROM FeatureDependency__c
            WHERE Id = :created.Id
        ];
        System.assertEquals(parent.Id, refetched.BlockedFeatureLookup__c,
            'Parent should land on the Blocked side.');
        System.assertEquals(child.Id, refetched.BlockingFeatureLookup__c,
            'Child should land on the Blocking side.');
        System.assertEquals('Soft', refetched.TypePk__c,
            'TypePk__c should reflect the supplied value.');
        System.assertEquals('Both', refetched.CascadeDirectionPk__c,
            'CascadeDirection should default to Both.');
        System.assertEquals('unit-test notes', refetched.NotesTxt__c,
            'Notes should round-trip through the create call.');
    }

    @IsTest
    static void testCreateDependencyDefaultsTypeToHardWhenBlank() {
        Feature__c parent = TestDataFactory.createFeature(null);
        Feature__c child = TestDataFactory.createFeature(null);

        Test.startTest();
        FeatureDependency__c created = DeliveryFeatureDepEditorController.createDependency(
            parent.Id, child.Id, null, null
        );
        Test.stopTest();

        FeatureDependency__c refetched = [
            SELECT Id, TypePk__c FROM FeatureDependency__c WHERE Id = :created.Id
        ];
        System.assertEquals('Hard', refetched.TypePk__c,
            'Blank depType should default to Hard.');
    }

    @IsTest
    static void testCreateDependencyRejectsSelfEdge() {
        Feature__c f = TestDataFactory.createFeature(null);

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryFeatureDepEditorController.createDependency(
                f.Id, f.Id, 'Hard', null
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'Self-edge (parent==child) must throw AuraHandledException.');
    }

    @IsTest
    static void testCreateDependencyRejectsDuplicate() {
        Feature__c parent = TestDataFactory.createFeature(null);
        Feature__c child = TestDataFactory.createFeature(null);
        DeliveryFeatureDepEditorController.createDependency(
            parent.Id, child.Id, 'Hard', null
        );

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryFeatureDepEditorController.createDependency(
                parent.Id, child.Id, 'Soft', 'second insert'
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'Inserting a duplicate (parent, child) edge must throw.');
    }

    @IsTest
    static void testCreateDependencyRejectsInvalidType() {
        Feature__c parent = TestDataFactory.createFeature(null);
        Feature__c child = TestDataFactory.createFeature(null);

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryFeatureDepEditorController.createDependency(
                parent.Id, child.Id, 'Bogus', null
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'Invalid TypePk__c value must throw before any DML.');
    }

    @IsTest
    static void testCreateDependencyRejectsNullParent() {
        Feature__c child = TestDataFactory.createFeature(null);

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryFeatureDepEditorController.createDependency(
                null, child.Id, 'Hard', null
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Null parent must throw.');
    }

    @IsTest
    static void testCreateDependencyRejectsNullChild() {
        Feature__c parent = TestDataFactory.createFeature(null);

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryFeatureDepEditorController.createDependency(
                parent.Id, null, 'Hard', null
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Null child must throw.');
    }

    @IsTest
    static void testCreateDependencyRefusesNonAdminCaller() {
        Feature__c parent = TestDataFactory.createFeature(null);
        Feature__c child = TestDataFactory.createFeature(null);
        User standard = buildStandardUser();

        Boolean threw = false;
        Test.startTest();
        System.runAs(standard) {
            try {
                DeliveryFeatureDepEditorController.createDependency(
                    parent.Id, child.Id, 'Hard', null
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'Non-admin caller must be refused by the admin gate.');
    }

    @IsTest
    static void testDeleteDependencyRemovesRow() {
        Feature__c parent = TestDataFactory.createFeature(null);
        Feature__c child = TestDataFactory.createFeature(null);
        FeatureDependency__c dep = TestDataFactory.newFeatureDependency(child.Id, parent.Id);

        Test.startTest();
        DeliveryFeatureDepEditorController.deleteDependency(dep.Id);
        Test.stopTest();

        Integer remaining = [
            SELECT COUNT() FROM FeatureDependency__c WHERE Id = :dep.Id
        ];
        System.assertEquals(0, remaining, 'Dependency should be deleted.');
    }

    @IsTest
    static void testDeleteDependencyRefusesNullId() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryFeatureDepEditorController.deleteDependency(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Null id must throw.');
    }

    @IsTest
    static void testDeleteDependencyRefusesNonAdminCaller() {
        Feature__c parent = TestDataFactory.createFeature(null);
        Feature__c child = TestDataFactory.createFeature(null);
        FeatureDependency__c dep = TestDataFactory.newFeatureDependency(child.Id, parent.Id);
        User standard = buildStandardUser();

        Boolean threw = false;
        Test.startTest();
        System.runAs(standard) {
            try {
                DeliveryFeatureDepEditorController.deleteDependency(dep.Id);
            } catch (AuraHandledException e) {
                threw = true;
            }
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'Non-admin caller must be refused by the admin gate.');
    }
}
