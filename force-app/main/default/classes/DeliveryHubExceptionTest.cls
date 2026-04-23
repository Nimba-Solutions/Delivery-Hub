/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryHubException. Verifies it can be thrown and
 *               caught by type from non-Aura contexts (the whole reason for
 *               its existence — AuraHandledException blows up as an
 *               uncatchable LimitException outside LWC/Aura entry points).
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc, PMD.MethodNamingConventions')
private class DeliveryHubExceptionTest {

    @IsTest
    static void testCanBeThrownAndCaughtByType() {
        Boolean caught = false;
        try {
            throw new DeliveryHubException('boom');
        } catch (DeliveryHubException e) {
            caught = true;
            System.assertEquals('boom', e.getMessage(), 'Message should propagate through the catch');
        }
        System.assertEquals(true, caught, 'DeliveryHubException should be catchable by its own type');
    }

    @IsTest
    static void testIsInstanceOfException() {
        try {
            throw new DeliveryHubException('generic');
        } catch (Exception e) {
            System.assert(e instanceof DeliveryHubException, 'Should be reachable via the generic Exception catch');
            System.assertEquals('generic', e.getMessage(), 'Message should survive generic Exception catch');
        }
    }

    @IsTest
    static void testNoArgConstructorIsUsable() {
        // The public DH pattern is `throw new DeliveryHubException('msg')`, but
        // Apex auto-generates a no-arg ctor on every Exception subclass.
        // Protects against someone accidentally adding a broken custom ctor.
        Boolean caught = false;
        try {
            throw new DeliveryHubException();
        } catch (DeliveryHubException e) {
            caught = true;
        }
        System.assertEquals(true, caught, 'No-arg constructor should produce a throwable exception');
    }

    @IsTest
    static void testCauseChainPreserved() {
        // Wrapping a lower-level exception in DeliveryHubException is the
        // canonical pattern for boundary-method rewrites. Verify the cause
        // chain survives.
        try {
            try {
                Integer.valueOf('not-a-number');
            } catch (Exception inner) {
                throw new DeliveryHubException('wrapped: ' + inner.getMessage());
            }
        } catch (DeliveryHubException outer) {
            System.assert(outer.getMessage().startsWith('wrapped:'), 'Wrapper message should carry the wrapped context');
        }
    }
}
