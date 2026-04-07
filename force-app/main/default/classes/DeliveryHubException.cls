/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Generic exception for internal Delivery Hub errors. Safe to throw
 *               from ANY Apex context (REST, Scheduled, Queueable, Batch, Aura, VF).
 *
 *               Use this instead of AuraHandledException in private/public helper
 *               methods that may be called from a non-Aura context. AuraHandledException
 *               is only safe to throw from inside @AuraEnabled methods invoked at
 *               runtime via Lightning/LWC. Throwing it from any other context (e.g.,
 *               a REST endpoint that happens to call an @AuraEnabled method) raises
 *               an UNCATCHABLE System.LimitException: "Can only throw this exception
 *               type from VisualForce or Aura context".
 *
 *               Pattern: helper methods throw DeliveryHubException; @AuraEnabled
 *               wrapper methods catch DeliveryHubException at the boundary and
 *               re-throw as AuraHandledException for the LWC layer.
 * @author Cloud Nimbus LLC
 */
public class DeliveryHubException extends Exception {}
