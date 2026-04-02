/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the Voice Notes LWC. Creates work items from
 *               voice transcriptions captured via Web Speech API. Supports both
 *               single-item creation from a full transcript and batch creation
 *               when the user splits the transcript into multiple notes.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
global with sharing class DeliveryVoiceNotesController {

    private static final Integer BRIEF_DESC_MAX_LENGTH = 100;

    /**
     * @description Wrapper returned after voice note work item creation.
     */
    global class VoiceNoteResult {
        /** @description The Id of the created WorkItem__c record */
        @AuraEnabled public Id recordId { get; set; }
        /** @description The auto-number Name of the created WorkItem__c record */
        @AuraEnabled public String recordName { get; set; }
    }

    /**
     * @description Creates a single WorkItem__c from a voice transcript.
     * @param transcript     The full voice transcript text.
     * @param briefTitle     Optional short title. If blank, first 100 chars of transcript are used.
     * @param priority       Priority level (High, Medium, Low). Defaults to Medium.
     * @param startDateStr   Optional ISO date string (YYYY-MM-DD) for EstimatedStartDevDate__c.
     * @return VoiceNoteResult containing the created record Id and Name.
     */
    @AuraEnabled
    global static VoiceNoteResult createWorkItemFromVoice(
        String transcript, String briefTitle, String priority, String startDateStr
    ) {
        if (String.isBlank(transcript)) {
            throw new AuraHandledException('Voice transcript is required.');
        }

        try {
            WorkItem__c wi = new WorkItem__c();

            // Brief description: use provided title or derive from transcript
            String brief = String.isNotBlank(briefTitle)
                ? briefTitle.trim()
                : transcript.trim();
            wi.BriefDescriptionTxt__c = brief.length() > BRIEF_DESC_MAX_LENGTH
                ? brief.substring(0, BRIEF_DESC_MAX_LENGTH)
                : brief;

            // Full transcript goes into Details
            wi.DetailsTxt__c = '[Voice Note] ' + transcript.trim();
            wi.PriorityPk__c = String.isNotBlank(priority) ? priority : 'Medium';
            wi.StageNamePk__c = 'Backlog';
            wi.ActivatedDateTime__c = Datetime.now();
            wi.StatusPk__c = 'New';

            // Parse optional start date
            if (String.isNotBlank(startDateStr)) {
                try {
                    wi.EstimatedStartDevDate__c = Date.valueOf(startDateStr);
                } catch (Exception dateEx) {
                    // Invalid date format — skip silently, don't block creation
                }
            }

            insert as system wi;

            // Re-query to get auto-number Name
            WorkItem__c created = [
                SELECT Id, Name
                FROM WorkItem__c
                WHERE Id = :wi.Id
                WITH SYSTEM_MODE
                LIMIT 1
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
     *              Each segment becomes its own work item. Useful when a user dictates
     *              multiple action items in a single session.
     * @param segments   JSON-serialized list of VoiceSegment objects.
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
            List<WorkItem__c> workItems = new List<WorkItem__c>();
            String effectivePriority = String.isNotBlank(priority) ? priority : 'Medium';

            for (Object raw : rawSegments) {
                Map<String, Object> seg = (Map<String, Object>) raw;
                String text = (String) seg.get('text');
                if (String.isBlank(text)) {
                    continue;
                }

                WorkItem__c wi = new WorkItem__c();
                String trimmed = text.trim();
                wi.BriefDescriptionTxt__c = trimmed.length() > BRIEF_DESC_MAX_LENGTH
                    ? trimmed.substring(0, BRIEF_DESC_MAX_LENGTH)
                    : trimmed;
                wi.DetailsTxt__c = '[Voice Note] ' + trimmed;
                wi.PriorityPk__c = effectivePriority;
                wi.StageNamePk__c = 'Backlog';
                wi.ActivatedDateTime__c = Datetime.now();
                wi.StatusPk__c = 'New';

                // Parse optional date from segment
                String segDate = (String) seg.get('startDate');
                if (String.isNotBlank(segDate)) {
                    try {
                        wi.EstimatedStartDevDate__c = Date.valueOf(segDate);
                    } catch (Exception dateEx) {
                        // skip
                    }
                }

                workItems.add(wi);
            }

            if (workItems.isEmpty()) {
                throw new AuraHandledException('No valid segments found in the voice notes.');
            }

            insert as system workItems;

            // Collect Ids for re-query
            Set<Id> createdIds = new Set<Id>();
            for (WorkItem__c wi : workItems) {
                createdIds.add(wi.Id);
            }

            Map<Id, WorkItem__c> createdMap = new Map<Id, WorkItem__c>([
                SELECT Id, Name
                FROM WorkItem__c
                WHERE Id IN :createdIds
                WITH SYSTEM_MODE
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

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }
}
