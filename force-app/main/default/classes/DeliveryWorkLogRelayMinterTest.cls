/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryWorkLogRelayMinter. The killer regression here is
 *              the guest-REST sharing bug (2026-06 nimba): worklogs arriving via
 *              DeliveryHubSyncService run the WorkLog trigger as the Delivery Hub
 *              Site Guest User, whose record access is forced Private. The relay
 *              eligibility queries were WITH SYSTEM_MODE inside a `with sharing`
 *              handler — FLS bypassed but sharing still enforced — so they returned
 *              empty and the mint silently no-opped: 65 rows / 138.5h never relayed
 *              to the billing org. These tests prove relays mint when the insert
 *              runs under a user with no sharing access to the parent records.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkLogRelayMinterTest {

    @TestSetup
    static void setup() {
        NetworkEntity__c client = new NetworkEntity__c(
            Name = 'Relay Test Client', EntityTypePk__c = 'Client', StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://relay-test-client.example.com'
        );
        // Vendor deliberately has NO endpoint → Push-mode stays ineligible, so the
        // guest test below expects exactly one (Hub-mode) relay.
        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Relay Test Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
        );
        insert new List<NetworkEntity__c>{ client, vendor };

        WorkItem__c linkedWorkItem = new WorkItem__c(
            BriefDescriptionTxt__c       = 'Relay Client Work Item',
            StageNamePk__c               = 'In Development',
            ClientNetworkEntityLookup__c = client.Id
        );
        insert linkedWorkItem;

        // Every WorkLog__c is Master-Detail to WorkRequest__c.
        insert new WorkRequest__c(
            WorkItemId__c           = linkedWorkItem.Id,
            DeliveryEntityLookup__c = vendor.Id,
            QuotedHoursNumber__c    = 20,
            HourlyRateCurrency__c   = 100,
            StatusPk__c             = 'Accepted'
        );
    }

    /**
     * @description Resolves a user whose sharing context reproduces the guest REST
     *              path. Preferred: the real Site Guest User (forced-Private record
     *              access — the exact context that minted nothing pre-fix; present
     *              in CI scratch orgs because unpackaged/post deploys the Delivery
     *              Hub site). Fallback when the org has no active guest user (e.g.
     *              the upload-beta packaging/validation org, where unpackaged/post
     *              is not deployed): a fresh minimal Standard User — weaker, since
     *              WorkItem__c's internal OWD is Public ReadWrite, but it keeps the
     *              test runnable everywhere while feature-test CI provides the
     *              true guest-sharing proof.
     * @return A user to runAs for the restricted-sharing insert.
     */
    private static User getRestrictedUser() {
        List<User> guests = [
            SELECT Id FROM User
            WHERE UserType = 'Guest' AND IsActive = true
            LIMIT 1
        ];
        if (!guests.isEmpty()) {
            return guests[0];
        }
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '') + Datetime.now().getTime();
        User restricted = new User(
            FirstName         = 'Relay',
            LastName          = 'Restricted',
            Alias             = 'rlymint',
            Email             = 'relay.restricted@example.com',
            Username          = 'relay.restricted.' + unique + '@example.com',
            ProfileId         = standardProfile.Id,
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        // Setup-object DML wrapped in runAs to dodge MIXED_DML with the
        // WorkLog__c DML that follows in the same test transaction.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert restricted;
        }
        return restricted;
    }

    /**
     * @description KILLER REGRESSION (guest REST relay mint). The mint queries
     *              executed under a user with no sharing access to WorkItem__c /
     *              WorkRequest__c must STILL find the parents and mint the relay.
     *              Pre-fix (`with sharing` handler owning the eligibility queries)
     *              this minted zero SyncItems under the Site Guest User; post-fix
     *              the `without sharing` DeliveryWorkLogRelayMinter mints exactly
     *              one Hub-mode relay — matching DeliverySyncEngine, which already
     *              ran `without sharing` and minted WorkItem relays in the same
     *              guest transactions. The WorkLog DML itself runs as admin: the
     *              restricted user cannot perform the insert in test context (the
     *              platform rejects the master-detail WorkRequest__c reference
     *              with INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY before any
     *              trigger fires) — in production the guest never owns that DML
     *              either; the without-sharing ingestor does.
     */
    @IsTest
    static void testRelayMintsUnderGuestSharingContext() {
        WorkItem__c workItem = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Relay Client Work Item' LIMIT 1];
        WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];
        User restricted = getRestrictedUser();

        DeliveryTriggerControl.disableAfterLogic();
        WorkLog__c log = new WorkLog__c(
            RequestId__c          = request.Id,
            WorkItemLookup__c     = workItem.Id,
            HoursLoggedNumber__c  = 2.5,
            WorkDateDate__c       = Date.today(),
            WorkDescriptionTxt__c = 'Inbound REST worklog (guest context)'
        );
        insert log;
        DeliveryTriggerControl.enableAfterLogic();

        System.runAs(restricted) {
            Test.startTest();
            DeliveryWorkLogRelayMinter.mintForLogs(new List<WorkLog__c>{ log });
            Test.stopTest();
        }

        // Assert OUTSIDE runAs — the restricted user can't see the SyncItems either.
        List<SyncItem__c> items = [
            SELECT ObjectTypePk__c, DirectionPk__c, StatusPk__c, RequestLookup__c
            FROM SyncItem__c
            WHERE WorkItemLookup__c = :workItem.Id
            AND ObjectTypePk__c = 'WorkLog__c'
        ];
        System.assertEquals(1, items.size(),
            'Relay must mint under a guest/restricted sharing context — empty means the '
            + 'eligibility queries ran with sharing enforced and the worklog will never sync onward');
        System.assertEquals('Outbound', items[0].DirectionPk__c, 'Relay must be Outbound');
        System.assertEquals('Queued', items[0].StatusPk__c, 'Relay must be Queued for the dispatcher');
        System.assertEquals(null, items[0].RequestLookup__c,
            'Expected the Hub-mode relay (vendor route has no endpoint in this setup)');
    }

    /**
     * @description Direct-call sanity check: mintForLogs with an eligible WorkLog
     *              produces one Hub-mode relay carrying the payload fields the
     *              receiver ingestor needs.
     */
    @IsTest
    static void testMintForLogsDirectCall() {
        WorkItem__c workItem = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Relay Client Work Item' LIMIT 1];
        WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];

        DeliveryTriggerControl.disableAfterLogic();
        WorkLog__c log = new WorkLog__c(
            RequestId__c          = request.Id,
            WorkItemLookup__c     = workItem.Id,
            HoursLoggedNumber__c  = 1.0,
            WorkDateDate__c       = Date.today(),
            WorkDescriptionTxt__c = 'Direct mint call'
        );
        insert log;
        DeliveryTriggerControl.enableAfterLogic();

        Test.startTest();
        DeliveryWorkLogRelayMinter.mintForLogs(new List<WorkLog__c>{ log });
        Test.stopTest();

        List<SyncItem__c> items = [
            SELECT GlobalSourceIdTxt__c, PayloadTxt__c, StatusPk__c
            FROM SyncItem__c
            WHERE LocalRecordIdTxt__c = :log.Id
            AND DirectionPk__c = 'Outbound'
        ];
        System.assertEquals(1, items.size(), 'Direct mint should produce one outbound relay');
        System.assertEquals((String) log.Id, items[0].GlobalSourceIdTxt__c,
            'Birthplace WorkLog mints its own Id as GlobalSourceId');
        System.assert(items[0].PayloadTxt__c.contains('HoursLoggedNumber__c'),
            'Payload must carry the hours field');
    }

    /**
     * @description mintForLogs must no-op cleanly when no log has a parent WorkItem.
     */
    @IsTest
    static void testMintForLogsNoParentNoOp() {
        Test.startTest();
        DeliveryWorkLogRelayMinter.mintForLogs(new List<WorkLog__c>{ new WorkLog__c(HoursLoggedNumber__c = 1.0) });
        Test.stopTest();
        // Scope to WorkLog relays — @TestSetup's WorkItem/NetworkEntity inserts mint
        // their own (non-WorkLog) SyncItems via DeliverySyncEngine.
        System.assertEquals(0, [SELECT COUNT() FROM SyncItem__c WHERE ObjectTypePk__c = 'WorkLog__c'],
            'No parent WorkItem → no relay');
    }
}
