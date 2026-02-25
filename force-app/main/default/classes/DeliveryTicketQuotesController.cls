/**
 * @description Controller for the deliveryTicketQuotes LWC.
 *              Returns all Request__c quotes linked to a ticket and supports bid acceptance.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryTicketQuotesController {

    /** @description Represents a single vendor quote (Request__c) on a ticket. */
    public class QuoteRow {
        @AuraEnabled public String id;
        @AuraEnabled public String vendorName;
        @AuraEnabled public String vendorId;
        @AuraEnabled public Decimal quotedHours;
        @AuraEnabled public Decimal hourlyRate;
        @AuraEnabled public Decimal projectedCost;
        @AuraEnabled public Decimal preApprovedHours;
        @AuraEnabled public String status;
        @AuraEnabled public String workProofUrl;
        @AuraEnabled public Boolean isAccepted;
    }

    /**
     * @description Returns all quotes (Request__c records) for a ticket.
     * @param ticketId The parent Ticket__c record Id.
     * @return List of QuoteRow wrappers.
     */
    @AuraEnabled(cacheable=true)
    public static List<QuoteRow> getQuotes(Id ticketId) {
        List<QuoteRow> rows = new List<QuoteRow>();
        for (Request__c req : [
            SELECT Id, DeliveryEntityId__r.Name, DeliveryEntityId__c,
                   QuotedHoursNumber__c, HourlyRateCurrency__c,
                   ProjectedCostCurrency__c, PreApprovedHoursNumber__c,
                   StatusPk__c, WorkProofUrl__c
            FROM Request__c
            WHERE TicketId__c = :ticketId
            AND QuotedHoursNumber__c != null
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
        ]) {
            QuoteRow row       = new QuoteRow();
            row.id             = req.Id;
            row.vendorName     = req.DeliveryEntityId__r != null ? req.DeliveryEntityId__r.Name : 'Unknown Vendor';
            row.vendorId       = req.DeliveryEntityId__c;
            row.quotedHours    = req.QuotedHoursNumber__c;
            row.hourlyRate     = req.HourlyRateCurrency__c;
            row.projectedCost  = req.ProjectedCostCurrency__c;
            row.preApprovedHours = req.PreApprovedHoursNumber__c;
            row.status         = req.StatusPk__c;
            row.workProofUrl   = req.WorkProofUrl__c;
            row.isAccepted     = req.StatusPk__c == 'Accepted' || req.StatusPk__c == 'In Progress' || req.StatusPk__c == 'Completed';
            rows.add(row);
        }
        return rows;
    }

    /**
     * @description Accepts a vendor quote: sets the chosen Request to Accepted,
     *              sets all others on the same ticket to Inactive.
     * @param requestId The Request__c record to accept.
     * @param ticketId  The parent Ticket__c for context (used to deactivate other bids).
     */
    @AuraEnabled
    public static void acceptQuote(Id requestId, Id ticketId) {
        List<Request__c> allRequests = [
            SELECT Id, StatusPk__c
            FROM Request__c
            WHERE TicketId__c = :ticketId
            WITH SYSTEM_MODE
        ];
        List<Request__c> toUpdate = new List<Request__c>();
        for (Request__c req : allRequests) {
            String newStatus = req.Id == requestId ? 'Accepted' : 'Inactive';
            if (req.StatusPk__c != newStatus) {
                toUpdate.add(new Request__c(Id = req.Id, StatusPk__c = newStatus));
            }
        }
        if (!toUpdate.isEmpty()) {
            // FIX: SYSTEM_MODE to prevent packaging test failures on namespaced fields
            Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
        }
    }
}
