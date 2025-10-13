@SuppressWarnings('PMD')
public class LeadAssignmentHandler {

    public static void reassignLeads(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        List<Lead> leadsToReassign = new List<Lead>();

        for (Lead l : newLeads) {
            Lead oldLead = oldLeadMap.get(l.Id);

            if (l.OwnerId != oldLead.OwnerId || l.Status != oldLead.Status) {
                Lead clonedLead = new Lead(Id = l.Id);
                leadsToReassign.add(clonedLead);
            }
        }

        if (!leadsToReassign.isEmpty()) {
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.assignmentRuleHeader.useDefaultRule = true;

            for (Lead l : leadsToReassign) {
                l.setOptions(dmlOptions);
            }

            update leadsToReassign;
        }
    }
}