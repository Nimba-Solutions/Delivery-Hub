/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Inbound Email Service handler that creates WorkItemComment__c records
 *               from incoming emails. Parses the work item number (e.g. T-0039) from
 *               the To address or Subject line, resolves the matching WorkItem__c, and
 *               inserts a comment. Feature is disabled by default — the sender must be
 *               a Salesforce user with EnableEmailNotificationsDateTime__c set in their
 *               DeliveryHubSettings__c hierarchy settings.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryInboundEmailHandler implements Messaging.InboundEmailHandler {

    @TestVisible
    private static final Pattern WORK_ITEM_PATTERN = Pattern.compile(
        '(?i)(?:workitem-)?T-?(\\d{1,6})'
    );

    /**
     * @description Processes inbound emails and creates WorkItemComment__c records from them.
     * @param email The inbound email message
     * @param envelope The inbound email envelope with sender/recipient info
     * @return InboundEmailResult indicating success or failure
     */
    public Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        User sender = resolveSender(email.fromAddress);
        if (sender == null) {
            result.success = false;
            result.message = 'Sender not found as an active Salesforce user.';
            return result;
        }
        if (!isSenderAuthorized(sender.Id)) {
            result.success = false;
            result.message = 'Email-to-comment is disabled for this user.';
            return result;
        }
        String workItemNumber = parseWorkItemNumber(email, envelope);
        if (String.isBlank(workItemNumber)) {
            result.success = false;
            result.message = 'Could not extract a work item number from the email.';
            return result;
        }
        WorkItem__c workItem = resolveWorkItem(workItemNumber);
        if (workItem == null) {
            result.success = false;
            result.message = 'No work item found matching: ' + workItemNumber;
            return result;
        }
        String commentBody = extractBody(email);
        WorkItemComment__c comment = new WorkItemComment__c(
            WorkItemId__c = workItem.Id,
            BodyTxt__c = commentBody,
            AuthorTxt__c = sender.Name,
            SourcePk__c = 'Email'
        );
        insert comment;
        DeliveryEmailService.notifyCommentSubscribers(workItem.Id, comment.Id, sender.Id);
        result.success = true;
        return result;
    }

    /**
     * @description Resolves the sender User record from the inbound email address.
     * @param fromAddress The sender's email address.
     * @return The matching active User, or null if not found.
     */
    @TestVisible
    private static User resolveSender(String fromAddress) {
        if (String.isBlank(fromAddress)) { return null; }
        List<User> users = [SELECT Id, Name, Email FROM User WHERE Email = :fromAddress AND IsActive = true WITH SYSTEM_MODE LIMIT 1];
        return users.isEmpty() ? null : users[0];
    }

    @TestVisible
    private static Boolean isSenderAuthorized(Id userId) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance(userId);
        return settings != null && settings.EnableEmailNotificationsDateTime__c != null;
    }

    @TestVisible
    private static String parseWorkItemNumber(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        if (email.toAddresses != null) {
            for (String toAddr : email.toAddresses) {
                String parsed = extractFromString(toAddr);
                if (parsed != null) { return parsed; }
            }
        }
        if (envelope != null && String.isNotBlank(envelope.toAddress)) {
            String parsed = extractFromString(envelope.toAddress);
            if (parsed != null) { return parsed; }
        }
        if (String.isNotBlank(email.subject)) { return extractFromString(email.subject); }
        return null;
    }

    @TestVisible
    private static String extractFromString(String input) {
        if (String.isBlank(input)) { return null; }
        Matcher m = WORK_ITEM_PATTERN.matcher(input);
        if (m.find()) {
            Integer num = Integer.valueOf(m.group(1));
            return 'T-' + String.valueOf(num).leftPad(4, '0');
        }
        return null;
    }

    @TestVisible
    private static WorkItem__c resolveWorkItem(String workItemName) {
        List<WorkItem__c> items = [SELECT Id, Name, BriefDescriptionTxt__c, DeveloperLookup__c, OwnerId FROM WorkItem__c WHERE Name = :workItemName WITH SYSTEM_MODE LIMIT 1];
        return items.isEmpty() ? null : items[0];
    }

    @TestVisible
    private static String extractBody(Messaging.InboundEmail email) {
        if (String.isNotBlank(email.plainTextBody)) { return stripReplyQuotes(email.plainTextBody); }
        if (String.isNotBlank(email.htmlBody)) { return email.htmlBody; }
        return '(empty email body)';
    }

    @TestVisible
    private static String stripReplyQuotes(String body) {
        if (String.isBlank(body)) { return body; }
        List<String> lines = body.split('\n');
        List<String> cleanLines = new List<String>();
        for (String line : lines) {
            if (line.startsWith('On ') && line.contains(' wrote:')) { break; }
            if (line.startsWith('>')) { break; }
            if (line.startsWith('From: ')) { break; }
            cleanLines.add(line);
        }
        String cleaned = String.join(cleanLines, '\n').trim();
        return String.isNotBlank(cleaned) ? cleaned : body.trim();
    }
}
