/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryDocActionController and the Phase 2 signing
 *               extensions on DeliveryDocActionService. Covers admin signing happy path,
 *               consent enforcement, feature flag gating, status advancement, audit log
 *               creation, and slot reassignment.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc, PMD.MethodNamingConventions')
private class DeliveryDocActionControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        DeliveryTriggerControl.disableAfterLogic();

        // Enable admin signing for these tests
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            settings = new DeliveryHubSettings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                EnableAdminSigningDateTime__c = Datetime.now()
            );
            insert settings;
        } else {
            settings.EnableAdminSigningDateTime__c = Datetime.now();
            update settings;
        }

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Sign Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            DefaultHourlyRateCurrency__c = 200
        );
        insert entity;

        DeliveryDocument__c doc = new DeliveryDocument__c(
            NetworkEntityId__c = entity.Id,
            TemplatePk__c = 'Client_Agreement',
            PeriodStartDate__c = Date.newInstance(2026, 3, 1),
            PeriodEndDate__c = Date.newInstance(2026, 3, 31),
            PublicTokenTxt__c = 'bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55',
            StatusPk__c = 'Sent',
            TotalCurrency__c = 10000,
            RequiresSigningCheckbox__c = true
        );
        insert doc;

        Map<String, Object> snapshot = new Map<String, Object>{
            'entity' => new Map<String, Object>{ 'id' => entity.Id, 'name' => entity.Name }
        };
        DeliveryDocActionService.createSlotsForTemplate(doc.Id, 'Client_Agreement', snapshot);

        DeliveryTriggerControl.enableAfterLogic();
    }

    private static DeliveryDocument__c getDoc() {
        return [
            SELECT Id, StatusPk__c, RequiresSigningCheckbox__c
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = 'bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55'
            LIMIT 1
        ];
    }

    private static List<DocumentAction__c> getActions(Id documentId) {
        return [
            SELECT Id, ActionLabelTxt__c, StatusPk__c, SortOrderNumber__c
            FROM DocumentAction__c
            WHERE DocumentId__c = :documentId
            ORDER BY SortOrderNumber__c ASC NULLS LAST
        ];
    }

    @IsTest
    static void testGetActionsForDocumentReturnsShapedList() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();

            Test.startTest();
            List<Map<String, Object>> result = DeliveryDocActionController.getActionsForDocument(doc.Id);
            Test.stopTest();

            System.assertEquals(2, result.size(), 'Should return both pending slots');
            Map<String, Object> first = result[0];
            System.assertEquals('Sign as Consultant', first.get('label'), 'First slot label');
            System.assertEquals('Pending', first.get('status'), 'First slot status');
            System.assertEquals(true, first.get('isPending'), 'First slot isPending flag');
            System.assertEquals(false, first.get('isCompleted'), 'First slot isCompleted flag');
        }
    }

    @IsTest
    static void testSignActionAdminHappyPath() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            List<DocumentAction__c> actions = getActions(doc.Id);
            Id firstActionId = actions[0].Id;

            Test.startTest();
            Map<String, Object> result = DeliveryDocActionController.signActionAdmin(
                firstActionId, 'Glen Bradford', 'glen@cloudnimbusllc.com', true
            );
            Test.stopTest();

            System.assertEquals('Completed', result.get('status'), 'Result should report Completed');
            System.assertEquals(firstActionId, result.get('actionId'), 'Result should echo action id');
            System.assertEquals(null, result.get('documentStatus'),
                'Document should NOT advance until both slots signed');

            DocumentAction__c reloaded = [
                SELECT StatusPk__c, SignerNameTxt__c, SignatureDataTxt__c,
                       CompletedDateTime__c, ElectronicConsentDateTime__c, ActivityLogId__c
                FROM DocumentAction__c WHERE Id = :firstActionId LIMIT 1
            ];
            System.assertEquals('Completed', reloaded.StatusPk__c, 'Action should be Completed');
            System.assertEquals('Glen Bradford', reloaded.SignerNameTxt__c, 'Signer name persisted');
            System.assert(reloaded.SignatureDataTxt__c.startsWith('Glen Bradford (digitally signed'),
                'Signature data should be the formatted stamp');
            System.assertNotEquals(null, reloaded.CompletedDateTime__c, 'CompletedDateTime persisted');
            System.assertNotEquals(null, reloaded.ElectronicConsentDateTime__c, 'Consent timestamp persisted');
            System.assertNotEquals(null, reloaded.ActivityLogId__c, 'ActivityLogId materialized');
        }
    }

    @IsTest
    static void testSignActionAdminBlocksWithoutConsent() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Id firstActionId = getActions(doc.Id)[0].Id;

            Test.startTest();
            try {
                DeliveryDocActionController.signActionAdmin(firstActionId, 'Glen', null, false);
                System.assert(false, 'Expected AuraHandledException for missing consent');
            } catch (AuraHandledException e) {
                // Expected — do not assert on getMessage() per CLAUDE.md
                System.assertNotEquals(null, e, 'Expected exception instance');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testSignActionAdminBlocksWithoutFeatureFlag() {
        System.runAs(testUser) {
            // Disable the feature flag
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.EnableAdminSigningDateTime__c = null;
            update settings;

            DeliveryDocument__c doc = getDoc();
            Id firstActionId = getActions(doc.Id)[0].Id;

            Test.startTest();
            try {
                DeliveryDocActionController.signActionAdmin(firstActionId, 'Glen', null, true);
                System.assert(false, 'Expected AuraHandledException when feature flag is off');
            } catch (AuraHandledException e) {
                // Expected — do not assert on getMessage() per CLAUDE.md
                System.assertNotEquals(null, e, 'Expected exception instance');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testSignAllSlotsAdvancesDocStatus() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            List<DocumentAction__c> actions = getActions(doc.Id);

            Test.startTest();
            for (DocumentAction__c a : actions) {
                DeliveryDocActionController.signActionAdmin(a.Id, 'Test Signer', 'test@example.com', true);
            }
            Test.stopTest();

            DeliveryDocument__c reloaded = [
                SELECT StatusPk__c FROM DeliveryDocument__c WHERE Id = :doc.Id LIMIT 1
            ];
            System.assertEquals('Approved', reloaded.StatusPk__c,
                'Document should be Approved after all slots signed');

            List<DeliveryTransaction__c> txns = [
                SELECT TypePk__c, AmountCurrency__c
                FROM DeliveryTransaction__c
                WHERE DocumentId__c = :doc.Id AND TypePk__c = 'Approval'
            ];
            System.assertEquals(1, txns.size(), 'Should create one Approval transaction');
            System.assertEquals(10000, txns[0].AmountCurrency__c,
                'Transaction amount should mirror document total');
        }
    }

    @IsTest
    static void testSignActionCreatesActivityLogWithChainHash() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Id firstActionId = getActions(doc.Id)[0].Id;

            Test.startTest();
            DeliveryDocActionController.signActionAdmin(firstActionId, 'Glen', null, true);
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ActionTypePk__c, RecordIdTxt__c, ContextDataTxt__c, HashChainTxt__c
                FROM ActivityLog__c
                WHERE RecordIdTxt__c = :String.valueOf(doc.Id)
                AND ActionTypePk__c = 'Document_Action'
            ];
            System.assertEquals(1, logs.size(), 'Should create one ActivityLog row per signature');
            System.assertNotEquals(null, logs[0].HashChainTxt__c,
                'Existing trigger should populate HashChainTxt__c on insert');
            System.assert(logs[0].ContextDataTxt__c.contains('"action":"sign"'),
                'Context data should record the sign action');
        }
    }

    @IsTest
    static void testSignActionRejectsAlreadyCompletedSlot() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Id firstActionId = getActions(doc.Id)[0].Id;

            DeliveryDocActionController.signActionAdmin(firstActionId, 'Glen', null, true);

            Test.startTest();
            try {
                DeliveryDocActionController.signActionAdmin(firstActionId, 'Glen Again', null, true);
                System.assert(false, 'Expected AuraHandledException for double-sign');
            } catch (AuraHandledException e) {
                // Expected — do not assert on getMessage() per CLAUDE.md
                System.assertNotEquals(null, e, 'Expected exception instance');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testUpdateAssignedEntity() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            NetworkEntity__c entity = [SELECT Id, Name FROM NetworkEntity__c LIMIT 1];
            Id firstActionId = getActions(doc.Id)[0].Id;

            Test.startTest();
            Map<String, Object> result = DeliveryDocActionController.updateAssignedEntity(
                firstActionId, entity.Id
            );
            Test.stopTest();

            System.assertEquals(entity.Id, result.get('assignedEntityId'), 'Result should echo entity id');
            System.assertEquals(entity.Name, result.get('assignedEntityName'), 'Result should include entity name');

            DocumentAction__c reloaded = [
                SELECT AssignedEntityId__c FROM DocumentAction__c WHERE Id = :firstActionId LIMIT 1
            ];
            System.assertEquals(entity.Id, reloaded.AssignedEntityId__c, 'Assignment persisted');
        }
    }

    @IsTest
    static void testUpdateAssignedEntityRejectsCompletedSlot() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];
            Id firstActionId = getActions(doc.Id)[0].Id;

            DeliveryDocActionController.signActionAdmin(firstActionId, 'Glen', null, true);

            Test.startTest();
            try {
                DeliveryDocActionController.updateAssignedEntity(firstActionId, entity.Id);
                System.assert(false, 'Expected AuraHandledException for completed slot reassignment');
            } catch (AuraHandledException e) {
                // Expected — do not assert on getMessage() per CLAUDE.md
                System.assertNotEquals(null, e, 'Expected exception instance');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testFormatTextSignatureStamp() {
        Datetime signedAt = Datetime.newInstance(2026, 4, 6, 14, 30, 0);
        String stamp = DeliveryDocActionService.formatTextSignatureStamp('Coleman Cameron', signedAt);
        System.assert(stamp.contains('Coleman Cameron'), 'Stamp should include name');
        System.assert(stamp.contains('digitally signed'), 'Stamp should include phrase');
        System.assert(stamp.contains('Apr 6, 2026'), 'Stamp should include formatted date');
    }
}
