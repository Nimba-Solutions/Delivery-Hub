/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Dedicated Schedulable class for the Escalation Engine. Evaluates
 *               CMT-driven escalation rules against stalled work items and fires
 *               automated actions (email, Chatter, or both). Can be scheduled
 *               independently of DeliveryHubScheduler for finer-grained control.
 *
 *               Schedule example (daily at 6 AM):
 *                 System.schedule('Delivery Escalation 6AM', '0 0 6 * * ?',
 *                     new DeliveryEscalationJob());
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryEscalationJob implements Schedulable {

    /**
     * @description Schedulable execute — delegates to DeliveryEscalationService.
     * @param sc The SchedulableContext provided by the platform.
     */
    public void execute(SchedulableContext sc) {
        try {
            DeliveryEscalationService.evaluateRules();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[DeliveryEscalationJob] Escalation processing failed: ' + e.getMessage()
                + ' | Stack: ' + e.getStackTraceString());
        }
    }
}
