/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Service for audit log hash chain computation, validation, and compliance export.
 *              Provides tamper detection via SHA-256 chain hashing and legal hold enforcement.
 * @author Cloud Nimbus LLC
 */
public without sharing class DeliveryAuditChainService {

    /**
     * @description Called from trigger before-insert: compute hash chain for new records.
     *              Each record's hash includes the previous record's hash, creating an
     *              immutable chain that detects tampering or deletion.
     * @param records The list of ActivityLog__c records being inserted
     */
    public static void setHashOnInsert(List<ActivityLog__c> records) {
        // Query the most recent ActivityLog to get the chain head hash
        List<ActivityLog__c> chain = [
            SELECT HashChainTxt__c FROM ActivityLog__c
            WHERE HashChainTxt__c != null
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        String previousHash = chain.isEmpty() ? null : chain[0].HashChainTxt__c;

        for (ActivityLog__c rec : records) {
            String hash = DeliveryCryptoService.computeChainHash(
                previousHash, rec.Id, rec.ActionTypePk__c,
                Datetime.now(), rec.ContextDataTxt__c
            );
            rec.HashChainTxt__c = hash;
            previousHash = hash; // chain within the batch
        }
    }

    /**
     * @description Prevents deletion of ActivityLog__c records that are under legal hold.
     *              A record is under legal hold when LegalHoldDateTime__c is non-null.
     * @param records The list of ActivityLog__c records being deleted
     */
    public static void blockLegalHoldDeletion(List<ActivityLog__c> records) {
        for (ActivityLog__c rec : records) {
            if (rec.LegalHoldDateTime__c != null) {
                rec.addError('This activity log record is under legal hold and cannot be deleted.');
            }
        }
    }

    /**
     * @description Validates the hash chain starting from the earliest record.
     *              Returns a map with totalChecked, valid, and broken counts.
     * @param batchSize Number of records to validate (defaults to 1000)
     * @return Map with validation results
     */
    public static Map<String, Object> validateChain(Integer batchSize) {
        if (batchSize == null || batchSize <= 0) {
            batchSize = 1000;
        }

        List<ActivityLog__c> records = [
            SELECT Id, HashChainTxt__c, ActionTypePk__c, CreatedDate, ContextDataTxt__c
            FROM ActivityLog__c
            WHERE HashChainTxt__c != null
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT :batchSize
        ];

        Integer valid = 0;
        Integer broken = 0;
        String previousHash = null;

        for (ActivityLog__c rec : records) {
            String expected = DeliveryCryptoService.computeChainHash(
                previousHash, rec.Id, rec.ActionTypePk__c,
                rec.CreatedDate, rec.ContextDataTxt__c
            );
            if (expected == rec.HashChainTxt__c) {
                valid++;
            } else {
                broken++;
            }
            previousHash = rec.HashChainTxt__c;
        }

        return new Map<String, Object>{
            'totalChecked' => records.size(),
            'valid' => valid,
            'broken' => broken
        };
    }

    /**
     * @description Per-document hash chain integrity check. Walks every
     *              ActivityLog__c record whose RecordIdTxt__c matches the
     *              given Salesforce Id, in CreatedDate order, and verifies
     *              that each row's HashChainTxt__c agrees with what we'd
     *              recompute given the previous row's hash. Returns
     *              passed=true ONLY when every row reconciles AND at least
     *              one row exists. A document with zero audit log entries
     *              returns passed=false so the portal does not falsely
     *              claim verification.
     * @param recordId The Salesforce Id of the parent record (typically
     *                 a DeliveryDocument__c) to validate the chain for.
     * @return Map with keys: passed (Boolean), totalChecked (Integer),
     *         broken (Integer), verifiedAt (Datetime).
     */
    public static Map<String, Object> validateChainForRecord(Id recordId) {
        Map<String, Object> result = new Map<String, Object>{
            'passed' => false,
            'totalChecked' => 0,
            'broken' => 0,
            'verifiedAt' => null
        };
        if (recordId == null) {
            return result;
        }
        String idString = String.valueOf(recordId);
        List<ActivityLog__c> records = [
            SELECT Id, HashChainTxt__c, ActionTypePk__c, CreatedDate, ContextDataTxt__c
            FROM ActivityLog__c
            WHERE RecordIdTxt__c = :idString
            AND HashChainTxt__c != null
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1000
        ];
        if (records.isEmpty()) {
            return result;
        }
        Integer broken = countBrokenLinks(records);
        result.put('totalChecked', records.size());
        result.put('broken', broken);
        result.put('passed', broken == 0);
        if (broken == 0) {
            result.put('verifiedAt', Datetime.now());
        }
        return result;
    }

    private static Integer countBrokenLinks(List<ActivityLog__c> records) {
        Integer broken = 0;
        String previousHash = lookupPreviousHash(records[0]);
        for (ActivityLog__c rec : records) {
            String expected = DeliveryCryptoService.computeChainHash(
                previousHash, rec.Id, rec.ActionTypePk__c,
                rec.CreatedDate, rec.ContextDataTxt__c
            );
            if (expected != rec.HashChainTxt__c) {
                broken++;
            }
            previousHash = rec.HashChainTxt__c;
        }
        return broken;
    }

    private static String lookupPreviousHash(ActivityLog__c firstRecord) {
        List<ActivityLog__c> prior = [
            SELECT HashChainTxt__c FROM ActivityLog__c
            WHERE CreatedDate < :firstRecord.CreatedDate
            AND HashChainTxt__c != null
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        return prior.isEmpty() ? null : prior[0].HashChainTxt__c;
    }

    /**
     * @description Export compliance data for a date range.
     *              Returns all ActivityLog__c records within the specified period.
     * @param fromDate Start date (inclusive)
     * @param toDate End date (inclusive)
     * @return List of ActivityLog__c records with audit fields
     */
    public static List<ActivityLog__c> exportComplianceData(Date fromDate, Date toDate) {
        DateTime fromDt = DateTime.newInstance(fromDate, Time.newInstance(0, 0, 0, 0));
        DateTime toDt = DateTime.newInstance(toDate.addDays(1), Time.newInstance(0, 0, 0, 0));
        return [
            SELECT Id, ActionTypePk__c, ComponentNameTxt__c, ContextDataTxt__c,
                   UserIdTxt__c, RecordIdTxt__c, HashChainTxt__c, LegalHoldDateTime__c,
                   CreatedDate, CreatedById
            FROM ActivityLog__c
            WHERE CreatedDate >= :fromDt AND CreatedDate < :toDt
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
        ];
    }
}
