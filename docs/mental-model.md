# Delivery Hub — Mental Model (Mermaid)

> Visual companion to `ARCHITECTURE.md`. Every diagram below is drawn from the shipped code
> (controllers, triggers, services) and the confirmed-happy-path runbook, not from the marketing README.
> Paste any block into a Mermaid renderer (VS Code Mermaid extension, GitHub, mermaid.live).

---

## 1. System context — the 8 layers

```mermaid
flowchart TB
    subgraph EXT[External actors]
        BUYER[Client / Buyer]
        VENDOR[Vendor org]
        PORTAL[Public portal / signer]
        CI[CI-CD & AI agents]
    end

    subgraph REST[REST surfaces  /services/apexrest/delivery/*]
        PUB[DeliveryPublicApiService  /api/*]
        SYNC[DeliveryHubSyncService  /sync/*]
        TASK[DeliveryTaskAPI  /tasks/*]
        SIGN[DeliveryDocActionRestApi  /sign/*]
    end

    subgraph L1[L1 Core domain]
        WI[WorkItem__c]
        WR[WorkRequest__c]
        WL[WorkLog__c]
        WC[WorkItemComment__c]
    end
    subgraph L2[L2 Sync and integration]
        SI[SyncItem__c ledger]
        NE[NetworkEntity__c]
        ENGINE[DeliverySyncEngine]
    end
    subgraph L3[L3 Observability]
        AL[ActivityLog__c  SHA-256 chain]
        WD[WatcherDigest__c]
    end
    subgraph L48[L4-L8 Cockpit  off by default]
        FEAT[Feature Catalog]
        ONB[Onboarding gates]
        DEV[Dev-loop mirror]
        DS[Dataset templates]
        FTR[FeatureToggle approvals]
    end
    subgraph DOC[Document engine]
        DD[DeliveryDocument__c]
        DA[DocumentAction__c  signer slots]
        DT[DeliveryTransaction__c  payments]
    end

    BUYER --> PUB
    PORTAL --> SIGN
    CI --> TASK
    VENDOR <--> SYNC

    PUB --> L1
    SIGN --> DOC
    L1 --> ENGINE
    ENGINE --> SI
    ENGINE <--> NE
    SYNC --> ENGINE
    L1 --> AL
    L1 --> DOC
    DD --> DA
    DD --> DT
    L1 -.emits.-> L3
```

---

## 2. The money loop — request to paid invoice (THE product)

> This is the one loop the whole product exists to serve. Verified backend-proven on a fresh
> install 2026-07-09, ending in a $2,100 invoice. Method names are the real `@AuraEnabled` controllers.

```mermaid
sequenceDiagram
    autonumber
    actor Admin
    actor Buyer
    participant Onb as DeliveryClientOnboardingController
    participant Ghost as DeliveryGhostController
    participant Triage as DeliveryTriageController
    participant ReqMgr as DeliveryRequestManagerController
    participant Appr as DeliveryWorkApprovalService
    participant Timer as DeliveryTimeLoggerController
    participant Doc as DeliveryDocumentController
    participant DB as Salesforce data

    Admin->>Onb: onboardClient(name,email,rate)
    Onb->>DB: NetworkEntity__c (client) + Client_Agreement doc
    Note over DB: Step 2 e-sign click-through is the one UNVERIFIED link

    Buyer->>Ghost: createQuickRequest(subject,desc,priority)
    Ghost->>DB: WorkItem__c  (Backlog/New, un-activated)

    Admin->>Triage: routeToDev(workItemIds, developerId)
    Triage->>DB: Stage = Ready for Sizing + stamp ActivatedDateTime__c

    Admin->>DB: create WorkRequest__c (vendor + HourlyRate)
    Admin->>DB: set Estimated + Quoted hours (sizing = field edits, no Apex)
    Admin->>DB: set Client link on WorkItem  (SKIP = $0 invoice!)

    Admin->>ReqMgr: sendRequestToVendor(requestId)
    ReqMgr->>DB: WorkRequest Status = Offer Sent

    Buyer->>Appr: approve(workRequestId, approvedHours, note)
    Note right of Appr: guard: must be Offer Sent
    Appr->>DB: Request = Accepted, raise ClientPreApprovedHours cap, Stage = Ready for Development

    Buyer->>Timer: logHours(workItemId, hours, notes, date)
    Timer->>DB: WorkLog__c (Approved unless approval flag on)

    Admin->>Triage: markDone(workItemIds)
    Triage->>DB: Stage = Done

    Admin->>Doc: generateDocument(entityId,'Invoice',start,end)
    Doc->>DB: sum in-period Approved logs x rate -> DeliveryDocument__c (Draft)
    Note over Doc,DB: $2,100 = 12h x $175. Send -> record payment -> auto Paid
```

---

## 3. Sync push flow (outbound, org to org)

```mermaid
sequenceDiagram
    autonumber
    participant TRG as Trigger (WorkItem/Comment/File/WorkLog)
    participant ENG as DeliverySyncEngine
    participant SI as SyncItem__c
    participant PROC as DeliverySyncItemProcessor (Queueable)
    participant NE as NetworkEntity__c
    participant REMOTE as Remote org /sync/{ObjectType}

    TRG->>ENG: captureChanges()
    ENG->>ENG: evaluate downstream (Vendor) + upstream (Client) routes
    ENG->>ENG: echo suppression (blockedOrigins, GlobalSourceId kill-switch)
    ENG->>SI: insert SyncItem (Status = Queued)
    ENG->>PROC: enqueue
    PROC->>NE: resolve endpoint URL + ApiKey
    PROC->>REMOTE: HTTP POST + X-Global-Source-Id + X-Api-Key
    REMOTE-->>PROC: 200 { processedId }
    PROC->>SI: Status = Synced (or Failed)
    PROC->>PROC: chain next batch if remaining
    Note over ENG,PROC: relay-mint paths MUST be `without sharing`<br/>(2026-06 nimba incident: 138.5h silently never relayed)
```

---

## 4. Sync pull + the Pending race-handler

```mermaid
sequenceDiagram
    autonumber
    participant POLL as DeliveryHubPoller (15-min schedule)
    participant REMOTE as Remote /sync/changes
    participant ING as DeliverySyncItemIngestor
    participant DB as Local records
    participant RES as DeliverySyncItemPendingResolver (Queueable)
    participant SCHED as DeliveryHubScheduler

    POLL->>REMOTE: GET /sync/changes?since=lastSync
    REMOTE-->>POLL: staged SyncItems (marked Synced remotely)
    loop each inbound item
        POLL->>ING: processInboundItem()
        ING->>DB: resolve local (bridge -> ledger -> direct id -> new)
        alt parent not yet arrived (child-before-parent)
            ING->>DB: insert SyncItem Status = Pending (store ParentRefTxt__c)
            ING->>RES: enqueue inline retry
            RES->>DB: re-attempt parent resolve
        else GlobalSourceId already exists locally
            ING->>ING: suppress duplicate create (PR #757)
        else resolved
            ING->>DB: upsert record + register echo-suppression origin
        end
    end
    SCHED->>DB: requeuePendingItems() every 15 min (auto-drains backlog)
    Note over RES,DB: flips to Failed after DEFAULT_MAX_RETRIES = 10
```

---

## 5. Document signing (native e-sign, no DocuSign)

```mermaid
sequenceDiagram
    autonumber
    actor Signer
    participant API as DeliveryDocActionRestApi  POST /sign/{token}
    participant SVC as DeliveryDocActionService
    participant DA as DocumentAction__c (slot)
    participant AL as ActivityLog__c (SHA-256 chain)
    participant DOC as DeliveryDocument__c
    participant CERT as DeliveryDocCertificateService

    Signer->>API: POST /sign/{token} {name,email,consent,signatureData}
    API->>SVC: signActionByToken(token, ctx)
    SVC->>DA: FOR UPDATE lock (blocks double-sign)
    SVC->>DA: apply signature + ip + user-agent + consent
    SVC->>AL: insert Document_Sign row
    SVC->>AL: re-query -> materialize PriorHashTxt__c
    SVC->>DA: stamp parent hash, rotate signer token to null
    Note over DOC: trigger advances Document -> Approved when all slots Completed
    DOC->>CERT: auto-generate Certificate_Of_Completion
    Note over API,AL: KNOWN GAP: external portal hashChainVerified can never return true;<br/>drawn (image) signatures silently dropped on public path
```

---

## 6. Work-approval / spend-control (roadmap Step 2, ~90% built)

```mermaid
sequenceDiagram
    autonumber
    actor Vendor
    actor Approver
    participant SVC as DeliveryWorkApprovalService
    participant WR as WorkRequest__c
    participant WI as WorkItem__c
    participant CAP as DeliveryWorkCapEnforcementService
    participant WLT as DeliveryWorkLogTriggerHandler

    Vendor->>SVC: submitForApproval(workItemIds, quotedHours)
    alt quoted <= DiscretionaryThreshold AND month-sum < MonthlyCap
        SVC->>WR: Accepted (AutoApprovedDateTime__c)
        SVC->>WI: stamp cap, Stage = Ready for Development
    else needs human
        SVC->>WR: Offer Sent (assign approver, ping)
        Approver->>SVC: approve(workRequestId, hours, note)
        SVC->>WR: Accepted
        SVC->>WI: set/raise ClientPreApprovedHoursNumber__c cap
    end
    Note over CAP,WLT: at WorkLog insert, enforce cap LIVE (rollups stale mid-txn)
    WLT->>CAP: checkInserts / checkUpdates
    alt EnforceApprovalCapDateTime__c set
        CAP-->>WLT: addError (hard block over cap)
    else flag mode
        CAP->>WI: Budget Hold (flag only)
    end
```

---

## 7. WorkRequest lifecycle (state)

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> OfferSent: sendRequestToVendor()
    OfferSent --> Accepted: approve()
    OfferSent --> Inactive: decline()
    Draft --> Accepted: auto-approve (<= threshold within cap)
    Accepted --> InProgress
    InProgress --> Completed
    Accepted --> BudgetHold: cap breach (flag mode)
    Completed --> [*]
    Inactive --> [*]
```

## 8. Document status flow (state)

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Ready
    Ready --> Sent
    Sent --> Viewed: no-signing path
    Sent --> AwaitingSignatures: RequiresSigningCheckbox true
    AwaitingSignatures --> Approved: all slots Completed
    Viewed --> Approved: approveDocumentByToken()
    Viewed --> Disputed: disputeDocumentByToken()
    Approved --> Paid: record payment
    Draft --> Superseded: regenerate (new version)
    Paid --> [*]
```

---

## Where to go next

- **Roadmap:** `DELIVERY-HUB-FUTURE.md` (sell first, finish work-approval, build Proof Pack).
- **Bug list:** `flow/fix-register.md` (F9/F6 fixed, T6 pushed, F7 tech-debt, B12 needs a call).
- **State-of-play matrix:** `flow/00-master-execution-tracker.md` (honest believed vs confirmed).
- **Deep reference:** `ARCHITECTURE.md` (846 lines, object/class/trigger detail).
- **Do-it-yourself loop:** `flow/confirmed-happy-path.md`.
