/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Business logic for the bounty marketplace. Handles listing, claiming,
 *               submission, and lifecycle management of bounty-enabled work items.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.ExcessiveParameterList')
public without sharing class DeliveryBountyService {

    // ── Query: List Open Bounties ────────────────────────────────────────

    /**
     * @description Returns all open bounty work items visible on the marketplace.
     * Supports optional filtering by difficulty and skill.
     * @param difficulty Optional difficulty level filter (e.g. 'Beginner', 'Advanced').
     * @param skill Optional skill keyword filter matched against BountySkillsTxt__c.
     * @return List of bounty maps with token, title, amount, skills, claim count, etc.
     */
    public static List<Map<String, Object>> listOpenBounties(String difficulty, String skill) {
        String skillFilter = String.isNotBlank(skill) ? '%' + skill + '%' : null;

        String query = 'SELECT Id, Name, BriefDescriptionTxt__c, DetailsTxt__c, '
            + 'AcceptanceCriteriaTxt__c, BountyAmountCurrency__c, BountyDeadlineDate__c, '
            + 'BountyStatusPk__c, BountyTokenTxt__c, BountyDifficultyPk__c, '
            + 'BountySkillsTxt__c, BountyMaxClaimsNumber__c, '
            + 'ClientNetworkEntityId__r.Name, CreatedDate, '
            + '(SELECT Id FROM BountyClaims__r WHERE StatusPk__c IN (\'Active\', \'Submitted\', \'Under Review\')) '
            + 'FROM WorkItem__c '
            + 'WHERE IsBountyBool__c = true AND BountyStatusPk__c = \'Open\' '
            + 'AND IsActiveBool__c = true';

        if (String.isNotBlank(difficulty)) {
            query += ' AND BountyDifficultyPk__c = :difficulty';
        }
        if (skillFilter != null) {
            query += ' AND BountySkillsTxt__c LIKE :skillFilter';
        }
        query += ' WITH SYSTEM_MODE ORDER BY CreatedDate DESC LIMIT 100';

        List<WorkItem__c> items = Database.query(query);
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (WorkItem__c wi : items) {
            results.add(buildBountyMap(wi));
        }
        return results;
    }

    // ── Query: Get Bounty by Token ───────────────────────────────────────

    /**
     * @description Returns a single bounty by its public token, including active claims count.
     * @param token The public bounty token used in URLs and API calls.
     * @return Map of bounty fields or null if not found.
     */
    public static Map<String, Object> getBountyByToken(String token) {
        List<WorkItem__c> items = [
            SELECT Id, Name, BriefDescriptionTxt__c, DetailsTxt__c,
                   AcceptanceCriteriaTxt__c, BountyAmountCurrency__c, BountyDeadlineDate__c,
                   BountyStatusPk__c, BountyTokenTxt__c, BountyDifficultyPk__c,
                   BountySkillsTxt__c, BountyMaxClaimsNumber__c,
                   ClientNetworkEntityId__r.Name, CreatedDate,
                   (SELECT Id, ClaimantNameTxt__c, StatusPk__c, ClaimedDateTime__c
                    FROM BountyClaims__r
                    WHERE StatusPk__c IN ('Active', 'Submitted', 'Under Review')
                    ORDER BY ClaimedDateTime__c ASC)
            FROM WorkItem__c
            WHERE BountyTokenTxt__c = :token
                AND IsBountyBool__c = true
                AND IsActiveBool__c = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (items.isEmpty()) { return null; }
        return buildBountyDetailMap(items[0]);
    }

    // ── Command: Claim a Bounty ──────────────────────────────────────────

    /**
     * @description Creates a new claim against a bounty. Validates that the bounty
     * is open, not expired, and hasn't reached its max claims.
     * @param token The public bounty token.
     * @param claimantEmail Email address of the developer claiming the bounty.
     * @param claimantName Display name of the developer.
     * @param note Optional note from the developer about their approach.
     * @return The created BountyClaim__c Id.
     */
    public static Id claimBounty(String token, String claimantEmail, String claimantName, String note) {
        WorkItem__c bounty = getBountyWorkItem(token);
        validateClaimEligibility(bounty, claimantEmail);

        BountyClaim__c claim = new BountyClaim__c(
            WorkItemId__c = bounty.Id,
            ClaimantEmailTxt__c = claimantEmail,
            ClaimantNameTxt__c = claimantName,
            NoteTxt__c = note,
            StatusPk__c = 'Active',
            ClaimedDateTime__c = Datetime.now()
        );

        // Link to NetworkEntity if one exists for this email
        List<NetworkEntity__c> entities = [
            SELECT Id FROM NetworkEntity__c
            WHERE ContactEmailTxt__c = :claimantEmail AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE LIMIT 1
        ];
        if (!entities.isEmpty()) {
            claim.ClaimantEntityId__c = entities[0].Id;
        }

        insert claim;

        // Update bounty status if max claims reached
        Integer activeClaims = [
            SELECT COUNT() FROM BountyClaim__c
            WHERE WorkItemId__c = :bounty.Id
                AND StatusPk__c IN ('Active', 'Submitted', 'Under Review')
            WITH SYSTEM_MODE
        ];
        if (bounty.BountyMaxClaimsNumber__c != null && activeClaims >= bounty.BountyMaxClaimsNumber__c) {
            bounty.BountyStatusPk__c = 'Claimed';
            update bounty;
        }

        return claim.Id;
    }

    // ── Command: Submit Work ─────────────────────────────────────────────

    /**
     * @description Submits completed work for a bounty claim. Moves claim to Submitted
     * and bounty to In Review.
     * @param token The public bounty token.
     * @param claimantEmail Email of the developer submitting work.
     * @param workProofUrl URL to the PR, demo, or proof of completed work.
     * @param note Optional submission note.
     */
    public static void submitWork(String token, String claimantEmail, String workProofUrl, String note) {
        WorkItem__c bounty = getBountyWorkItem(token);

        List<BountyClaim__c> claims = [
            SELECT Id, StatusPk__c FROM BountyClaim__c
            WHERE WorkItemId__c = :bounty.Id
                AND ClaimantEmailTxt__c = :claimantEmail
                AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (claims.isEmpty()) {
            throw new AuraHandledException('No active claim found for this email on this bounty.');
        }

        BountyClaim__c claim = claims[0];
        claim.StatusPk__c = 'Submitted';
        claim.SubmittedDateTime__c = Datetime.now();
        claim.WorkProofUrlTxt__c = workProofUrl;
        if (String.isNotBlank(note)) { claim.NoteTxt__c = note; }
        update claim;

        bounty.BountyStatusPk__c = 'In Review';
        update bounty;
    }

    // ── Command: Withdraw Claim ──────────────────────────────────────────

    /**
     * @description Withdraws an active claim. Re-opens the bounty if it was fully claimed.
     * @param token The public bounty token.
     * @param claimantEmail Email of the developer withdrawing their claim.
     */
    public static void withdrawClaim(String token, String claimantEmail) {
        WorkItem__c bounty = getBountyWorkItem(token);

        List<BountyClaim__c> claims = [
            SELECT Id, StatusPk__c FROM BountyClaim__c
            WHERE WorkItemId__c = :bounty.Id
                AND ClaimantEmailTxt__c = :claimantEmail
                AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (claims.isEmpty()) {
            throw new AuraHandledException('No active claim found to withdraw.');
        }

        claims[0].StatusPk__c = 'Withdrawn';
        update claims[0];

        // Re-open bounty if it was in Claimed status
        if (bounty.BountyStatusPk__c == 'Claimed') {
            bounty.BountyStatusPk__c = 'Open';
            update bounty;
        }
    }

    // ── Token Generation ─────────────────────────────────────────────────

    /**
     * @description Generates a URL-safe bounty token (20 hex chars).
     * @return A 20-character hexadecimal string.
     */
    public static String generateBountyToken() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 20);
    }

    // ── Private Helpers ──────────────────────────────────────────────────

    private static WorkItem__c getBountyWorkItem(String token) {
        List<WorkItem__c> items = [
            SELECT Id, BountyStatusPk__c, BountyDeadlineDate__c, BountyMaxClaimsNumber__c,
                   IsBountyBool__c, IsActiveBool__c
            FROM WorkItem__c
            WHERE BountyTokenTxt__c = :token AND IsBountyBool__c = true AND IsActiveBool__c = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (items.isEmpty()) {
            throw new AuraHandledException('Bounty not found.');
        }
        return items[0];
    }

    private static void validateClaimEligibility(WorkItem__c bounty, String claimantEmail) {
        if (bounty.BountyStatusPk__c != 'Open') {
            throw new AuraHandledException('This bounty is not accepting claims (status: ' + bounty.BountyStatusPk__c + ').');
        }

        if (bounty.BountyDeadlineDate__c != null && bounty.BountyDeadlineDate__c < Date.today()) {
            throw new AuraHandledException('This bounty has expired.');
        }

        // Check for duplicate claim
        Integer existingClaims = [
            SELECT COUNT() FROM BountyClaim__c
            WHERE WorkItemId__c = :bounty.Id
                AND ClaimantEmailTxt__c = :claimantEmail
                AND StatusPk__c IN ('Active', 'Submitted', 'Under Review')
            WITH SYSTEM_MODE
        ];
        if (existingClaims > 0) {
            throw new AuraHandledException('You already have an active claim on this bounty.');
        }

        // Check max claims
        if (bounty.BountyMaxClaimsNumber__c != null) {
            Integer activeClaims = [
                SELECT COUNT() FROM BountyClaim__c
                WHERE WorkItemId__c = :bounty.Id
                    AND StatusPk__c IN ('Active', 'Submitted', 'Under Review')
                WITH SYSTEM_MODE
            ];
            if (activeClaims >= bounty.BountyMaxClaimsNumber__c) {
                throw new AuraHandledException('This bounty has reached its maximum number of claims.');
            }
        }
    }

    private static Map<String, Object> buildBountyMap(WorkItem__c wi) {
        return new Map<String, Object>{
            'token' => wi.BountyTokenTxt__c,
            'number' => wi.Name,
            'title' => wi.BriefDescriptionTxt__c,
            'description' => wi.DetailsTxt__c,
            'amount' => wi.BountyAmountCurrency__c,
            'deadline' => wi.BountyDeadlineDate__c,
            'status' => wi.BountyStatusPk__c,
            'difficulty' => wi.BountyDifficultyPk__c,
            'skills' => parseSkills(wi.BountySkillsTxt__c),
            'maxClaims' => wi.BountyMaxClaimsNumber__c,
            'claimCount' => wi.BountyClaims__r != null ? wi.BountyClaims__r.size() : 0,
            'posterName' => wi.ClientNetworkEntityId__r != null ? wi.ClientNetworkEntityId__r.Name : null,
            'postedDate' => wi.CreatedDate
        };
    }

    private static Map<String, Object> buildBountyDetailMap(WorkItem__c wi) {
        Map<String, Object> result = buildBountyMap(wi);
        result.put('acceptanceCriteria', wi.AcceptanceCriteriaTxt__c);

        List<Map<String, Object>> claims = new List<Map<String, Object>>();
        if (wi.BountyClaims__r != null) {
            for (BountyClaim__c c : wi.BountyClaims__r) {
                claims.add(new Map<String, Object>{
                    'name' => c.ClaimantNameTxt__c,
                    'status' => c.StatusPk__c,
                    'claimedDate' => c.ClaimedDateTime__c
                });
            }
        }
        result.put('activeClaims', claims);
        return result;
    }

    private static List<String> parseSkills(String skillsText) {
        List<String> skills = new List<String>();
        if (String.isNotBlank(skillsText)) {
            for (String s : skillsText.split(';')) {
                String trimmed = s.trim();
                if (String.isNotBlank(trimmed)) { skills.add(trimmed); }
            }
        }
        return skills;
    }
}
