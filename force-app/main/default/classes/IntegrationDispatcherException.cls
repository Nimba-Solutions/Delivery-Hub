/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Exception type for IntegrationDispatcher errors. Extracted as
 *              a top-level class because inner Exception classes don't
 *              cleanly cross managed-package namespace boundaries when
 *              referenced from test classes during package upload.
 * @author       Cloud Nimbus LLC
 */
public class IntegrationDispatcherException extends Exception {}
