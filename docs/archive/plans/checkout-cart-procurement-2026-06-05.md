# Checkout Cart — procurement-side ordering inside Delivery Hub

**Date:** 2026-06-05
**Thesis fit:** DH = Salesforce-native **procurement** (self-serve), cloudnimbus = white-label
**fulfillment**, bidirectional sync is the spine. The cart is the *procurement* surface made
literal: a client assembles a basket of scoped work, it auto-**sizes** and auto-**sequences**,
and checkout routes it into the existing delivery pipeline.

> Origin: 2026-06-04/05 MF billing-call arc. Jose/Jared want no-surprises visibility into
> hours + what's coming. The cart lets a purchaser say "I want these, in this order" and lets
> Glen review the basket in a meeting as a ready-to-action proposal.

**Scope (locked 2026-06-05):** **one org-wide cart** (not per-client, not per-purchaser,
not multiple). **Zero new objects.** The cart is a *state* over existing WorkItems.

---

## 1. Persistence — the cart is already in the schema (`ClientIntentionPk__c`)

No new object, no new cart fields. The cart = WorkItems carrying a client-intent state:

| `ClientIntentionPk__c` (existing) | Cart meaning |
|-----------------------------------|--------------|
| `Will Do`     | **committed cart** — checkout candidate |
| `Sizing Only` | **in cart, exploring** — wants the estimate, not committed |
| `Deferred` / `On Hold` | not in the active cart |

- **Org-wide cart** = all `WorkItem__c` where `ClientIntentionPk__c ∈ {Will Do, Sizing Only}`
  **and** `ActivatedDateTime__c == NULL`. One basket for the whole org.
- **Checkout = stamp `ActivatedDateTime__c`** on the `Will Do` lines → they cross into the
  live pipeline and inherit forecast (PR #873 keys in-flight on `ActivatedDateTime != NULL`),
  gantt, sync, and invoicing **for free**. No copy/convert, no parallel data model.
- Per-line sizing already exists: `EstimatedHoursNumber__c`; on the WorkRequest
  `QuotedHoursNumber__c × HourlyRateCurrency__c = ProjectedCostCurrency__c`.
- Per-line order already exists: `PriorityGroupPk__c` / `PriorityPk__c` + `FeatureDependency__c`.

> **Multi-cart is a clean future upgrade, deferred:** because lines are already real WorkItems,
> adding a thin `Cart__c` header + `CartLookup__c` later is purely additive — zero rework of
> anything below. Don't build it until multiple concurrent carts are a real need.

---

## 2. Experience config — capability flags resolved per actor (org-level primary)

The experience is **orthogonal capabilities**, so any client is a *combination*, never a named
"mode." New client shapes = new flag combinations, **zero new code**.

| Capability     | Mechanism                              | MF        | Self-serve client |
|----------------|----------------------------------------|-----------|-------------------|
| `showDollars`  | `EnableCartDollarsDateTime__c` (Settings) | **off** | on                |
| `checkoutMode` | `CheckoutModeTxt__c` (Approve\|Invoice\|Stripe — Text, validated in Apex) | `Invoice` | `Stripe` |
| `selfServe`    | `EnableCartSelfServeDateTime__c`       | off (Glen assembles) | on |

> **`checkoutMode` is `CheckoutModeTxt__c` (Text), NOT a Picklist/GVS.** It lives on
> `DeliveryHubSettings__c`, which is a **Custom Setting** — Custom Settings cannot hold
> Picklist fields (primitive types only). The value is one of `Approve | Invoice | Stripe`,
> validated and normalized in Apex (`CartExperienceProfile.normalizeMode`); blank defaults to
> `Invoice`. This supersedes the original "via GVS" sizing note in §4 below.

**Resolution:** **`DeliveryHubSettings__c` org defaults** are primary (one org-wide cart →
org-level config). `NetworkEntity__c` override stays *available* (it already hosts the
`EnableBillingDateTime__c` pattern) but is optional/future. Role (admin vs client) gates which
surface a user sees — same split as the Home pages (#869/#870).

Flags are **DateTime stamps + a Text mode, never booleans** (house pattern), so they stay
queryable/reportable. **Only genuinely new metadata in this whole plan = these ~3 config fields.**
One Apex resolver returns a `CartExperienceProfile`; both LWCs are a pure function of
`(cartData, profile)` — MF and a self-serve client run **identical bytes** (same "never fork the
renderer" lesson as the gantt + the NG pacing `controls`/`defaults`).

---

## 3. Two surfaces (one config-driven LWC each)

### A. `deliveryCartBuilder` (client / purchaser) — "add to cart"
- Browse catalog (`Feature__c` via the `deliveryFeatureCockpit` pattern; cascade via
  `deliveryFeatureCascadePreview`) and/or freeform request (`deliveryQuickRequest` pattern).
- Add → sets `ClientIntentionPk__c = Sizing Only` (exploring) or `Will Do` (committed) on a
  pre-activation WorkItem.
- Running total: Σ hours, **Σ $ only when `showDollars`** (reuses the pacing dollar gate).
- Timeline impact: call the forecast engine on the cart's lines → "this lands across these months."
- Reorder (drag priority) → writes `PriorityPk__c`.

### B. `deliveryCartCheckout` (Glen's meeting / review surface) — "review the checkout"
- The org-wide basket, auto-**sized** (hrs + $ per profile) and auto-**sequenced**
  (priority + dependency) — recommendations-to-action in order.
- One control → **checkout**, branching on `checkoutMode`:
  - `Invoice` (MF) → stamp `Will Do` lines active + generate proposal/agreement via
    `DeliveryDocGenerationService` (retainer/fixed-bid/hourly clauses already shipped).
  - `Stripe` (self-serve) → activate + hand off to `DeliveryStripePaymentHandler` (seam).
  - `Approve` → activate + route through the approval rails (seam).

---

## 4. Build steps — sized & ordered

| # | Step | Size | Notes |
|---|------|------|-------|
| 1 | ~3 config fields on `DeliveryHubSettings__c` (`EnableCartDollarsDateTime__c`, `EnableCartSelfServeDateTime__c`, `CheckoutModeTxt__c` — **Text, not GVS**: Custom Settings can't hold picklists) | S | the only new metadata |
| 2 | `CartExperienceProfile` resolver + `DeliveryCartService` (add/remove/reorder/checkout over `ClientIntentionPk__c` + `ActivatedDateTime__c`) | M | checkout = activate `Will Do` lines |
| 3 | `deliveryCartCheckout` LWC (review surface) — sized + sequenced + checkout control | M | reuses forecast engine, DocGen, Stripe, approval |
| 4 | `deliveryCartBuilder` LWC (add-to-cart) — catalog + freeform + running total | M | reuses Feature cockpit + cascade + quick-request patterns |
| 5 | FlexiPage placement (cart tab + checkout-review on AdminHome) + info popovers | S | **place on FlexiPages in-package** (lesson #869) |
| 6 | Apex + Jest tests; profile matrix (MF hours-only vs self-serve $/Stripe) | M | upload-beta-safe (namespaced describe, ≤40-char identifiers, global DTOs) |

**Order:** 1 → 2 → 3 (review surface first — it's the meeting need and proves sizing/sequencing)
→ 4 → 5 → 6. Steps 3 and 4 parallelize once 2 lands.

---

## 5. Open decisions (greenlight before build) — RESOLVED 2026-06-05
1. **`Will Do` vs `Sizing Only` as the checkout line** — *Locked: checkout activates `Will Do`
   only; `Sizing Only` stays in the cart as "priced but not committed."*
2. **Checkout-review placement** — *Locked: a `Cart` tab (the org's single basket) hosting
   `deliveryCartCheckout` + an "Open cart" summary card on AdminHome.*
3. **`showDollars` default** — *Locked: off by default org-wide (MF behavior); self-serve orgs
   opt in.*

---

## 6. What this reuses (nothing rebuilt)
`ClientIntentionPk__c` (cart state) · forecast engine (sizing, PR #873) · priority +
`FeatureDependency__c` (order) · `DeliveryDocGenerationService` + agreement clauses (proposal) ·
approval rails (`DeliveryFeatureApprovalService`, multi-step) · `DeliveryStripePaymentHandler`
(paid checkout) · `Feature__c` catalog + `deliveryFeatureCockpit`/`deliveryFeatureCascadePreview`
(browse/add) · bidirectional sync (a cart line syncs like any work). The cart is **assembly +
~3 config fields + two screens** on top of machinery that already exists — the deplatformer
thesis in miniature.

---

## 7. As-built notes / TODO seams (2026-06-05)
- **Stripe checkout is a seam.** `DeliveryStripePaymentHandler` is an *inbound* webhook event
  handler (charge.succeeded → `DeliveryTransaction__c`), not an outbound payment initiator.
  `checkout()` in `Stripe` mode activates the `Will Do` lines and returns a clearly-marked
  message; a real Checkout Session / Payment Link callout is a follow-up. No payment behavior
  is faked.
- **Approve checkout is a seam.** The shipped approval rails (`DeliveryFeatureApprovalService`)
  key on `Feature__c` toggle requests, not on a basket of WorkItems. `Approve` mode activates
  the lines and notes the seam; a WorkItem-basket approval flow is a follow-up.
- **Invoice proposal generation** is wired when the committed lines share exactly one client
  `NetworkEntity__c` (`ClientNetworkEntityLookup__c`); it generates a `Client_Agreement` via
  `DeliveryDocGenerationService.generateDocument`. When the lines span zero or many client
  entities, activation stands and the result notes that no single-client proposal was generated
  (no fabricated document).
- **Forecast month-spread** on the review surface reuses
  `DeliveryHoursAnalyticsController.getPortfolioPacing` (the active-portfolio forecast). The
  exact cart-only month spread folds into that view once lines are activated.
