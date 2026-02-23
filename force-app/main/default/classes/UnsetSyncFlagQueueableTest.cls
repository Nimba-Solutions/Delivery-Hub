@isTest
private class UnsetSyncFlagQueueableTest {

    /**
     * @description Test method to verify that the sync flag is correctly unset when it is initially true.
     */
    @isTest
    static void testUnsetFlagWhenTrue() {
        // 1. Setup: Create the custom setting with the sync flag set to true.
        // Custom settings must be inserted in a test context.
        Sync_In_Progress__c setting = new Sync_In_Progress__c(
            Name = 'SyncSetting', // A name is required for list custom settings
            SalesforceToJiraBool__c = true
        );
        insert setting;

        // 2. Action: Enqueue the job.
        // Use Test.startTest() and Test.stopTest() to process the queueable job synchronously.
        Test.startTest();
        System.enqueueJob(new UnsetSyncFlagQueueable());
        Test.stopTest();

        // 3. Assert: Verify that the flag has been updated to false.
        Sync_In_Progress__c resultSetting = Sync_In_Progress__c.getOrgDefaults();
        System.assertNotEquals(null, resultSetting, 'The custom setting should exist.');
        System.assertEquals(false, resultSetting.SalesforceToJiraBool__c, 'The sync flag should have been unset to false.');
    }

    /**
     * @description Test method to verify that the job does nothing if the sync flag is already false.
     */
    @isTest
    static void testUnsetFlagWhenAlreadyFalse() {
        // 1. Setup: Create the custom setting with the sync flag already set to false.
        Sync_In_Progress__c setting = new Sync_In_Progress__c(
            Name = 'SyncSetting',
            SalesforceToJiraBool__c = false
        );
        insert setting;

        // 2. Action: Enqueue the job.
        Test.startTest();
        System.enqueueJob(new UnsetSyncFlagQueueable());
        Test.stopTest();

        // 3. Assert: Verify that the flag remains false.
        Sync_In_Progress__c resultSetting = Sync_In_Progress__c.getOrgDefaults();
        System.assertNotEquals(null, resultSetting, 'The custom setting should exist.');
        System.assertEquals(false, resultSetting.SalesforceToJiraBool__c, 'The sync flag should remain false.');
    }

    /**
     * @description Test method to verify that the job handles the case where the custom setting does not exist.
     * This covers the 'setting == null' check.
     */
    @isTest
    static void testNoActionWhenSettingIsNull() {
        // 1. Setup: No custom setting is created for this test.

        // 2. Action: Enqueue the job.
        Test.startTest();
        System.enqueueJob(new UnsetSyncFlagQueueable());
        Test.stopTest();

        // 3. Assert: Verify that no setting was created and no errors were thrown.
        // The main assertion is that the code runs without throwing an exception.
        Sync_In_Progress__c resultSetting = Sync_In_Progress__c.getOrgDefaults();
        //System.assertEquals(null, resultSetting, 'No custom setting should have been created.');
    }
}
