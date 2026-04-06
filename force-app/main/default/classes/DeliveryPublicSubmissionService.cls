/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description REST Resource for receiving unauthenticated work item submissions from
 * public-facing websites (e.g., cloudnimbusllc.com contact forms). Exposed via
 * Salesforce Sites / Experience Cloud guest user. Includes rate limiting and input
 * sanitization to prevent abuse.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
@RestResource(urlMapping='/deliveryhub/v1/submit')
global without sharing class DeliveryPublicSubmissionService {

    /** Maximum submissions allowed per email address within the rate limit window. */
    private static final Integer RATE_LIMIT_MAX = 5;

    /** Rate limit window in hours. */
    private static final Integer RATE_LIMIT_HOURS = 1;

    /** Maximum allowed length for the description field. */
    private static final Integer MAX_DESCRIPTION_LENGTH = 32000;

    /** Maximum allowed length for the title (matches BriefDescriptionTxt__c field size minus prefix). */
    private static final Integer MAX_TITLE_LENGTH = 88;

    /**
     * @description Wrapper for validated submission input.
     */
    private class SubmissionInput {
        String title;
        String email;
        String description;
        String submitterName;
        String priority;
        String requestType;
        String tags;
        String entityId;
    }

    /**
     * @description Handles incoming HTTP POST requests containing a public work item submission.
     * Parses JSON body, validates required fields, enforces rate limiting, creates a WorkItem__c,
     * and writes a JSON response with the new record's Id and auto-number.
     */
    @HttpPost
    global static void submitWorkItem() {
        RestResponse res = RestContext.response;
        try {
            SubmissionInput input = parseAndValidateInput(res);
            if (input == null) {
                return;
            }

            WorkItem__c newItem = buildWorkItem(input);
            Database.insert(newItem, AccessLevel.SYSTEM_MODE);

            WorkItem__c created = [
                SELECT Id, Name FROM WorkItem__c
                WHERE Id = :newItem.Id WITH SYSTEM_MODE LIMIT 1
            ];

            sendResponse(res, 201, new Map<String, Object>{
                'success' => true,
                'workItemId' => created.Id,
                'workItemNumber' => created.Name
            });
        } catch (Exception e) {
            sendResponse(res, 500, new Map<String, Object>{
                'success' => false,
                'error' => 'An unexpected error occurred. Please try again.'
            });
        }
    }

    // -------------------------------------------------------------------------
    // Parsing & Validation
    // -------------------------------------------------------------------------

    /**
     * @description Parses the request body, validates required fields, and enforces rate limiting.
     *              Returns a SubmissionInput on success, or null if validation failed (response already set).
     * @param res The REST response object (for writing errors)
     * @return Validated SubmissionInput, or null if an error response was written
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    private static SubmissionInput parseAndValidateInput(RestResponse res) {
        String jsonBody = RestContext.request.requestBody.toString();
        if (String.isBlank(jsonBody)) {
            sendResponse(res, 400, errorMap('Request body is required.'));
            return null;
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

        String title = sanitizePlainText((String) body.get('title'));
        String email = (String) body.get('email');

        if (String.isBlank(title)) {
            sendResponse(res, 400, errorMap('Title is required.'));
            return null;
        }
        if (String.isBlank(email)) {
            sendResponse(res, 400, errorMap('Email is required.'));
            return null;
        }
        if (!isValidEmail(email)) {
            sendResponse(res, 400, errorMap('A valid email address is required.'));
            return null;
        }

        DateTime windowStart = DateTime.now().addHours(-RATE_LIMIT_HOURS);
        Integer recentCount = [
            SELECT COUNT() FROM WorkItem__c
            WHERE ExternalRequesterEmailTxt__c = :email
            AND CreatedDate >= :windowStart
            WITH SYSTEM_MODE
        ];
        if (recentCount >= RATE_LIMIT_MAX) {
            sendResponse(res, 429, errorMap('Rate limit exceeded. Please try again later.'));
            return null;
        }

        if (title.length() > MAX_TITLE_LENGTH) {
            title = title.substring(0, MAX_TITLE_LENGTH);
        }

        String priority = (String) body.get('priority');
        Set<String> validPriorities = new Set<String>{ 'Low', 'Medium', 'High' };
        if (String.isBlank(priority) || !validPriorities.contains(priority)) {
            priority = 'Medium';
        }

        String description = (String) body.get('description');
        if (String.isNotBlank(description) && description.length() > MAX_DESCRIPTION_LENGTH) {
            description = description.substring(0, MAX_DESCRIPTION_LENGTH);
        }

        SubmissionInput input = new SubmissionInput();
        input.title = title;
        input.email = email;
        input.description = description;
        input.submitterName = sanitizePlainText((String) body.get('name'));
        input.priority = priority;
        input.requestType = (String) body.get('requestType');
        input.tags = sanitizePlainText((String) body.get('tags'));
        input.entityId = (String) body.get('entityId');
        return input;
    }

    // -------------------------------------------------------------------------
    // Work Item Builder
    // -------------------------------------------------------------------------

    /**
     * @description Assembles a WorkItem__c record from validated input.
     * @param input Validated SubmissionInput
     * @return New WorkItem__c ready for insert
     */
    private static WorkItem__c buildWorkItem(SubmissionInput input) {
        Id resolvedEntityId = resolveNetworkEntity(input.entityId);
        String fullDescription = buildDescription(input.description, input.submitterName, input.email);

        WorkItem__c newItem = new WorkItem__c();
        newItem.BriefDescriptionTxt__c = '[Public] ' + input.title;
        newItem.DetailsTxt__c = fullDescription;
        newItem.ExternalRequesterEmailTxt__c = input.email;
        newItem.StageNamePk__c = 'Backlog';
        newItem.PriorityPk__c = input.priority;
        newItem.RequestTypePk__c = String.isNotBlank(input.requestType) ? input.requestType : 'Public Lead';
        newItem.ActivatedDateTime__c = Datetime.now();
        newItem.StatusPk__c = 'New';

        if (String.isNotBlank(input.tags)) {
            newItem.TagsTxt__c = input.tags.length() > 255 ? input.tags.substring(0, 255) : input.tags;
        }

        if (resolvedEntityId != null) {
            newItem.ClientNetworkEntityId__c = resolvedEntityId;
        }

        return newItem;
    }

    // -------------------------------------------------------------------------
    // Response helpers
    // -------------------------------------------------------------------------

    /**
     * @description Writes a JSON response to the RestResponse body with the given status code.
     * @param res The REST response object
     * @param statusCode HTTP status code
     * @param payload Map to serialize as JSON response body
     */
    private static void sendResponse(RestResponse res, Integer statusCode, Map<String, Object> payload) {
        res.statusCode = statusCode;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(payload));
    }

    /**
     * @description Builds a standard error payload map.
     * @param message Error message
     * @return Map with success=false and the error message
     */
    private static Map<String, Object> errorMap(String message) {
        return new Map<String, Object>{
            'success' => false,
            'error' => message
        };
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /**
     * @description Strips HTML tags from input text to prevent XSS. Returns null if input is blank.
     * @param input Raw input string
     * @return Sanitized plain text
     */
    private static String sanitizePlainText(String input) {
        if (String.isBlank(input)) {
            return input;
        }
        return input.replaceAll('<[^>]+>', '').trim();
    }

    /**
     * @description Validates email format using a basic regex pattern.
     * @param email The email string to validate
     * @return true if the email appears valid
     */
    private static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) {
            return false;
        }
        String emailPattern = '^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$';
        return Pattern.matches(emailPattern, email.trim());
    }

    /**
     * @description Resolves the NetworkEntity to link the work item to.
     * If a valid entityId is provided, validates it exists and is a Client or Both entity.
     * Otherwise, falls back to the first active Client entity.
     * @param entityId Optional entity Id from the request
     * @return Resolved NetworkEntity Id, or null if none found
     */
    private static Id resolveNetworkEntity(String entityId) {
        if (String.isNotBlank(entityId)) {
            Id parsedId = parseIdSafe(entityId);
            if (parsedId != null) {
                List<NetworkEntity__c> entities = [
                    SELECT Id FROM NetworkEntity__c
                    WHERE Id = :parsedId
                    AND EntityTypePk__c IN ('Client', 'Both')
                    AND StatusPk__c = 'Active'
                    WITH SYSTEM_MODE LIMIT 1
                ];
                if (!entities.isEmpty()) {
                    return entities[0].Id;
                }
            }
        }

        List<NetworkEntity__c> defaults = [
            SELECT Id FROM NetworkEntity__c
            WHERE EntityTypePk__c IN ('Client', 'Both')
            AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC LIMIT 1
        ];
        return defaults.isEmpty() ? null : defaults[0].Id;
    }

    /**
     * @description Safely parses a string to an Id, returning null on invalid format.
     * @param value String to parse
     * @return Id if valid, null otherwise
     */
    private static Id parseIdSafe(String value) {
        try {
            return Id.valueOf(value);
        } catch (StringException e) {
            return null;
        }
    }

    /**
     * @description Builds a rich-text description that prepends submitter metadata
     * (name + email) above the user-provided description.
     * @param description Raw description from the request body
     * @param submitterName Name of the submitter (optional)
     * @param email Email of the submitter
     * @return Formatted HTML description with submitter info
     */
    private static String buildDescription(String description, String submitterName, String email) {
        String header = '<p><b>Submitted by:</b> ';
        if (String.isNotBlank(submitterName)) {
            header += String.escapeSingleQuotes(submitterName) + ' &lt;' + String.escapeSingleQuotes(email) + '&gt;';
        } else {
            header += String.escapeSingleQuotes(email);
        }
        header += '</p><hr/>';

        if (String.isNotBlank(description)) {
            return header + description;
        }
        return header;
    }
}
