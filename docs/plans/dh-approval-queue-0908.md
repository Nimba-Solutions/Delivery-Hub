# Approval queue: three product changes surfaced by the 8 Sep MF check-in

> Additive to `dh-intake-slack-alerts-0805.md` (still the plan of record for intake alerts). This note records what the
> client-side approval flow needs so a client PM can approve work on a standup call from the queue alone. No code yet.

**Trigger.** Jose (MF) opened the queue on the 8 Sep call wanting to approve work live. What he saw was eleven
July estimates for cash flow work nobody intends to start, with no way to tell they were stale, no link to the scope
behind any of them, and a stage name ("Ready for Final Approval") that the vendor himself read as closeout.

## Change 1: name the stage for what it is
`Ready for Final Approval` is the stage `submitForApproval` parks a WorkItem in while the client decides. Rename the
label to **Awaiting Client Approval** (API name can stay). Anywhere the queue or the board shows the stage, the client
should read "your decision", not "almost done". Check the Kanban column header, the approval card, the Slack stage-change
message, and the closeout queue's exclusion list.

## Change 2: the approval card carries the scope
`PendingApprovalDTO` today: label, quoted hours, requested increase, submitted date, latest proposal note. Add:
- **Scope link.** Either repurpose `WorkProofUrl__c` (misnamed for this) or add `ScopeUrlTxt__c` on WorkItem, shown
  as a "Read the write-up" link on the card. The vendor's proposal pages already exist; the card is where they are needed.
- **Range, not a point.** Proposal notes carry "30 to 60"; the card shows only the quoted 60. Show the note text under
  the hours by default rather than behind a click.

## Change 3: stale offers
- **Age badge** on the card when `submittedAt` is older than N days (default 21). Colour only.
- **Stand down from the queue** as a bulk action for the vendor (Inactive with a reason), mirroring `approveMany`.
  Today clearing eleven stale offers means eleven `decline` calls or a script.

## Non-changes
- The Draft -> Offer Sent -> Accepted / Inactive loop, `ClientPreApprovedHoursNumber__c` as the budget of record, and
  the auto-created WorkRequest all work as designed. The gap is presentation and hygiene, not the state machine.
- Do not auto-expire offers. A stale offer is a vendor problem to clean up, not a client decision to be made for them.

## Sequence
Change 1 first (label only, no data). Change 2 next (one field + DTO + card). Change 3 last. Each ships as its own
package release; none touches MF business objects. Cut nothing without Glen's "cut it".
