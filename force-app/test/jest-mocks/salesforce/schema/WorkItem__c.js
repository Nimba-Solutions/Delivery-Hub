/**
 * @description Jest mock for the WorkItem__c object schema import. The
 *              moduleNameMapper catch-all routes @salesforce/schema/WorkItem__c here.
 *              Mirrors the shape sfdx-lwc-jest's default schema resolver returns so
 *              components reading WORK_ITEM_OBJECT.objectApiName resolve under test.
 */
export default { objectApiName: "WorkItem__c" };
