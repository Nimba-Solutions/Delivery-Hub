@IsTest
private class DeliveryGuideControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void testGetGuideContext() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> ctx = DeliveryGuideController.getGuideContext();
            Test.stopTest();

            System.assertNotEquals(null, ctx, 'Context should not be null');
            System.assert(ctx.containsKey('orgDomain'), 'Should contain orgDomain');
            System.assert(ctx.containsKey('setupAppManager'), 'Should contain setupAppManager');
            System.assert(ctx.containsKey('apps'), 'Should contain apps');

            String orgDomain = (String) ctx.get('orgDomain');
            System.assert(orgDomain.startsWith('https://'), 'Org domain should be HTTPS URL');

            String setupUrl = (String) ctx.get('setupAppManager');
            System.assert(setupUrl.contains('/lightning/setup/'), 'Setup URL should point to Lightning Setup');

            List<Object> apps = (List<Object>) ctx.get('apps');
            System.assertNotEquals(null, apps, 'Apps list should not be null');

            if (!apps.isEmpty()) {
                Map<String, Object> firstApp = (Map<String, Object>) apps[0];
                System.assert(firstApp.containsKey('label'), 'App should have label');
                System.assert(firstApp.containsKey('name'), 'App should have name');
                System.assert(firstApp.containsKey('hasGhostRecorder'), 'App should have hasGhostRecorder flag');
            }
        }
    }
}
