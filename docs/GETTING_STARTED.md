# Getting Started with Delivery Hub

This guide walks you through installing Delivery Hub, running the setup wizard, creating your first work item, and optionally configuring cross-org sync and external API access.

---

## 1. Install the Package

Install Delivery Hub into your Salesforce org:

| Environment | Link |
|---|---|
| **Production** | [Install in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tQr000000T0SrIAK) |
| **Sandbox** | [Install in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tQr000000T0SrIAK) |

When prompted, select **Install for All Users** (recommended) or configure per-profile access.

---

## 2. Assign Permission Sets

Assign the appropriate permission set to each user:

- **DeliveryHubApp** -- for all standard users who need to view and manage work items
- **DeliveryHubAdmin_App** -- for administrators who need access to setup, settings, and sync configuration

To assign via Setup:

1. Go to **Setup > Permission Sets**
2. Click **DeliveryHubApp** (or **DeliveryHubAdmin_App**)
3. Click **Manage Assignments > Add Assignments**
4. Select the users and save

Or via Apex:

```apex
PermissionSetAssignment psa = new PermissionSetAssignment(
    AssigneeId = 'USER_ID',
    PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'DeliveryHubApp'].Id
);
insert psa;
```

---

## 3. Run the Getting Started Wizard

1. Open the **Delivery Hub** app from the App Launcher
2. Navigate to the **Home** tab
3. The **Getting Started** wizard (`deliveryGettingStarted`) appears at the top of the page
4. Follow the 4-step wizard:
   - **Step 1**: Review your org configuration
   - **Step 2**: Click **Quickstart Connection** to automatically configure scheduled jobs, connection handshake, and default settings
   - **Step 3**: Verify the connection health indicator shows "Connected"
   - **Step 4**: Complete the setup

The wizard handles all backend configuration automatically. No manual REST endpoint setup or Apex scripts required.

---

## 4. Create Your First Work Item

1. Navigate to the **Board** tab in the Delivery Hub app
2. Click the **+ New** button (or use the Ghost Recorder floating form)
3. Enter a title (e.g., "Build login page")
4. Optionally fill in:
   - **Priority**: Critical, High, Medium, Low
   - **Description**: Detailed requirements
   - **Request Type**: Internal, External, Bug, Enhancement
5. The item appears in the **Backlog** column
6. Drag it to the appropriate stage to progress it through the workflow

### Using the Ghost Recorder

The Ghost Recorder is a floating form available anywhere in the Delivery Hub app. It allows quick work item submission without navigating away from your current screen:

1. Look for the floating button in the bottom-right corner
2. Click to open the form
3. Enter a title and optional details
4. Submit -- the item is created in Backlog immediately

---

## 5. Set Up Cross-Org Sync (Optional)

Connect two Salesforce orgs for bidirectional work item synchronization. This is useful when a vendor org manages delivery and a client org needs visibility.

### On the Vendor Org

1. Create a NetworkEntity for the client:
   - **Name**: The client's name
   - **Entity Type**: `Client`
   - **Connection Status**: `Connected`
   - **Org ID**: The client's 15-character Organization ID

2. Add a Remote Site Setting for the client org's domain:
   - **Setup > Remote Site Settings > New**
   - URL: `https://CLIENT_INSTANCE.salesforce.com`

### On the Client Org

1. Create a NetworkEntity for the vendor:
   - **Name**: The vendor's name
   - **Entity Type**: `Vendor`
   - **Connection Status**: `Connected`
   - **Integration Endpoint URL**: `https://VENDOR_INSTANCE.salesforce.com/services/apexrest/delivery/deliveryhub/v1/sync`
   - **Org ID**: The vendor's 15-character Organization ID

2. Add a Remote Site Setting for the vendor org's domain

3. Create a WorkRequest to link a work item for sync:
   - **Work Item**: Select the work item to sync
   - **Delivery Entity**: Select the vendor NetworkEntity
   - **Status**: `Active`

### Verify the Connection

After creating the WorkRequest:
1. Make a change to the linked work item (e.g., update the stage)
2. The sync engine queues an outbound SyncItem automatically
3. Check the vendor org -- the work item should appear within seconds
4. On the admin home page, the **Sync Retry Panel** shows sync status and any errors

### Enable API Key Authentication (Optional)

For additional security on the sync connection:

1. Generate an API key: `DeliveryPublicApiService.generateApiKey()`
2. Set it on the NetworkEntity's `ApiKeyTxt__c` field
3. The outbound processor automatically includes the key in HTTP headers
4. The receiving org validates the key if present

### Enable Real-Time Vendor Push (Optional)

By default, client orgs poll for updates. To enable real-time push from vendor to client:

1. On the vendor org's client NetworkEntity:
   - Set **Enable Vendor Push** to `true`
   - Set **Integration Endpoint URL** to the client's sync endpoint
2. Changes are now pushed to the client immediately instead of waiting for the next poll cycle

See the [Sync API Guide](SYNC_API_GUIDE.md) for complete technical details.

---

## 6. Connect a Website or External App (Optional)

Expose Delivery Hub data to a website, mobile app, or external platform via the Public REST API.

### Generate an API Key

```apex
NetworkEntity__c entity = new NetworkEntity__c(
    Name = 'My Website',
    EntityTypePk__c = 'Client',
    StatusPk__c = 'Active',
    ApiKeyTxt__c = DeliveryPublicApiService.generateApiKey(),
    ConnectionStatusPk__c = 'Connected'
);
insert entity;
System.debug('API Key: ' + entity.ApiKeyTxt__c);
```

### Configure Salesforce Site (for unauthenticated access)

If your website needs to call the API without a Salesforce login:

1. **Setup > Sites** -- create or configure a Salesforce Site
2. Assign the `DeliveryHubGuestUser` permission set to the Site guest user profile
3. The API is now accessible via the Site URL with just the `X-Api-Key` header
4. **Setup > CORS** -- add your website's domain to the CORS whitelist if calling from browser JavaScript

### Make API Calls

```bash
# Get dashboard
curl -s \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_SITE_URL/services/apexrest/delivery/deliveryhub/v1/api/dashboard"

# Get active work items
curl -s \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_SITE_URL/services/apexrest/delivery/deliveryhub/v1/api/work-items?status=active"

# Submit a new request
curl -s -X POST \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title": "New feature request", "description": "Details here", "priority": "Medium"}' \
  "YOUR_SITE_URL/services/apexrest/delivery/deliveryhub/v1/api/work-items"
```

See the [Public API Guide](PUBLIC_API_GUIDE.md) for all endpoints, request/response schemas, and error codes.

---

## 7. Time Tracking & Work Logs

Delivery Hub includes built-in time tracking so team members can log hours against work items.

### Logging Hours

1. Open any Work Item record page -- the **Time Logger** component is on the sidebar
2. Alternatively, use the **Time Logger** in the Home page sidebar for quick logging
3. Fill in the required fields:
   - **Hours**: Number of hours worked (decimal values supported, e.g., 1.5)
   - **Work Date**: The date the work was performed
   - **Description**: What was accomplished during the logged time
4. Click **Log Time** to save

Each WorkLog record is automatically linked to the active **WorkRequest** for that work item. If multiple WorkRequests exist, the active one is auto-selected.

### Viewing Logged Hours

- Work item record pages show all associated WorkLogs
- The **Budget Summary** component on the Home page displays aggregate hours and budget utilization
- The **Activity Feed** includes hour entries alongside comments and field changes

---

## 8. Work Log Approval

For teams that need oversight before hours are reported to clients, Delivery Hub supports an optional approval workflow for WorkLogs.

### Enabling Approval

1. Go to **Setup > Custom Settings > DeliveryHubSettings__c**
2. Set the **RequireWorkLogApprovalDateTime__c** field to a date value
3. All WorkLogs created on or after that date require approval before syncing

### Status Flow

When approval is enabled, WorkLogs follow this lifecycle:

- **Draft** -- Initial status when a WorkLog is created. Draft logs are visible internally but do NOT sync to client orgs.
- **Approved** -- An admin or manager approves the log. Approved logs sync automatically to the connected client org.
- **Rejected** -- The log is rejected with optional feedback. Rejected logs do not sync.

### Approving and Rejecting Logs

1. Open the **Activity Feed** (Delivery Activity tab or Home page)
2. Look for the **Pending Approvals** section at the top -- it shows all Draft WorkLogs awaiting review
3. Click **Approve** or **Reject** on each entry

### Backward Compatibility

When approval is not enabled (RequireWorkLogApprovalDateTime__c is blank or the WorkLog date is before the configured date), hours sync immediately upon creation -- no approval step required. Existing orgs continue to work without changes.

---

## 9. Documents & Invoicing

The **Document Engine** generates professional documents -- invoices, status reports, proposals, and more -- directly from Delivery Hub data.

### Document Types

| Type | Description |
|---|---|
| **Invoice** | Billable hours and rates for a time period |
| **Status Report** | Progress summary across active work items |
| **Client Agreement** | Client-facing service agreement |
| **Contractor Agreement** | Contractor-facing engagement agreement |
| **Proposal** | Scoped work breakdown with estimated hours |
| **Executive Summary** | High-level overview for stakeholders |
| **Meeting Brief** | Agenda and context for upcoming meetings |
| **Weekly Digest** | AI-powered weekly activity summary |

### Generating a Document

1. Open the **Document Viewer** component -- available on the Admin Home page or any Network Entity record page
2. Click **Generate**
3. Select a **template** (document type) and the **time period** to cover
4. The engine pulls hours, work items, and activity data to populate the document
5. Review the generated document and update its status as needed

### Rate Hierarchy

The Document Engine calculates billable amounts using this precedence:

1. **WorkRequest rate** -- if a rate is set on the specific WorkRequest, it takes priority
2. **WorkItem rate** -- falls back to the rate on the Work Item
3. **Entity default rate** -- uses the Network Entity's default hourly rate as a last resort

### Document Lifecycle

Documents follow a status progression:

**Draft** → **Ready** → **Sent** → **Viewed** → **Paid**

Each document is an **immutable JSON snapshot** -- changing underlying data (hours, rates, descriptions) after generation will not alter existing documents. Generate a new document to reflect updated data.

### Payment Terms

Documents support configurable payment terms such as "Net 30", "Due on Receipt", "Net 15", etc. Due dates are auto-calculated from the document issue date based on the selected terms.

### Invoice Generation Notes

- **Zero-hour filtering**: Work items with zero logged hours in the billing period are automatically excluded from generated invoices. Only items with actual billable time appear in the document.
- **PDF hyperlinks**: Work item names in the PDF are clickable links that navigate to the corresponding Salesforce record. This applies to both the work items summary table and the time log detail table.

### PDF Rendering

Documents can be rendered as PDF for download or email attachment:

1. Open a generated document in the **Document Viewer**
2. Click **Download PDF** -- a Visualforce page renders the snapshot data into a professional PDF layout
3. The PDF includes vendor branding (company name, address, contact details), line-item details, totals, payment terms, due date, an A/R summary of prior unpaid balances, and a footer linking to the vendor's website (cloudnimbusllc.com for Cloud Nimbus-issued documents)

The PDF rendering is handled server-side by `DeliveryDocumentPdf.page` with runtime namespace detection (no hardcoded namespace tokens). The page works for both authenticated users and public access via Salesforce Sites.

### Sending Documents by Email

To email a document to a client:

1. Open a generated document in the **Document Viewer**
2. Click **Send Email**
3. The system sends the document as a PDF attachment to the client contact's email address (from the NetworkEntity)
4. The document status transitions to **Sent**

### CC Email Configuration

To receive a copy of every outbound document email:

1. Go to **Setup > Custom Settings > DeliveryHubSettings__c**
2. Set the **DocumentCcEmailTxt__c** field to the desired email address (e.g., `billing@yourcompany.com`)
3. All future document emails will CC this address automatically

Leave the field blank to disable CC.

### Payment Tracking

Record payments and other financial transactions against a document:

1. Open a **DeliveryDocument__c** record
2. Create a **DeliveryTransaction__c** child record with:
   - **Type**: Payment, Credit, Refund, Adjustment, or Write-Off
   - **Amount**: The transaction amount
   - **Method**: Payment method (check, ACH, wire, etc.)
   - **Transaction Date**: When the transaction occurred
   - **Note**: Optional description
3. Multiple transactions can be recorded per document
4. The A/R summary on invoices automatically reflects payment history

### White-Label Vendor Branding

Documents display the vendor entity's branding, not the Salesforce org identity. The vendor is resolved from the WorkRequest linkage. To configure vendor branding:

1. Open the vendor **NetworkEntity** record
2. Populate the **Name**, **AddressTxt__c**, **ContactEmailTxt__c**, and **ContactPhoneTxt__c** fields
3. All documents generated for that vendor's work requests will use these details in the header

### Public Access Tokens

Each generated document receives a unique 64-character token. This token enables portal viewing without Salesforce authentication -- share the document link with clients and they can view it directly in the portal.

---

## 10. Client Portal Setup

The Client Portal is a standalone web application (e.g., `cloudnimbusllc.com/portal`) that gives your clients visibility into their delivery work without requiring a Salesforce license.

### Granting Portal Access

1. Create a **PortalAccess__c** record for each user who needs access:
   - **Email**: The user's email address (used for login)
   - **Network Entity**: Link to the client's NetworkEntity record
   - **Access Level**: Set the appropriate access level (e.g., User, Admin)
2. The user can now log in to the portal using their email

### Authentication Methods

The portal supports three authentication methods:

- **Passkey / WebAuthn** -- Biometric or hardware key authentication (most secure, recommended)
- **Password** -- Traditional email + password login
- **Magic Link** -- Passwordless login via email link

### Portal Capabilities

Once authenticated, portal users can:

- **View the Board** -- See work items on a Kanban board filtered to their entity
- **Track Activity** -- Browse the activity feed for comments, changes, and updates
- **Review Hours** -- See all logged hours and time breakdowns
- **Log Hours** -- Submit their own time entries from the portal
- **Approve / Reject Hours** -- Admins can approve or reject pending WorkLogs
- **View Documents** -- Access invoices, status reports, and other generated documents
- **Browse Files** -- View files attached to work items

---

## 11. Activity Feed

The **Activity Feed** provides a unified timeline of all activity across work items -- comments, work logs, and field changes in one place.

### Accessing the Activity Feed

1. Navigate to the **Delivery Activity** tab in the Delivery Hub app
2. The feed displays entries in reverse chronological order

### Filtering

Use the filter controls at the top of the feed to narrow results:

- **Type filter**: All, Comments, Hours, Changes
- **Date range**: Filter to a specific time period
- **Network Entity**: Show activity for a specific client or vendor

### Pending Approvals

When Work Log Approval is enabled, the Activity Feed includes a **Pending Approvals** section at the top for admins. This section surfaces all Draft WorkLogs awaiting review, allowing quick approve/reject actions without navigating to individual records.

---

## 12. Delivery Guide Tab

Delivery Hub includes built-in documentation accessible directly from the app.

- Open the **Delivery Guide** tab in either the **Delivery Hub** or **Delivery Hub Admin** app
- The guide covers all features, configuration options, and best practices
- It also includes **Ghost Recorder utility bar detection** -- the guide checks whether the Ghost Recorder is available across all Lightning apps in the org and provides setup instructions if it is missing

---

## 13. Record Page Components

Delivery Hub places LWC components on record pages for contextual information and actions:

| Record Page | Component | Location | Description |
|-------------|-----------|----------|-------------|
| **WorkItem** | `deliveryScore` | Sidebar | Attention score indicator showing urgency level |
| **DeliveryDocument** | `deliveryDocumentViewer` | Preview tab | Document preview and PDF download |
| **NetworkEntity** | `deliverySyncRetryPanel` | Sidebar | Monitor and retry failed sync items for the entity |

The WorkItem Admin record page uses **Dynamic Forms**, placing fields directly on the Lightning page with conditional visibility rules instead of relying on page layout assignments.

All Lightning apps (Delivery Hub, Delivery Hub Admin) include record page assignments for their respective objects.

---

## 14. Timeline View

The **Delivery Timeline** tab provides a Gantt-style horizontal timeline of active work items, grouped by NetworkEntity.

### Accessing the Timeline

1. Navigate to the **Delivery Timeline** tab in either the Delivery Hub or Delivery Hub Admin app
2. The timeline displays all active work items as horizontal bars positioned by date range

### Timeline Controls

- **Zoom levels**: Switch between Week, Month, and Quarter views using the toolbar buttons
- **Scroll**: Use the left/right arrow controls to navigate through the time range
- **Today marker**: A vertical red line marks the current date for quick orientation
- **Stage colors**: Each bar is colored based on its current workflow stage (pulled from WorkflowStage__mdt configuration)

### Date Range Logic

The timeline determines bar placement using a fallback chain:

1. **Start date**: CreatedDate of the work item (always available)
2. **End date**: CalculatedETADate__c if set, otherwise CreatedDate + EstimatedHoursNumber__c converted to days, otherwise CreatedDate + 5 days as a default span

### Interacting with Items

Click any bar on the timeline to navigate directly to that work item's record page.

---

## 15. Saved Filters

Save and recall board filter configurations so you do not have to re-apply filters every time you visit the board.

### Saving a Filter

1. Apply your desired filters on the **Board** tab (status, priority, entity, search text, etc.)
2. Click the **Save Filter** icon in the filter toolbar
3. Enter a label for the filter
4. Optionally mark it as **Default** -- default filters auto-apply when the board loads

### Loading a Saved Filter

1. Click the filter dropdown in the board toolbar
2. Select a saved filter from the list
3. The board immediately updates to reflect the saved filter criteria

### Managing Filters

- Each user maintains their own set of saved filters (Private sharing model -- other users cannot see your filters)
- Filters are scoped to the current workflow type (Software_Delivery, Loan_Approval, etc.)
- Delete a saved filter by selecting it and clicking the delete icon
- Up to 50 saved filters per user per workflow type

### Filter Storage

Filters are stored as JSON in `DeliverySavedFilter__c.FilterJsonTxt__c`, capturing the complete board filter state including status filters, priority selections, entity scope, and search text.

---

## 16. Invoice Approval Flow

Clients can approve or dispute invoices directly from the portal without needing a Salesforce license.

### How It Works

1. Generate an invoice via the Document Engine (see Section 9)
2. Send the invoice to the client -- the client receives a link with the document's public token
3. The client reviews the invoice in the portal document viewer
4. The client clicks **Approve** or **Dispute**

### Approval

When the client approves:
- The document status changes to **Approved**
- A DeliveryTransaction__c record of type "Approval" is created
- An ActivityLog__c record is created for audit

### Dispute

When the client disputes:
- The client must provide a dispute reason (stored in `DisputeReasonTxt__c`)
- The document status changes to **Disputed**
- An ActivityLog__c record captures the dispute action and reason
- The vendor team can review the dispute reason and regenerate the invoice if needed

### API Endpoints

These actions are also available via the Public API:

- `POST /api/document-approve` -- Approve by public token
- `POST /api/document-dispute` -- Dispute with reason by public token
- `GET /api/documents/{token}` -- Retrieve document detail by public token

---

## 17. Email-Based Commenting

Reply to work item notification emails to create comments directly in Salesforce -- no login required.

### Enabling Email Notifications

1. Go to **Setup > Custom Settings > DeliveryHubSettings__c**
2. Set `EnableEmailNotificationsDateTime__c` to a DateTime value (this also records when the feature was activated)
3. Once enabled, comment notifications are sent to the developer and owner of a work item when a new comment is posted

### How Inbound Email Works

1. A comment is posted on a work item (from UI, sync, or portal)
2. DeliveryEmailService sends notification emails to subscribed users (developer + owner)
3. The email includes a reply-to address formatted as `workitem-T0039@{email-service-domain}`
4. The recipient replies to the email
5. DeliveryInboundEmailHandler parses the work item number from the To address or Subject line
6. A new WorkItemComment__c is created with `SourcePk__c = 'Email'`
7. Reply quote text ("On DATE, NAME wrote:") is stripped automatically for clean comment bodies

### Supported Work Item Number Formats

The inbound handler recognizes these patterns in the To address or Subject:
- `workitem-T0039` (canonical format in reply-to address)
- `T-0039` (hyphenated)
- `T0039` (compact)

### Setup Requirements

For inbound email to work, you must configure an **Email Service** in Salesforce Setup:
1. Go to **Setup > Email Services**
2. Create a new Email Service pointing to `DeliveryInboundEmailHandler`
3. Create an Email Address for the service
4. Use this domain in your outbound notification reply-to addresses

---

## 18. AI Features

Delivery Hub integrates with OpenAI to provide AI-powered content generation and analysis.

### Configuration

1. Open the **Settings** panel (Delivery Hub Admin app)
2. Navigate to the **AI Settings** section
3. Enter your **OpenAI API key**
4. Save the settings

### Configurable Operational Settings

The Settings panel also exposes operational parameters that control background job behavior. Each setting has a sensible default that applies when no value is configured:

| Setting | Default | Description |
|---------|---------|-------------|
| **Reconciliation Hour (GMT)** | 6 | Hour of the day (0-23) when the daily sync reconciliation job runs |
| **Sync Retry Limit** | 3 | Maximum number of retry attempts for failed outbound sync items |
| **Activity Log Retention Days** | 90 | Number of days to retain navigation/activity logs before cleanup |
| **Escalation Cooldown Hours** | 24 | Minimum hours between repeated escalations of the same work item |

These settings are stored on `DeliveryHubSettings__c` and read at runtime by the scheduler, cleanup, and escalation services. The settings use DateTime activation toggles -- features like Work Log Approval show the exact activation timestamp, providing a clear audit trail of when each feature was enabled.

### Available AI Features

- **Auto-Generate Descriptions**: When creating or editing a work item, AI generates a detailed description from just a title. Toggle this on via the AutoGenerateDescriptions setting.
- **Board Summary / Weekly Digest**: AI analyzes recent board activity and produces a narrative summary. Access via the Weekly Update feature or the Weekly Digest document type.
- **Document Narratives**: When generating invoices and status reports, AI creates executive summary paragraphs that contextualize the raw data for stakeholders.

---

## Next Steps

- **Configure workflows**: Delivery Hub ships with Software Delivery (40+ stages) and Loan Approval (8 stages). Create custom workflow types via Custom Metadata. See [Architecture](ARCHITECTURE.md) for details.
- **Set up escalation rules**: Define automated escalation conditions via `WorkflowEscalationRule__mdt` custom metadata.
- **Enable AI features**: Configure OpenAI integration in the Settings panel for auto-generated descriptions, acceptance criteria, and weekly digest emails.
- **Import existing work**: Use the CSV Import wizard (`deliveryCsvImport`) to bulk-import work items from spreadsheets.
- **Add team members**: Assign the `DeliveryHubApp` permission set to your team and they can start using the board immediately.
- **Enable email commenting**: Set up the inbound email handler so team members can reply to notifications and create comments without opening Salesforce (see Section 17).
- **Use the Timeline**: Open the Delivery Timeline tab to see a Gantt-style view of all active work items with zoom and scroll controls (see Section 14).
- **Save board filters**: Save your preferred board filter settings so they auto-apply on every visit (see Section 15).
- **Spin up a demo org**: Run `cci flow run demo_org --org dev` to get a fully configured scratch org with sample data for evaluation or demos.
