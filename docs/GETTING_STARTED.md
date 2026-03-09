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

## Next Steps

- **Configure workflows**: Delivery Hub ships with Software Delivery (40+ stages) and Loan Approval (8 stages). Create custom workflow types via Custom Metadata. See [Architecture](ARCHITECTURE.md) for details.
- **Set up escalation rules**: Define automated escalation conditions via `WorkflowEscalationRule__mdt` custom metadata.
- **Enable AI features**: Configure OpenAI integration in the Settings panel for auto-generated descriptions, acceptance criteria, and weekly digest emails.
- **Import existing work**: Use the CSV Import wizard (`deliveryCsvImport`) to bulk-import work items from spreadsheets.
- **Add team members**: Assign the `DeliveryHubApp` permission set to your team and they can start using the board immediately.
