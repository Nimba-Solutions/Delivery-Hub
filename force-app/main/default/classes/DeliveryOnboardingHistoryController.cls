/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read-only org-wide audit-trail viewer for
 *               OnboardingProgress__c rows. Surfaces all users + all tracks
 *               so an admin can see who has completed which onboarding
 *               track, who is in flight, and who has yet to start. Status
 *               is derived from the CompletedDateTime__c / StartedDateTime__c
 *               pair:
 *                  - CompletedDateTime__c populated -> 'Completed'
 *                  - StartedDateTime__c populated only -> 'In Progress'
 *                  - neither populated -> 'Not Started'
 *
 *               Companion to deliveryFeatureOnboarding (the per-user
 *               learner UI). Closes the cross-flow audit-trail gap from
 *               docs/audits/e2e-walkthrough-2026-05-21.md.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryOnboardingHistoryController {

    private static final Integer DEFAULT_LIMIT = 50;
    private static final Integer MAX_LIMIT = 200;

    /**
     * @description Flat row shape for lightning-datatable. UserName +
     *              status are pre-resolved so the LWC never has to do
     *              follow-up wires.
     */
    public class OnboardingRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String userName;
        @AuraEnabled public Id userId;
        @AuraEnabled public String track;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime startedDateTime;
        @AuraEnabled public Datetime completedDateTime;
        @AuraEnabled public Decimal quizAttempts;
        @AuraEnabled public Decimal quizScore;
        @AuraEnabled public Datetime quizLastAttemptDateTime;
    }

    /**
     * @description Returns the most recent OnboardingProgress__c rows,
     *              optionally filtered by a single user Id. Bounded by
     *              recordLimit (1..200, default 50).
     *
     *              Uses WITH SYSTEM_MODE — the viewer is admin-only via
     *              the DeliveryHubAdmin_App permset's modifyAllRecords
     *              grant on OnboardingProgress__c.
     * @param  recordLimit Max rows to return. Null / <1 falls back to 50.
     *                     Capped at 200.
     * @param  contextId   Optional user Id used to filter on
     *                     UserLookup__c. When null, the viewer shows
     *                     org-wide onboarding state.
     * @return List<OnboardingRow> ordered by CompletedDateTime__c DESC NULLS LAST,
     *         then StartedDateTime__c DESC.
     */
    @AuraEnabled(cacheable=true)
    public static List<OnboardingRow> recent(Integer recordLimit, Id contextId) {
        Integer bound = resolveLimit(recordLimit);

        List<OnboardingProgress__c> rows;
        if (contextId == null) {
            rows = [
                SELECT Id, Name, UserLookup__c, UserLookup__r.Name,
                       TrackTxt__c, StartedDateTime__c, CompletedDateTime__c,
                       QuizAttemptsNumber__c, QuizScoreNumber__c,
                       QuizLastAttemptDateTime__c
                FROM OnboardingProgress__c
                WITH SYSTEM_MODE
                ORDER BY CompletedDateTime__c DESC NULLS LAST, StartedDateTime__c DESC NULLS LAST
                LIMIT :bound
            ];
        } else {
            rows = [
                SELECT Id, Name, UserLookup__c, UserLookup__r.Name,
                       TrackTxt__c, StartedDateTime__c, CompletedDateTime__c,
                       QuizAttemptsNumber__c, QuizScoreNumber__c,
                       QuizLastAttemptDateTime__c
                FROM OnboardingProgress__c
                WHERE UserLookup__c = :contextId
                WITH SYSTEM_MODE
                ORDER BY CompletedDateTime__c DESC NULLS LAST, StartedDateTime__c DESC NULLS LAST
                LIMIT :bound
            ];
        }

        List<OnboardingRow> out = new List<OnboardingRow>();
        for (OnboardingProgress__c o : rows) {
            OnboardingRow r = new OnboardingRow();
            r.id = o.Id;
            r.name = o.Name;
            r.userId = o.UserLookup__c;
            r.userName = (o.UserLookup__r != null) ? o.UserLookup__r.Name : '';
            r.track = o.TrackTxt__c;
            r.startedDateTime = o.StartedDateTime__c;
            r.completedDateTime = o.CompletedDateTime__c;
            r.quizAttempts = o.QuizAttemptsNumber__c;
            r.quizScore = o.QuizScoreNumber__c;
            r.quizLastAttemptDateTime = o.QuizLastAttemptDateTime__c;
            r.status = deriveStatus(o);
            out.add(r);
        }
        return out;
    }

    private static String deriveStatus(OnboardingProgress__c o) {
        if (o.CompletedDateTime__c != null) {
            return 'Completed';
        }
        if (o.StartedDateTime__c != null) {
            return 'In Progress';
        }
        return 'Not Started';
    }

    private static Integer resolveLimit(Integer requested) {
        if (requested == null || requested < 1) {
            return DEFAULT_LIMIT;
        }
        return requested > MAX_LIMIT ? MAX_LIMIT : requested;
    }
}
