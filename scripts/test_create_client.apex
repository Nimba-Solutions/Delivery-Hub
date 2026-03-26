// Simulate what the Create Client onboarding does
try {
    delivery.DeliveryClientOnboardingController.OnboardingRequest req =
        new delivery.DeliveryClientOnboardingController.OnboardingRequest();
    req.clientName = 'Test Client Onboarding';
    req.contactEmail = 'test@example.com';
    req.hourlyRate = 100;
    Map<String, Object> result = delivery.DeliveryClientOnboardingController.onboardClient(req);
    System.debug(LoggingLevel.ERROR, 'SUCCESS: ' + JSON.serialize(result));
    // Clean up - delete the created records
    Id entityId = (Id) result.get('entityId');
    Id docId = (Id) result.get('documentId');
    delete [SELECT Id FROM delivery__DeliveryDocument__c WHERE Id = :docId];
    delete [SELECT Id FROM delivery__NetworkEntity__c WHERE Id = :entityId];
    System.debug(LoggingLevel.ERROR, 'Cleaned up test records');
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, 'FAILED: ' + e.getTypeName() + ': ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Stack: ' + e.getStackTraceString());
}
