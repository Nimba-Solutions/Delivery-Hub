/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryContentDocLinkTriggerHandler covering outbound
 *              file sync ledger creation for Work Item and non-Work Item attachments.
 *              Post 2026-04-21 rewrite: payload is metadata-only; verifies
 *              FileTransport=pull-callout and Sha256 population.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryContentDocLinkTriggerHandlerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void testHandleAfterInsertWithWorkItem() {
        System.runAs(testUser) {
            // 1. Prevent infinite test queues
            DeliverySyncEngine.isSyncContext = false; // Ensure it's false to allow outbound sync

            // 2. Setup Routing Data
            NetworkEntity__c vendor = new NetworkEntity__c(
                Name = 'Test Vendor',
                IntegrationEndpointUrlTxt__c = 'https://example.com/api',
                StatusPk__c = 'Active',
                EntityTypePk__c = 'Vendor'
            );
            insert vendor;

            WorkItem__c workItem = new WorkItem__c();
            insert workItem;

            WorkRequest__c req = new WorkRequest__c(
                WorkItemId__c = workItem.Id,
                DeliveryEntityLookup__c = vendor.Id,
                RemoteWorkItemIdTxt__c = 'REMOTE-123',
                StatusPk__c = 'Open'
            );
            insert req;

            // 3. Setup File
            ContentVersion cv = new ContentVersion(
                Title = 'Test File',
                PathOnClient = 'TestFile.txt',
                VersionData = Blob.valueOf('Test file body')
            );
            insert cv;

            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

            // 4. Attach File to Work Item
            ContentDocumentLink link = new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId = workItem.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );

            Test.startTest();
            insert link;
            Test.stopTest();

            // 5. Verify the Unified Ledger successfully generated an item.
            List<SyncItem__c> items = [
                SELECT Id, ObjectTypePk__c, PayloadTxt__c
                FROM SyncItem__c
                WHERE ObjectTypePk__c = 'ContentVersion'
            ];
            System.assertEquals(1, items.size(),
                'Should have generated exactly 1 Sync Item for the attached file');

            // 6. Verify metadata-only payload shape
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(items[0].PayloadTxt__c);
            System.assertEquals('pull-callout', payload.get('FileTransport'),
                'Payload should flag FileTransport=pull-callout so receiver pulls bytes');
            System.assertEquals(false, payload.containsKey('VersionData'),
                'Payload must NOT inline base64 VersionData anymore');
            System.assertNotEquals(null, payload.get('Sha256'),
                'Small files should carry a Sha256 digest for integrity checking');
            System.assertEquals(64, ((String) payload.get('Sha256')).length(),
                'Sha256 should be 64 hex characters');
            System.assertNotEquals(null, payload.get('ContentDocumentId'),
                'Payload should include ContentDocumentId so receiver can call back');
            System.assertEquals(cv.Id, (String) payload.get('SourceId'),
                'SourceId should be the source ContentVersion Id');
        }
    }

    @IsTest
    static void testHandleAfterInsertNonWorkItemRecord() {
        System.runAs(testUser) {
            Account acc = new Account(Name = 'Test Account');
            insert acc;

            ContentVersion cv = new ContentVersion(
                Title = 'Another File',
                PathOnClient = 'AnotherFile.txt',
                VersionData = Blob.valueOf('Another file body')
            );
            insert cv;

            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

            ContentDocumentLink link = new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId = acc.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );

            Test.startTest();
            insert link;
            Test.stopTest();

            // Should completely ignore files attached to Accounts
            List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE ObjectTypePk__c = 'ContentVersion'];
            System.assertEquals(0, items.size(), 'Should not generate a Sync Item for non-workItem files');
        }
    }

    /**
     * @description Regression guard: the old 131k cap made anything > ~95 KB
     *              fail with STRING_TOO_LONG because the payload inlined bytes.
     *              With the metadata-only rewrite, even a multi-KB payload
     *              should insert cleanly because PayloadTxt__c now carries only
     *              metadata, not base64 bytes.
     */
    @IsTest
    static void testLargeFilePayloadInsertsWithoutStringTooLong() {
        System.runAs(testUser) {
            DeliverySyncEngine.isSyncContext = false;

            WorkItem__c workItem = new WorkItem__c();
            insert workItem;

            // Make a file that — pre-rewrite — would have exploded the Long Text
            // field once base64-encoded (roughly 95 KB encoded).
            String payloadBody = '';
            String blockOf1k = '';
            for (Integer i = 0; i < 1024; i++) {
                blockOf1k += 'a';
            }
            for (Integer i = 0; i < 80; i++) {
                payloadBody += blockOf1k;
            }
            ContentVersion cv = new ContentVersion(
                Title = 'Large File',
                PathOnClient = 'LargeFile.bin',
                VersionData = Blob.valueOf(payloadBody)
            );
            insert cv;

            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

            ContentDocumentLink link = new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId = workItem.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );

            Test.startTest();
            insert link;
            Test.stopTest();

            List<SyncItem__c> items = [
                SELECT Id, PayloadTxt__c FROM SyncItem__c
                WHERE ObjectTypePk__c = 'ContentVersion'
            ];
            System.assertEquals(1, items.size(), 'Should insert a sync item for a large file');
            System.assert(items[0].PayloadTxt__c.length() < 5000,
                'Metadata-only payload should be well under the 131k cap (actual: ' + items[0].PayloadTxt__c.length() + ')');
        }
    }
}
