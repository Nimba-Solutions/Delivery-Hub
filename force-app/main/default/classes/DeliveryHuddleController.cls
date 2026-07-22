/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read-mostly controller behind the workspace Huddle tab — the
 *               meeting-prep surface. One query answers "what do we talk
 *               about": every open WorkItem with its latest comment, due date,
 *               epic grouping and external page link, so a standup can open on
 *               the board instead of on memory.
 *
 *               getHuddleItems() — open (non-terminal) WorkItems, newest-touch
 *                 first, each carrying its most recent WorkItemComment__c via
 *                 subquery. Sectioning (overdue / due soon / recently changed /
 *                 stale) is derived client-side from the returned dates so the
 *                 Apex stays one cacheable query.
 *               quickAddItem()  — five-second capture during a meeting: title
 *                 (+ optional due date / epic / external link) inserted as a
 *                 standard intake WorkItem (StatusPk 'New', not activated),
 *                 so it lands in the same front-of-pipe the Intake tab drains.
 *
 *               SOQL is WITH SYSTEM_MODE per CLAUDE.md (WITH USER_MODE breaks
 *               in namespaced package test context). Picklist values are safe
 *               known literals (the picklist-allowlist trigger is a documented
 *               no-op). Terminal stages come from the same CMT-driven union
 *               DeliveryTriageController uses, so a closed-out item never
 *               reappears in a huddle.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryHuddleController {

    /** Intake status quickAddItem inserts with — same front-of-pipe semantics
     *  as a reported issue (Status='New' is the legitimate intake state). */
    private static final String STATUS_NEW = 'New';

    /** Statuses that are closed regardless of stage. */
    private static final Set<String> CLOSED_STATUSES =
        new Set<String>{ 'Done', 'Cancelled' };

    /** Hard cap so a years-old org can't blow up the wire payload. */
    private static final Integer MAX_ITEMS = 400;

    /**
     * @description WorkItem__c stages excluded from the huddle — CMT-driven
     * terminal union (defaults to Done/Cancelled when CMT empty).
     */
    @TestVisible
    private static Set<String> terminalStages {
        get {
            if (terminalStages == null) {
                terminalStages = DeliveryWorkflowConfigService.getAllTerminalStageValues();
            }
            return terminalStages;
        }
        set;
    }

    // ────────────────────────────────────────────────────────────────────
    // DTOs
    // ────────────────────────────────────────────────────────────────────

    /** @description One open WorkItem row on the Huddle tab. */
    public class HuddleItemDTO {
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String status;
        @AuraEnabled public String stage;
        @AuraEnabled public String epic;
        @AuraEnabled public String tags;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public String externalPageUrl;
        @AuraEnabled public Datetime lastModified;
        @AuraEnabled public String lastCommentBody;
        @AuraEnabled public String lastCommentAuthor;
        @AuraEnabled public Datetime lastCommentDate;
    }

    // ────────────────────────────────────────────────────────────────────
    // Reads
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Every open WorkItem with its latest comment, for the Huddle
     *              tab. Ordered most-recently-touched first — in a meeting the
     *              live items outrank the quiet ones.
     * @return open items, newest LastModifiedDate first, capped at MAX_ITEMS
     */
    @AuraEnabled(cacheable=true)
    public static List<HuddleItemDTO> getHuddleItems() {
        Set<String> closedStages = terminalStages;
        List<WorkItem__c> rows = [
            SELECT Id, Name, BriefDescriptionTxt__c, StatusPk__c, StageNamePk__c,
                   EpicTxt__c, TagsTxt__c, Owner.Name, SLATargetDate__c,
                   ExternalPageUrl__c, LastModifiedDate,
                   (SELECT BodyTxt__c, AuthorTxt__c, CreatedDate
                      FROM WorkItemComments__r
                     ORDER BY CreatedDate DESC
                     LIMIT 1)
              FROM WorkItem__c
             WHERE (StageNamePk__c NOT IN :closedStages OR StageNamePk__c = null)
               AND (StatusPk__c NOT IN :CLOSED_STATUSES OR StatusPk__c = null)
              WITH SYSTEM_MODE
             ORDER BY LastModifiedDate DESC
             LIMIT :MAX_ITEMS
        ];
        List<HuddleItemDTO> out = new List<HuddleItemDTO>();
        for (WorkItem__c row : rows) {
            HuddleItemDTO dto = new HuddleItemDTO();
            dto.workItemId = row.Id;
            dto.name = row.Name;
            dto.title = row.BriefDescriptionTxt__c;
            dto.status = row.StatusPk__c;
            dto.stage = row.StageNamePk__c;
            dto.epic = row.EpicTxt__c;
            dto.tags = row.TagsTxt__c;
            dto.ownerName = row.Owner.Name;
            dto.dueDate = row.SLATargetDate__c;
            dto.externalPageUrl = row.ExternalPageUrl__c;
            dto.lastModified = row.LastModifiedDate;
            if (!row.WorkItemComments__r.isEmpty()) {
                WorkItemComment__c c = row.WorkItemComments__r[0];
                dto.lastCommentBody = c.BodyTxt__c;
                dto.lastCommentAuthor = c.AuthorTxt__c;
                dto.lastCommentDate = c.CreatedDate;
            }
            out.add(dto);
        }
        return out;
    }

    // ────────────────────────────────────────────────────────────────────
    // Writes
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Quick capture during a meeting. Inserts a plain intake
     *              WorkItem (Status 'New', not activated) so it flows through
     *              the exact same front-of-pipe as a reported issue.
     * @param title required one-line description
     * @param dueDate optional SLA target date
     * @param epic optional epic/group label
     * @param externalPageUrl optional link-out to the page holding context
     * @return Id of the created WorkItem
     */
    @AuraEnabled
    public static Id quickAddItem(String title, Date dueDate, String epic, String externalPageUrl) {
        if (String.isBlank(title)) {
            throw new AuraHandledException('A title is required.');
        }
        try {
            WorkItem__c wi = new WorkItem__c(
                BriefDescriptionTxt__c = title.trim(),
                StatusPk__c = STATUS_NEW,
                SLATargetDate__c = dueDate,
                EpicTxt__c = String.isBlank(epic) ? null : epic.trim(),
                ExternalPageUrl__c = String.isBlank(externalPageUrl) ? null : externalPageUrl.trim()
            );
            insert wi;
            return wi.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Could not create the work item: ' + e.getMessage());
        }
    }
}
