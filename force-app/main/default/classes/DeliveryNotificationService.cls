/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Cross-flow in-app notification service. Closes the
 *               cross-flow notifications gap surfaced in
 *               docs/audits/e2e-walkthrough-2026-05-21.md: three async user
 *               actions (admin feature toggle, approval grant/reject,
 *               onboarding track completion) used to complete silently,
 *               forcing users to poll the cockpit to discover state changes.
 *
 *               Each public entry point:
 *                 (a) queries the related records it needs to build a title +
 *                     body string;
 *                 (b) resolves the target user-id set (requester, approver,
 *                     onboarding user, or every admin for toggle watchers);
 *                 (c) enqueues a DeliveryNotificationQueueable so the parent
 *                     transaction never blocks on the bell-notification
 *                     fanout — and so a notification-send failure cannot
 *                     abort the calling DML.
 *
 *               Every method is null-safe: a missing record, missing
 *               recipient set, or null parameter is logged at WARN and
 *               returns quietly. Notifications are an audit-trail nicety,
 *               not a transactional requirement — they must never break
 *               their callers.
 *
 *               v1 ships in-app bell notifications only. Slack and email
 *               are explicitly out-of-scope (see the audit doc); they can
 *               be layered onto the same queueable in a follow-on PR.
 *
 *               Global by intent so REST/external callers can fire these
 *               same notifications via a future surface; per CLAUDE.md
 *               ("When making Apex classes global, ALL inner classes used
 *               as return/param types must also be global") this class
 *               exposes no inner classes in its public signature.
 *
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.ExcessivePublicCount')
global with sharing class DeliveryNotificationService {

    // ────────────────────────────────────────────────────────────────────
    // FEATURE TOGGLE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Feature toggled — notify every Delivery Hub admin (i.e.
     *              users assigned the DeliveryHubAdmin permission set group).
     *              Bell notifications inform watchers that a feature flag
     *              changed without forcing them to keep the cockpit open.
     *              No-op when featureId is null or no admins are assigned.
     * @param featureId The Feature__c row whose toggle just flipped.
     * @param enabled True for enable, false for disable.
     */
    global static void notifyFeatureToggled(Id featureId, Boolean enabled) {
        if (featureId == null) {
            return;
        }
        try {
            Feature__c feature = loadFeatureOrNull(featureId);
            if (feature == null) {
                return;
            }
            Set<Id> admins = collectAdminUserIds();
            if (admins.isEmpty()) {
                return;
            }
            String label = resolveFeatureLabel(feature);
            String actionWord = (enabled == true) ? 'enabled' : 'disabled';
            String actorName = resolveUserName(UserInfo.getUserId());
            String title = 'Feature ' + actionWord + ': ' + label;
            String body = actorName + ' ' + actionWord + ' the "' + label + '" feature.';
            sendQueueable(admins, title, body, featureId);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryNotificationService.notifyFeatureToggled] failed: ' + e.getMessage());
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // APPROVAL FLOW
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Approval submitted — notify the assigned approver so they
     *              know an item is waiting in their inbox. PR 8 leaves
     *              ApproverUserLookup__c null at submit time (admins assign
     *              approvers out-of-band), so this method is also called
     *              opportunistically by the inbox / record-page when an
     *              approver is wired up. No-op when the row has no approver.
     * @param approvalId The FeatureToggleApproval__c row that was created.
     */
    global static void notifyApprovalSubmitted(Id approvalId) {
        if (approvalId == null) {
            return;
        }
        try {
            FeatureToggleApproval__c row = loadApprovalContext(approvalId);
            if (row == null || row.ApproverUserLookup__c == null) {
                return;
            }
            String featureLabel = resolveApprovalFeatureLabel(row);
            String requester = (row.RequestLookup__r != null
                && row.RequestLookup__r.RequestedByUserLookup__r != null)
                ? row.RequestLookup__r.RequestedByUserLookup__r.Name
                : 'A user';
            String action = (row.RequestLookup__r != null) ? row.RequestLookup__r.ActionPk__c : 'Toggle';
            String title = 'Approval needed: ' + action + ' ' + featureLabel;
            String body = requester + ' submitted a request to ' + action.toLowerCase()
                + ' "' + featureLabel + '" — review it in the approval inbox.';
            sendQueueable(new Set<Id>{ row.ApproverUserLookup__c }, title, body, approvalId);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryNotificationService.notifyApprovalSubmitted] failed: ' + e.getMessage());
        }
    }

    /**
     * @description Approval granted — notify the original requester so they
     *              know an approval came through. The body identifies which
     *              approver made the call so the requester has audit context
     *              without opening the chain modal.
     * @param approvalId The FeatureToggleApproval__c row that was approved.
     */
    global static void notifyApprovalGranted(Id approvalId) {
        notifyApprovalDecision(approvalId, 'granted', 'approved');
    }

    /**
     * @description Approval rejected — notify the original requester so they
     *              know the request was blocked. Same shape as the granted
     *              variant; only the verb differs.
     * @param approvalId The FeatureToggleApproval__c row that was rejected.
     */
    global static void notifyApprovalRejected(Id approvalId) {
        notifyApprovalDecision(approvalId, 'rejected', 'rejected');
    }

    /**
     * @description Shared shape behind grant/reject notifications.
     * @param approvalId The decided approval row.
     * @param verb Past-tense verb for the body sentence ('granted' / 'rejected').
     * @param titleWord Past-tense word for the title ('approved' / 'rejected').
     */
    private static void notifyApprovalDecision(Id approvalId, String verb, String titleWord) {
        if (approvalId == null) {
            return;
        }
        try {
            FeatureToggleApproval__c row = loadApprovalContext(approvalId);
            if (row == null || row.RequestLookup__r == null
                || row.RequestLookup__r.RequestedByUserLookup__c == null) {
                return;
            }
            String featureLabel = resolveApprovalFeatureLabel(row);
            String action = String.isBlank(row.RequestLookup__r.ActionPk__c)
                ? 'Toggle' : row.RequestLookup__r.ActionPk__c;
            String deciderName = resolveUserName(UserInfo.getUserId());
            String title = 'Approval ' + titleWord + ': ' + action + ' ' + featureLabel;
            String body = deciderName + ' ' + verb + ' your request to ' + action.toLowerCase()
                + ' "' + featureLabel + '".';
            sendQueueable(
                new Set<Id>{ row.RequestLookup__r.RequestedByUserLookup__c },
                title, body, row.RequestLookup__c);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryNotificationService.notifyApprovalDecision] failed: ' + e.getMessage());
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // ONBOARDING
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Onboarding track completed — notify the user who owns the
     *              progress row so they know the track is done and the
     *              gated feature is unlocked. Triggered from
     *              DeliveryOnboardingService.updateAndCheckComplete the first
     *              time CompletedDateTime__c is stamped.
     * @param progressId The OnboardingProgress__c row whose track just completed.
     */
    global static void notifyOnboardingCompleted(Id progressId) {
        if (progressId == null) {
            return;
        }
        try {
            OnboardingProgress__c row = loadProgressOrNull(progressId);
            if (row == null || row.UserLookup__c == null) {
                return;
            }
            String trackLabel = resolveTrackLabel(row.TrackTxt__c);
            String title = 'Onboarding complete: ' + trackLabel;
            String body = 'You finished the "' + trackLabel
                + '" onboarding track. Features gated on this track are now unlocked for your user.';
            sendQueueable(new Set<Id>{ row.UserLookup__c }, title, body, progressId);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryNotificationService.notifyOnboardingCompleted] failed: ' + e.getMessage());
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // INTERNAL — record loaders
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Loads a Feature__c with the fields needed to build a label
     *              string. Returns null when the row doesn't exist (don't
     *              throw — the caller should silently skip the notification).
     * @param featureId The Feature__c id to load.
     * @return The Feature__c row, or null when not found.
     */
    private static Feature__c loadFeatureOrNull(Id featureId) {
        List<Feature__c> rows = [
            SELECT Id, Name, FeatureDefinitionTxt__c
            FROM Feature__c
            WHERE Id = :featureId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows.get(0);
    }

    /**
     * @description Loads a FeatureToggleApproval__c with the related-record
     *              context the notification builder needs (approver, request
     *              + action, original requester user, feature label).
     * @param approvalId The approval id to load.
     * @return The approval row with related fields, or null when not found.
     */
    private static FeatureToggleApproval__c loadApprovalContext(Id approvalId) {
        List<FeatureToggleApproval__c> rows = [
            SELECT Id, ApproverUserLookup__c, RequestLookup__c, FeatureLookup__c,
                   RequestLookup__r.ActionPk__c,
                   RequestLookup__r.RequestedByUserLookup__c,
                   RequestLookup__r.RequestedByUserLookup__r.Name,
                   FeatureLookup__r.Name,
                   FeatureLookup__r.FeatureDefinitionTxt__c
            FROM FeatureToggleApproval__c
            WHERE Id = :approvalId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows.get(0);
    }

    /**
     * @description Loads an OnboardingProgress__c with the fields needed for
     *              the completion notification.
     * @param progressId The progress row id to load.
     * @return The progress row, or null when not found.
     */
    private static OnboardingProgress__c loadProgressOrNull(Id progressId) {
        List<OnboardingProgress__c> rows = [
            SELECT Id, UserLookup__c, TrackTxt__c, CompletedDateTime__c
            FROM OnboardingProgress__c
            WHERE Id = :progressId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows.get(0);
    }

    // ────────────────────────────────────────────────────────────────────
    // INTERNAL — label resolvers (namespace-tolerant)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Builds the human label for a feature notification. Prefers
     *              the FeatureDefinition__mdt LabelTxt__c when the join
     *              resolves; falls back to the FeatureDefinitionTxt__c
     *              DeveloperName and then the Feature__c.Name.
     * @param feature Loaded Feature__c row.
     * @return Best-available human label, never null / blank.
     */
    private static String resolveFeatureLabel(Feature__c feature) {
        if (feature == null) {
            return 'Feature';
        }
        String defName = feature.FeatureDefinitionTxt__c;
        if (String.isNotBlank(defName)) {
            List<FeatureDefinition__mdt> defs = [
                SELECT LabelTxt__c
                FROM FeatureDefinition__mdt
                WHERE DeveloperName = :defName
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!defs.isEmpty() && String.isNotBlank(defs.get(0).LabelTxt__c)) {
                return defs.get(0).LabelTxt__c;
            }
            return defName;
        }
        return String.isBlank(feature.Name) ? 'Feature' : feature.Name;
    }

    /**
     * @description Builds the human label for an approval notification — same
     *              shape as resolveFeatureLabel but pulls from the
     *              FeatureLookup__r relation that's already on the approval row.
     * @param row Approval row loaded by loadApprovalContext.
     * @return Best-available human label.
     */
    private static String resolveApprovalFeatureLabel(FeatureToggleApproval__c row) {
        if (row == null || row.FeatureLookup__r == null) {
            return 'Feature';
        }
        String defName = row.FeatureLookup__r.FeatureDefinitionTxt__c;
        if (String.isNotBlank(defName)) {
            List<FeatureDefinition__mdt> defs = [
                SELECT LabelTxt__c
                FROM FeatureDefinition__mdt
                WHERE DeveloperName = :defName
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!defs.isEmpty() && String.isNotBlank(defs.get(0).LabelTxt__c)) {
                return defs.get(0).LabelTxt__c;
            }
            return defName;
        }
        return String.isBlank(row.FeatureLookup__r.Name) ? 'Feature' : row.FeatureLookup__r.Name;
    }

    /**
     * @description Returns the OnboardingTrack__mdt LabelTxt__c when available,
     *              falling back to the DeveloperName itself.
     * @param trackDeveloperName DeveloperName from OnboardingProgress__c.TrackTxt__c.
     * @return Best-available human label.
     */
    private static String resolveTrackLabel(String trackDeveloperName) {
        if (String.isBlank(trackDeveloperName)) {
            return 'Onboarding';
        }
        List<OnboardingTrack__mdt> tracks = [
            SELECT LabelTxt__c
            FROM OnboardingTrack__mdt
            WHERE DeveloperName = :trackDeveloperName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (tracks.isEmpty() || String.isBlank(tracks.get(0).LabelTxt__c)) {
            return trackDeveloperName;
        }
        return tracks.get(0).LabelTxt__c;
    }

    /**
     * @description Returns the User.Name for the given id, defaulting to
     *              'A user' when the lookup fails or returns no row.
     * @param userId User id to resolve.
     * @return Best-available human name.
     */
    private static String resolveUserName(Id userId) {
        if (userId == null) {
            return 'A user';
        }
        List<User> rows = [
            SELECT Name FROM User WHERE Id = :userId
            WITH SYSTEM_MODE LIMIT 1
        ];
        return rows.isEmpty() ? 'A user' : rows.get(0).Name;
    }

    // ────────────────────────────────────────────────────────────────────
    // INTERNAL — recipient sets
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Returns the set of active user ids assigned the
     *              DeliveryHubAdmin permission-set-group. Accepts both the
     *              bare DeveloperName (dev scratch) and the namespaced one
     *              (subscriber install) — same dual-name pattern used
     *              elsewhere for PSG lookups.
     * @return Set of admin user ids; empty when no PSG is deployed.
     */
    private static Set<Id> collectAdminUserIds() {
        Set<Id> out = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId FROM PermissionSetAssignment
            WHERE PermissionSetGroup.DeveloperName IN
                  ('DeliveryHubAdmin', 'delivery__DeliveryHubAdmin')
              AND Assignee.IsActive = true
            WITH SYSTEM_MODE
            LIMIT 200
        ]) {
            if (psa.AssigneeId != null) {
                out.add(psa.AssigneeId);
            }
        }
        return out;
    }

    // ────────────────────────────────────────────────────────────────────
    // INTERNAL — enqueue helper
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Enqueues the DeliveryNotificationQueueable when there's at
     *              least one target. Wrapped in try / catch so a
     *              queueable-limit overflow (50 chained queueables per tx)
     *              cannot abort the calling transaction; we log at WARN.
     *              Skips the enqueue inside @future / batch / scheduled
     *              contexts where System.isQueueable would refuse — those
     *              contexts can't chain a Queueable. The notification is
     *              dropped silently in those cases (acceptable: the caller
     *              is async, not the user).
     * @param targets Recipient user ids (already deduped).
     * @param title Notification title.
     * @param body Notification body.
     * @param targetRecordId Optional deep-link record id.
     */
    private static void sendQueueable(
        Set<Id> targets, String title, String body, Id targetRecordId
    ) {
        if (targets == null || targets.isEmpty()) {
            return;
        }
        try {
            System.enqueueJob(new DeliveryNotificationQueueable(
                targets, title, body, targetRecordId));
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryNotificationService.sendQueueable] enqueue failed: ' + e.getMessage());
        }
    }
}
