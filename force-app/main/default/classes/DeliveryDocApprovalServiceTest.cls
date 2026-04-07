/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryDocApprovalService.
 *               Covers approveDocumentByToken, disputeDocumentByToken,
 *               invalid token handling, and already-approved guard.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class DeliveryDocApprovalServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        DeliveryTriggerControl.disableAfterLogic();

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Approval Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert entity;

        DeliveryDocument__c doc = new DeliveryDocument__c(
            NetworkEntityLookup__c = entity.Id,
            TemplatePk__c = 'Invoice',
            PeriodStartDate__c = Date.newInstance(2026, 1, 1),
            PeriodEndDate__c = Date.newInstance(2026, 1, 31),
            PublicTokenTxt__c = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
            StatusPk__c = 'Sent',
            TotalCurrency__c = 5000
        );
        insert doc;

        DeliveryTriggerControl.enableAfterLogic();
    }

    private static DeliveryDocument__c getDoc() {
        return [
            SELECT Id, StatusPk__c, PublicTokenTxt__c, DisputeReasonTxt__c, TotalCurrency__c
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            LIMIT 1
        ];
    }

    @IsTest
    static void testApproveDocument() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            System.assertEquals('Sent', doc.StatusPk__c, 'Pre-condition: status should be Sent');

            Test.startTest();
            Map<String, Object> result = DeliveryDocApprovalService.approveDocumentByToken(doc.PublicTokenTxt__c);
            Test.stopTest();

            System.assertEquals('Approved', result.get('status'), 'Result status should be Approved');
            System.assertEquals(doc.Id, result.get('id'), 'Result id should match document');

            DeliveryDocument__c updated = getDoc();
            System.assertEquals('Approved', updated.StatusPk__c, 'Document status should be Approved');

            // Verify approval transaction was created
            List<DeliveryTransaction__c> txns = [
                SELECT TypePk__c, AmountCurrency__c
                FROM DeliveryTransaction__c
                WHERE DocumentLookup__c = :doc.Id AND TypePk__c = 'Approval'
            ];
            System.assertEquals(1, txns.size(), 'Should create one Approval transaction');
            System.assertEquals(5000, txns[0].AmountCurrency__c, 'Transaction amount should match doc total');

            // Verify activity log was created
            List<ActivityLog__c> logs = [
                SELECT ActionTypePk__c, RecordIdTxt__c
                FROM ActivityLog__c
                WHERE RecordIdTxt__c = :String.valueOf(doc.Id)
                AND ActionTypePk__c = 'Document_Action'
            ];
            System.assert(!logs.isEmpty(), 'Should create an activity log entry');
        }
    }

    @IsTest
    static void testDisputeDocument() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            String disputeReason = 'Hours are incorrect for MF-699';

            Test.startTest();
            Map<String, Object> result = DeliveryDocApprovalService.disputeDocumentByToken(
                doc.PublicTokenTxt__c, disputeReason
            );
            Test.stopTest();

            System.assertEquals('Disputed', result.get('status'), 'Result status should be Disputed');

            DeliveryDocument__c updated = getDoc();
            System.assertEquals('Disputed', updated.StatusPk__c, 'Document status should be Disputed');
            System.assertEquals(disputeReason, updated.DisputeReasonTxt__c, 'Dispute reason should be stored');
        }
    }

    @IsTest
    static void testInvalidTokenThrows() {
        System.runAs(testUser) {
            Boolean threw = false;

            Test.startTest();
            try {
                DeliveryDocApprovalService.approveDocumentByToken('invalid-nonexistent-token-value-padded-to-fill-out');
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assert(threw, 'Should throw AuraHandledException for invalid token');
        }
    }

    @IsTest
    static void testBlankTokenThrows() {
        System.runAs(testUser) {
            Boolean threw = false;

            Test.startTest();
            try {
                DeliveryDocApprovalService.approveDocumentByToken('');
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assert(threw, 'Should throw AuraHandledException for blank token');
        }
    }

    @IsTest
    static void testAlreadyApprovedThrows() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();

            // First, approve it
            DeliveryDocApprovalService.approveDocumentByToken(doc.PublicTokenTxt__c);

            // Now try to approve again — status is Approved, not Sent/Viewed
            Boolean threw = false;
            Test.startTest();
            try {
                DeliveryDocApprovalService.approveDocumentByToken(doc.PublicTokenTxt__c);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assert(threw, 'Should throw AuraHandledException when document is already approved');
        }
    }

    @IsTest
    static void testDisputeWithBlankReason() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();

            Test.startTest();
            Map<String, Object> result = DeliveryDocApprovalService.disputeDocumentByToken(
                doc.PublicTokenTxt__c, ''
            );
            Test.stopTest();

            System.assertEquals('Disputed', result.get('status'), 'Should still dispute with blank reason');

            DeliveryDocument__c updated = getDoc();
            System.assertEquals(null, updated.DisputeReasonTxt__c, 'Blank reason should store as null');
        }
    }

    @IsTest
    static void testApproveShortCircuitsForSignRequiredDocument() {
        System.runAs(testUser) {
            DeliveryTriggerControl.disableAfterLogic();
            DeliveryDocument__c doc = getDoc();
            doc.RequireSigningDateTime__c = Datetime.now();
            update doc;
            DeliveryTriggerControl.enableAfterLogic();

            Test.startTest();
            Map<String, Object> result = DeliveryDocApprovalService.approveDocumentByToken(doc.PublicTokenTxt__c);
            Test.stopTest();

            System.assertEquals('Awaiting_Signatures', result.get('status'),
                'Sign-required doc should short-circuit to Awaiting_Signatures, not Approved');
            System.assertEquals(true, result.get('requiresSigning'),
                'Result should flag requiresSigning so the caller can route to the sign portal');

            DeliveryDocument__c updated = getDoc();
            System.assertEquals('Awaiting_Signatures', updated.StatusPk__c,
                'Document status should be Awaiting_Signatures');

            // No Approval transaction should be created on short-circuit
            List<DeliveryTransaction__c> txns = [
                SELECT Id FROM DeliveryTransaction__c
                WHERE DocumentLookup__c = :doc.Id AND TypePk__c = 'Approval'
            ];
            System.assertEquals(0, txns.size(),
                'No Approval transaction should be created when short-circuiting to Awaiting_Signatures');
        }
    }
}
