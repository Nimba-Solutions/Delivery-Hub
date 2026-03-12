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
@RestResource(urlMapping='/delivery/deliveryhub/v1/submit')
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
     * @description Handles incoming HTTP POST requests containing a public work item submission.
     * Parses JSON body, validates required fields, enforces rate limiting, creates a WorkItem__c,
     * and returns the new record's Id and auto-number.
     *
     * Expected JSON body:
     * {
     *   "title": "I need help with X",
     *   "description": "Detailed description...",
     *   "email": "submitter@example.com",
     *   "name": "John Doe",
     *   "priority": "Medium",
     *   "requestType": "Feature",
     *   "tags": "portal,lead",
     *   "entityId": "optional-network-entity-id"
     * }
     *
     * @return Map containing success status, workItemId, and workItemNumber on success,
     *         or success=false with error message on failure.
     */
    @HttpPost
    global static Map<String, Object> submitWorkItem() {
        RestResponse res = RestContext.response;
        try {
            // 1. Parse request body
            String jsonBody = RestContext.request.requestBody.toString();
            if (String.isBlank(jsonBody)) {
                return errorResponse(res, 400, 'Request body is required.');
            }

            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

            // 2. Extract and validate required fields
            String title = sanitizePlainText((String) body.get('title'));
            String email = (String) body.get('email');

            if (String.isBlank(title)) {
                return errorResponse(res, 400, 'Title is required.');
            }
            if (String.isBlank(email)) {
                return errorResponse(res, 400, 'Email is required.');
            }
            if (!isValidEmail(email)) {
                return errorResponse(res, 400, 'A valid email address is required.');
            }

            // 3. Rate limiting: check recent submissions from this email
            DateTime windowStart = DateTime.now().addHours(-RATE_LIMIT_HOURS);
            Integer recentCount = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE ExternalRequesterEmailTxt__c = :email
                AND CreatedDate >= :windowStart
                WITH SYSTEM_MODE
            ];

            if (recentCount >= RATE_LIMIT_MAX) {
                return errorResponse(res, 429, 'Rate limit exceeded. Please try again later.');
            }

            // 4. Extract optional fields
            String description = (String) body.get('description');
            String submitterName = sanitizePlainText((String) body.get('name'));
            String priority = (String) body.get('priority');
            String requestType = (String) body.get('requestType');
            String tags = sanitizePlainText((String) body.get('tags'));
            String entityId = (String) body.get('entityId');

            // Sanitize description length
            if (String.isNotBlank(description) && description.length() > MAX_DESCRIPTION_LENGTH) {
                description = description.substring(0, MAX_DESCRIPTION_LENGTH);
            }

            // Truncate title to fit field (100 chars minus "[Public] " prefix = 88)
            if (title.length() > MAX_TITLE_LENGTH) {
                title = title.substring(0, MAX_TITLE_LENGTH);
            }

            // Validate priority against allowed values
            Set<String> validPriorities = new Set<String>{ 'Low', 'Medium', 'High' };
            if (String.isBlank(priority) || !validPriorities.contains(priority)) {
                priority = 'Medium';
            }

            // 5. Resolve NetworkEntity
            Id resolvedEntityId = resolveNetworkEntity(entityId);

            // 6. Build the description with submitter metadata
            String fullDescription = buildDescription(description, submitterName, email);

            // 7. Create the WorkItem__c
            WorkItem__c newItem = new WorkItem__c();
            newItem.BriefDescriptionTxt__c = '[Public] ' + title;
            newItem.DetailsTxt__c = fullDescription;
            newItem.ExternalRequesterEmailTxt__c = email;
            newItem.StageNamePk__c = 'Backlog';
            newItem.PriorityPk__c = priority;
            newItem.RequestTypePk__c = String.isNotBlank(requestType) ? requestType : 'Public Lead';
            newItem.IsActiveBool__c = true;
            newItem.StatusPk__c = 'New';

            if (String.isNotBlank(tags)) {
                // Limit tags to 255 chars (Text field max)
                newItem.Tags__c = tags.length() > 255 ? tags.substring(0, 255) : tags;
            }

            if (resolvedEntityId != null) {
                newItem.ClientNetworkEntityId__c = resolvedEntityId;
            }

            Database.insert(newItem, AccessLevel.SYSTEM_MODE);

            // 8. Re-query to get the auto-number Name field
            WorkItem__c created = [
                SELECT Id, Name
                FROM WorkItem__c
                WHERE Id = :newItem.Id
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            res.statusCode = 201;
            return new Map<String, Object>{
                'success' => true,
                'workItemId' => created.Id,
                'workItemNumber' => created.Name
            };

        } catch (Exception e) {
            return errorResponse(res, 500, 'An unexpected error occurred. Please try again.');
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /**
     * @description Builds an error response map and sets the HTTP status code.
     * @param res The REST response object
     * @param statusCode HTTP status code to return
     * @param message Error message
     * @return Map with success=false and the error message
     */
    private static Map<String, Object> errorResponse(RestResponse res, Integer statusCode, String message) {
        res.statusCode = statusCode;
        return new Map<String, Object>{
            'success' => false,
            'error' => message
        };
    }

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
        // Basic email pattern: something@something.something
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
        // If an explicit entityId was provided, validate it
        if (String.isNotBlank(entityId)) {
            try {
                Id parsedId = Id.valueOf(entityId);
                List<NetworkEntity__c> entities = [
                    SELECT Id
                    FROM NetworkEntity__c
                    WHERE Id = :parsedId
                    AND EntityTypePk__c IN ('Client', 'Both')
                    AND StatusPk__c = 'Active'
                    WITH SYSTEM_MODE
                    LIMIT 1
                ];
                if (!entities.isEmpty()) {
                    return entities[0].Id;
                }
            } catch (StringException e) {
                // Invalid Id format — fall through to default resolution
            }
        }

        // Fallback: find the first active Client entity
        List<NetworkEntity__c> defaults = [
            SELECT Id
            FROM NetworkEntity__c
            WHERE EntityTypePk__c IN ('Client', 'Both')
            AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return defaults.isEmpty() ? null : defaults[0].Id;
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
