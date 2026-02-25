/**
 * @description Trigger handler for WorkLog__c. On insert, queues an outbound Sync_Item__c
 *              for each WorkLog whose parent Ticket has a client Network Entity linked.
 *              This seeds the sync queue so the scheduled processor can push logged hours
 *              to the client org once the sync pipeline supports WorkLog payloads.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryWorkLogTriggerHandler {

    /**
     * @description Processes newly inserted WorkLog records and creates outbound sync items
     *              for those tied to client-linked tickets.
     * @param newLogs List of newly inserted WorkLog__c records.
     */
    public static void onAfterInsert(List<WorkLog__c> newLogs) {
        if (!DeliveryTriggerControl.runAfterLogic) {
            return;
        }
        Set<Id> ticketIds = new Set<Id>();
        for (WorkLog__c wl : newLogs) {
            if (wl.TicketId__c != null) {
                ticketIds.add(wl.TicketId__c);
            }
        }
        if (ticketIds.isEmpty()) {
            return;
        }

        Map<Id, Ticket__c> clientTickets = new Map<Id, Ticket__c>([
            SELECT Id, ClientNetworkEntityId__c
            FROM Ticket__c
            WHERE Id IN :ticketIds
            AND ClientNetworkEntityId__c != null
            WITH SYSTEM_MODE
        ]);

        if (clientTickets.isEmpty()) {
            return;
        }

        List<Sync_Item__c> syncItems = buildSyncItems(newLogs, clientTickets);
        if (!syncItems.isEmpty()) {
            // FIX: SYSTEM_MODE to prevent packaging test failures on namespaced fields
            Database.insert(syncItems, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Builds the list of Sync_Item__c records for WorkLogs on client-linked tickets.
     * @param logs The WorkLog records to evaluate.
     * @param clientTickets Map of ticket Ids that have a client entity linked.
     * @return List of Sync_Item__c records ready for insert.
     */
    private static List<Sync_Item__c> buildSyncItems(List<WorkLog__c> logs, Map<Id, Ticket__c> clientTickets) {
        List<Sync_Item__c> items = new List<Sync_Item__c>();
        for (WorkLog__c wl : logs) {
            if (!clientTickets.containsKey(wl.TicketId__c)) {
                continue;
            }
            Map<String, Object> payload = new Map<String, Object>{
                'TicketId__c'            => wl.TicketId__c,
                'HoursLoggedNumber__c'   => wl.HoursLoggedNumber__c,
                'WorkDateDate__c'        => String.valueOf(wl.WorkDateDate__c),
                'WorkDescriptionTxt__c'  => wl.WorkDescriptionTxt__c
            };
            items.add(new Sync_Item__c(
                ObjectTypePk__c         = 'WorkLog__c',
                LocalRecordIdTxt__c     = wl.Id,
                TicketId__c             = wl.TicketId__c,
                DirectionPk__c          = 'Outbound',
                StatusPk__c             = 'Queued',
                PayloadTxt__c           = JSON.serialize(payload)
            ));
        }
        return items;
    }
}
