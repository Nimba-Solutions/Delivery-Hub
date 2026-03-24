// ============================================================================
// Delivery Hub — Record Page Assignment Guide
// ============================================================================
// Flexipage assignments (Lightning Record Page → App Default) cannot be set
// via Apex Metadata API or anonymous Apex. They must be configured through
// one of these methods:
//
//   A) Setup UI (manual, per-object)
//   B) SFDX CLI: retrieve/deploy FlexipageAssignment metadata
//
// This script documents the exact assignments needed after package install.
// ============================================================================

// ---------------------------------------------------------------------------
// Objects & Record Pages to Assign as App Default for "Delivery Hub" app:
// ---------------------------------------------------------------------------
// #   Object                  Record Page Name
// --  ----------------------  ----------------------------------------
// 1.  WorkItem__c             DeliveryWorkItemRecordPage
// 2.  NetworkEntity__c        DeliveryNetworkEntityRecordPage
// 3.  WorkRequest__c          DeliveryWorkRequestRecordPage
// 4.  WorkItemComment__c      DeliveryWorkItemCommentRecordPage
// 5.  SyncItem__c             DeliverySyncItemRecordPage
// 6.  DeliveryDocument__c     DeliveryDocumentRecordPage
// 7.  ActivityLog__c          DeliveryActivityLogRecordPage
// 8.  WorkLog__c              DeliveryWorkLogRecordPage
// 9.  DeliveryTransaction__c  DeliveryTransactionRecordPage
// 10. PortalAccess__c         DeliveryPortalAccessRecordPage

// ---------------------------------------------------------------------------
// Method A — Setup UI (per object):
// ---------------------------------------------------------------------------
// 1. Go to Setup > Object Manager > [Object]
// 2. Click "Lightning Record Pages" in the left sidebar
// 3. Click the record page name listed above
// 4. Click "Activation"
// 5. Click "Assign as App Default"
// 6. Under "App", select "Delivery Hub"
// 7. Save
// Repeat for all 10 objects above.

// ---------------------------------------------------------------------------
// Method B — SFDX CLI (bulk deploy):
// ---------------------------------------------------------------------------
// After retrieving the org's current flexipage assignments:
//
//   sf project retrieve start -m "FlexipageAssignment"
//
// Update or create the assignment metadata, then deploy:
//
//   sf project deploy start -d unpackaged/post/flexipageAssignments/
//
// See unpackaged/post/ for the deployable metadata if available.

// ---------------------------------------------------------------------------
// Verification — run this snippet to confirm pages exist in the org:
// ---------------------------------------------------------------------------
List<FlexiPage> pages = [
    SELECT DeveloperName, MasterLabel, EntityDefinitionId
    FROM FlexiPage
    WHERE DeveloperName IN (
        'DeliveryWorkItemRecordPage',
        'DeliveryNetworkEntityRecordPage',
        'DeliveryWorkRequestRecordPage',
        'DeliveryWorkItemCommentRecordPage',
        'DeliverySyncItemRecordPage',
        'DeliveryDocumentRecordPage',
        'DeliveryActivityLogRecordPage',
        'DeliveryWorkLogRecordPage',
        'DeliveryTransactionRecordPage',
        'DeliveryPortalAccessRecordPage'
    )
];

System.debug('Found ' + pages.size() + ' of 10 expected Delivery Hub record pages:');
for (FlexiPage fp : pages) {
    System.debug('  ✓ ' + fp.DeveloperName + ' → ' + fp.MasterLabel);
}

if (pages.size() < 10) {
    System.debug('⚠ Missing pages — ensure the Delivery Hub package is fully installed.');
}

System.debug('');
System.debug('Next step: Assign each page as the App Default for the Delivery Hub app.');
System.debug('Go to Setup > Object Manager > [Object] > Lightning Record Pages > [Page] > Activation > Assign as App Default > Delivery Hub.');
