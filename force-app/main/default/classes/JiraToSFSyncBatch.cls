/**
* @File Name : JiraToSFSyncBatch.cls
* @Description : Batchable & Schedulable class to sync Jira changes into Salesforce.
* @Author :
* @Last Modified By :
* @Last Modified On : July 9, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | July 9, 2025 |   | Initial Version
**/

public with sharing class JiraToSFSyncBatch implements Database.Batchable<SObject>, Schedulable, Database.AllowsCallouts {

    public static Integer SYNC_WINDOW_MINS = 60; // Change as needed

    // Schedulable entry point
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new JiraToSFSyncBatch());
    }

    // Invocable for Flow/button use
    @InvocableMethod(label='Sync Tickets From Jira')
    public static void runOnDemand(List<Id> ids) {
        Database.executeBatch(new JiraToSFSyncBatch());
    }

    // Batch start: dummy query, all logic in execute()
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id FROM Ticket__c WHERE Id != null LIMIT 1]);
    }

    // Main batch logic
    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        DateTime lastSync = Datetime.now().addMinutes(-SYNC_WINDOW_MINS);
        String jql = 'updated >= "' + lastSync.formatGmt('yyyy/MM/dd HH:mm') + '"';

        List<Map<String, Object>> jiraIssues = JiraCallout.queryIssues(jql);
        List<String> jiraKeys = new List<String>();

        // 1. Collect all Jira keys
        for (Map<String, Object> issue : jiraIssues) {
            String jiraKey = (String)issue.get('key');
            if (jiraKey != null) jiraKeys.add(jiraKey);
        }

        // 2. Query all matching tickets in one go
        Map<String, Ticket__c> ticketsByJiraKey = new Map<String, Ticket__c>();
        if (!jiraKeys.isEmpty()) {
            for (Ticket__c t : [
                SELECT Id, JiraTicketKeyTxt__c, DetailsTxt__c, BriefDescriptionTxt__c, StageNamePk__c
                FROM Ticket__c
                WHERE JiraTicketKeyTxt__c IN :jiraKeys
            ]) {
                ticketsByJiraKey.put(t.JiraTicketKeyTxt__c, t);
            }
        }

        List<Ticket__c> ticketsToUpdate = new List<Ticket__c>();

        // 3. Loop through Jira issues and update as needed
        for (Map<String, Object> issue : jiraIssues) {
            String jiraKey = (String)issue.get('key');
            Ticket__c sfTicket = ticketsByJiraKey.get(jiraKey);
            if (sfTicket == null) continue;
            Map<String, Object> fields = (Map<String, Object>)issue.get('fields');

            // --- Robust updatedBy extraction ---
            String updatedBy = 'Jira User';
            if (fields.containsKey('updatedBy') && fields.get('updatedBy') != null) {
                Object updaterObj = fields.get('updatedBy');
                try {
                    Map<String, Object> updaterMap = (Map<String, Object>)updaterObj;
                    if (updaterMap.containsKey('displayName') && updaterMap.get('displayName') != null) {
                        updatedBy = String.valueOf(updaterMap.get('displayName'));
                    } else if (updaterMap.containsKey('emailAddress') && updaterMap.get('emailAddress') != null) {
                        updatedBy = String.valueOf(updaterMap.get('emailAddress'));
                    }
                } catch (Exception ex) {
                    // Not a Map, so treat as string
                    updatedBy = String.valueOf(updaterObj);
                }
            }

            Boolean needsUpdate = false;

            // --- Description sync ---
            /*
            Object jiraDescriptionObj = fields.get('description');
            String jiraDescription = jiraDescriptionObj != null ? JSON.serialize(jiraDescriptionObj) : null;
            if (sfTicket.DetailsTxt__c != jiraDescription) {
                AuditLogger.logFieldChange(
                    sfTicket.Id,
                    'Description',
                    sfTicket.DetailsTxt__c,
                    jiraDescription,
                    'Jira',
                    updatedBy
                );
                sfTicket.DetailsTxt__c = jiraDescription;
                needsUpdate = true;
            }*/

            // --- Status sync ---
            String jiraStatus = null;
            if (fields.containsKey('status')) {
                Map<String, Object> statusMap = (Map<String, Object>) fields.get('status');
                jiraStatus = statusMap != null && statusMap.containsKey('name') ? String.valueOf(statusMap.get('name')) : null;
            }
            if (jiraStatus != null && sfTicket.StageNamePk__c != jiraStatus) {
                AuditLogger.logFieldChange(
                    sfTicket.Id,
                    'Status',
                    sfTicket.StageNamePk__c,
                    jiraStatus,
                    'Jira',
                    updatedBy
                );
                sfTicket.StageNamePk__c = jiraStatus;
                needsUpdate = true;
            }

            if (needsUpdate) {
                ticketsToUpdate.add(sfTicket);
            }
        }
        if (!ticketsToUpdate.isEmpty()) {
            for(Ticket__c ticket:ticketsToUpdate) {
                ticket.JiraSyncStatusTxt__c = 'Synced From JIRA ' + String.valueOf(system.now());
            }
            update ticketsToUpdate;
        }
    }



    public void finish(Database.BatchableContext BC) {
        // Optionally log or notify on finish.
    }
}