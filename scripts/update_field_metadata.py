#!/usr/bin/env python3
"""
Populates missing <description> and <inlineHelpText> tags in Salesforce field metadata XML files.
Inserts them in the canonical order: fullName -> description -> inlineHelpText -> label -> ...
"""

import os
import re

BASE = "force-app/main/default/objects"

# Dictionary: "Object/FieldName" -> {"description": "...", "inlineHelpText": "..."}
# Only entries for fields that are missing one or both tags.
FIELD_META = {
    # ── Cloud_Nimbus_LLC_Marketing__mdt ──────────────────────────────────────
    "Cloud_Nimbus_LLC_Marketing__mdt/CloudNimbusLlcEndpointTxt__c": {
        "inlineHelpText": "Base URL for the Cloud Nimbus LLC integration endpoint.",
    },
    "Cloud_Nimbus_LLC_Marketing__mdt/EnabledBool__c": {
        "inlineHelpText": "Enable or disable this Cloud Nimbus LLC marketing integration.",
    },

    # ── Delivery_Hub_Settings__c ─────────────────────────────────────────────
    "Delivery_Hub_Settings__c/AutoCreateRequestFromTicketBool__c": {
        "inlineHelpText": "When enabled, a delivery Request is automatically created whenever a new Ticket is saved.",
    },
    "Delivery_Hub_Settings__c/AutoSyncNetworkEntityBool__c": {
        "inlineHelpText": "When enabled, Network Entity records are kept in sync with their remote counterparts automatically.",
    },
    "Delivery_Hub_Settings__c/EnableNotificationsBool__c": {
        "inlineHelpText": "Enable in-app and email notifications for ticket status changes and comments.",
    },
    "Delivery_Hub_Settings__c/OpenAIApiKeyTxt__c": {
        "inlineHelpText": "Your OpenAI secret API key. Required for AI estimation and description generation features.",
    },
    "Delivery_Hub_Settings__c/OpenAiApiTestedBool__c": {
        "inlineHelpText": "Read-only flag set to true once the OpenAI API key has been successfully validated.",
    },
    "Delivery_Hub_Settings__c/StagesToAutoShareWithDevTeamTxt__c": {
        "inlineHelpText": "Comma-separated list of stage names. Tickets entering these stages are automatically shared with the development team.",
    },

    # ── Kanban_Configuration__mdt ────────────────────────────────────────────
    "Kanban_Configuration__mdt/ActiveDevelopmentStagesTxt__c": {
        "inlineHelpText": "Comma-separated stage names counted as active development (affects capacity and ETA calculations).",
    },
    "Kanban_Configuration__mdt/BlockedStagesTxt__c": {
        "inlineHelpText": "Comma-separated stage names treated as blocked (highlighted on the board and excluded from ETA).",
    },
    "Kanban_Configuration__mdt/DefaultDevCountNumber__c": {
        "inlineHelpText": "Default number of developers used when no team-specific count is configured.",
    },
    "Kanban_Configuration__mdt/PostDevelopmentStagesTxt__c": {
        "inlineHelpText": "Comma-separated stage names that follow active development (QA, UAT, deployment stages).",
    },
    "Kanban_Configuration__mdt/PreDevelopmentStagesTxt__c": {
        "inlineHelpText": "Comma-separated stage names that precede active development (backlog, scoping, sizing stages).",
    },
    "Kanban_Configuration__mdt/PriorityWeightsTxt__c": {
        "inlineHelpText": "JSON map of priority label to numeric weight used in ETA scheduling calculations.",
    },
    "Kanban_Configuration__mdt/UATBufferDaysNumber__c": {
        "inlineHelpText": "Number of buffer days added to ETA calculations to account for UAT review time.",
    },

    # ── Kanban_Stage_Field_Requirement__mdt ──────────────────────────────────
    "Kanban_Stage_Field_Requirement__mdt/DescriptionTxt__c": {
        "inlineHelpText": "Human-readable description of why these fields are required at this stage.",
    },
    "Kanban_Stage_Field_Requirement__mdt/IsActiveBool__c": {
        "inlineHelpText": "Uncheck to disable this requirement without deleting the record.",
    },
    "Kanban_Stage_Field_Requirement__mdt/RequiredFieldsTxt__c": {
        "inlineHelpText": "Comma-separated API field names that must be populated before a ticket can enter the target stage.",
    },
    "Kanban_Stage_Field_Requirement__mdt/TargetStageTxt__c": {
        "inlineHelpText": "The exact stage name (matches StageNamePk__c picklist value) this requirement applies to.",
    },

    # ── Network_Entity__c ────────────────────────────────────────────────────
    "Network_Entity__c/DefaultHourlyRateCurrency__c": {
        "inlineHelpText": "Default billing rate applied to this entity's work logs when no override is specified on a request.",
    },
    "Network_Entity__c/EntityTypePk__c": {
        "inlineHelpText": "Select Client, Vendor, or Both to define this entity's role in the delivery network.",
    },
    "Network_Entity__c/GithubUsernameTxt__c": {
        "inlineHelpText": "GitHub username for this entity, used to link commits and PRs to tickets.",
    },
    "Network_Entity__c/IntegrationEndpointUrlTxt__c": {
        "inlineHelpText": "Base URL of this entity's Salesforce org used for cross-org sync API calls.",
    },
    "Network_Entity__c/StatusPk__c": {
        "inlineHelpText": "Active entities participate in sync and routing. Inactive entities are excluded from all automated processes.",
    },

    # ── OpenAI_Configuration__mdt ────────────────────────────────────────────
    "OpenAI_Configuration__mdt/API_Key__c": {
        "inlineHelpText": "OpenAI API key stored in custom metadata. Used by AI estimation and description features.",
    },

    # ── Request__c ───────────────────────────────────────────────────────────
    "Request__c/BudgetUtilizationPercent__c": {
        "inlineHelpText": "Auto-calculated: (Total Logged Hours / Pre-Approved Hours) × 100. Alerts when nearing 100%.",
    },
    "Request__c/DeliveryEntityId__c": {
        "inlineHelpText": "Lookup to the Network Entity (vendor/delivery partner) assigned to fulfil this request.",
    },
    "Request__c/HourlyRateCurrency__c": {
        "inlineHelpText": "Agreed hourly rate for this request. Overrides the entity's default rate if set.",
    },
    "Request__c/PreApprovedHoursNumber__c": {
        "inlineHelpText": "Maximum hours authorised by the client. Work beyond this threshold requires a budget increase request.",
    },
    "Request__c/ProjectedCostCurrency__c": {
        "inlineHelpText": "Auto-calculated: Quoted Hours × Hourly Rate. Shows expected cost before work begins.",
    },
    "Request__c/QuotedHoursNumber__c": {
        "inlineHelpText": "Hours quoted by the vendor in their proposal for this request.",
    },
    "Request__c/RemoteTicketIdTxt__c": {
        "inlineHelpText": "ID of the corresponding ticket in the vendor's remote Salesforce org, used for cross-org sync.",
    },
    "Request__c/RequestedBudgetIncreaseNumber__c": {
        "inlineHelpText": "Additional hours requested by the vendor when the original pre-approved budget is insufficient.",
    },
    "Request__c/StandDownReasonTxt__c": {
        "inlineHelpText": "Reason provided when the request is paused or cancelled. Required when status is set to Inactive.",
    },
    "Request__c/StatusPk__c": {
        "inlineHelpText": "Tracks the request lifecycle: Draft → Open for Bids → Offer Sent → Accepted → In Progress → Completed.",
    },
    "Request__c/TicketId__c": {
        "inlineHelpText": "The parent Ticket that originated this delivery request.",
    },
    "Request__c/TotalLoggedHoursNumber__c": {
        "inlineHelpText": "Sum of all WorkLog hours associated with this request. Used to track budget consumption.",
    },
    "Request__c/WorkProofUrl__c": {
        "inlineHelpText": "URL to a PR, deployment log, or other evidence of completed work submitted by the vendor.",
    },

    # ── Sync_Item__c ─────────────────────────────────────────────────────────
    "Sync_Item__c/GlobalSourceIdTxt__c": {
        "inlineHelpText": "Globally unique identifier for the source record across all orgs in the network.",
    },
    "Sync_Item__c/TicketCommentId__c": {
        "inlineHelpText": "Lookup to the Ticket Comment this sync item represents, if the payload is a comment event.",
    },
    "Sync_Item__c/TicketId__c": {
        "inlineHelpText": "Lookup to the Ticket this sync item is associated with.",
    },

    # ── Ticket__c ────────────────────────────────────────────────────────────
    "Ticket__c/BillableRateCurrency__c": {
        "inlineHelpText": "Hourly rate used to calculate the projected and actual cost of this ticket.",
    },
    "Ticket__c/BriefDescriptionTxt__c": {
        "inlineHelpText": "One or two sentences summarising what this ticket is about. Shown in board card previews.",
    },
    "Ticket__c/BudgetVarianceNumber__c": {
        "inlineHelpText": "Difference between pre-approved hours and total logged hours. Negative means over budget.",
    },
    "Ticket__c/CalculatedETADate__c": {
        "inlineHelpText": "System-calculated estimated completion date based on queue position, team capacity, and priority.",
    },
    "Ticket__c/ClientIntentionPk__c": {
        "description": "Indicates the client's current intention for this ticket: whether they intend to proceed, want sizing only, have deferred it, or placed it on hold.",
        "inlineHelpText": "Select the client's intent: Will Do, Sizing Only, Deferred, or On Hold.",
    },
    "Ticket__c/DetailsTxt__c": {
        "inlineHelpText": "Full technical and functional details of this ticket. Supports rich text formatting.",
    },
    "Ticket__c/Developer__c": {
        "inlineHelpText": "The developer currently assigned to work on this ticket.",
    },
    "Ticket__c/DeveloperDaysSizeNumber__c": {
        "inlineHelpText": "T-shirt size expressed in developer-days. Used as input for ETA calculations.",
    },
    "Ticket__c/Epic__c": {
        "inlineHelpText": "The parent Epic ticket this ticket belongs to. Leave blank for standalone tickets.",
    },
    "Ticket__c/EstimatedEndDevDate__c": {
        "inlineHelpText": "Estimated date when development work on this ticket will be complete.",
    },
    "Ticket__c/EstimatedHoursNumber__c": {
        "inlineHelpText": "Manually entered or AI-suggested estimate of total effort required in hours.",
    },
    "Ticket__c/EstimatedStartDevDate__c": {
        "inlineHelpText": "Estimated date when a developer will begin active work on this ticket.",
    },
    "Ticket__c/EventReceivedOnDateTime__c": {
        "inlineHelpText": "Timestamp when the source platform event that created or updated this ticket was received.",
    },
    "Ticket__c/ExternalRequesterEmailTxt__c": {
        "inlineHelpText": "Email address of the person who submitted this request from an external org.",
    },
    "Ticket__c/ExternalSourceOrgTxt__c": {
        "inlineHelpText": "Salesforce org ID or name of the client org that originated this ticket via cross-org sync.",
    },
    "Ticket__c/HoursVarianceNumber__c": {
        "inlineHelpText": "Estimated Hours minus Total Logged Hours. Positive means under estimate; negative means over.",
    },
    "Ticket__c/IsActiveBool__c": {
        "inlineHelpText": "Uncheck to soft-delete this ticket from board views without permanently removing the record.",
    },
    "Ticket__c/PriorityPk__c": {
        "inlineHelpText": "Select the priority level. Higher priority tickets are scheduled earlier in ETA calculations.",
    },
    "Ticket__c/ProjectedUATReadyDate__c": {
        "inlineHelpText": "System-calculated date when this ticket is expected to be ready for UAT, including buffer days.",
    },
    "Ticket__c/RequestTypePk__c": {
        "inlineHelpText": "Classifies whether this ticket is a Bug, Feature, Change Request, or other type of work.",
    },
    "Ticket__c/SortOrderNumber__c": {
        "inlineHelpText": "Manual sort position within the ticket's current stage column on the Kanban board.",
    },
    "Ticket__c/SourceEventReplayIdTxt__c": {
        "inlineHelpText": "Platform event replay ID used to detect and deduplicate duplicate inbound sync events.",
    },
    "Ticket__c/StageNamePk__c": {
        "inlineHelpText": "Current stage on the Kanban board. Drag the card to a new column to update this value.",
    },
    "Ticket__c/StatusPk__c": {
        "inlineHelpText": "High-level status (Open, In Progress, Resolved, Closed). Distinct from the detailed Stage Name.",
    },
    "Ticket__c/Tags__c": {
        "inlineHelpText": "Comma-separated tags for filtering and grouping tickets on the board (e.g., frontend, api, urgent).",
    },
    "Ticket__c/TotalLoggedHoursNumber__c": {
        "inlineHelpText": "Sum of all WorkLog hours recorded against this ticket. Auto-updated by roll-up.",
    },

    # ── Ticket_Comment__c ────────────────────────────────────────────────────
    "Ticket_Comment__c/AuthorTxt__c": {
        "inlineHelpText": "Display name of the person who wrote this comment (may be from a remote org).",
    },
    "Ticket_Comment__c/BodyTxt__c": {
        "inlineHelpText": "The full text content of this comment.",
    },
    "Ticket_Comment__c/SourcePk__c": {
        "inlineHelpText": "Indicates whether this comment originated locally or was synced from a remote org.",
    },
    "Ticket_Comment__c/SyncedDateTime__c": {
        "inlineHelpText": "Timestamp when this comment was last successfully synced with the remote org.",
    },
    "Ticket_Comment__c/TicketId__c": {
        "inlineHelpText": "The ticket this comment belongs to.",
    },

    # ── Ticket_Dependency__c ─────────────────────────────────────────────────
    "Ticket_Dependency__c/Blocked_Ticket__c": {
        "inlineHelpText": "The ticket that cannot proceed until the blocking ticket is resolved.",
    },
    "Ticket_Dependency__c/Blocking_Ticket__c": {
        "inlineHelpText": "The ticket that must be completed before the blocked ticket can move forward.",
    },
    "Ticket_Dependency__c/ExternalIdTxt__c": {
        "inlineHelpText": "External identifier for this dependency record, used for cross-org sync deduplication.",
    },
    "Ticket_Dependency__c/TypePk__c": {
        "inlineHelpText": "Blocks: the blocking ticket must finish first. Relates To: informational link. Clones: duplicate relationship.",
    },

    # ── WorkLog__c ───────────────────────────────────────────────────────────
    "WorkLog__c/HoursLoggedNumber__c": {
        "inlineHelpText": "Number of hours worked in this session (e.g., 1.5 for 90 minutes).",
    },
    "WorkLog__c/RequestId__c": {
        "inlineHelpText": "The delivery Request this work log is billed against.",
    },
    "WorkLog__c/TicketId__c": {
        "inlineHelpText": "The Ticket this work log is associated with.",
    },
    "WorkLog__c/WorkDateDate__c": {
        "inlineHelpText": "The date the work was performed.",
    },
    "WorkLog__c/WorkDescriptionTxt__c": {
        "inlineHelpText": "Brief description of what was done during this work session.",
    },
}


def insert_after_tag(xml: str, after_tag: str, new_content: str) -> str:
    """Insert new_content immediately after the closing of after_tag's line."""
    pattern = re.compile(r'([ \t]*<' + re.escape(after_tag) + r'>[^\n]*\n)')
    match = pattern.search(xml)
    if match:
        pos = match.end()
        return xml[:pos] + new_content + xml[pos:]
    return xml


def insert_before_tag(xml: str, before_tag: str, new_content: str) -> str:
    """Insert new_content immediately before the line containing before_tag."""
    pattern = re.compile(r'([ \t]*<' + re.escape(before_tag) + r'>)')
    match = pattern.search(xml)
    if match:
        pos = match.start()
        return xml[:pos] + new_content + xml[pos:]
    return xml


def get_indent(xml: str, tag: str) -> str:
    """Get the indentation used for a given tag in the XML."""
    pattern = re.compile(r'^([ \t]*)<' + re.escape(tag) + r'>', re.MULTILINE)
    match = pattern.search(xml)
    return match.group(1) if match else "    "


def process_field_file(filepath: str, obj_name: str, field_name: str) -> bool:
    with open(filepath, "r", encoding="utf-8") as f:
        original = f.read()

    key = f"{obj_name}/{field_name}"
    meta = FIELD_META.get(key)
    if not meta:
        return False  # Nothing to add

    xml = original
    changed = False
    indent = get_indent(xml, "fullName")

    has_description = "<description>" in xml
    has_inline = "<inlineHelpText>" in xml

    # Add description if missing
    if not has_description and "description" in meta:
        desc_line = f'{indent}<description>{meta["description"]}</description>\n'
        # Insert after <fullName>
        xml = insert_after_tag(xml, "fullName", desc_line)
        changed = True

    # Add inlineHelpText if missing
    if not has_inline and "inlineHelpText" in meta:
        help_line = f'{indent}<inlineHelpText>{meta["inlineHelpText"]}</inlineHelpText>\n'
        if "<description>" in xml:
            # Insert after <description>
            xml = insert_after_tag(xml, "description", help_line)
        else:
            # Insert after <fullName>
            xml = insert_after_tag(xml, "fullName", help_line)
        changed = True

    if changed and xml != original:
        with open(filepath, "w", encoding="utf-8", newline="\n") as f:
            f.write(xml)
        return True

    return False


def main():
    updated = 0
    skipped = 0
    errors = 0

    for obj_dir in sorted(os.listdir(BASE)):
        fields_dir = os.path.join(BASE, obj_dir, "fields")
        if not os.path.isdir(fields_dir):
            continue

        for filename in sorted(os.listdir(fields_dir)):
            if not filename.endswith(".field-meta.xml"):
                continue

            field_name = filename.replace(".field-meta.xml", "")
            filepath = os.path.join(fields_dir, filename)

            try:
                result = process_field_file(filepath, obj_dir, field_name)
                if result:
                    print(f"  UPDATED: {obj_dir}/{field_name}")
                    updated += 1
                else:
                    skipped += 1
            except Exception as e:
                print(f"  ERROR:   {obj_dir}/{field_name}: {e}")
                errors += 1

    print(f"\nDone. Updated: {updated}, Skipped (already complete): {skipped}, Errors: {errors}")


if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))
    main()
