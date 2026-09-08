# Approval queue: make it usable on a client standup (8 Sep 2026)

> **For the Delivery Hub session:** this is a self-contained handoff. Current state, the fix, and what to do, with the
> file pointers. REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Additive to
> `dh-intake-slack-alerts-0805.md` (intake alerts), which stays the plan of record for its own scope. Cut nothing
> without Glen's "cut it".

## Why this exists

On the 8 Sep MF check-in the client PM (Jose) opened the Delivery Hub approval queue wanting to approve work live, so
that "both MF and you are clear on what's approved". What he saw:

- Eleven requests at `Offer Sent`, all Phase 1 cash flow estimates quoted in July, none of which will start. No way to
  tell they were stale, no link to the scope behind any of them.
- None of the work that IS sized and waiting for his yes (six items) had been submitted, so nothing he actually needed
  to decide had a button.
- The stage those items park in is named `Ready for Final Approval`. The vendor (Glen) read it as closeout on the
  call. It is the opposite: it means "awaiting the client's approval to start".

The data hygiene half (stand down the stale offers, submit the sized items) is being done by hand in MF-Prod this
week and is NOT this plan. This plan is the product half: three changes so the queue reads correctly on a call.

## Current state, read from the source (main, 8 Sep)

**State machine (fine, do not touch).** `DeliveryWorkApprovalService.cls` (global with sharing):
- `proposeEstimate(workItemId, hours, reasoning)` -> writes `QuotedHoursNumber__c` and a `PROPOSAL_NOTE_PREFIX`
  ("Estimate proposal: ") `WorkItemComment__c`.
- `submitForApproval(Set<Id>)` -> request `Draft` -> `Offer Sent`; WorkItem `StageNamePk__c` -> `Ready for Final Approval`
  (`STAGE_READY_FOR_FINAL_APPROVAL`, line ~110).
- `approve(requestId, approvedHours, note)` -> request `Accepted`, `DecisionDateTime__c`, `ApproverUserLookup__c`,
  WorkItem `ClientPreApprovedHoursNumber__c` set, stage -> `Ready for Development` (`STAGE_READY_FOR_DEVELOPMENT`).
- `decline(requestId, reason)` -> request `Inactive` + `StandDownReasonTxt__c`. `approveMany(List<Id>, note)` exists;
  there is no `declineMany`.
- `getPendingForApprover(userId)` -> `List<PendingApprovalDTO>` from `WorkRequest__c WHERE StatusPk__c = 'Offer Sent'
  ORDER BY CreatedDate ASC` (~line 674), then `applyLatestProposalNotes(rows)`.

**The DTO the queue card renders** (`PendingApprovalDTO`, lines ~145-166): requestId, workItemId, workItemName,
workItemLabel, quotedHours, requestedIncrease, requestStatus, submittedAt, approverUserId, parentWorkItemId,
parentLabel, latestProposalNote. No scope link, no age, no range.

**Where the stage name is used** (all must change together if the label changes):
- `objects/WorkItem__c/fields/StageNamePk__c.field-meta.xml` (picklist value + label)
- `classes/DeliveryWorkApprovalService.cls`, `DeliveryHubDashboardController.cls`, `DeliveryApprovalSummaryControllerTest.cls`,
  `DeliveryWorkApprovalServiceTest.cls`
- `lwc/deliveryProFormaTimeline/deliveryProFormaTimeline.js`
- `objects/WorkItem__c/listViews/WorkItems_Approval.listView-meta.xml`, `reports/DeliveryHubPipeline/WorkItems_Approval.report-meta.xml`
- Board columns: `lwc/deliveryHubBoard` reads `StageNamePk__c`; check how column headers are labelled (picklist label vs
  hard-coded map) before assuming the rename is free.

**Existing URL fields on WorkItem__c:** `ExternalPageUrl__c`, `PRUrl__c`, `RepoUrl__c`. No scope/proposal URL field.

**LWC:** `lwc/deliveryApprovalQueue/` (html, js, css, `__tests__/`). Imports `getPendingForApprover`, `approve`,
`approveMany`, `decline`, `getHiddenHomeComponents`. Card shows label, quotedHours, submittedAt, latestProposalNote.

**Global constraints carried over from the 0805 plan:** namespace `delivery`; typed describes, never
`Schema.getGlobalDescribe()`; `WITH SYSTEM_MODE` in test-reachable SOQL; prefer no new Apex classes (put logic in the
existing service; tests in the existing `*Test.cls`) to avoid the `ApexTestSuite` registration gap that breaks
`beta_create`; feature flags are DateTime stamps, never Booleans.

## The fix: three changes, in this order, each its own PR and package release

### Change 1: the stage says what it means
- **API name stays** `Ready for Final Approval` (renaming the value would break every subscriber org's data). Change the
  picklist **label** to `Awaiting Client Approval` in `StageNamePk__c.field-meta.xml`.
- Grep every place above that renders the stage to a human and make sure it uses the label, not the API name. The
  board column header and the pro forma timeline are the two most likely to hard-code text.
- Slack stage-change message (`DeliverySlackService`): confirm it uses the label.
- Tests: existing tests compare on the API value; they should not need to change. Add one assertion that the label
  resolves via `Schema.PicklistEntry.getLabel()` for that value.
- **Done when:** the queue, the board column, the timeline and the Slack message all read "Awaiting Client Approval"
  and no test compares against the label string.

### Change 2: the approval card carries the scope and the range
- **New field** `WorkItem__c.ScopeUrl__c` (Url, label "Scope write-up"). Do not overload `ExternalPageUrl__c`; its
  meaning is the client-facing page for the item itself, which may be different. Add to the permission sets that carry
  `PRUrl__c` (same FLS pattern) and to the WorkItem page layout next to `PRUrl__c`.
- **DTO:** add `@AuraEnabled public String scopeUrl;` to `PendingApprovalDTO`; populate in `getPendingForApprover` from
  `WorkItemId__r.ScopeUrl__c`. Keep the DTO global-compatible (adding a field is additive).
- **Card:** in `deliveryApprovalQueue.html`, render a "Read the write-up" link when `scopeUrl` is set (opens new tab),
  and render `latestProposalNote` inline under the hours by default rather than behind a click. The note is where the
  range lives ("30 to 60 hours; quoted at 60").
- **`deliveryManageRequest` / `deliveryQuickRequest`:** expose `ScopeUrl__c` so the vendor can set it when quoting.
- Tests: `DeliveryWorkApprovalServiceTest` gets one case asserting `scopeUrl` round-trips; the LWC jest test
  `__tests__` gets a render case with and without the link.
- **Done when:** a request submitted with a ScopeUrl shows the link and the note on the card without a click.

### Change 3: stale offers are visible and clearable
- **Age badge:** in the LWC, compute days since `submittedAt`; show a small badge when older than a threshold. Threshold
  from a Custom Setting field `DeliveryHubSettings__c.StaleOfferDays__c` (Number, default 21 when blank). Colour only,
  no behaviour change, no auto-expiry.
- **Bulk stand-down:** add `global static BulkDeclineResultDTO declineMany(List<Id> workRequestIds, String reason)` to
  `DeliveryWorkApprovalService`, mirroring `approveMany` (same result shape: `declinedIds` + `failures`). One reason
  applied to all; each request goes `Inactive` with `StandDownReasonTxt__c`; the WorkItem stage is left alone (the
  hygiene of where a stood-down card sits is the vendor's call on the board, not the queue's).
- **Queue UI:** vendor-side only (the client must not see a stand-down button): a checkbox selection + "Stand down
  selected" action that calls `declineMany`, visible when the running user is not the approver. Reuse the existing
  `approveMany` selection UI if it has one.
- Tests: `declineMany` happy path + one failure in the list; LWC render of the badge at threshold +1 and threshold -1.
- **Done when:** eleven stale offers can be cleared in one action with one reason, and a 30-day-old offer shows a badge.

## Not in scope
- Auto-expiring offers. A stale offer is the vendor's to clean up, never a decision made for the client.
- Any change to `approve` / `ClientPreApprovedHoursNumber__c` as the budget of record.
- The MF-Prod data moves (stand down the eleven July cash flow offers, submit the six sized items). Those run by hand
  from the MF workspace on Glen's go, tracked in `Mobilization-Funding-Claude/handoffs/dh-approval-queue-0908.md`.

## Sequence and gates
Change 1 -> PR -> beta -> Glen's "cut it" -> install to dh-prod then MF-Prod (each subscriber gets it on its next
install). Then Change 2, then Change 3. No prod-deploying CI run without Glen's go; reruns count. Each PR body says
which of the three it is and what "done when" it meets.
