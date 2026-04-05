/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Centralized query service for WorkItem__c records. Provides a standard
 *               field set and reusable query methods to reduce scattered SOQL across the codebase.
 *               Field sets derived from the top 5 consumers: DeliveryHubBoardController (19 queries),
 *               DeliveryPortalController (12), DeliveryHubDashboardController (11),
 *               EscalationRuleEvaluator (2), and DeliveryGanttController (2).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ExcessiveParameterList')
public with sharing class WorkItemQueryService {

    // -------------------------------------------------------------------------
    // Standard field set — covers the most commonly needed fields across all consumers.
    // Suitable for list views, dashboards, escalation evaluation, and search results.
    // -------------------------------------------------------------------------
    public static final String STANDARD_FIELDS = 'Id, Name, BriefDescriptionTxt__c, StageNamePk__c, '
        + 'PriorityPk__c, StatusPk__c, WorkflowTypeTxt__c, ActivatedDateTime__c, '
        + 'TemplateMarkedDateTime__c, Developer__c, Developer__r.Name, OwnerId, '
        + 'ClientNetworkEntityId__c, ClientNetworkEntityId__r.Name, '
        + 'EstimatedHoursNumber__c, TotalLoggedHoursNumber__c, '
        + 'StageEnteredDateTime__c, CreatedDate, LastModifiedDate, CreatedBy.Name';

    // -------------------------------------------------------------------------
    // Extended field set — adds board/detail/Gantt-specific fields on top of STANDARD_FIELDS.
    // Suitable for board columns, detail panels, Gantt charts, and portal detail views.
    // -------------------------------------------------------------------------
    public static final String BOARD_FIELDS = STANDARD_FIELDS + ', '
        + 'RequestTypePk__c, DeveloperDaysSizeNumber__c, CalculatedETADate__c, '
        + 'SLATargetDate__c, SLAStatusTxt__c, ParentWorkItemId__c, '
        + 'ProjectedUATReadyDate__c, EstimatedStartDevDate__c, EstimatedEndDevDate__c, '
        + 'LastEscalatedDateTime__c, SortOrderNumber__c, Epic__c, Tags__c, '
        + 'ClientIntentionPk__c, DetailsTxt__c, CreatedById';

    // -------------------------------------------------------------------------
    // Active filter clause — the canonical "is an active work item" condition
    // used by board, dashboard, Gantt, escalation, and portal queries.
    // -------------------------------------------------------------------------
    private static final String ACTIVE_FILTER = 'ActivatedDateTime__c != null AND TemplateMarkedDateTime__c = null';

    /**
     * @description Returns work items by a set of record Ids using BOARD_FIELDS.
     * @param ids Set of WorkItem__c Ids to retrieve
     * @return List of matching WorkItem__c records
     */
    public static List<WorkItem__c> getByIds(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) {
            return new List<WorkItem__c>();
        }
        String whereClause = 'Id IN :ids';
        return queryWithFields(BOARD_FIELDS, whereClause, 'LastModifiedDate DESC', null, new Map<String, Object>{ 'ids' => ids });
    }

    /**
     * @description Returns active work items scoped to a single NetworkEntity using STANDARD_FIELDS.
     * @param entityId The ClientNetworkEntityId__c to filter by
     * @return List of active WorkItem__c records for the given entity
     */
    public static List<WorkItem__c> getActiveByEntity(Id entityId) {
        if (entityId == null) {
            return new List<WorkItem__c>();
        }
        String whereClause = ACTIVE_FILTER + ' AND ClientNetworkEntityId__c = :entityId';
        return queryWithFields(STANDARD_FIELDS, whereClause, 'LastModifiedDate DESC', null, new Map<String, Object>{ 'entityId' => entityId });
    }

    /**
     * @description Returns active work items whose StageNamePk__c is in the provided set.
     * @param stages Set of stage values to match
     * @return List of active WorkItem__c records in the specified stages
     */
    public static List<WorkItem__c> getActiveInStages(Set<String> stages) {
        if (stages == null || stages.isEmpty()) {
            return new List<WorkItem__c>();
        }
        String whereClause = ACTIVE_FILTER + ' AND StageNamePk__c IN :stages';
        return queryWithFields(STANDARD_FIELDS, whereClause, 'LastModifiedDate DESC', null, new Map<String, Object>{ 'stages' => stages });
    }

    /**
     * @description Returns all active work items using STANDARD_FIELDS.
     * @return List of all active WorkItem__c records
     */
    public static List<WorkItem__c> getActive() {
        return queryWithFields(STANDARD_FIELDS, ACTIVE_FILTER, 'LastModifiedDate DESC', null, new Map<String, Object>());
    }

    /**
     * @description Returns all active work items using the extended BOARD_FIELDS set.
     *              Suitable for board views, Gantt charts, and detail panels.
     * @return List of all active WorkItem__c records with board-level detail
     */
    public static List<WorkItem__c> getActiveWithBoardFields() {
        return queryWithFields(BOARD_FIELDS, ACTIVE_FILTER, 'SortOrderNumber__c ASC NULLS LAST, CreatedDate DESC', null, new Map<String, Object>());
    }

    /**
     * @description Returns active work items scoped to a NetworkEntity using BOARD_FIELDS.
     * @param entityId The ClientNetworkEntityId__c to filter by
     * @return List of active WorkItem__c records with board-level detail for the entity
     */
    public static List<WorkItem__c> getActiveWithBoardFieldsByEntity(Id entityId) {
        if (entityId == null) {
            return new List<WorkItem__c>();
        }
        String whereClause = ACTIVE_FILTER + ' AND ClientNetworkEntityId__c = :entityId';
        return queryWithFields(BOARD_FIELDS, whereClause, 'SortOrderNumber__c ASC NULLS LAST, CreatedDate DESC', null, new Map<String, Object>{ 'entityId' => entityId });
    }

    // -------------------------------------------------------------------------
    // Private helper — builds and executes dynamic SOQL with standard patterns
    // -------------------------------------------------------------------------

    /**
     * @description Executes a dynamic SOQL query against WorkItem__c with the specified
     *              field set, WHERE clause, ORDER BY, and optional LIMIT.
     * @param fields Comma-separated field API names to SELECT
     * @param additionalWhere WHERE clause conditions (without the WHERE keyword)
     * @param orderBy ORDER BY clause (without the ORDER BY keywords). Null for no ordering.
     * @param limitCount Optional record limit. Null for no limit.
     * @param bindVars Map of bind variable names to values for the WHERE clause
     * @return List of WorkItem__c records matching the query
     */
    private static List<WorkItem__c> queryWithFields(
        String fields,
        String additionalWhere,
        String orderBy,
        Integer limitCount,
        Map<String, Object> bindVars
    ) {
        String query = 'SELECT ' + fields + ' FROM WorkItem__c';

        if (String.isNotBlank(additionalWhere)) {
            query += ' WHERE ' + additionalWhere;
        }

        query += ' WITH SYSTEM_MODE';

        if (String.isNotBlank(orderBy)) {
            query += ' ORDER BY ' + orderBy;
        }

        if (limitCount != null && limitCount > 0) {
            query += ' LIMIT ' + limitCount;
        }

        return Database.queryWithBinds(query, bindVars, AccessLevel.SYSTEM_MODE);
    }
}
