/**
 * @description Tests for DeliveryTicketDependenciesController.
 */
@IsTest
private class DeliveryTicketDependenciesControllerTest {

    @TestSetup
    static void setup() {
        Ticket__c blocker = new Ticket__c(BriefDescriptionTxt__c = 'Blocker', StageNamePk__c = 'In Development');
        Ticket__c blocked = new Ticket__c(BriefDescriptionTxt__c = 'Blocked', StageNamePk__c = 'Ready for Development');
        insert new List<Ticket__c>{ blocker, blocked };

        insert new Ticket_Dependency__c(
            Blocking_Ticket__c = blocker.Id,
            Blocked_Ticket__c  = blocked.Id,
            TypePk__c          = 'Blocks'
        );
    }

    @IsTest
    static void testGetDependenciesBlocking() {
        Ticket__c blocker = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Blocker' LIMIT 1];
        Map<String, Object> result = DeliveryTicketDependenciesController.getDependencies(blocker.Id);
        List<Object> blocking = (List<Object>) result.get('blocking');
        System.assertEquals(1, blocking.size(), 'Should find 1 ticket being blocked');
    }

    @IsTest
    static void testGetDependenciesBlockedBy() {
        Ticket__c blocked = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Blocked' LIMIT 1];
        Map<String, Object> result = DeliveryTicketDependenciesController.getDependencies(blocked.Id);
        List<Object> blockedBy = (List<Object>) result.get('blockedBy');
        System.assertEquals(1, blockedBy.size(), 'Should find 1 blocker');
    }

    @IsTest
    static void testGetDependenciesNone() {
        Ticket__c lone = new Ticket__c(BriefDescriptionTxt__c = 'Solo', StageNamePk__c = 'Backlog');
        insert lone;
        Map<String, Object> result = DeliveryTicketDependenciesController.getDependencies(lone.Id);
        List<Object> blocking  = (List<Object>) result.get('blocking');
        List<Object> blockedBy = (List<Object>) result.get('blockedBy');
        System.assertEquals(0, blocking.size());
        System.assertEquals(0, blockedBy.size());
    }
}
