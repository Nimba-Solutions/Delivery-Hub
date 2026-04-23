/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryDocActionRestApi — the public document
 *               signing REST endpoint. Covers the GET bundle flow, the POST
 *               sign flow for both Text and Image signatures, URI parsing
 *               edge cases (query strings, trailing slashes), X-Forwarded-For
 *               IP resolution (single, chained, fallback), the portalSession
 *               user-agent stitching, blank-body and malformed-body handling,
 *               and the 400-on-error response shape.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc, PMD.MethodNamingConventions, PMD.ExcessiveClassLength')
private class DeliveryDocActionRestApiTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        DeliveryTriggerControl.disableAfterLogic();

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'REST Sign Test Client',
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
            PublicTokenTxt__c = 'ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00',
            StatusPk__c = 'Draft',
            SnapshotTxt__c = JSON.serialize(new Map<String, Object>{
                'entity' => new Map<String, Object>{ 'id' => entity.Id, 'name' => entity.Name }
            }),
            TotalCurrency__c = 0
        );
        insert doc;

        // Create a pending signature slot with a known signer token so the
        // REST endpoint can be exercised end-to-end.
        Map<String, Object> snapshot = new Map<String, Object>{
            'entity' => new Map<String, Object>{ 'id' => entity.Id, 'name' => entity.Name }
        };
        DeliveryDocActionService.createSlotsForTemplate(doc.Id, 'Client_Agreement', snapshot);

        DeliveryTriggerControl.enableAfterLogic();
    }

    private static DocumentAction__c firstPendingSlot() {
        return [
            SELECT Id, SignerTokenTxt__c, DocumentId__c, StatusPk__c, ActionLabelTxt__c
            FROM DocumentAction__c
            WHERE StatusPk__c = 'Pending'
            ORDER BY SortOrderNumber__c ASC
            LIMIT 1
        ];
    }

    private static RestRequest buildRequest(String method, String token, String body) {
        RestRequest req = new RestRequest();
        req.httpMethod = method;
        req.requestURI = '/services/apexrest/sign/' + token;
        if (String.isNotBlank(body)) {
            req.requestBody = Blob.valueOf(body);
        }
        return req;
    }

    private static RestRequest buildRequest(String method, String token, String body, Map<String, String> headers) {
        RestRequest req = buildRequest(method, token, body);
        if (headers != null) {
            for (String k : headers.keySet()) {
                req.headers.put(k, headers.get(k));
            }
        }
        return req;
    }

    // ── GET ────────────────────────────────────────────────────────

    @IsTest
    static void testHandleGetReturnsBundle() {
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            RestContext.request = buildRequest('GET', slot.SignerTokenTxt__c, null);
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handleGet();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode,
                'Known signer token should return 200');
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );
            System.assertNotEquals(null, body.get('document'), 'Bundle should carry document block');
            System.assertNotEquals(null, body.get('signerActionId'), 'Bundle should carry signerActionId');
            System.assertEquals(slot.Id, (Id) body.get('signerActionId'),
                'signerActionId should match the slot we resolved from the token');
        }
    }

    @IsTest
    static void testHandleGetInvalidTokenReturns400() {
        System.runAs(testUser) {
            RestContext.request = buildRequest('GET',
                'deadbeef00000000000000000000000000000000000000000000000000000000', null);
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handleGet();
            Test.stopTest();

            System.assertEquals(400, RestContext.response.statusCode,
                'Unknown token should return 400');
            Map<String, Object> err = (Map<String, Object>) JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );
            System.assertEquals(true, err.get('error'), 'Error payload should set error=true');
            System.assertNotEquals(null, err.get('message'), 'Error payload should include a message');
        }
    }

    @IsTest
    static void testHandleGetShortTokenReturns400() {
        System.runAs(testUser) {
            RestContext.request = buildRequest('GET', 'too-short', null);
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handleGet();
            Test.stopTest();

            System.assertEquals(400, RestContext.response.statusCode,
                'Sub-64-char token should return 400 without hitting the DB');
        }
    }

    // ── POST — happy path (text signature) ─────────────────────────

    @IsTest
    static void testHandlePostTextSignatureCompletesSlot() {
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            String body = JSON.serialize(new Map<String, Object>{
                'signerName'    => 'Alice Apex',
                'signerEmail'   => 'alice@example.com',
                'consentGiven'  => true
            });
            RestContext.request = buildRequest('POST', slot.SignerTokenTxt__c, body,
                new Map<String, String>{
                    'User-Agent' => 'ApexTestAgent/1.0',
                    'X-Salesforce-SIP' => '10.0.0.42'
                });
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handlePost();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode, 'Sign should succeed');
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );
            System.assertEquals('Completed', (String) result.get('status'),
                'Slot should be marked Completed after sign');

            DocumentAction__c after = [
                SELECT StatusPk__c, SignerNameTxt__c, SignatureTypePk__c, IpAddressTxt__c, UserAgentTxt__c
                FROM DocumentAction__c WHERE Id = :slot.Id
            ];
            System.assertEquals('Completed', after.StatusPk__c, 'DB row should reflect completion');
            System.assertEquals('Text', after.SignatureTypePk__c, 'Signature type should default to Text');
            System.assertEquals('Alice Apex', after.SignerNameTxt__c, 'Signer name should persist');
            System.assertEquals('10.0.0.42', after.IpAddressTxt__c,
                'Fallback to X-Salesforce-SIP when X-Forwarded-For is absent');
            System.assertEquals('ApexTestAgent/1.0', after.UserAgentTxt__c,
                'User-Agent header should land in the audit column');
        }
    }

    // ── POST — no consent rejected ─────────────────────────────────

    @IsTest
    static void testHandlePostMissingConsentReturns400() {
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            String body = JSON.serialize(new Map<String, Object>{
                'signerName'    => 'Bob NoConsent',
                'signerEmail'   => 'bob@example.com',
                'consentGiven'  => false
            });
            RestContext.request = buildRequest('POST', slot.SignerTokenTxt__c, body);
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handlePost();
            Test.stopTest();

            System.assertEquals(400, RestContext.response.statusCode,
                'Missing consent must reject with 400');
            DocumentAction__c after = [SELECT StatusPk__c FROM DocumentAction__c WHERE Id = :slot.Id];
            System.assertEquals('Pending', after.StatusPk__c, 'Slot must stay Pending after rejection');
        }
    }

    // ── POST — X-Forwarded-For handling ────────────────────────────

    @IsTest
    static void testHandlePostPrefersXForwardedForOverSalesforceSip() {
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            String body = JSON.serialize(new Map<String, Object>{
                'signerName'    => 'Carol XFF',
                'consentGiven'  => true
            });
            RestContext.request = buildRequest('POST', slot.SignerTokenTxt__c, body,
                new Map<String, String>{
                    'X-Forwarded-For' => '203.0.113.7',
                    'X-Salesforce-SIP' => '10.0.0.99'
                });
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handlePost();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode);
            DocumentAction__c after = [
                SELECT IpAddressTxt__c FROM DocumentAction__c WHERE Id = :slot.Id
            ];
            System.assertEquals('203.0.113.7', after.IpAddressTxt__c,
                'X-Forwarded-For must take precedence over X-Salesforce-SIP');
        }
    }

    @IsTest
    static void testHandlePostXForwardedForChainTakesLeftmost() {
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            String body = JSON.serialize(new Map<String, Object>{
                'signerName'    => 'Dave Proxied',
                'consentGiven'  => true
            });
            RestContext.request = buildRequest('POST', slot.SignerTokenTxt__c, body,
                new Map<String, String>{ 'X-Forwarded-For' => '203.0.113.7, 10.1.1.1, 10.2.2.2' });
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handlePost();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode);
            DocumentAction__c after = [
                SELECT IpAddressTxt__c FROM DocumentAction__c WHERE Id = :slot.Id
            ];
            System.assertEquals('203.0.113.7', after.IpAddressTxt__c,
                'Proxy chain: leftmost address (originating client) must win');
        }
    }

    // ── POST — portalSessionEmail stitched into user-agent ────────

    @IsTest
    static void testHandlePostStitchesPortalSessionEmailIntoUserAgent() {
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            String body = JSON.serialize(new Map<String, Object>{
                'signerName'         => 'Eve Portal',
                'consentGiven'       => true,
                'portalSessionEmail' => 'eve-session@example.com'
            });
            RestContext.request = buildRequest('POST', slot.SignerTokenTxt__c, body,
                new Map<String, String>{ 'User-Agent' => 'PortalUA/1.0' });
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handlePost();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode);
            DocumentAction__c after = [
                SELECT UserAgentTxt__c FROM DocumentAction__c WHERE Id = :slot.Id
            ];
            System.assert(after.UserAgentTxt__c.contains('PortalUA/1.0'),
                'Real User-Agent header must survive');
            System.assert(after.UserAgentTxt__c.contains('[portalSession=eve-session@example.com]'),
                'portalSessionEmail should be stitched into UA string as a marker');
        }
    }

    // ── POST — image signature with data-URI prefix stripped ──────

    @IsTest
    static void testHandlePostImageSignatureStripsDataUriPrefix() {
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            // Minimal valid base64 (the prefix-stripper runs on this, then
            // EncodingUtil.base64Decode turns it into the PNG bytes).
            String base64Png = EncodingUtil.base64Encode(Blob.valueOf('fake-png-bytes'));
            String dataUri = 'data:image/png;base64,' + base64Png;
            String body = JSON.serialize(new Map<String, Object>{
                'signerName'    => 'Frank Drawn',
                'consentGiven'  => true,
                'signatureType' => 'Image',
                'signatureData' => dataUri
            });
            RestContext.request = buildRequest('POST', slot.SignerTokenTxt__c, body);
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handlePost();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode,
                'Image signature with data-URI prefix should succeed (prefix stripped)');
            DocumentAction__c after = [
                SELECT SignatureTypePk__c, SignatureDataTxt__c FROM DocumentAction__c WHERE Id = :slot.Id
            ];
            System.assertEquals('Image', after.SignatureTypePk__c,
                'SignatureTypePk__c should be Image');
            System.assertNotEquals(null, after.SignatureDataTxt__c,
                'Should store the ContentVersion Id in SignatureDataTxt');
        }
    }

    @IsTest
    static void testHandlePostImageSignatureNormalizesDrawnToImage() {
        // signatureType="Drawn" is a legacy spelling; endpoint must normalize
        // it to "Image" when persisting.
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            String base64Png = EncodingUtil.base64Encode(Blob.valueOf('pretend-png'));
            String body = JSON.serialize(new Map<String, Object>{
                'signerName'    => 'Grace Legacy',
                'consentGiven'  => true,
                'signatureType' => 'Drawn',
                'signatureData' => base64Png
            });
            RestContext.request = buildRequest('POST', slot.SignerTokenTxt__c, body);
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handlePost();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode);
            DocumentAction__c after = [
                SELECT SignatureTypePk__c FROM DocumentAction__c WHERE Id = :slot.Id
            ];
            System.assertEquals('Image', after.SignatureTypePk__c,
                'Legacy "Drawn" signatureType should be normalized to "Image"');
        }
    }

    // ── POST — body parsing edge cases ─────────────────────────────

    @IsTest
    static void testHandlePostBlankBodyReturns400() {
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            RestContext.request = buildRequest('POST', slot.SignerTokenTxt__c, null);
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handlePost();
            Test.stopTest();

            // Blank body => ctx has consentGiven=false => validateSignContext
            // throws => 400.
            System.assertEquals(400, RestContext.response.statusCode,
                'Blank body should produce a 400, not an uncaught exception');
        }
    }

    @IsTest
    static void testHandlePostMalformedJsonReturns400() {
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            RestContext.request = buildRequest('POST', slot.SignerTokenTxt__c, '{not valid json');
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handlePost();
            Test.stopTest();

            System.assertEquals(400, RestContext.response.statusCode,
                'Malformed JSON must produce a 400, not propagate');
        }
    }

    @IsTest
    static void testHandlePostJsonArrayReturns400() {
        // Body is valid JSON but not a Map — deserializeUntyped yields a List,
        // and the endpoint should gracefully reject it (ctx.consentGiven=false).
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            RestContext.request = buildRequest('POST', slot.SignerTokenTxt__c, '[1,2,3]');
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handlePost();
            Test.stopTest();

            System.assertEquals(400, RestContext.response.statusCode,
                'Non-object JSON should produce a 400 via consent validation');
        }
    }

    // ── URI parsing edge cases ─────────────────────────────────────

    @IsTest
    static void testHandleGetStripsQueryStringFromUri() {
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            RestRequest req = new RestRequest();
            req.httpMethod = 'GET';
            req.requestURI = '/services/apexrest/sign/' + slot.SignerTokenTxt__c + '?foo=bar&baz=qux';
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handleGet();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode,
                'Trailing query string must not break token extraction');
        }
    }

    @IsTest
    static void testHandleGetStripsTrailingSlashFromUri() {
        System.runAs(testUser) {
            DocumentAction__c slot = firstPendingSlot();
            RestRequest req = new RestRequest();
            req.httpMethod = 'GET';
            req.requestURI = '/services/apexrest/sign/' + slot.SignerTokenTxt__c + '/something';
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handleGet();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode,
                'Trailing /path must not break token extraction (substring before next /)');
        }
    }

    @IsTest
    static void testHandleGetMissingSignMarkerInUriReturns400() {
        System.runAs(testUser) {
            RestRequest req = new RestRequest();
            req.httpMethod = 'GET';
            req.requestURI = '/services/apexrest/NOT_SIGN/abc';
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            DeliveryDocActionRestApi.handleGet();
            Test.stopTest();

            System.assertEquals(400, RestContext.response.statusCode,
                'URI missing /sign/ must produce 400, not a NullPointerException');
        }
    }
}
