trigger LeadAssignmentTrigger on Lead (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        LeadAssignmentHandler.reassignLeads(Trigger.new, Trigger.oldMap);
    }
}