/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryBountyService.
 *               Validates bounty listing, claiming, submission, withdrawal, and edge cases.
 * @author       Cloud Nimbus LLC
 */
@IsTest
private class DeliveryBountyServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Acme Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            ContactEmailTxt__c = 'dev@example.com',
            ApiKeyTxt__c = 'bounty-test-key-abc123',
            ConnectionStatusPk__c = 'Connected'
        );
        insert entity;

        List<WorkItem__c> items = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Build LWC Dashboard',
                DetailsTxt__c = 'Create a real-time dashboard component',
                AcceptanceCriteriaTxt__c = '1. Shows live data\n2. Refreshes every 30s',
                StageNamePk__c = 'Backlog',
                PriorityPk__c = 'High',
                ActivatedDateTime__c = Datetime.now(),
                BountyEnabledDateTime__c = Datetime.now(),
                BountyAmountCurrency__c = 500.00,
                BountyDeadlineDate__c = Date.today().addDays(30),
                BountyStatusPk__c = 'Open',
                BountyTokenTxt__c = 'tok-lwc-dashboard-001',
                BountyDifficultyPk__c = 'Intermediate',
                BountySkillsTxt__c = 'LWC;Apex;SOQL',
                BountyMaxClaimsNumber__c = 3,
                ClientNetworkEntityId__c = entity.Id
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Fix Apex Batch Job',
                DetailsTxt__c = 'Batch job fails on large data sets',
                StageNamePk__c = 'Backlog',
                PriorityPk__c = 'Medium',
                ActivatedDateTime__c = Datetime.now(),
                BountyEnabledDateTime__c = Datetime.now(),
                BountyAmountCurrency__c = 250.00,
                BountyDeadlineDate__c = Date.today().addDays(14),
                BountyStatusPk__c = 'Open',
                BountyTokenTxt__c = 'tok-apex-batch-002',
                BountyDifficultyPk__c = 'Advanced',
                BountySkillsTxt__c = 'Apex;Apex Batch',
                BountyMaxClaimsNumber__c = 1,
                ClientNetworkEntityId__c = entity.Id
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Expired Bounty',
                StageNamePk__c = 'Backlog',
                ActivatedDateTime__c = Datetime.now(),
                BountyEnabledDateTime__c = Datetime.now(),
                BountyAmountCurrency__c = 100.00,
                BountyDeadlineDate__c = Date.today().addDays(-1),
                BountyStatusPk__c = 'Open',
                BountyTokenTxt__c = 'tok-expired-003',
                BountyDifficultyPk__c = 'Beginner',
                BountyMaxClaimsNumber__c = 5,
                ClientNetworkEntityId__c = entity.Id
            ),
            // Non-bounty work item (should not appear in listings)
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Regular Work Item',
                StageNamePk__c = 'In Development',
                ActivatedDateTime__c = Datetime.now(),
                BountyEnabledDateTime__c = null,
                ClientNetworkEntityId__c = entity.Id
            )
        };
        insert items;
    }

    // ── List Bounties ────────────────────────────────────────────────────

    @IsTest
    static void testListOpenBountiesNoFilters() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, Object>> bounties = DeliveryBountyService.listOpenBounties(null, null);
            Test.stopTest();

            // Should return all 3 open bounties (including expired — status is still Open)
            System.assertEquals(3, bounties.size(), 'Should return all open bounty work items');
            Map<String, Object> first = bounties[0];
            System.assertNotEquals(null, first.get('token'), 'Each bounty should have a token');
            System.assertNotEquals(null, first.get('title'), 'Each bounty should have a title');
        }
    }

    @IsTest
    static void testListOpenBountiesFilterByDifficulty() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, Object>> bounties = DeliveryBountyService.listOpenBounties('Advanced', null);
            Test.stopTest();

            System.assertEquals(1, bounties.size(), 'Should return only Advanced bounties');
            System.assertEquals('tok-apex-batch-002', bounties[0].get('token'));
        }
    }

    @IsTest
    static void testListOpenBountiesFilterBySkill() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, Object>> bounties = DeliveryBountyService.listOpenBounties(null, 'LWC');
            Test.stopTest();

            System.assertEquals(1, bounties.size(), 'Should return only bounties requiring LWC');
        }
    }

    // ── Get Bounty by Token ──────────────────────────────────────────────

    @IsTest
    static void testGetBountyByTokenFound() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> bounty = DeliveryBountyService.getBountyByToken('tok-lwc-dashboard-001');
            Test.stopTest();

            System.assertNotEquals(null, bounty, 'Should find the bounty');
            System.assertEquals('Build LWC Dashboard', bounty.get('title'));
            System.assertEquals(500.00, bounty.get('amount'));
            System.assertEquals('Intermediate', bounty.get('difficulty'));
        }
    }

    @IsTest
    static void testGetBountyByTokenNotFound() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> bounty = DeliveryBountyService.getBountyByToken('nonexistent-token');
            Test.stopTest();

            System.assertEquals(null, bounty, 'Should return null for unknown token');
        }
    }

    // ── Claim Bounty ─────────────────────────────────────────────────────

    @IsTest
    static void testClaimBountySuccess() {
        System.runAs(testUser) {
            Test.startTest();
            Id claimId = DeliveryBountyService.claimBounty(
                'tok-lwc-dashboard-001', 'dev@example.com', 'Test Dev', 'I can build this!'
            );
            Test.stopTest();

            System.assertNotEquals(null, claimId, 'Should return a claim Id');

            BountyClaim__c claim = [
                SELECT ClaimantEmailTxt__c, ClaimantNameTxt__c, StatusPk__c, NoteTxt__c
                FROM BountyClaim__c WHERE Id = :claimId
            ];
            System.assertEquals('dev@example.com', claim.ClaimantEmailTxt__c);
            System.assertEquals('Active', claim.StatusPk__c);
            System.assertEquals('I can build this!', claim.NoteTxt__c);
        }
    }

    @IsTest
    static void testClaimBountyMaxClaimsReached() {
        System.runAs(testUser) {
            // tok-apex-batch-002 has maxClaims = 1
            DeliveryBountyService.claimBounty('tok-apex-batch-002', 'first@example.com', 'First', null);

            Test.startTest();
            try {
                DeliveryBountyService.claimBounty('tok-apex-batch-002', 'second@example.com', 'Second', null);
                System.assert(false, 'Should have thrown exception');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Should throw AuraHandledException for max claims');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testClaimBountyDuplicateClaim() {
        System.runAs(testUser) {
            DeliveryBountyService.claimBounty('tok-lwc-dashboard-001', 'dev@example.com', 'Dev', null);

            Test.startTest();
            try {
                DeliveryBountyService.claimBounty('tok-lwc-dashboard-001', 'dev@example.com', 'Dev', null);
                System.assert(false, 'Should have thrown exception');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Should throw AuraHandledException for duplicate claim');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testClaimBountyExpired() {
        System.runAs(testUser) {
            Test.startTest();
            try {
                DeliveryBountyService.claimBounty('tok-expired-003', 'dev@example.com', 'Dev', null);
                System.assert(false, 'Should have thrown exception');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Should throw AuraHandledException for expired bounty');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testClaimBountyNotFound() {
        System.runAs(testUser) {
            Test.startTest();
            try {
                DeliveryBountyService.claimBounty('fake-token', 'dev@example.com', 'Dev', null);
                System.assert(false, 'Should have thrown exception');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Should throw AuraHandledException for not found');
            }
            Test.stopTest();
        }
    }

    // ── Submit Work ──────────────────────────────────────────────────────

    @IsTest
    static void testSubmitWorkSuccess() {
        System.runAs(testUser) {
            DeliveryBountyService.claimBounty('tok-lwc-dashboard-001', 'dev@example.com', 'Dev', null);

            Test.startTest();
            DeliveryBountyService.submitWork(
                'tok-lwc-dashboard-001', 'dev@example.com',
                'https://github.com/example/pr/1', 'Ready for review'
            );
            Test.stopTest();

            BountyClaim__c claim = [
                SELECT StatusPk__c, WorkProofUrlTxt__c FROM BountyClaim__c
                WHERE ClaimantEmailTxt__c = 'dev@example.com'
                AND WorkItemId__r.BountyTokenTxt__c = 'tok-lwc-dashboard-001'
            ];
            System.assertEquals('Submitted', claim.StatusPk__c);
            System.assertEquals('https://github.com/example/pr/1', claim.WorkProofUrlTxt__c);

            WorkItem__c bounty = [
                SELECT BountyStatusPk__c FROM WorkItem__c
                WHERE BountyTokenTxt__c = 'tok-lwc-dashboard-001'
            ];
            System.assertEquals('In Review', bounty.BountyStatusPk__c);
        }
    }

    @IsTest
    static void testSubmitWorkNoClaim() {
        System.runAs(testUser) {
            Test.startTest();
            try {
                DeliveryBountyService.submitWork(
                    'tok-lwc-dashboard-001', 'nobody@example.com',
                    'https://example.com', null
                );
                System.assert(false, 'Should have thrown exception');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Should throw AuraHandledException for no active claim');
            }
            Test.stopTest();
        }
    }

    // ── Withdraw Claim ───────────────────────────────────────────────────

    @IsTest
    static void testWithdrawClaimSuccess() {
        System.runAs(testUser) {
            DeliveryBountyService.claimBounty('tok-lwc-dashboard-001', 'dev@example.com', 'Dev', null);

            Test.startTest();
            DeliveryBountyService.withdrawClaim('tok-lwc-dashboard-001', 'dev@example.com');
            Test.stopTest();

            BountyClaim__c claim = [
                SELECT StatusPk__c FROM BountyClaim__c
                WHERE ClaimantEmailTxt__c = 'dev@example.com'
                AND WorkItemId__r.BountyTokenTxt__c = 'tok-lwc-dashboard-001'
            ];
            System.assertEquals('Withdrawn', claim.StatusPk__c);
        }
    }

    @IsTest
    static void testWithdrawClaimNoClaim() {
        System.runAs(testUser) {
            Test.startTest();
            try {
                DeliveryBountyService.withdrawClaim('tok-lwc-dashboard-001', 'nobody@example.com');
                System.assert(false, 'Should have thrown exception');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Should throw AuraHandledException for no active claim');
            }
            Test.stopTest();
        }
    }

    // ── Token Generation ─────────────────────────────────────────────────

    @IsTest
    static void testGenerateBountyToken() {
        System.runAs(testUser) {
            Test.startTest();
            String token = DeliveryBountyService.generateBountyToken();
            Test.stopTest();

            System.assertEquals(20, token.length(), 'Token should be 20 characters');
            // Generate a second and verify uniqueness
            String token2 = DeliveryBountyService.generateBountyToken();
            System.assertNotEquals(token, token2, 'Tokens should be unique');
        }
    }

    // ── Skills Parsing ───────────────────────────────────────────────────

    @IsTest
    static void testBountySkillsParsing() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> bounty = DeliveryBountyService.getBountyByToken('tok-lwc-dashboard-001');
            Test.stopTest();

            List<Object> skills = (List<Object>) bounty.get('skills');
            System.assertEquals(3, skills.size(), 'Should parse 3 skills from semicolon-delimited string');
            System.assertEquals('LWC', skills[0]);
            System.assertEquals('Apex', skills[1]);
            System.assertEquals('SOQL', skills[2]);
        }
    }

    // ── Entity Linkage ───────────────────────────────────────────────────

    @IsTest
    static void testClaimBountyLinksToExistingEntity() {
        System.runAs(testUser) {
            Test.startTest();
            Id claimId = DeliveryBountyService.claimBounty(
                'tok-lwc-dashboard-001', 'dev@example.com', 'Dev', null
            );
            Test.stopTest();

            BountyClaim__c claim = [
                SELECT ClaimantEntityId__c FROM BountyClaim__c WHERE Id = :claimId
            ];
            System.assertNotEquals(null, claim.ClaimantEntityId__c,
                'Should auto-link to NetworkEntity with matching email');
        }
    }

    // ── Bounty Status Transitions ────────────────────────────────────────

    @IsTest
    static void testClaimBountyStatusChangesToClaimed() {
        System.runAs(testUser) {
            // tok-apex-batch-002 has maxClaims = 1, so one claim should flip status to Claimed
            Test.startTest();
            DeliveryBountyService.claimBounty('tok-apex-batch-002', 'dev@example.com', 'Dev', null);
            Test.stopTest();

            WorkItem__c bounty = [
                SELECT BountyStatusPk__c FROM WorkItem__c
                WHERE BountyTokenTxt__c = 'tok-apex-batch-002'
            ];
            System.assertEquals('Claimed', bounty.BountyStatusPk__c,
                'Bounty should move to Claimed when max claims reached');
        }
    }

    @IsTest
    static void testWithdrawClaimReopensBounty() {
        System.runAs(testUser) {
            // Claim the single-slot bounty, then withdraw
            DeliveryBountyService.claimBounty('tok-apex-batch-002', 'dev@example.com', 'Dev', null);

            Test.startTest();
            DeliveryBountyService.withdrawClaim('tok-apex-batch-002', 'dev@example.com');
            Test.stopTest();

            WorkItem__c bounty = [
                SELECT BountyStatusPk__c FROM WorkItem__c
                WHERE BountyTokenTxt__c = 'tok-apex-batch-002'
            ];
            System.assertEquals('Open', bounty.BountyStatusPk__c,
                'Bounty should revert to Open when a claim is withdrawn from a fully-claimed bounty');
        }
    }
}
