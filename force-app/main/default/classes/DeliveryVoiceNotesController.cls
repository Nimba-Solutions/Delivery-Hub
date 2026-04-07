/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the Voice Notes LWC. Creates work items from
 *               voice transcriptions captured via Web Speech API. Supports both
 *               single-item creation from a full transcript and batch creation
 *               when the user splits the transcript into multiple notes.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier, PMD.ExcessiveParameterList, PMD.CyclomaticComplexity')
global with sharing class DeliveryVoiceNotesController {

    private static final Integer BRIEF_DESC_MAX_LENGTH = 100;

    /**
     * @description Wrapper returned after voice note work item creation.
     */
    global class VoiceNoteResult {
        /** @description The Id of the created WorkItem record */
        @AuraEnabled public Id recordId { get; set; }
        /** @description The auto-number Name of the created WorkItem record */
        @AuraEnabled public String recordName { get; set; }
    }

    /**
     * @description Returns Id/Name pairs for all active Network Entities.
     *              Used by Voice Notes LWC for entity name matching in transcripts.
     * @return List of maps with 'id' and 'name' keys.
     */
    @AuraEnabled(cacheable=true)
    global static List<Map<String, String>> getEntityNames() {
        List<Map<String, String>> entities = new List<Map<String, String>>();
        for (NetworkEntity__c ne : [
            SELECT Id, Name FROM NetworkEntity__c
            WHERE StatusPk__c != 'Inactive'
            WITH SYSTEM_MODE
            ORDER BY Name ASC
        ]) {
            Map<String, String> entry = new Map<String, String>();
            entry.put('id', ne.Id);
            entry.put('name', ne.Name);
            entities.add(entry);
        }
        return entities;
    }

    /**
     * @description Creates a single WorkItem__c from a voice transcript.
     * @param transcript     The full voice transcript text.
     * @param briefTitle     Optional short title. If blank, first 100 chars of transcript are used.
     * @param priority       Priority level (High, Medium, Low). Defaults to Medium.
     * @param startDateStr   Optional ISO date string (YYYY-MM-DD) for EstimatedStartDevDate__c.
     * @param entityId       Optional Network Entity Id for client association.
     * @param actionType     Optional action type to set initial stage (e.g., Bug Fix, Meeting).
     * @return VoiceNoteResult containing the created record Id and Name.
     */
    @AuraEnabled
    global static VoiceNoteResult createWorkItemFromVoice(
        String transcript, String briefTitle, String priority, String startDateStr,
        String entityId, String actionType
    ) {
        if (String.isBlank(transcript)) {
            throw new AuraHandledException('Voice transcript is required.');
        }

        try {
            WorkItem__c wi = buildWorkItem(
                String.isNotBlank(briefTitle) ? briefTitle.trim() : transcript.trim(),
                transcript.trim(),
                String.isNotBlank(priority) ? priority : 'Medium',
                parseDateSafe(startDateStr)
            );
            if (String.isNotBlank(entityId)) {
                wi.ClientNetworkEntityLookup__c = entityId;
            }
            if (String.isNotBlank(actionType)) {
                wi.RequestTypePk__c = actionType;
            }

            insert as system wi;

            WorkItem__c created = [
                SELECT Id, Name FROM WorkItem__c WHERE Id = :wi.Id WITH SYSTEM_MODE LIMIT 1
            ];

            VoiceNoteResult result = new VoiceNoteResult();
            result.recordId = created.Id;
            result.recordName = created.Name;
            return result;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Creates multiple WorkItem__c records from a list of voice note segments.
     * @param segments   JSON-serialized list of objects with 'text' and optional 'startDate' keys.
     * @param priority   Priority level applied to all created items.
     * @return List of VoiceNoteResult for each created work item.
     */
    @AuraEnabled
    global static List<VoiceNoteResult> createBatchWorkItems(String segments, String priority) {
        if (String.isBlank(segments)) {
            throw new AuraHandledException('At least one voice segment is required.');
        }

        try {
            List<Object> rawSegments = (List<Object>) JSON.deserializeUntyped(segments);
            String effectivePriority = String.isNotBlank(priority) ? priority : 'Medium';
            List<WorkItem__c> workItems = buildWorkItemsFromSegments(rawSegments, effectivePriority);

            if (workItems.isEmpty()) {
                throw new AuraHandledException('No valid segments found in the voice notes.');
            }

            insert as system workItems;

            return buildResults(workItems);

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    // ── Private helpers ───────────────────────────────────────────────

    private static WorkItem__c buildWorkItem(String title, String fullText, String priority, Date startDate) {
        WorkItem__c wi = new WorkItem__c();
        wi.BriefDescriptionTxt__c = title.length() > BRIEF_DESC_MAX_LENGTH
            ? title.substring(0, BRIEF_DESC_MAX_LENGTH)
            : title;
        wi.DetailsTxt__c = '[Voice Note] ' + fullText;
        wi.PriorityPk__c = priority;
        wi.StageNamePk__c = 'Backlog';
        wi.ActivatedDateTime__c = Datetime.now();
        wi.StatusPk__c = 'New';
        if (startDate != null) {
            wi.EstimatedStartDevDate__c = startDate;
        }
        return wi;
    }

    private static List<WorkItem__c> buildWorkItemsFromSegments(List<Object> rawSegments, String priority) {
        List<WorkItem__c> items = new List<WorkItem__c>();
        for (Object raw : rawSegments) {
            Map<String, Object> seg = (Map<String, Object>) raw;
            String text = (String) seg.get('text');
            if (String.isBlank(text)) {
                continue;
            }
            String segDate = (String) seg.get('startDate');
            items.add(buildWorkItem(text.trim(), text.trim(), priority, parseDateSafe(segDate)));
        }
        return items;
    }

    private static List<VoiceNoteResult> buildResults(List<WorkItem__c> workItems) {
        Set<Id> createdIds = new Set<Id>();
        for (WorkItem__c wi : workItems) {
            createdIds.add(wi.Id);
        }
        Map<Id, WorkItem__c> createdMap = new Map<Id, WorkItem__c>([
            SELECT Id, Name FROM WorkItem__c WHERE Id IN :createdIds WITH SYSTEM_MODE
        ]);
        List<VoiceNoteResult> results = new List<VoiceNoteResult>();
        for (WorkItem__c wi : workItems) {
            VoiceNoteResult r = new VoiceNoteResult();
            r.recordId = wi.Id;
            WorkItem__c queried = createdMap.get(wi.Id);
            r.recordName = queried != null ? queried.Name : '';
            results.add(r);
        }
        return results;
    }

    private static Date parseDateSafe(String dateStr) {
        if (String.isBlank(dateStr)) {
            return null;
        }
        try {
            return Date.valueOf(dateStr);
        } catch (Exception e) {
            return null;
        }
    }
}
