/**
 * @description Controller for retrieving and seeding demo DH_Ticket__c records.
 */
public with sharing class DH_TicketController {

    /**
     * @description Returns all active DH_Ticket__c records, ordered by SortOrderNumber__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<DH_Ticket__c> getTickets() {
        if (!Schema.sObjectType.DH_Ticket__c.isAccessible()
            || !Schema.sObjectType.DH_Ticket__c.fields.StageNamePk__c.isAccessible()) {
            return new List<DH_Ticket__c>();
        }
        return [
            SELECT Id,
                   BriefDescriptionTxt__c,
                   CalculatedETADate__c,
                   DeveloperDaysSizeNumber__c,
                   StageNamePk__c,
                   Client_Intention__c,
                   SortOrderNumber__c,
                   Epic__c,
                   Tags__c
            FROM DH_Ticket__c
            WHERE IsActiveBool__c = true
            ORDER BY SortOrderNumber__c
        ];
    }

    /**
     * @description Creates demo DH_Ticket__c records and returns them.
     */
    @AuraEnabled
    public static List<DH_Ticket__c> createDummyTickets() {
        List<DH_Ticket__c> demo = new List<DH_Ticket__c>{
            new DH_Ticket__c(
                BriefDescriptionTxt__c='Alpha summary',
                CalculatedETADate__c=Date.today().addDays(7),
                DeveloperDaysSizeNumber__c=2.5,
                StageNamePk__c='Backlog',
                SortOrderNumber__c=1,
                IsActiveBool__c=true
            ),
            new DH_Ticket__c(
                BriefDescriptionTxt__c='Beta scope',
                CalculatedETADate__c=Date.today().addDays(10),
                DeveloperDaysSizeNumber__c=3.0,
                StageNamePk__c='Active Scoping',
                SortOrderNumber__c=1,
                IsActiveBool__c=true
            ),
            new DH_Ticket__c(
                BriefDescriptionTxt__c='Gamma done',
                CalculatedETADate__c=Date.today().addDays(5),
                DeveloperDaysSizeNumber__c=1.75,
                StageNamePk__c='Dev Complete',
                SortOrderNumber__c=1,
                IsActiveBool__c=true
            ),
            new DH_Ticket__c(
                BriefDescriptionTxt__c='Delta final',
                CalculatedETADate__c=Date.today().addDays(3),
                DeveloperDaysSizeNumber__c=4.0,
                StageNamePk__c='Done',
                SortOrderNumber__c=1,
                IsActiveBool__c=true
            )
        };
        insert demo;
        return demo;
    }

    @AuraEnabled
    public static void updateTicketSortOrders(List<Map<String, Object>> updates) {
        List<DH_Ticket__c> tickets = new List<DH_Ticket__c>();
        for (Map<String, Object> u : updates) {
            Object sortOrderRaw = u.get('SortOrderNumber__c');
            Decimal sortOrder;
            if (sortOrderRaw == null) {
                sortOrder = null;
            } else if (sortOrderRaw instanceof Decimal) {
                sortOrder = (Decimal)sortOrderRaw;
            } else if (sortOrderRaw instanceof Integer) {
                sortOrder = Decimal.valueOf((Integer)sortOrderRaw);
            } else if (sortOrderRaw instanceof Long) {
                sortOrder = Decimal.valueOf(((Long)sortOrderRaw).intValue());
            } else if (sortOrderRaw instanceof Double) {
                sortOrder = Decimal.valueOf(((Double)sortOrderRaw).intValue());
            } else if (sortOrderRaw instanceof String) {
                sortOrder = Decimal.valueOf((String)sortOrderRaw);
            } else {
                sortOrder = null;
            }
            tickets.add(new DH_Ticket__c(
                Id = (String)u.get('Id'),
                SortOrderNumber__c = sortOrder
            ));
        }
        update tickets;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isMarketingEnabled() {
        try {
            Cloud_Nimbus_LLC_Marketing__mdt m = [
                SELECT Enabled__c
                FROM Cloud_Nimbus_LLC_Marketing__mdt
                WHERE DeveloperName = 'Cloud_Nimbus_LLC_Marketing_Enabled'
                LIMIT 1
            ];
            return m != null && m.Enabled__c;
        } catch (Exception e) {
            // Optional: log exception or handle gracefully
            return false;
        }
    }


}