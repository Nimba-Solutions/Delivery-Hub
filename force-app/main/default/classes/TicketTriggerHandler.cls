/**
 * @description Aggregates Ticket rows that need a SyncEngine update,
 * then enqueues worker jobs. Also handles Network Entity Sync and High-Water Mark Sync.
 */
public without sharing class TicketTriggerHandler {
    
    /** @description Flag to disable trigger execution */
    public static boolean triggerDisabled = false;

    /**
     * @description Entry point for After Insert/Update logic
     * @param newRows List of new Ticket records
     * @param oldMap Map of old Ticket records
     * @param isInsert Boolean indicating insert context
     * @param isUpdate Boolean indicating update context
     */
    public static void handleAfter(
        List<Ticket__c> newRows,
        Map<Id, Ticket__c> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ){
        if (!TriggerControl.runAfterLogic) { return; }

        // 1. BRIDGE CREATION (Network Entity Sync)
        if (isInsert){
            handleNetworkEntitySync(newRows);
        }

        // 2. UNIFIED SYNC ENGINE (High-Water Mark)
        Set<String> syncFields = new Set<String>{
            'BriefDescriptionTxt__c', 
            'DetailsTxt__c', 
            'StageNamePk__c', 
            'StatusPk__c', 
            'PriorityPk__c', 
            'DeveloperDaysSizeNumber__c', 
            'EstimatedHoursNumber__c', 
            'ClientPreApprovedHoursNumber__c', 
            'Developer__c', 
            'CalculatedETADate__c', 
            'ProjectedUATReadyDate__c',
            'AcceptanceCriteriaTxt__c', 
            'StepsToReproduceTxt__c'
        };

        SyncEngine.captureChanges(newRows, oldMap, syncFields);
    }

    /**
     * @description Checks settings and auto-creates/sends a Request if configured.
     * @param newTickets List of new tickets
     */
    private static void handleNetworkEntitySync(List<Ticket__c> newTickets) {
        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getInstance();
        
        Boolean shouldCreateRequest = true;
        if (settings.Id != null) {
            Map<String, Object> populatedFields = settings.getPopulatedFieldsAsMap();
            if (populatedFields.containsKey('AutoCreateRequestFromTicketBool__c')) {
                shouldCreateRequest = settings.AutoCreateRequestFromTicketBool__c;
            }
        }

        if (!shouldCreateRequest) {
            return;
        }

        // Fix: Added WITH USER_MODE to satisfy PMD ApexCRUDViolation
        List<Network_Entity__c> vendors = [
            SELECT Id FROM Network_Entity__c
            WHERE StatusPk__c = 'Active' AND EntityTypePk__c = 'Vendor'
            WITH USER_MODE
            LIMIT 1
        ];

        List<Request__c> newRequests = new List<Request__c>();

        if (!vendors.isEmpty()) {
            Network_Entity__c vendor = vendors[0];
            for (Ticket__c t : newTickets) {
                newRequests.add(new Request__c(
                    TicketId__c = t.Id,
                    DeliveryEntityId__c = vendor.Id,
                    StatusPk__c = 'Draft',
                    PreApprovedHoursNumber__c = (t.ClientPreApprovedHoursNumber__c != null) ? t.ClientPreApprovedHoursNumber__c : 0
                ));
            }
        } else {
            for (Ticket__c t : newTickets) {
                if (t.ClientNetworkEntityId__c != null) {
                    newRequests.add(new Request__c(
                        TicketId__c = t.Id,
                        DeliveryEntityId__c = t.ClientNetworkEntityId__c,
                        StatusPk__c = 'Draft',
                        PreApprovedHoursNumber__c = (t.ClientPreApprovedHoursNumber__c != null) ? t.ClientPreApprovedHoursNumber__c : 0
                    ));
                }
            }
        }

        if (newRequests.isEmpty()) {
            return;
        }

        // Enforce CRUD/FLS on Insert
        Database.insert(newRequests, AccessLevel.USER_MODE);
    }
    
    /**
     * @description Logic to handle Before Update events (Blocking logic)
     */
    public static void handleBeforeUpdate(List<Ticket__c> newTickets, Map<Id, Ticket__c> oldMap) {
        Set<String> activeDevStages = new Set<String>{'In Development', 'Ready for QA'}; 
        Set<Id> ticketsToCheck = new Set<Id>();
        for (Ticket__c ticket : newTickets) {
            String oldStage = oldMap.get(ticket.Id).StageNamePk__c;
            String newStage = ticket.StageNamePk__c;
            if (activeDevStages.contains(newStage) && !activeDevStages.contains(oldStage)) {
                ticketsToCheck.add(ticket.Id);
            }
        }
        if (!ticketsToCheck.isEmpty()) {
            // Fix: Added WITH USER_MODE to satisfy PMD ApexCRUDViolation
            List<Ticket_Dependency__c> unresolvedBlockers = [
                SELECT Blocked_Ticket__c, Blocking_Ticket__r.BriefDescriptionTxt__c Blocking_Ticket__r.StageNamePk__c
                FROM Ticket_Dependency__c
                WHERE Blocked_Ticket__c IN :ticketsToCheck
                AND Blocking_Ticket__r.StageNamePk__c NOT IN ('Done', 'Deployed to Prod', 'Cancelled')
                WITH USER_MODE
            ];
            for (Ticket_Dependency__c dependency : unresolvedBlockers) {
                for (Ticket__c ticket : newTickets) {
                    if (ticket.Id == dependency.Blocked_Ticket__c) {
                        ticket.addError('This ticket cannot be started. It is blocked by ticket: ' + dependency.Blocking_Ticket__r.BriefDescriptionTxt__c);
                    }
                }
            }
        }
    }
}