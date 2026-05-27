/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryDatasetController. Covers:
 *                 - getTemplatesForFeature happy + null + no-match
 *                 - getTemplatesForWorkItem null + (degrades to empty)
 *                 - getRecentAssignmentsForTemplate ordering + null guard
 *                 - getAssignmentsForScratchOrg degrades when PR 9 schema absent
 *                 - formatCciCommand returns expected shape + rejects null
 *
 *               Anchors all date assertions on Datetime.now() to keep
 *               rolling-window math stable across week boundaries (per
 *               feedback_anchor_rolling_window_tests_on_today.md).
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryDatasetControllerTest {

    @IsTest
    static void testGetTemplatesForFeatureReturnsRows() {
        Feature__c f = TestDataFactory.createFeature(null);
        DatasetTemplate__c t = TestDataFactory.createDatasetTemplate(
            new Map<String, Object>{ 'FeatureLookup__c' => f.Id }
        );

        Test.startTest();
        List<DeliveryDatasetController.DatasetTemplateDTO> dtos =
            DeliveryDatasetController.getTemplatesForFeature(f.Id);
        Test.stopTest();

        System.assertEquals(1, dtos.size(), 'Should surface one template for the feature.');
        System.assertEquals(t.Id, dtos.get(0).templateId, 'Template id should round-trip.');
        System.assertEquals(t.Name, dtos.get(0).name, 'Template name should round-trip.');
    }

    @IsTest
    static void testGetTemplatesForFeatureNullReturnsEmpty() {
        Test.startTest();
        List<DeliveryDatasetController.DatasetTemplateDTO> dtos =
            DeliveryDatasetController.getTemplatesForFeature(null);
        Test.stopTest();

        System.assertNotEquals(null, dtos, 'Null id should return empty list, not null.');
        System.assertEquals(0, dtos.size(), 'Null id should return zero rows.');
    }

    @IsTest
    static void testGetTemplatesForWorkItemDegradesToEmpty() {
        // WorkItem__c does not carry a FeatureLookup__c in the current schema,
        // so this method must degrade to an empty list rather than throwing.
        WorkItem__c wi = TestDataFactory.createWorkItem(null);

        Test.startTest();
        List<DeliveryDatasetController.DatasetTemplateDTO> dtos =
            DeliveryDatasetController.getTemplatesForWorkItem(wi.Id);
        Test.stopTest();

        System.assertNotEquals(null, dtos, 'WI with no feature should return empty, not null.');
        System.assertEquals(0, dtos.size(),
            'WI without a direct FeatureLookup__c yields zero templates.');
    }

    @IsTest
    static void testGetRecentAssignmentsForTemplateReturnsRowsOrderedNewestFirst() {
        DatasetTemplate__c t = TestDataFactory.newDatasetTemplate();

        DatasetTemplateAssignment__c older = TestDataFactory.buildDatasetTemplateAssignment(
            t.Id, new Map<String, Object>{
                'LoadedDateTime__c' => Datetime.now().addHours(-2),
                'RecordsLoadedNumber__c' => 4
            }
        );
        DatasetTemplateAssignment__c newer = TestDataFactory.buildDatasetTemplateAssignment(
            t.Id, new Map<String, Object>{
                'LoadedDateTime__c' => Datetime.now().addMinutes(-5),
                'RecordsLoadedNumber__c' => 7
            }
        );
        insert new List<DatasetTemplateAssignment__c>{ older, newer };

        Test.startTest();
        List<DeliveryDatasetController.AssignmentSummaryDTO> dtos =
            DeliveryDatasetController.getRecentAssignmentsForTemplate(t.Id);
        Test.stopTest();

        System.assertEquals(2, dtos.size(), 'Both assignments should surface.');
        System.assertEquals(newer.Id, dtos.get(0).assignmentId,
            'Newest assignment must be first (DESC NULLS LAST on LoadedDateTime__c).');
        System.assertEquals(7, dtos.get(0).recordsLoaded,
            'recordsLoaded should match the inserted RecordsLoadedNumber__c value.');
    }

    @IsTest
    static void testGetRecentAssignmentsForTemplateNullReturnsEmpty() {
        Test.startTest();
        List<DeliveryDatasetController.AssignmentSummaryDTO> dtos =
            DeliveryDatasetController.getRecentAssignmentsForTemplate(null);
        Test.stopTest();
        System.assertEquals(0, dtos.size(), 'Null templateId returns empty list.');
    }

    @IsTest
    static void testGetAssignmentsForScratchOrgDegradesWhenPr9Absent() {
        // PR 9 has not merged at the time this test class ships — the
        // ScratchOrgInstanceLookup__c field is not present on
        // DatasetTemplateAssignment__c, so this method must return an
        // empty list (never throw). Borrow the running-user Id as a
        // non-null Id of any sObject type — the method short-circuits
        // on hasScratchOrgLookup() before the type is dereferenced.
        Id fakeScratchOrgId = UserInfo.getUserId();
        Test.startTest();
        List<DeliveryDatasetController.AssignmentSummaryDTO> dtos =
            DeliveryDatasetController.getAssignmentsForScratchOrg(fakeScratchOrgId);
        Test.stopTest();
        System.assertNotEquals(null, dtos, 'Must return empty list when PR 9 schema is absent.');
        System.assertEquals(0, dtos.size(),
            'Must return zero rows when ScratchOrgInstanceLookup__c is not deployed.');
    }

    @IsTest
    static void testFormatCciCommandReturnsExpectedShape() {
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'Name' => 'Invoice_Generation'
        });
        DatasetTemplate__c t = TestDataFactory.createDatasetTemplate(
            new Map<String, Object>{
                'FeatureLookup__c' => f.Id,
                'Name' => 'Invoice Generation Demo'
            }
        );

        Test.startTest();
        String cmd = DeliveryDatasetController.formatCciCommand(t.Id);
        Test.stopTest();

        System.assertNotEquals(null, cmd, 'Command string must not be null.');
        System.assert(cmd.startsWith('cci task run load_feature_data'),
            'Command should target the load_feature_data task. Got: ' + cmd);
        System.assert(cmd.contains('--feature'),
            'Command should include the --feature flag. Got: ' + cmd);
        // Prefers the linked feature's Name over the template's Name when present.
        System.assert(cmd.endsWith('Invoice_Generation'),
            'Command should end with the linked feature Name. Got: ' + cmd);
    }

    @IsTest
    static void testFormatCciCommandRejectsNull() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DeliveryDatasetController.formatCciCommand(null);
        } catch (AuraHandledException e) {
            thrown = true;
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'Null templateId must produce an exception.');
    }

    // ────────────────────────────────────────────────────────────────────
    // recordAssignment + getLastAssignment — writer + reader of the
    // DatasetTemplateAssignment__c audit row (Flow 7 #2 gap closure).
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Builds a standard (non-admin) User. Used to assert the
     *              admin gate fires on recordAssignment.
     * @return Inserted standard User.
     */
    private static User buildStandardUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'ddctt',
            Email = 'ddctt+' + Crypto.getRandomLong() + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'DatasetTester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'ddctt+' + Crypto.getRandomLong() + '@dh-test.example.test'
        );
        // Setup-object insert isolated in runAs(current) to avoid MIXED_DML
        // against the caller's subsequent DatasetTemplate__c inserts.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }

    /**
     * @description Builds an admin User with the DeliveryHubAdmin PSG
     *              assigned so the assertAdminOrThrow gate lets calls
     *              through. Calculates the PSG before assignment per
     *              [[psg-must-be-calculated-before-assignment-in-test]] —
     *              the namespaced packaging-org test context leaves PSGs
     *              "Outdated" after install and PermissionSetAssignment
     *              insert will fail without the recalc.
     * @return Inserted admin User.
     */
    private static User buildAdminUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'ddcta',
            Email = 'ddcta+' + Crypto.getRandomLong() + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'DatasetAdmin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'ddcta+' + Crypto.getRandomLong() + '@dh-test.example.test'
        );
        List<PermissionSetGroup> psgs = [
            SELECT Id FROM PermissionSetGroup
            WHERE DeveloperName IN ('DeliveryHubAdmin', 'delivery__DeliveryHubAdmin')
            LIMIT 1
        ];
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            if (!psgs.isEmpty()) {
                Test.calculatePermissionSetGroup(psgs[0].Id);
                insert new PermissionSetAssignment(
                    AssigneeId = u.Id,
                    PermissionSetGroupId = psgs[0].Id
                );
            }
        }
        return u;
    }

    @IsTest
    static void testRecordAssignmentInsertsRow() {
        User admin = buildAdminUser();
        DatasetTemplate__c t = TestDataFactory.newDatasetTemplate();

        Test.startTest();
        DatasetTemplateAssignment__c inserted;
        System.runAs(admin) {
            inserted = DeliveryDatasetController.recordAssignment(t.Id, 'Loaded the invoice demo seed.');
        }
        Test.stopTest();

        System.assertNotEquals(null, inserted, 'recordAssignment must return the inserted row.');
        System.assertNotEquals(null, inserted.Id, 'Returned row must be persisted (have an Id).');
        DatasetTemplateAssignment__c reloaded = [
            SELECT Id, DatasetTemplateLookup__c, LoadedByUserLookup__c, OutcomePk__c,
                   NotesTxt__c, LoadedDateTime__c
            FROM DatasetTemplateAssignment__c
            WHERE Id = :inserted.Id
            LIMIT 1
        ];
        System.assertEquals(t.Id, reloaded.DatasetTemplateLookup__c, 'Template lookup must match.');
        System.assertEquals(admin.Id, reloaded.LoadedByUserLookup__c, 'LoadedBy must be the running admin.');
        System.assertEquals('Success', reloaded.OutcomePk__c, 'Outcome must default to Success.');
        System.assertEquals('Loaded the invoice demo seed.', reloaded.NotesTxt__c, 'Notes must round-trip.');
        System.assertNotEquals(null, reloaded.LoadedDateTime__c, 'LoadedDateTime__c must be populated.');
    }

    @IsTest
    static void testRecordAssignmentRequiresAdmin() {
        User standard = buildStandardUser();
        DatasetTemplate__c t = TestDataFactory.newDatasetTemplate();

        Boolean thrown = false;
        Test.startTest();
        System.runAs(standard) {
            try {
                DeliveryDatasetController.recordAssignment(t.Id, 'no perms');
            } catch (AuraHandledException e) {
                thrown = true;
            } catch (Exception e) {
                thrown = true;
            }
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Non-admin caller must hit the admin gate.');
        Integer rows = [
            SELECT COUNT() FROM DatasetTemplateAssignment__c
            WHERE DatasetTemplateLookup__c = :t.Id
        ];
        System.assertEquals(0, rows, 'No audit row should land when the gate fires.');
    }

    @IsTest
    static void testRecordAssignmentUpdatesExistingSameDayRow() {
        User admin = buildAdminUser();
        DatasetTemplate__c t = TestDataFactory.newDatasetTemplate();

        Test.startTest();
        DatasetTemplateAssignment__c first;
        DatasetTemplateAssignment__c second;
        System.runAs(admin) {
            first = DeliveryDatasetController.recordAssignment(t.Id, 'first click');
            second = DeliveryDatasetController.recordAssignment(t.Id, 'second click — same day');
        }
        Test.stopTest();

        System.assertEquals(first.Id, second.Id,
            'Same-day idempotency: second call must update the same row, not insert a duplicate.');
        Integer rows = [
            SELECT COUNT() FROM DatasetTemplateAssignment__c
            WHERE DatasetTemplateLookup__c = :t.Id
              AND LoadedByUserLookup__c = :admin.Id
        ];
        System.assertEquals(1, rows, 'Only one audit row should exist for this user+template today.');
        DatasetTemplateAssignment__c reloaded = [
            SELECT Id, NotesTxt__c FROM DatasetTemplateAssignment__c
            WHERE Id = :second.Id
            LIMIT 1
        ];
        System.assertEquals('second click — same day', reloaded.NotesTxt__c,
            'Notes should reflect the most-recent click.');
    }

    @IsTest
    static void testRecordAssignmentRejectsInvalidTemplateId() {
        User admin = buildAdminUser();
        // Borrow the running-user Id as a non-null Id of the WRONG sObject
        // type — recordAssignment looks the template up by Id and must throw
        // when no DatasetTemplate__c row matches.
        Id bogus = UserInfo.getUserId();

        Boolean thrown = false;
        Test.startTest();
        System.runAs(admin) {
            try {
                DeliveryDatasetController.recordAssignment(bogus, null);
            } catch (AuraHandledException e) {
                thrown = true;
            } catch (Exception e) {
                thrown = true;
            }
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Bogus / wrong-type templateId must throw.');
    }

    @IsTest
    static void testRecordAssignmentRejectsNullTemplateId() {
        User admin = buildAdminUser();

        Boolean thrown = false;
        Test.startTest();
        System.runAs(admin) {
            try {
                DeliveryDatasetController.recordAssignment(null, 'no id');
            } catch (AuraHandledException e) {
                thrown = true;
            } catch (Exception e) {
                thrown = true;
            }
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Null templateId must throw.');
    }

    @IsTest
    static void testGetLastAssignmentReturnsMostRecentRow() {
        DatasetTemplate__c t = TestDataFactory.newDatasetTemplate();
        DatasetTemplateAssignment__c older = TestDataFactory.buildDatasetTemplateAssignment(
            t.Id, new Map<String, Object>{
                'LoadedDateTime__c' => Datetime.now().addHours(-3),
                'RecordsLoadedNumber__c' => 4
            }
        );
        DatasetTemplateAssignment__c newer = TestDataFactory.buildDatasetTemplateAssignment(
            t.Id, new Map<String, Object>{
                'LoadedDateTime__c' => Datetime.now().addMinutes(-2),
                'RecordsLoadedNumber__c' => 11
            }
        );
        insert new List<DatasetTemplateAssignment__c>{ older, newer };

        Test.startTest();
        DeliveryDatasetController.LastAssignmentDTO dto =
            DeliveryDatasetController.getLastAssignment(t.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'Must return a DTO when assignments exist.');
        System.assertEquals(newer.Id, dto.assignmentId,
            'Must return the most-recent row by LoadedDateTime__c DESC.');
        System.assertEquals(t.Id, dto.templateId, 'Template id should round-trip.');
        System.assertEquals(11, dto.recordsLoaded, 'recordsLoaded must reflect the newest row.');
    }

    @IsTest
    static void testGetLastAssignmentNullReturnsNull() {
        Test.startTest();
        DeliveryDatasetController.LastAssignmentDTO dto =
            DeliveryDatasetController.getLastAssignment(null);
        Test.stopTest();
        System.assertEquals(null, dto, 'Null templateId must return null (not throw).');
    }

    @IsTest
    static void testGetLastAssignmentReturnsNullWhenNoRowsExist() {
        DatasetTemplate__c t = TestDataFactory.newDatasetTemplate();
        Test.startTest();
        DeliveryDatasetController.LastAssignmentDTO dto =
            DeliveryDatasetController.getLastAssignment(t.Id);
        Test.stopTest();
        System.assertEquals(null, dto, 'No assignment rows means null DTO (first-load case).');
    }
}
