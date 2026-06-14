# Field Tracking (the capture layer)

Delivery Hub ships a **field-change capture engine**: a configurable, tamper-evident
audit trail that records *who changed which field from what to what, and when*, into
`ActivityLog__c`. It is the data foundation for history views, trend analysis, and
(downstream) automated diagnosis.

This doc covers what the engine is, the two toggles that gate it, and — the part that
was previously undiscoverable — **how to point it at an object Delivery Hub does not
own** (one of your own business objects: an Opportunity, a Project, a billing/accounting
transaction, etc.).

## What's built

| Piece | What it does |
|---|---|
| `DeliveryFieldTrackingService` | Trigger-side utility. Reads `TrackedField__mdt`, diffs old vs. new on insert/update/delete, emits change requests. **Called from a trigger on the object.** |
| `DeliveryFieldChangeService` | Persists change requests to `ActivityLog__c` (generic — `RecordIdTxt__c` is plain text, so it logs *any* object). Also exposes the **`Capture Field Change`** invocable for Flows. |
| `TrackedField__mdt` | The allowlist: one record per `(Object API name, Field API name)` you want tracked. Config-as-data — no code to add a field. |
| `ActivityLog__c` | The append-only log, with a hash chain for tamper-evidence. |

Out of the box, `TrackedField__mdt` covers Delivery Hub's own objects (WorkItem, WorkLog,
WorkRequest, NetworkEntity, Document, BountyClaim). The package ships triggers on those
objects that call `DeliveryFieldTrackingService`, which is why they're tracked
automatically.

## The two toggles (both must be ON to capture)

Both live on `DeliveryHubSettings__c` and use the DateTime-stamp pattern (null = off):

- **`EnableFieldTrackingDateTime__c`** — gates the trigger-driven path (the diff logic in
  `DeliveryFieldTrackingService`).
- **`EnableActivityLoggingDateTime__c`** — gates the actual write to `ActivityLog__c`
  (in `DeliveryFieldChangeService.captureFieldChanges`, including the Flow path below).

Both ship **OFF** (safe-by-default). Set them to "now" to enable.

## Tracking one of YOUR business objects (the part you wire)

Delivery Hub cannot ship a trigger on an object it doesn't own — it doesn't know that
object exists at package-build time. So for a non-Delivery-Hub object, you supply the
trigger via a **Record-Triggered Flow** that calls the package's invocable action. Three
steps, no Apex:

1. **Allowlist the fields.** Add a `TrackedField__mdt` record (Custom Metadata) per field
   you care about: set `ObjectApiNameTxt__c` to the object's API name, `FieldApiNameTxt__c`
   to the field, `FieldLabelTxt__c` to a label, and stamp `EnabledDateTime__c`.

2. **Add a Record-Triggered Flow** on that object (after-save, "A record is updated"). In
   the Flow, add an **Apex Action** → **"Capture Field Change"** (category: *Delivery Hub*),
   and map:
   - `Record ID` → `{!$Record.Id}`
   - `Object Name` → the object's API name
   - `Field Name` / `Field Label` → the field you're tracking
   - `Old Value` → `{!$Record__Prior.<Field>}`  ·  `New Value` → `{!$Record.<Field>}`

   Use a decision (`{!$Record.<Field>} != {!$Record__Prior.<Field>}`) so it only logs real
   changes. Repeat the action per field, or build the inputs as a collection.

3. **Confirm both toggles are ON** (above). Edit a record; the change lands in
   `ActivityLog__c`.

> **Why this matters:** the engine has always been able to log any object generically —
> the only thing that gated business-object capture was whether an admin could *reach* the
> `Capture Field Change` action in subscriber Flow Builder. That action is now `global`, so
> it appears in the picker.

## Generic by design

Nothing here names a specific tenant's objects. The allowlist is data you add per org; the
Flow is built per object in the subscriber org. Delivery Hub supplies the engine, the log,
and the action — you point them at whatever business process you want to make visible.
