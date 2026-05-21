/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Single row of a Watcher signal — one WorkItem / Document /
 *              SyncItem etc. surfaced into the digest body. Up to 5 entries
 *              per signal go into both the Slack Block Kit message and the
 *              persisted WatcherDigest__c.DigestBodyTxt__c plaintext.
 *
 *              Held as a top-level class so individual signal services don't
 *              have to import each other's inner types. All fields
 *              @AuraEnabled because they bubble through the orchestrator's
 *              return DTO into PR-C+ admin LWCs.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global virtual class SignalEntryDTO {

    /** @description Salesforce Id of the surfaced record (WorkItem, Document, etc.). Null when the entry is synthetic (e.g. roll-up aggregate). */
    @AuraEnabled public Id recordId;

    /** @description Human-readable title — typically `Name — BriefDescription`. */
    @AuraEnabled public String label;

    /** @description One-line detail string (e.g. `3 days breached · stage: In Review · owner Jose`). */
    @AuraEnabled public String detailLine;

    /** @description Optional record-page URL for the Slack action button. May be null. */
    @AuraEnabled public String url;

    /**
     * @description Default constructor. All fields null on construction.
     */
    global SignalEntryDTO() {
    }

    /**
     * @description Convenience constructor.
     * @param recordId  Surfaced record Id.
     * @param label     Human-readable title.
     * @param detailLine Detail string.
     * @param url       Optional record-page URL.
     */
    global SignalEntryDTO(Id recordId, String label, String detailLine, String url) {
        this.recordId = recordId;
        this.label = label;
        this.detailLine = detailLine;
        this.url = url;
    }
}
