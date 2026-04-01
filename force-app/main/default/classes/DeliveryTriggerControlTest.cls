/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryTriggerControl utility class.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryTriggerControlTest {

    @IsTest
    static void testDisableAndEnableAfterLogic() {
        // Default state
        System.assertEquals(true, DeliveryTriggerControl.runAfterLogic,
            'runAfterLogic should default to true');

        // Disable
        DeliveryTriggerControl.disableAfterLogic();
        System.assertEquals(false, DeliveryTriggerControl.runAfterLogic,
            'runAfterLogic should be false after disableAfterLogic()');

        // Re-enable
        DeliveryTriggerControl.enableAfterLogic();
        System.assertEquals(true, DeliveryTriggerControl.runAfterLogic,
            'runAfterLogic should be true after enableAfterLogic()');
    }
}
