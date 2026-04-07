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
            NetworkEntityLookup__c = entity.Id,
            TemplatePk__c = 'Client_Agreement',
            PeriodStartDate__c = Date.newInstance(2026, 3, 1),
            PeriodEndDate__c = Date.newInstance(2026, 3, 31),
            PublicTokenTxt__c = 'bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55',
            StatusPk__c = 'Sent',
            TotalCurrency__c = 10000,
            RequireSigningDateTime__c = Datetime.now()
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
            SELECT Id, StatusPk__c, RequireSigningDateTime__c
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = 'bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55'
            LIMIT 1
        ];
    }

    private static List<DocumentAction__c> getActions(Id documentId) {
        return [
            SELECT Id, ActionLabelTxt__c, StatusPk__c, SortOrderNumber__c
            FROM DocumentAction__c
            WHERE DocumentLookup__c = :documentId
            ORDER BY SortOrderNumber__c ASC NULLS LAST
        ];
    }

    /**
     * @description Helper for the Phase 5 payload-map signature of signActionAdmin.
     */
    private static Map<String, Object> signAdminPayload(String name, String email, Boolean consent) {
        return new Map<String, Object>{
            'signerName'   => name,
            'signerEmail'  => email,
            'consentGiven' => consent
        };
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
                firstActionId, signAdminPayload('Glen Bradford', 'glen@cloudnimbusllc.com', true)
            );
            Test.stopTest();

            System.assertEquals('Completed', result.get('status'), 'Result should report Completed');
            System.assertEquals(firstActionId, result.get('actionId'), 'Result should echo action id');
            System.assertEquals(null, result.get('documentStatus'),
                'Document should NOT advance until both slots signed');

            DocumentAction__c reloaded = [
                SELECT StatusPk__c, SignerNameTxt__c, SignatureDataTxt__c,
                       CompletedDateTime__c, ElectronicConsentDateTime__c, ActivityLogLookup__c
                FROM DocumentAction__c WHERE Id = :firstActionId LIMIT 1
            ];
            System.assertEquals('Completed', reloaded.StatusPk__c, 'Action should be Completed');
            System.assertEquals('Glen Bradford', reloaded.SignerNameTxt__c, 'Signer name persisted');
            System.assert(reloaded.SignatureDataTxt__c.startsWith('Glen Bradford (digitally signed'),
                'Signature data should be the formatted stamp');
            System.assertNotEquals(null, reloaded.CompletedDateTime__c, 'CompletedDateTime persisted');
            System.assertNotEquals(null, reloaded.ElectronicConsentDateTime__c, 'Consent timestamp persisted');
            System.assertNotEquals(null, reloaded.ActivityLogLookup__c, 'ActivityLogId materialized');
        }
    }

    @IsTest
    static void testSignActionAdminBlocksWithoutConsent() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Id firstActionId = getActions(doc.Id)[0].Id;

            Test.startTest();
            try {
                DeliveryDocActionController.signActionAdmin(firstActionId, signAdminPayload('Glen', null, false));
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
                DeliveryDocActionController.signActionAdmin(firstActionId, signAdminPayload('Glen', null, true));
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
                DeliveryDocActionController.signActionAdmin(a.Id, signAdminPayload('Test Signer', 'test@example.com', true));
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
                WHERE DocumentLookup__c = :doc.Id AND TypePk__c = 'Approval'
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
            DeliveryDocActionController.signActionAdmin(firstActionId, signAdminPayload('Glen', null, true));
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

            DeliveryDocActionController.signActionAdmin(firstActionId, signAdminPayload('Glen', null, true));

            Test.startTest();
            try {
                DeliveryDocActionController.signActionAdmin(firstActionId, signAdminPayload('Glen Again', null, true));
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
                SELECT AssignedEntityLookup__c FROM DocumentAction__c WHERE Id = :firstActionId LIMIT 1
            ];
            System.assertEquals(entity.Id, reloaded.AssignedEntityLookup__c, 'Assignment persisted');
        }
    }

    @IsTest
    static void testUpdateAssignedEntityRejectsCompletedSlot() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];
            Id firstActionId = getActions(doc.Id)[0].Id;

            DeliveryDocActionController.signActionAdmin(firstActionId, signAdminPayload('Glen', null, true));

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

    // ═══════════════════════════════════════════════════════════
    //  PHASE 5: DRAWN SIGNATURE TESTS
    // ═══════════════════════════════════════════════════════════

    /**
     * Tiny 1x1 transparent PNG so the test doesn't carry around a real signature
     * blob. Just enough to verify the ContentVersion path end to end.
     */
    private static final String TINY_PNG_BASE64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkAAIAAAUAAen63NgAAAAASUVORK5CYII=';

    @IsTest
    static void testSignActionAdminWithDrawnSignatureCreatesContentVersion() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Id firstActionId = getActions(doc.Id)[0].Id;

            Test.startTest();
            DeliveryDocActionController.signActionAdmin(
                firstActionId,
                new Map<String, Object>{
                    'signerName'     => 'Coleman Cameron',
                    'consentGiven'   => true,
                    'signatureType'  => 'Image',
                    'drawnSignature' => TINY_PNG_BASE64
                }
            );
            Test.stopTest();

            DocumentAction__c reloaded = [
                SELECT StatusPk__c, SignatureTypePk__c, SignatureDataTxt__c
                FROM DocumentAction__c
                WHERE Id = :firstActionId
            ];
            System.assertEquals('Completed', reloaded.StatusPk__c, 'Slot should be Completed');
            System.assertEquals('Image', reloaded.SignatureTypePk__c, 'Signature type should be Image');
            // SignatureDataTxt__c holds the ContentVersion Id for image-type signatures
            System.assertNotEquals(null, reloaded.SignatureDataTxt__c, 'Signature data should hold the ContentVersion Id');
            // Verify the ContentVersion actually exists and contains our bytes
            ContentVersion stored = [
                SELECT Id, VersionData, Title FROM ContentVersion WHERE Id = :reloaded.SignatureDataTxt__c
            ];
            System.assert(stored.Title.startsWith('signature_'), 'File should be named signature_*.png');
            System.assert(stored.VersionData.size() > 0, 'Stored bytes should be non-empty');
        }
    }

    @IsTest
    static void testSignActionAdminImageBlocksWithoutBytes() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Id firstActionId = getActions(doc.Id)[0].Id;

            Test.startTest();
            try {
                DeliveryDocActionController.signActionAdmin(
                    firstActionId,
                    new Map<String, Object>{
                        'signerName'     => 'Coleman Cameron',
                        'consentGiven'   => true,
                        'signatureType'  => 'Image'
                        // intentionally omitted: drawnSignature
                    }
                );
                System.assert(false, 'Expected AuraHandledException when image bytes are missing');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Expected exception instance');
            }
            Test.stopTest();
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  PHASE 3: PUBLIC PORTAL SIGNING TESTS
    // ═══════════════════════════════════════════════════════════

    private static String getFirstSignerToken() {
        DeliveryDocument__c doc = getDoc();
        DocumentAction__c action = [
            SELECT SignerTokenTxt__c
            FROM DocumentAction__c
            WHERE DocumentLookup__c = :doc.Id
            ORDER BY SortOrderNumber__c ASC NULLS LAST
            LIMIT 1
        ];
        return action.SignerTokenTxt__c;
    }

    @IsTest
    static void testGetDocumentForSignerHappyPath() {
        System.runAs(testUser) {
            String token = getFirstSignerToken();

            Test.startTest();
            Map<String, Object> bundle = DeliveryDocActionController.getDocumentForSigner(token);
            Test.stopTest();

            System.assertNotEquals(null, bundle, 'Bundle should not be null');
            System.assertNotEquals(null, bundle.get('document'), 'Bundle should include document');
            System.assertNotEquals(null, bundle.get('signerActionId'), 'Bundle should include signer action id');
            System.assertNotEquals(null, bundle.get('actions'), 'Bundle should include sibling actions');

            Map<String, Object> docMap = (Map<String, Object>) bundle.get('document');
            System.assertEquals(true, docMap.get('requiresSigning'),
                'Document should be flagged as requires signing');
            System.assertNotEquals(null, docMap.get('consentText'),
                'Document bundle should include consent text');
        }
    }

    @IsTest
    static void testGetDocumentForSignerInvalidToken() {
        System.runAs(testUser) {
            Test.startTest();
            try {
                DeliveryDocActionController.getDocumentForSigner('not-a-real-token-just-padding-1234567890123456789012345678');
                System.assert(false, 'Expected AuraHandledException for invalid token');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Expected exception instance');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetDocumentForSignerBlankToken() {
        System.runAs(testUser) {
            Test.startTest();
            try {
                DeliveryDocActionController.getDocumentForSigner('');
                System.assert(false, 'Expected AuraHandledException for blank token');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Expected exception instance');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testSignActionPublicHappyPath() {
        System.runAs(testUser) {
            String token = getFirstSignerToken();
            Id firstActionId = getActions(getDoc().Id)[0].Id;

            Test.startTest();
            Map<String, Object> result = DeliveryDocActionController.signActionPublic(
                token,
                new Map<String, Object>{
                    'signerName'   => 'Coleman Cameron',
                    'signerEmail'  => 'coleman@example.com',
                    'consentGiven' => true,
                    'userAgent'    => 'Mozilla/5.0 Test'
                }
            );
            Test.stopTest();

            System.assertEquals('Completed', result.get('status'),
                'Sign should mark slot Completed');

            // Look up by Id, not by token — token is rotated to null on completion
            DocumentAction__c reloaded = [
                SELECT StatusPk__c, SignerNameTxt__c, SignerEmail__c, UserAgentTxt__c
                FROM DocumentAction__c
                WHERE Id = :firstActionId
            ];
            System.assertEquals('Completed', reloaded.StatusPk__c, 'Slot should be Completed');
            System.assertEquals('Coleman Cameron', reloaded.SignerNameTxt__c, 'Name should persist');
            System.assertEquals('Mozilla/5.0 Test', reloaded.UserAgentTxt__c, 'User-agent should persist');
        }
    }

    @IsTest
    static void testSignActionPublicRotatesTokenOnCompletion() {
        // Defense-in-depth: even though loadPendingAction rejects re-signing
        // of a Completed slot, we null the SignerTokenTxt__c so that a leaked
        // completed-slot token cannot be used to fetch the document bundle
        // via getDocumentForSigner (which has no status filter).
        System.runAs(testUser) {
            String token = getFirstSignerToken();
            Id firstActionId = getActions(getDoc().Id)[0].Id;

            Test.startTest();
            DeliveryDocActionController.signActionPublic(
                token,
                new Map<String, Object>{
                    'signerName'   => 'Coleman Cameron',
                    'consentGiven' => true
                }
            );
            Test.stopTest();

            DocumentAction__c reloaded = [
                SELECT StatusPk__c, SignerTokenTxt__c
                FROM DocumentAction__c
                WHERE Id = :firstActionId
                LIMIT 1
            ];
            System.assertEquals('Completed', reloaded.StatusPk__c, 'Slot should be Completed');
            System.assertEquals(null, reloaded.SignerTokenTxt__c,
                'SignerTokenTxt__c should be nulled out on completion');

            // The old token should no longer resolve via getDocumentForSigner
            try {
                DeliveryDocActionController.getDocumentForSigner(token);
                System.assert(false, 'Expected AuraHandledException — rotated token must not resolve');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Expected exception instance');
            }
        }
    }

    @IsTest
    static void testSignActionPublicBlocksWithoutConsent() {
        System.runAs(testUser) {
            String token = getFirstSignerToken();

            Test.startTest();
            try {
                DeliveryDocActionController.signActionPublic(
                    token,
                    new Map<String, Object>{
                        'signerName'   => 'Coleman',
                        'consentGiven' => false
                    }
                );
                System.assert(false, 'Expected AuraHandledException for missing consent');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Expected exception instance');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testSignActionPublicAdvancesDocumentWhenAllSigned() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            List<DocumentAction__c> allActions = [
                SELECT Id, SignerTokenTxt__c
                FROM DocumentAction__c
                WHERE DocumentLookup__c = :doc.Id
                ORDER BY SortOrderNumber__c ASC NULLS LAST
            ];

            Test.startTest();
            for (DocumentAction__c a : allActions) {
                DeliveryDocActionController.signActionPublic(
                    a.SignerTokenTxt__c,
                    new Map<String, Object>{
                        'signerName'   => 'Signer ' + a.Id,
                        'signerEmail'  => 'signer@example.com',
                        'consentGiven' => true,
                        'userAgent'    => 'UA'
                    }
                );
            }
            Test.stopTest();

            DeliveryDocument__c reloaded = [
                SELECT StatusPk__c FROM DeliveryDocument__c WHERE Id = :doc.Id LIMIT 1
            ];
            System.assertEquals('Approved', reloaded.StatusPk__c,
                'Document should advance to Approved when all slots signed via public portal');
        }
    }

    @IsTest
    static void testRestApiPostSignsAction() {
        System.runAs(testUser) {
            String token = getFirstSignerToken();
            Id firstActionId = getActions(getDoc().Id)[0].Id;

            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/sign/' + token;
            req.httpMethod = 'POST';
            req.headers.put('X-Salesforce-SIP', '203.0.113.42');
            req.headers.put('User-Agent', 'curl/8.0 Test');
            req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'signerName'   => 'Coleman Cameron',
                'signerEmail'  => 'coleman@example.com',
                'consentGiven' => true
            }));
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handlePost();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode,
                'REST POST should return 200 on success');
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );
            System.assertEquals('Completed', result.get('status'),
                'REST POST should sign the slot');

            // Look up by Id, not by token — token is rotated to null on completion
            DocumentAction__c reloaded = [
                SELECT StatusPk__c, IpAddressTxt__c, UserAgentTxt__c
                FROM DocumentAction__c
                WHERE Id = :firstActionId
            ];
            System.assertEquals('Completed', reloaded.StatusPk__c, 'Slot should be Completed');
            System.assertEquals('203.0.113.42', reloaded.IpAddressTxt__c,
                'IP should be captured from X-Salesforce-SIP header');
            System.assertEquals('curl/8.0 Test', reloaded.UserAgentTxt__c,
                'User-agent should be captured from User-Agent header');
        }
    }

    @IsTest
    static void testRestApiGetReturnsBundle() {
        System.runAs(testUser) {
            String token = getFirstSignerToken();

            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/sign/' + token;
            req.httpMethod = 'GET';
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handleGet();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode,
                'REST GET should return 200 on success');
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );
            System.assertNotEquals(null, result.get('document'),
                'GET should return the document bundle');
            System.assertNotEquals(null, result.get('signerActionId'),
                'GET should include the signer action id');
        }
    }

    @IsTest
    static void testRestApiGetWithInvalidTokenReturnsError() {
        System.runAs(testUser) {
            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/sign/notarealtokennotarealtokennotarealtokennotarealtokennotarea1234';
            req.httpMethod = 'GET';
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handleGet();
            Test.stopTest();

            System.assertEquals(400, RestContext.response.statusCode,
                'Invalid token should return 400');
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );
            System.assertEquals(true, result.get('error'),
                'Invalid token should return error response body');
        }
    }
}
