/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Procurement-side Checkout Cart service. The cart is a STATE over
 *               existing WorkItem__c records — ZERO new objects:
 *
 *                 cart = WorkItem__c WHERE ClientIntentionPk__c IN
 *                        {Will Do, Sizing Only} AND ActivatedDateTime__c == NULL
 *
 *               'Will Do' = committed (checkout candidate); 'Sizing Only' = priced but
 *               not committed; 'Deferred'/'On Hold' = not in the cart. Checkout stamps
 *               ActivatedDateTime__c on the Will Do lines so they cross into the live
 *               pipeline (forecast / gantt / sync / invoicing) with no copy/convert.
 *
 *               Per-line sizing is EstimatedHoursNumber__c; the projected cost comes
 *               from the child WorkRequest__c (QuotedHoursNumber__c x HourlyRateCurrency__c
 *               = ProjectedCostCurrency__c, an existing formula). Per-line order is
 *               PriorityPk__c.
 *
 *               Global + all inner DTOs global so the @AuraEnabled boundary and any
 *               global caller can use them as return types. SOQL is WITH SYSTEM_MODE
 *               (namespaced package test context). ClientIntentionPk__c is unrestricted
 *               with no trigger enforcement (CLAUDE.md) — safe known values are passed
 *               directly and validated in Apex.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity')
global with sharing class DeliveryCartService {

    /** @description Cart intent: committed — included at checkout. */
    @TestVisible private static final String INTENT_WILL_DO = 'Will Do';
    /** @description Cart intent: exploring — priced, NOT included at checkout. */
    @TestVisible private static final String INTENT_SIZING_ONLY = 'Sizing Only';
    /** @description Out-of-cart intent. */
    @TestVisible private static final String INTENT_DEFERRED = 'Deferred';
    /** @description Out-of-cart intent. */
    @TestVisible private static final String INTENT_ON_HOLD = 'On Hold';

    /** @description Intent values accepted by add/remove. */
    private static final Set<String> VALID_INTENTIONS = new Set<String>{
        INTENT_WILL_DO, INTENT_SIZING_ONLY, INTENT_DEFERRED, INTENT_ON_HOLD
    };

    /** @description Intent values that constitute the active cart. */
    private static final Set<String> CART_INTENTIONS = new Set<String>{
        INTENT_WILL_DO, INTENT_SIZING_ONLY
    };

    /** @description Hard cap on cart lines scanned. */
    private static final Integer MAX_CART_LINES = 2000;

    // ── DTOs ─────────────────────────────────────────────────────────────

    /** @description One render-ready cart line (a non-activated WorkItem). */
    global class CartLineDTO {
        @AuraEnabled global Id workItemId;
        @AuraEnabled global String name;
        @AuraEnabled global String intention;
        @AuraEnabled global Decimal estimatedHours;
        @AuraEnabled global Decimal projectedCost;
        @AuraEnabled global String priority;
        @AuraEnabled global String priorityGroup;
        @AuraEnabled global String stage;
        @AuraEnabled global String developerName;
        @AuraEnabled global Date estimatedStart;
        @AuraEnabled global Date estimatedEnd;
        @AuraEnabled global Boolean isCommitted;
    }

    /** @description Cart summary header. */
    global class CartSummaryDTO {
        @AuraEnabled global Integer count;
        @AuraEnabled global Integer willDoCount;
        @AuraEnabled global Integer sizingOnlyCount;
        @AuraEnabled global Decimal willDoHours;
        @AuraEnabled global Decimal sizingOnlyHours;
        @AuraEnabled global Decimal willDoCost;
    }

    /** @description Full cart payload returned to the LWC. */
    global class CartDTO {
        @AuraEnabled global List<CartLineDTO> lines;
        @AuraEnabled global CartSummaryDTO summary;
        @AuraEnabled global CartExperienceProfile profile;
    }

    /** @description Result of a checkout call. */
    global class CheckoutResultDTO {
        @AuraEnabled global Integer activatedCount;
        @AuraEnabled global String checkoutMode;
        @AuraEnabled global Id documentId;
        @AuraEnabled global String message;
    }

    // ── Read ─────────────────────────────────────────────────────────────

    /**
     * @description Returns the org-wide cart (Will Do + Sizing Only, non-activated
     *              WorkItems), sequenced by priority + dependency, plus a summary
     *              header and the resolved CartExperienceProfile.
     * @return CartDTO render-ready payload.
     */
    @AuraEnabled
    global static CartDTO getCart() {
        try {
            CartExperienceProfile profile = CartExperienceProfile.resolve();
            List<WorkItem__c> rows = queryCartItems();

            CartDTO cart = new CartDTO();
            cart.profile = profile;
            cart.lines = new List<CartLineDTO>();
            CartSummaryDTO summary = newSummary();

            for (WorkItem__c wi : rows) {
                CartLineDTO line = toLine(wi);
                cart.lines.add(line);
                accumulate(summary, line);
            }
            summary.count = cart.lines.size();
            cart.summary = summary;
            return cart;
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    private static CartSummaryDTO newSummary() {
        CartSummaryDTO s = new CartSummaryDTO();
        s.count = 0;
        s.willDoCount = 0;
        s.sizingOnlyCount = 0;
        s.willDoHours = 0;
        s.sizingOnlyHours = 0;
        s.willDoCost = 0;
        return s;
    }

    private static void accumulate(CartSummaryDTO s, CartLineDTO line) {
        Decimal hours = line.estimatedHours == null ? 0 : line.estimatedHours;
        Decimal cost = line.projectedCost == null ? 0 : line.projectedCost;
        if (line.isCommitted) {
            s.willDoCount++;
            s.willDoHours += hours;
            s.willDoCost += cost;
        } else {
            s.sizingOnlyCount++;
            s.sizingOnlyHours += hours;
        }
    }

    /**
     * @description Queries the non-activated cart WorkItems, sequenced by priority
     *              group then priority then planned start. The child WorkRequest's
     *              ProjectedCostCurrency__c is pulled via the Requests subquery for
     *              per-line cost.
     */
    private static List<WorkItem__c> queryCartItems() {
        return [
            SELECT Id, Name, BriefDescriptionTxt__c, ClientIntentionPk__c,
                   EstimatedHoursNumber__c, PriorityPk__c, PriorityGroupPk__c,
                   StageNamePk__c, EstimatedStartDevDate__c, EstimatedEndDevDate__c,
                   DeveloperLookup__r.Name,
                   (SELECT Id, ProjectedCostCurrency__c, QuotedHoursNumber__c
                    FROM Requests__r
                    ORDER BY CreatedDate DESC
                    LIMIT 1)
            FROM WorkItem__c
            WHERE ClientIntentionPk__c IN :CART_INTENTIONS
              AND ActivatedDateTime__c = NULL
              AND ArchivedDateTime__c = NULL
              AND TemplateMarkedDateTime__c = NULL
            WITH SYSTEM_MODE
            ORDER BY PriorityGroupPk__c NULLS LAST, PriorityPk__c NULLS LAST,
                     EstimatedStartDevDate__c NULLS LAST, CreatedDate
            LIMIT :MAX_CART_LINES
        ];
    }

    private static CartLineDTO toLine(WorkItem__c wi) {
        CartLineDTO line = new CartLineDTO();
        line.workItemId = wi.Id;
        line.name = String.isNotBlank(wi.BriefDescriptionTxt__c) ? wi.BriefDescriptionTxt__c : wi.Name;
        line.intention = wi.ClientIntentionPk__c;
        line.isCommitted = wi.ClientIntentionPk__c == INTENT_WILL_DO;
        line.estimatedHours = wi.EstimatedHoursNumber__c;
        line.priority = wi.PriorityPk__c;
        line.priorityGroup = wi.PriorityGroupPk__c;
        line.stage = wi.StageNamePk__c;
        line.estimatedStart = wi.EstimatedStartDevDate__c;
        line.estimatedEnd = wi.EstimatedEndDevDate__c;
        if (wi.DeveloperLookup__r != null) {
            line.developerName = wi.DeveloperLookup__r.Name;
        }
        if (wi.Requests__r != null && !wi.Requests__r.isEmpty()) {
            line.projectedCost = wi.Requests__r[0].ProjectedCostCurrency__c;
        }
        return line;
    }

    // ── Mutations ────────────────────────────────────────────────────────

    /**
     * @description Sets ClientIntentionPk__c on a WorkItem to place it in (or pull it
     *              out of) the cart. Intention is validated against the four known
     *              values; the field is unrestricted with no trigger enforcement so
     *              safe known values are written directly.
     * @param workItemId The WorkItem to update.
     * @param intention One of Will Do, Sizing Only, Deferred, On Hold.
     */
    @AuraEnabled
    global static void addToCart(Id workItemId, String intention) {
        try {
            if (workItemId == null) {
                throw new AuraHandledException('workItemId is required.');
            }
            if (!VALID_INTENTIONS.contains(intention)) {
                throw new AuraHandledException('Invalid cart intention: ' + intention);
            }
            updateIntention(workItemId, intention);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    /**
     * @description Removes a WorkItem from the cart by setting ClientIntentionPk__c
     *              to Deferred (out-of-cart). The line is not deleted — it stays a real
     *              WorkItem, just no longer part of the active basket.
     * @param workItemId The WorkItem to remove.
     */
    @AuraEnabled
    global static void removeFromCart(Id workItemId) {
        try {
            if (workItemId == null) {
                throw new AuraHandledException('workItemId is required.');
            }
            updateIntention(workItemId, INTENT_DEFERRED);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    /**
     * @description Reorders a cart line by writing PriorityPk__c.
     * @param workItemId The WorkItem to reorder.
     * @param priority The new PriorityPk__c value (passed through as a known value).
     */
    @AuraEnabled
    global static void reorder(Id workItemId, String priority) {
        try {
            if (workItemId == null) {
                throw new AuraHandledException('workItemId is required.');
            }
            WorkItem__c wi = new WorkItem__c(Id = workItemId, PriorityPk__c = priority);
            persist(wi);
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    /**
     * @description Freeform-adds a NEW pre-activation WorkItem to the cart. Creates a
     *              WorkItem with the given description + estimated hours, the chosen cart
     *              intention, and ActivatedDateTime__c left NULL (so it is a cart line,
     *              not a live-pipeline item). Safe known StatusPk__c/StageNamePk__c values
     *              are passed directly (unrestricted fields, no trigger enforcement).
     * @param description The brief description / line name (required).
     * @param estimatedHours Optional per-line sizing.
     * @param intention Will Do (commit) or Sizing Only (explore). Other values rejected.
     * @return The new WorkItem Id.
     */
    @AuraEnabled
    global static Id createCartItem(String description, Decimal estimatedHours, String intention) {
        try {
            if (String.isBlank(description)) {
                throw new AuraHandledException('A description is required.');
            }
            if (!CART_INTENTIONS.contains(intention)) {
                throw new AuraHandledException('Cart adds must be Will Do or Sizing Only.');
            }
            WorkItem__c wi = new WorkItem__c(
                BriefDescriptionTxt__c = description,
                ClientIntentionPk__c = intention,
                EstimatedHoursNumber__c = estimatedHours,
                StatusPk__c = 'Active',
                StageNamePk__c = 'Backlog'
                // ActivatedDateTime__c intentionally left NULL — cart line, not live.
            );
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, new List<WorkItem__c>{ wi });
            insert decision.getRecords();
            return decision.getRecords()[0].Id;
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    private static void updateIntention(Id workItemId, String intention) {
        WorkItem__c wi = new WorkItem__c(Id = workItemId, ClientIntentionPk__c = intention);
        persist(wi);
    }

    private static void persist(WorkItem__c wi) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPDATABLE, new List<WorkItem__c>{ wi });
        update decision.getRecords();
    }

    // ── Checkout ─────────────────────────────────────────────────────────

    /**
     * @description Checks out the cart: stamps ActivatedDateTime__c = now() on the
     *              non-activated Will Do lines (ONLY — Sizing Only stays in the cart),
     *              then branches on the resolved checkoutMode:
     *                Invoice  -> also generate a Client_Agreement proposal via
     *                            DeliveryDocGenerationService when the committed lines
     *                            share one client NetworkEntity (else: activate only,
     *                            noted in the result).
     *                Stripe   -> activate; paid-checkout wiring is a clearly-marked
     *                            seam (DeliveryStripePaymentHandler is an inbound
     *                            webhook handler, not an outbound initiator — see TODO).
     *                Approve  -> activate; approval routing seam (the approval rails
     *                            key on Feature__c, not WorkItems — see TODO).
     * @return CheckoutResultDTO with the activated count, mode, optional doc id, and a message.
     */
    @AuraEnabled
    global static CheckoutResultDTO checkout() {
        try {
            CartExperienceProfile profile = CartExperienceProfile.resolve();
            String mode = profile.checkoutMode;

            List<WorkItem__c> willDo = [
                SELECT Id, ClientNetworkEntityLookup__c
                FROM WorkItem__c
                WHERE ClientIntentionPk__c = :INTENT_WILL_DO
                  AND ActivatedDateTime__c = NULL
                  AND ArchivedDateTime__c = NULL
                  AND TemplateMarkedDateTime__c = NULL
                WITH SYSTEM_MODE
                LIMIT :MAX_CART_LINES
            ];

            CheckoutResultDTO result = new CheckoutResultDTO();
            result.checkoutMode = mode;
            result.activatedCount = 0;

            if (willDo.isEmpty()) {
                result.message = 'No committed (Will Do) lines to check out.';
                return result;
            }

            Datetime now = Datetime.now();
            List<WorkItem__c> toActivate = new List<WorkItem__c>();
            for (WorkItem__c wi : willDo) {
                toActivate.add(new WorkItem__c(Id = wi.Id, ActivatedDateTime__c = now));
            }
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE, toActivate);
            update decision.getRecords();
            result.activatedCount = toActivate.size();

            routeCheckout(mode, willDo, result);
            return result;
        } catch (Exception e) {
            throw toAura(e);
        }
    }

    /**
     * @description Mode-specific post-activation routing. Activation already happened;
     *              this layers the proposal/payment/approval step on top.
     */
    private static void routeCheckout(String mode, List<WorkItem__c> willDo, CheckoutResultDTO result) {
        if (mode == CartExperienceProfile.MODE_INVOICE) {
            generateProposal(willDo, result);
            return;
        }
        if (mode == CartExperienceProfile.MODE_STRIPE) {
            // TODO(seam): paid checkout. DeliveryStripePaymentHandler is an INBOUND
            // webhook event handler (charge.succeeded -> DeliveryTransaction__c), not an
            // outbound payment initiator. A real Stripe checkout needs a Checkout Session
            // / Payment Link callout that does not exist yet. Activation is the real,
            // load-bearing behavior; the payment hand-off is intentionally not faked.
            result.message = 'Lines activated. Stripe paid-checkout hand-off is a pending integration seam.';
            return;
        }
        // Approve
        // TODO(seam): approval routing. The shipped approval rails
        // (DeliveryFeatureApprovalService.submit) key on Feature__c toggle requests, not
        // on a basket of WorkItems. A WorkItem-basket approval object/flow does not exist
        // yet. Activation is the real behavior; the approval hand-off is a noted seam.
        result.message = 'Lines activated. Approval routing for a WorkItem basket is a pending seam.';
    }

    /**
     * @description Generates a Client_Agreement proposal for the committed lines when
     *              they share exactly one client NetworkEntity. When the lines span
     *              zero or many client entities (ambiguous), activation stands and the
     *              result notes that no single-client proposal was generated — no
     *              fabricated document.
     */
    private static void generateProposal(List<WorkItem__c> willDo, CheckoutResultDTO result) {
        Set<Id> entityIds = new Set<Id>();
        for (WorkItem__c wi : willDo) {
            if (wi.ClientNetworkEntityLookup__c != null) {
                entityIds.add(wi.ClientNetworkEntityLookup__c);
            }
        }
        if (entityIds.size() != 1) {
            result.message = 'Lines activated. Proposal not generated — committed lines span '
                + entityIds.size() + ' client entities (need exactly one).';
            return;
        }
        Id entityId = new List<Id>(entityIds)[0];
        Date today = Date.today();
        try {
            result.documentId = DeliveryDocGenerationService.generateDocument(
                entityId, 'Client_Agreement', today, today, null);
            result.message = 'Lines activated and a Client Agreement proposal was generated.';
        } catch (Exception docEx) {
            // Don't roll back the activation if proposal generation fails — the cart
            // crossing into the pipeline is the primary effect.
            result.message = 'Lines activated. Proposal generation failed: ' + docEx.getMessage();
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private static AuraHandledException toAura(Exception e) {
        if (e instanceof AuraHandledException) {
            return (AuraHandledException) e;
        }
        AuraHandledException ahe = new AuraHandledException(e.getMessage());
        ahe.setMessage(e.getMessage());
        return ahe;
    }
}
