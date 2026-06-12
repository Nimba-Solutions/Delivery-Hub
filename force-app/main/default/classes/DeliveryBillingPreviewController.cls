/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read-only monthly billing close-out feed for the
 *               deliveryBillingPreview LWC (approval-queue spec §9 — the
 *               "Approved vs Logged vs Billable" view): for every WorkItem
 *               carrying a client-approved cap (ClientPreApprovedHoursNumber__c
 *               &gt; 0), shows what was logged in the selected calendar month,
 *               how much of it is billable under the cap, and the over-cap
 *               excess that is NOT billable until a budget increase is
 *               approved. The total billable figure is the invoice preview
 *               that should ≈ the actual invoice — no-invoice-surprises,
 *               made visible.
 *
 *               v1 billable formula (kept deliberately simple):
 *                 headroom = MAX(0, approvedCap − loggedBeforeThisMonth)
 *                 billable = MIN(monthLogged, headroom)
 *                 overCap  = monthLogged − billable
 *               where loggedBeforeThisMonth is the item's LIFETIME logged
 *               hours prior to the selected month (a proxy for cap headroom
 *               already consumed — v1 assumes all prior logged hours drew
 *               against the cap; there is no per-invoice billed-to-date
 *               ledger yet).
 *
 *               Dollars: mirrors DeliveryHoursAnalyticsController's
 *               resolveBlendedRate — a single blended hourly rate is surfaced
 *               only when EXACTLY ONE active NetworkEntity__c carries a
 *               DefaultHourlyRateCurrency__c; zero or many distinct rates is
 *               ambiguous → hours-only display.
 *
 *               SOQL is WITH SYSTEM_MODE per CLAUDE.md (WITH USER_MODE breaks
 *               in namespaced package test context). Kept separate from
 *               DeliveryApprovalSummaryController (the agenda card feed) so
 *               the close-out view can evolve independently.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryBillingPreviewController {

    /** @description Hard cap on capped WorkItems scanned for the preview. */
    private static final Integer MAX_CAPPED_ITEMS = 1000;

    /** @description Hard cap on the per-item WorkLog aggregate rows consumed. */
    private static final Integer MAX_AGGREGATE_ROWS = 5000;

    /** @description Three-letter month names for the headline label. */
    private static final List<String> MONTH_NAMES = new List<String>{
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    };

    /** @description One per-item Approved vs Logged vs Billable row. */
    public class BillingRowDTO {
        @AuraEnabled public Id workItemId;
        /** Brief description, else the WorkItem auto-number Name (mirrors the forecast drill-down fallback). */
        @AuraEnabled public String label;
        /** The client-approved cap (ClientPreApprovedHoursNumber__c). */
        @AuraEnabled public Decimal approvedCap;
        /** Lifetime hours logged BEFORE the selected month (v1 headroom proxy). */
        @AuraEnabled public Decimal loggedBefore;
        /** Hours logged inside the selected calendar month. */
        @AuraEnabled public Decimal monthLogged;
        /** MIN(monthLogged, MAX(0, approvedCap − loggedBefore)). */
        @AuraEnabled public Decimal billable;
        /** monthLogged − billable: the non-billable over-cap excess this month. */
        @AuraEnabled public Decimal overCap;
        /** True when any of this month's hours exceed the remaining cap headroom. */
        @AuraEnabled public Boolean isOverCap;
    }

    /** @description The month's billing close-out: per-item rows + totals + optional dollars. */
    public class BillingPreviewDTO {
        @AuraEnabled public Integer year;
        @AuraEnabled public Integer month;
        /** Display label for the selected month, e.g. "Jun 2026". */
        @AuraEnabled public String monthLabel;
        /** Single blended hourly rate, or null when zero/many rates exist (hours-only). */
        @AuraEnabled public Decimal blendedRate;
        /** Count of WorkItems carrying a cap, whether or not they logged this month. */
        @AuraEnabled public Integer cappedItemCount;
        /** Sum of approvedCap across the rows shown (items that logged this month). */
        @AuraEnabled public Decimal totalApprovedCap;
        /** Sum of monthLogged across the rows shown. */
        @AuraEnabled public Decimal totalMonthLogged;
        /** Sum of billable across the rows shown — the invoice preview headline. */
        @AuraEnabled public Decimal totalBillable;
        /** Sum of overCap across the rows shown — hours parked pending an increase. */
        @AuraEnabled public Decimal totalOverCap;
        /** totalBillable × blendedRate, or null when no unambiguous rate resolves. */
        @AuraEnabled public Decimal totalBillableAmount;
        /** Per-item rows (only items that logged hours in the selected month), monthLogged desc. */
        @AuraEnabled public List<BillingRowDTO> rows;
    }

    /**
     * @description Builds the monthly Approved vs Logged vs Billable close-out:
     *              one row per capped WorkItem that logged hours in the selected
     *              calendar month, with the v1 billable split (see class doc),
     *              plus totals and the optional blended-rate dollar figure.
     * @param year Calendar year of the month to preview. Null defaults to the
     *             current year (both params null = current month).
     * @param month Calendar month 1–12. Null defaults to the current month.
     * @return BillingPreviewDTO; numbers default to 0 and rows to empty — never null.
     */
    @AuraEnabled(cacheable=true)
    public static BillingPreviewDTO getBillingPreview(Integer year, Integer month) {
        try {
            Date today = Date.today();
            Integer effectiveYear = (year == null) ? today.year() : year;
            Integer effectiveMonth = (month == null) ? today.month() : month;
            if (effectiveMonth < 1 || effectiveMonth > 12) {
                throw new AuraHandledException('month must be between 1 and 12.');
            }
            if (effectiveYear < 1900 || effectiveYear > 2200) {
                throw new AuraHandledException('year is out of range.');
            }

            Date monthStart = Date.newInstance(effectiveYear, effectiveMonth, 1);
            Date monthEnd = monthStart.addMonths(1).addDays(-1);

            BillingPreviewDTO dto = new BillingPreviewDTO();
            dto.year = effectiveYear;
            dto.month = effectiveMonth;
            dto.monthLabel = MONTH_NAMES[effectiveMonth - 1] + ' ' + effectiveYear;
            dto.rows = new List<BillingRowDTO>();
            dto.totalApprovedCap = 0;
            dto.totalMonthLogged = 0;
            dto.totalBillable = 0;
            dto.totalOverCap = 0;

            List<WorkItem__c> cappedItems = queryCappedItems();
            dto.cappedItemCount = cappedItems.size();

            if (!cappedItems.isEmpty()) {
                Set<Id> itemIds = new Map<Id, WorkItem__c>(cappedItems).keySet();
                Map<Id, Decimal> monthLoggedByItem =
                    sumLoggedByItem(itemIds, monthStart, monthEnd);
                Map<Id, Decimal> beforeLoggedByItem =
                    sumLoggedByItem(itemIds, null, monthStart.addDays(-1));
                buildRows(dto, cappedItems, monthLoggedByItem, beforeLoggedByItem);
            }

            sortRowsByMonthLoggedDesc(dto.rows);

            dto.blendedRate = resolveBlendedRate();
            if (dto.blendedRate != null) {
                dto.totalBillableAmount = (dto.totalBillable * dto.blendedRate)
                    .setScale(2, System.RoundingMode.HALF_UP);
            }
            return dto;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description All WorkItems carrying a positive client-approved cap — the
     *              billing universe. Deliberately NOT filtered by stage or
     *              activation: a capped item that logged hours this month
     *              belongs on the invoice preview regardless of board state.
     * @return Capped WorkItems (id + label fields + cap), LIMIT-guarded.
     */
    private static List<WorkItem__c> queryCappedItems() {
        return [
            SELECT Id, Name, BriefDescriptionTxt__c, ClientPreApprovedHoursNumber__c
            FROM WorkItem__c
            WHERE ClientPreApprovedHoursNumber__c > 0
            WITH SYSTEM_MODE
            LIMIT :MAX_CAPPED_ITEMS
        ];
    }

    /**
     * @description One grouped WorkLog aggregate: per-item SUM(HoursLoggedNumber__c)
     *              over an optional WorkDateDate__c window. Passing a null
     *              windowStart makes the window open-ended on the left (lifetime
     *              logged up to windowEnd — the loggedBefore aggregate).
     * @param itemIds The capped WorkItem ids.
     * @param windowStart Inclusive lower bound, or null for open-ended.
     * @param windowEnd Inclusive upper bound.
     * @return Map of WorkItem id → summed hours (items with no logs absent).
     */
    private static Map<Id, Decimal> sumLoggedByItem(Set<Id> itemIds, Date windowStart, Date windowEnd) {
        List<AggregateResult> results;
        if (windowStart == null) {
            results = [
                SELECT WorkItemLookup__c wid, SUM(HoursLoggedNumber__c) total
                FROM WorkLog__c
                WHERE WorkItemLookup__c IN :itemIds
                  AND WorkDateDate__c <= :windowEnd
                WITH SYSTEM_MODE
                GROUP BY WorkItemLookup__c
                LIMIT :MAX_AGGREGATE_ROWS
            ];
        } else {
            results = [
                SELECT WorkItemLookup__c wid, SUM(HoursLoggedNumber__c) total
                FROM WorkLog__c
                WHERE WorkItemLookup__c IN :itemIds
                  AND WorkDateDate__c >= :windowStart
                  AND WorkDateDate__c <= :windowEnd
                WITH SYSTEM_MODE
                GROUP BY WorkItemLookup__c
                LIMIT :MAX_AGGREGATE_ROWS
            ];
        }
        Map<Id, Decimal> byItem = new Map<Id, Decimal>();
        for (AggregateResult ar : results) {
            Object widObj = ar.get('wid');
            Object totalObj = ar.get('total');
            if (widObj != null && totalObj != null) {
                byItem.put((Id) widObj, (Decimal) totalObj);
            }
        }
        return byItem;
    }

    /**
     * @description Applies the v1 billable formula per capped item and appends a
     *              row for every item that logged hours in the selected month,
     *              accumulating the DTO totals as it goes. Items with no
     *              month activity are skipped (they contribute nothing to the
     *              invoice) but still count in cappedItemCount.
     * @param dto The DTO being filled (rows + totals).
     * @param cappedItems The capped-WorkItem universe.
     * @param monthLoggedByItem Per-item hours logged inside the month.
     * @param beforeLoggedByItem Per-item lifetime hours logged before the month.
     */
    private static void buildRows(
        BillingPreviewDTO dto,
        List<WorkItem__c> cappedItems,
        Map<Id, Decimal> monthLoggedByItem,
        Map<Id, Decimal> beforeLoggedByItem
    ) {
        for (WorkItem__c wi : cappedItems) {
            Decimal monthLogged = monthLoggedByItem.containsKey(wi.Id)
                ? monthLoggedByItem.get(wi.Id) : 0;
            if (monthLogged <= 0) {
                continue;
            }
            Decimal cap = wi.ClientPreApprovedHoursNumber__c;
            Decimal loggedBefore = beforeLoggedByItem.containsKey(wi.Id)
                ? beforeLoggedByItem.get(wi.Id) : 0;
            Decimal headroom = cap - loggedBefore;
            if (headroom < 0) {
                headroom = 0;
            }
            Decimal billable = (monthLogged < headroom) ? monthLogged : headroom;

            BillingRowDTO row = new BillingRowDTO();
            row.workItemId = wi.Id;
            // Brief description, else the auto-number Name — mirrors the forecast
            // drill-down name fallback so the invoice preview never shows raw ids.
            row.label = String.isNotBlank(wi.BriefDescriptionTxt__c)
                ? wi.BriefDescriptionTxt__c : wi.Name;
            row.approvedCap = cap;
            row.loggedBefore = loggedBefore.setScale(2, System.RoundingMode.HALF_UP);
            row.monthLogged = monthLogged.setScale(2, System.RoundingMode.HALF_UP);
            row.billable = billable.setScale(2, System.RoundingMode.HALF_UP);
            row.overCap = (monthLogged - billable).setScale(2, System.RoundingMode.HALF_UP);
            row.isOverCap = row.overCap > 0;
            dto.rows.add(row);

            dto.totalApprovedCap += cap;
            dto.totalMonthLogged += row.monthLogged;
            dto.totalBillable += row.billable;
            dto.totalOverCap += row.overCap;
        }
        dto.totalApprovedCap = dto.totalApprovedCap.setScale(2, System.RoundingMode.HALF_UP);
        dto.totalMonthLogged = dto.totalMonthLogged.setScale(2, System.RoundingMode.HALF_UP);
        dto.totalBillable = dto.totalBillable.setScale(2, System.RoundingMode.HALF_UP);
        dto.totalOverCap = dto.totalOverCap.setScale(2, System.RoundingMode.HALF_UP);
    }

    /**
     * @description In-place sort of the rows by monthLogged desc so the biggest
     *              line items lead the invoice preview (same simple selection
     *              swap the forecast drill-down uses — row counts are small).
     * @param rows The rows to sort.
     */
    private static void sortRowsByMonthLoggedDesc(List<BillingRowDTO> rows) {
        for (Integer i = 0; i < rows.size(); i++) {
            for (Integer j = i + 1; j < rows.size(); j++) {
                if (rows[j].monthLogged > rows[i].monthLogged) {
                    BillingRowDTO tmp = rows[i];
                    rows[i] = rows[j];
                    rows[j] = tmp;
                }
            }
        }
    }

    /**
     * @description Reads a single blended hourly rate when EXACTLY ONE active
     *              NetworkEntity carries a DefaultHourlyRateCurrency__c, so the
     *              LWC can render the ≈ $ figure. Returns null when zero or
     *              many distinct rates exist (ambiguous — hours-only display).
     *              Mirrors DeliveryHoursAnalyticsController.resolveBlendedRate
     *              (private there) so the billing preview and the pacing card
     *              can never disagree on the rate.
     * @return The single blended rate, or null when ambiguous.
     */
    private static Decimal resolveBlendedRate() {
        List<NetworkEntity__c> rated = [
            SELECT DefaultHourlyRateCurrency__c
            FROM NetworkEntity__c
            WHERE DefaultHourlyRateCurrency__c != NULL
              AND DefaultHourlyRateCurrency__c > 0
              AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            LIMIT 2
        ];
        if (rated.size() == 1) {
            return rated[0].DefaultHourlyRateCurrency__c;
        }
        return null;
    }
}
