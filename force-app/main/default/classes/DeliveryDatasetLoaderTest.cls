/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryDatasetLoader — the in-app sample-data
 *               loader (P2 of the install-experience initiative). Covers the
 *               full safety contract:
 *                 • load() inserts clearly-marked sample records + an audit row
 *                 • load() is idempotent (re-run does not duplicate)
 *                 • remove() deletes EXACTLY the marked records and leaves
 *                   non-marked (real) records completely intact
 *                 • outcome + count are recorded on the assignment row
 *                 • unknown / missing templates throw cleanly
 *
 *               Does NOT assert on AuraHandledException.getMessage() (generic
 *               in managed-package context); the loader throws its own typed
 *               DatasetLoaderException which IS safe to assert on.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryDatasetLoaderTest {

    private static final String MARKER = '[DH SAMPLE]';

    /**
     * @description Builds the Invoice Generation feature + a DatasetTemplate__c
     *              linked to it so the loader's resolveDatasetKey matches the
     *              invoice dataset. Mirrors how the install handler seeds the
     *              template (Name + FeatureLookup__c).
     * @return Inserted DatasetTemplate__c linked to the invoice feature.
     */
    private static DatasetTemplate__c seedInvoiceTemplate() {
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'Name' => 'Invoice_Generation',
            'FeatureDefinitionTxt__c' => 'Invoice_Generation'
        });
        return TestDataFactory.createDatasetTemplate(new Map<String, Object>{
            'Name' => 'Invoice Generation Sample Data',
            'FeatureLookup__c' => f.Id
        });
    }

    /**
     * @description Count WorkItems carrying the sample marker.
     * @return Number of WorkItems whose description starts with the marker.
     */
    private static Integer markedWorkItemCount() {
        return [
            SELECT COUNT() FROM WorkItem__c
            WHERE BriefDescriptionTxt__c LIKE :(MARKER + '%')
        ];
    }

    @IsTest
    static void testLoadInsertsMarkedRecordsAndAuditRow() {
        DatasetTemplate__c t = seedInvoiceTemplate();

        Test.startTest();
        DeliveryDatasetLoader.LoadResult result = DeliveryDatasetLoader.load(t.Id);
        Test.stopTest();

        System.assertEquals('Success', result.outcome, 'Load should succeed.');
        System.assertEquals(false, result.alreadyLoaded, 'First load is not a no-op.');
        // 2 vendors + 5 WI + 5 WR + 10 WL = 22 records inserted.
        System.assertEquals(22, result.recordCount,
            'Should report every inserted record (2 vendors + 5 WI + 5 WR + 10 WL).');

        System.assertEquals(5, markedWorkItemCount(),
            'Exactly 5 marked WorkItems should exist after load.');
        Integer markedLogs = [
            SELECT COUNT() FROM WorkLog__c
            WHERE WorkDescriptionTxt__c LIKE :(MARKER + '%')
        ];
        System.assertEquals(10, markedLogs, '10 marked WorkLogs should exist.');
        Integer markedVendors = [
            SELECT COUNT() FROM NetworkEntity__c
            WHERE Name LIKE :(MARKER + '%')
        ];
        System.assertEquals(2, markedVendors, '2 marked vendors should exist.');

        // Audit row written with real outcome + count.
        System.assertNotEquals(null, result.assignmentId, 'An audit row id should be returned.');
        DatasetTemplateAssignment__c audit = [
            SELECT Id, DatasetTemplateLookup__c, OutcomePk__c, RecordsLoadedNumber__c,
                   LoadedByUserLookup__c, LoadedDateTime__c, NotesTxt__c
            FROM DatasetTemplateAssignment__c
            WHERE Id = :result.assignmentId
            LIMIT 1
        ];
        System.assertEquals(t.Id, audit.DatasetTemplateLookup__c, 'Audit row ties to the template.');
        System.assertEquals('Success', audit.OutcomePk__c, 'Audit outcome must be Success.');
        System.assertEquals(22, audit.RecordsLoadedNumber__c.intValue(),
            'Audit records-loaded must match the real count.');
        System.assertEquals(UserInfo.getUserId(), audit.LoadedByUserLookup__c,
            'Audit row records the running user as loader.');
    }

    @IsTest
    static void testLoadIsIdempotent() {
        DatasetTemplate__c t = seedInvoiceTemplate();

        Test.startTest();
        DeliveryDatasetLoader.LoadResult first = DeliveryDatasetLoader.load(t.Id);
        DeliveryDatasetLoader.LoadResult second = DeliveryDatasetLoader.load(t.Id);
        Test.stopTest();

        System.assertEquals(false, first.alreadyLoaded, 'First load is real.');
        System.assertEquals(true, second.alreadyLoaded,
            'Second load must be a no-op (already loaded).');
        System.assertEquals('Success', second.outcome, 'No-op still reports Success.');

        // Re-running must NOT duplicate — still exactly 5 WI / 10 WL / 2 vendors.
        System.assertEquals(5, markedWorkItemCount(),
            'Idempotent: still exactly 5 marked WorkItems after a second load.');
        Integer markedLogs = [
            SELECT COUNT() FROM WorkLog__c
            WHERE WorkDescriptionTxt__c LIKE :(MARKER + '%')
        ];
        System.assertEquals(10, markedLogs, 'Idempotent: still 10 marked WorkLogs.');
        Integer markedVendors = [
            SELECT COUNT() FROM NetworkEntity__c
            WHERE Name LIKE :(MARKER + '%')
        ];
        System.assertEquals(2, markedVendors, 'Idempotent: still 2 marked vendors.');
    }

    @IsTest
    static void testRemoveDeletesOnlyMarkedRecords() {
        DatasetTemplate__c t = seedInvoiceTemplate();

        // A REAL (non-sample) WorkItem + its own WorkRequest + WorkLog, plus a
        // real vendor. None of these carry the marker — remove() must leave
        // every one of them intact. This is the core safety assertion.
        WorkItem__c realWi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'REAL production work item — do not delete'
        });
        WorkLog__c realLog = TestDataFactory.createWorkLog(
            realWi.Id, 8, Date.today(), new Map<String, Object>{
                'WorkDescriptionTxt__c' => 'REAL billable work — do not delete'
            }
        );
        NetworkEntity__c realVendor = TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'Name' => 'Acme Real Vendor'
        });

        // Load the sample data, then remove it.
        DeliveryDatasetLoader.load(t.Id);

        Test.startTest();
        DeliveryDatasetLoader.LoadResult removeResult = DeliveryDatasetLoader.remove(t.Id);
        Test.stopTest();

        System.assertEquals('Success', removeResult.outcome, 'Remove should succeed.');
        // 2 vendors + 5 WI + 5 WR + 10 WL = 22 deleted.
        System.assertEquals(22, removeResult.recordCount,
            'Remove should delete exactly the 22 marked records.');

        // No marked records survive.
        System.assertEquals(0, markedWorkItemCount(),
            'All marked WorkItems must be gone after remove.');
        System.assertEquals(0, [
            SELECT COUNT() FROM WorkLog__c
            WHERE WorkDescriptionTxt__c LIKE :(MARKER + '%')
        ], 'All marked WorkLogs must be gone.');
        System.assertEquals(0, [
            SELECT COUNT() FROM NetworkEntity__c
            WHERE Name LIKE :(MARKER + '%')
        ], 'All marked vendors must be gone.');

        // The REAL records are completely intact — THE safety guarantee.
        System.assertEquals(1, [
            SELECT COUNT() FROM WorkItem__c WHERE Id = :realWi.Id
        ], 'Real WorkItem must NOT be deleted by remove().');
        System.assertEquals(1, [
            SELECT COUNT() FROM WorkLog__c WHERE Id = :realLog.Id
        ], 'Real WorkLog must NOT be deleted by remove().');
        System.assertEquals(1, [
            SELECT COUNT() FROM NetworkEntity__c WHERE Id = :realVendor.Id
        ], 'Real vendor must NOT be deleted by remove().');
    }

    @IsTest
    static void testRemoveRecordsAuditRowWithOutcomeAndCount() {
        DatasetTemplate__c t = seedInvoiceTemplate();
        DeliveryDatasetLoader.load(t.Id);

        Test.startTest();
        DeliveryDatasetLoader.LoadResult removeResult = DeliveryDatasetLoader.remove(t.Id);
        Test.stopTest();

        System.assertNotEquals(null, removeResult.assignmentId,
            'Remove should write an audit row.');
        DatasetTemplateAssignment__c audit = [
            SELECT Id, OutcomePk__c, RecordsLoadedNumber__c, NotesTxt__c
            FROM DatasetTemplateAssignment__c
            WHERE Id = :removeResult.assignmentId
            LIMIT 1
        ];
        System.assertEquals('Success', audit.OutcomePk__c, 'Remove outcome recorded.');
        System.assertEquals(22, audit.RecordsLoadedNumber__c.intValue(),
            'Remove audit records the count deleted.');
        System.assert(audit.NotesTxt__c.contains('Removed'),
            'Remove audit notes should say "Removed". Got: ' + audit.NotesTxt__c);
    }

    @IsTest
    static void testRemoveWhenNothingLoadedIsCleanNoOp() {
        DatasetTemplate__c t = seedInvoiceTemplate();

        Test.startTest();
        DeliveryDatasetLoader.LoadResult removeResult = DeliveryDatasetLoader.remove(t.Id);
        Test.stopTest();

        System.assertEquals('Success', removeResult.outcome,
            'Removing with nothing loaded is a clean success.');
        System.assertEquals(0, removeResult.recordCount,
            'Nothing loaded means nothing removed.');
    }

    @IsTest
    static void testLoadThrowsWhenTemplateMissing() {
        // Borrow the running user id as a non-null id of the WRONG type so the
        // template lookup misses and the loader throws its typed exception.
        Id bogus = UserInfo.getUserId();

        Boolean thrown = false;
        Test.startTest();
        try {
            DeliveryDatasetLoader.load(bogus);
        } catch (DeliveryDatasetLoader.DatasetLoaderException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Missing template must throw DatasetLoaderException.');
    }

    @IsTest
    static void testLoadThrowsWhenNullTemplate() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DeliveryDatasetLoader.load(null);
        } catch (DeliveryDatasetLoader.DatasetLoaderException e) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'Null template must throw DatasetLoaderException.');
    }

    @IsTest
    static void testLoadThrowsWhenNoLoaderRegistered() {
        // A template NOT tied to a recognised dataset (random feature name)
        // must throw — we never silently load the wrong dataset.
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'Name' => 'Some_Other_Feature',
            'FeatureDefinitionTxt__c' => 'Some_Other_Feature'
        });
        DatasetTemplate__c t = TestDataFactory.createDatasetTemplate(new Map<String, Object>{
            'Name' => 'Unrecognised Template',
            'FeatureLookup__c' => f.Id
        });

        Boolean thrown = false;
        Test.startTest();
        try {
            DeliveryDatasetLoader.load(t.Id);
        } catch (DeliveryDatasetLoader.DatasetLoaderException e) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown,
            'A template with no registered loader must throw, not load the wrong data.');
    }

    @IsTest
    static void testResolvesByTemplateNameWhenFeatureUnlinked() {
        // No feature link — resolution must fall back to the template Name.
        DatasetTemplate__c t = TestDataFactory.createDatasetTemplate(new Map<String, Object>{
            'Name' => 'Invoice Generation Sample Data'
        });

        Test.startTest();
        DeliveryDatasetLoader.LoadResult result = DeliveryDatasetLoader.load(t.Id);
        Test.stopTest();

        System.assertEquals('Success', result.outcome,
            'Template named for the invoice dataset should resolve even without a feature link.');
        System.assertEquals(5, markedWorkItemCount(),
            'Name-based resolution should still load the 5 invoice WorkItems.');
    }
}
