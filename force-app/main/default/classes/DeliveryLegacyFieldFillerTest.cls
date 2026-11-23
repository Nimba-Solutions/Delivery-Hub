/**
 * @name         Delivery Hub
 * @license      BSL 1.1 - See LICENSE.md
 * @description  Tests for DeliveryLegacyFieldFiller. Written to pass in BOTH kinds of org: CI/dev
 *               orgs (no legacy fields exist, fill() must be a no-op) and subscriber orgs such as
 *               MF-Prod (deprecated required legacy fields exist and must be back-filled).
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryLegacyFieldFillerTest {

    private static Schema.DescribeFieldResult findField(Schema.SObjectType t, String unprefixedName) {
        for (Schema.SObjectField f : t.getDescribe().fields.getMap().values()) {
            Schema.DescribeFieldResult d = f.getDescribe();
            String n = d.getName();
            String bare = n.countMatches('__') > 1 ? n.substringAfter('__') : n;
            if (bare == unprefixedName) {
                return d;
            }
        }
        return null;
    }

    @IsTest
    static void testFillNullSafe() {
        DeliveryLegacyFieldFiller.fill((List<SObject>) null);
        DeliveryLegacyFieldFiller.fill(new List<SObject>());
        System.assert(true, 'null / empty input must not throw');
    }

    @IsTest
    static void testFillDependencyCopiesIntoLegacyLookups() {
        WorkItem__c a = new WorkItem__c(BriefDescriptionTxt__c = 'Blocker', StageNamePk__c = 'Backlog');
        WorkItem__c b = new WorkItem__c(BriefDescriptionTxt__c = 'Blocked', StageNamePk__c = 'Backlog');
        insert new List<WorkItem__c>{ a, b };

        WorkItemDependency__c dep = new WorkItemDependency__c(
            BlockingWorkItemLookup__c = a.Id,
            BlockedWorkItemLookup__c = b.Id
        );
        DeliveryLegacyFieldFiller.fill(dep);

        Schema.DescribeFieldResult legacyBlocked = findField(WorkItemDependency__c.SObjectType, 'BlockedWorkItemId__c');
        Schema.DescribeFieldResult legacyBlocking = findField(WorkItemDependency__c.SObjectType, 'BlockingWorkItemId__c');
        if (legacyBlocked != null && !legacyBlocked.isNillable()) {
            System.assertEquals(b.Id, dep.get(legacyBlocked.getName()), 'Legacy blocked lookup should be back-filled');
        }
        if (legacyBlocking != null && !legacyBlocking.isNillable()) {
            System.assertEquals(a.Id, dep.get(legacyBlocking.getName()), 'Legacy blocking lookup should be back-filled');
        }
        System.assertEquals(a.Id, dep.BlockingWorkItemLookup__c, 'Current field must be untouched');
        System.assertEquals(b.Id, dep.BlockedWorkItemLookup__c, 'Current field must be untouched');

        // The real proof in any org: the insert succeeds.
        insert dep;
        System.assertNotEquals(null, dep.Id, 'Dependency insert must succeed with or without legacy required fields');
    }

    @IsTest
    static void testFillDoesNotOverwriteExistingLegacyValue() {
        WorkItem__c a = new WorkItem__c(BriefDescriptionTxt__c = 'Blocker', StageNamePk__c = 'Backlog');
        WorkItem__c b = new WorkItem__c(BriefDescriptionTxt__c = 'Blocked', StageNamePk__c = 'Backlog');
        WorkItem__c c = new WorkItem__c(BriefDescriptionTxt__c = 'Other', StageNamePk__c = 'Backlog');
        insert new List<WorkItem__c>{ a, b, c };

        Schema.DescribeFieldResult legacyBlocked = findField(WorkItemDependency__c.SObjectType, 'BlockedWorkItemId__c');
        if (legacyBlocked == null || legacyBlocked.isNillable()) {
            return; // no required legacy field in this org - nothing to protect
        }
        WorkItemDependency__c dep = new WorkItemDependency__c(
            BlockingWorkItemLookup__c = a.Id,
            BlockedWorkItemLookup__c = b.Id
        );
        dep.put(legacyBlocked.getName(), c.Id);
        DeliveryLegacyFieldFiller.fill(dep);
        System.assertEquals(c.Id, dep.get(legacyBlocked.getName()), 'An explicit legacy value must not be overwritten');
    }

    @IsTest
    static void testClaimInsertSucceedsRegardlessOfLegacyEmailField() {
        WorkItem__c bounty = new WorkItem__c(BriefDescriptionTxt__c = 'Bounty', StageNamePk__c = 'Backlog');
        insert bounty;
        BountyClaim__c claim = new BountyClaim__c(
            WorkItemId__c = bounty.Id,
            ClaimantEmail__c = 'legacy-fill@example.com',
            ClaimantNameTxt__c = 'Legacy Fill',
            StatusPk__c = 'Active',
            ClaimedDateTime__c = Datetime.now()
        );
        insert claim;
        System.assertNotEquals(null, claim.Id, 'Claim insert must succeed with or without legacy required fields');
    }
}
