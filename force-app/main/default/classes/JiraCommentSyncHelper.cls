public with sharing class JiraCommentSyncHelper {

    public static void handleAfterInsert(Map<Id, Ticket_Comment__c> commentMap) {
        Set<Id> ticketIds = new Set<Id>();
        for (Ticket_Comment__c comment : commentMap.values()) {
            ticketIds.add(comment.TicketId__c);
        }

        Map<Id, Ticket__c> ticketMap = new Map<Id, Ticket__c>(
            [SELECT Id, JiraTicketKeyTxt__c FROM Ticket__c WHERE Id IN :ticketIds]
        );

        List<Id> commentIdsToSync = new List<Id>();
        for (Ticket_Comment__c comment : commentMap.values()) {
            Ticket__c ticket = ticketMap.get(comment.TicketId__c);
            if (
                comment.SourcePk__c != 'Jira' &&
                !String.isBlank(comment.BodyTxt__c) &&
                String.isBlank(comment.JiraSyncStatusTxt__c) &&
                ticket != null &&
                !String.isBlank(ticket.JiraTicketKeyTxt__c)
            ) {
                commentIdsToSync.add(comment.Id);
            }
        }
        if (!commentIdsToSync.isEmpty()) {
            System.enqueueJob(new JiraCommentSyncHelperQueueable(commentIdsToSync));
        }
    }

    public class JiraCommentSyncHelperQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> commentIds;

        public JiraCommentSyncHelperQueueable(List<Id> commentIds) {
            this.commentIds = commentIds;
        }

        public void execute(QueueableContext context) {
            List<Ticket_Comment__c> comments = [
                SELECT Id, BodyTxt__c, TicketId__c, JiraSyncStatusTxt__c,
                       TicketId__r.JiraTicketKeyTxt__c,JiraCommentIdTxt__c
                FROM Ticket_Comment__c
                WHERE Id IN :commentIds
            ];
            
            List<Ticket_Comment__c> commentsToUpdate = new List<Ticket_Comment__c>();
            
            for (Ticket_Comment__c comment : comments) {
                String status;
                String jiraKey = comment.TicketId__r != null ? comment.TicketId__r.JiraTicketKeyTxt__c : null;
                String htmlCommentBody = comment.BodyTxt__c; // Original HTML body

                if (String.isBlank(jiraKey)) {
                    status = 'No Jira Key on ticket';
                } else if (String.isBlank(htmlCommentBody)) {
                    status = 'No comment body';
                } else {
                    try {
                        // --- CRITICAL CHANGE: Convert HTML to ADF here ---
                        String adfJsonBody = JiraCommentSyncHelper.convertHtmlToAdf(htmlCommentBody);

                        // Use JiraCallout to send the ADF JSON
                        HttpResponse res = JiraCallout.addComment(jiraKey, adfJsonBody); 
                         Map<String,Object> parsed =
                        (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                        System.debug('parsed'+parsed);
            
                        if (res != null && (res.getStatusCode() == 201 || res.getStatusCode() == 200)) {
                            status = 'Success';
                            comment.JiraCommentIdTxt__c = (String)parsed.get('id');
                        } else {
                            status = 'Error: ' + (res == null ? 'No response' : res.getStatusCode() + ' ' + res.getBody());
                        }
                    } catch (Exception e) {
                        status = 'Exception: ' + e.getMessage();
                    }
                }
                
                comment.JiraSyncStatusTxt__c = status;
                commentsToUpdate.add(comment);
            }
            
            if (!commentsToUpdate.isEmpty()) {
                update commentsToUpdate;
            }
        }
    }

    // Helper method to convert HTML to ADF JSON
    // This method will try to parse <p>, <b>, <strong>, <i>, <em>, and handle plain text.
    public static String convertHtmlToAdf(String htmlString) {
        if (String.isBlank(htmlString)) {
            return '{"version":1,"type":"doc","content":[]}';
        }

        // 1. Basic HTML Entity Decoding
        String cleanedHtml = htmlString;
        cleanedHtml = cleanedHtml.replaceAll('&amp;', '&'); // Must be first
        cleanedHtml = cleanedHtml.replaceAll('&lt;', '<');
        cleanedHtml = cleanedHtml.replaceAll('&gt;', '>');
        cleanedHtml = cleanedHtml.replaceAll('&quot;', '"');
        cleanedHtml = cleanedHtml.replaceAll('&apos;', '\'');
        cleanedHtml = cleanedHtml.replaceAll('&nbsp;', ' ');
        // Add more common entities if needed

        // 2. Wrap the entire content in a virtual <div> if not already.
        // This helps handle text that might not be inside <p> tags.
        // Use (?i) for case-insensitive matching of <div> and <p> tags.
        if (!Pattern.compile('(?i)^\\s*<p>').matcher(cleanedHtml).find() && !Pattern.compile('(?i)^\\s*<div>').matcher(cleanedHtml).find()) {
             cleanedHtml = '<div>' + cleanedHtml + '</div>';
        }


        // Use a JSONGenerator to build the ADF structure
        JSONGenerator gen = JSON.createGenerator(true); // true for pretty printing
        gen.writeStartObject(); // {
        gen.writeFieldName('version');
        gen.writeNumber(1);
        gen.writeFieldName('type');
        gen.writeString('doc');
        gen.writeFieldName('content');
        gen.writeStartArray(); // Start of 'content' array for top-level nodes (paragraphs, etc.)

        // Regex to find paragraphs and process them. Using (?is) for DOTALL and CASE_INSENSITIVE.
        Pattern pTagPattern = Pattern.compile('(?is)<p>(.*?)</p>'); 
        Matcher pTagMatcher = pTagPattern.matcher(cleanedHtml);
        
        // Track parts of the string that haven't been consumed by <p> tags
        Integer lastMatchEnd = 0;

        while (pTagMatcher.find()) {
            // Handle any plain text before this <p> tag
            if (pTagMatcher.start() > lastMatchEnd) {
                String leadingText = cleanedHtml.substring(lastMatchEnd, pTagMatcher.start()).trim();
                if (!String.isBlank(leadingText)) {
                    // Treat leading plain text as a paragraph, splitting by <br>
                    processPlainHtmlIntoParagraphs(gen, leadingText);
                }
            }

            String paragraphContent = pTagMatcher.group(1);
            writeParagraphNode(gen, paragraphContent);
            lastMatchEnd = pTagMatcher.end();
        }

        // Handle any remaining plain text after the last <p> tag
        if (lastMatchEnd < cleanedHtml.length()) {
            String trailingText = cleanedHtml.substring(lastMatchEnd).trim();
            if (!String.isBlank(trailingText)) {
                // If it's just raw text, remove outer div if it was wrapped by us
                trailingText = Pattern.compile('(?is)^<div>(.*?)</div>$').matcher(trailingText).replaceAll('$1');
                processPlainHtmlIntoParagraphs(gen, trailingText);
            }
        }
        
        // If no <p> tags were found at all, and there's still content, treat it as a single paragraph
        if (!pTagMatcher.find() && lastMatchEnd == 0 && !String.isBlank(cleanedHtml.trim())) {
            // Remove any leading/trailing <div> tags if it was wrapped by us
            String finalContent = Pattern.compile('(?is)^<div>(.*?)</div>$').matcher(cleanedHtml).replaceAll('$1').trim();
            processPlainHtmlIntoParagraphs(gen, finalContent);
        }


        gen.writeEndArray(); // End of 'content' array
        gen.writeEndObject(); // End of top-level object

        return gen.getAsString();
    }

    // Helper method to write a paragraph node and its content
    private static void writeParagraphNode(JSONGenerator gen, String htmlContent) {
        // Remove known, non-formatting inline tags that might remain (like span with ql-cursor)
        String cleanedContent = Pattern.compile('(?i)<span\\s+class="ql-cursor">.*?</span>').matcher(htmlContent).replaceAll(''); 
        cleanedContent = Pattern.compile('(?i)<span[^>]*>|</span>').matcher(cleanedContent).replaceAll(''); 

        if (String.isBlank(cleanedContent.trim())) { // Use trim() to check for actual content
             // If paragraph is empty or only contains removed tags, create an empty paragraph for spacing
            gen.writeStartObject(); 
            gen.writeFieldName('type'); gen.writeString('paragraph');
            gen.writeFieldName('content'); gen.writeStartArray(); gen.writeEndArray(); // Empty content for empty paragraph
            gen.writeEndObject();
            return;
        }

        gen.writeStartObject(); // Start of paragraph node {
        gen.writeFieldName('type');
        gen.writeString('paragraph');
        gen.writeFieldName('content');
        gen.writeStartArray(); // Start of content array for text and marks

        // This is the core logic to parse inline bold/italic and plain text
        List<Map<String, Object>> parts = parseInlineFormatting(cleanedContent);

        // Write the processed parts to JSONGenerator
        for (Map<String, Object> part : parts) {
            gen.writeStartObject();
            gen.writeFieldName('type');
            gen.writeString((String)part.get('type')); // Should be 'text'
            gen.writeFieldName('text');
            gen.writeString((String)part.get('text'));
            
            if (part.containsKey('marks') && !((List<Map<String, String>>)part.get('marks')).isEmpty()) {
                gen.writeFieldName('marks');
                gen.writeStartArray();
                for (Map<String, String> mark : (List<Map<String, String>>)part.get('marks')) {
                    gen.writeStartObject();
                    gen.writeFieldName('type');
                    gen.writeString(mark.get('type'));
                    gen.writeEndObject();
                }
                gen.writeEndArray();
            }
            gen.writeEndObject();
        }

        gen.writeEndArray(); // End of content array for text and marks
        gen.writeEndObject(); // End of paragraph node }
    }


    // Helper for parsing inline bold/italic and plain text
    private static List<Map<String, Object>> parseInlineFormatting(String htmlFragment) {
        List<Map<String, Object>> parts = new List<Map<String, Object>>();
        if (String.isBlank(htmlFragment)) return parts;

        String tempFragment = htmlFragment;
        Integer currentPos = 0;

        // Combined regex for bold and italic to handle them in sequence
        Pattern tagPattern = Pattern.compile('(?i)<(b|strong|i|em)>'); // (?i) for CASE_INSENSITIVE
        
        // This recursive-like parsing approach is more robust for nested elements
        while(currentPos < tempFragment.length()){
            Matcher tagMatcher = tagPattern.matcher(tempFragment).region(currentPos, tempFragment.length());
            
            if (tagMatcher.find() && tagMatcher.start() == currentPos) {
                // Found an opening tag
                String tag = tagMatcher.group(1).toLowerCase();
                String markType = '';
                if (tag == 'b' || tag == 'strong') {
                    markType = 'strong';
                } else if (tag == 'i' || tag == 'em') {
                    markType = 'em';
                }

                Integer openTagEnd = tagMatcher.end();
                Integer closeTagStart = findMatchingClosingTag(tempFragment, openTagEnd, tag);

                if (closeTagStart != -1) {
                    String innerContent = tempFragment.substring(openTagEnd, closeTagStart);
                    
                    // Recursively process inner content for nested formatting
                    List<Map<String, Object>> innerParts = parseInlineFormatting(innerContent);
                    
                    // Apply the current mark to all inner text nodes
                    for(Map<String, Object> innerPart : innerParts){
                        if(innerPart.get('type') == 'text'){
                            List<Map<String, String>> currentMarks = (List<Map<String, String>>)innerPart.get('marks');
                            if(currentMarks == null) currentMarks = new List<Map<String, String>>();
                            currentMarks.add(new Map<String, String>{'type' => markType});
                            innerPart.put('marks', currentMarks);
                        }
                        parts.add(innerPart);
                    }
                    currentPos = closeTagStart + ('</' + tag + '>').length(); // Move past closing tag
                } else {
                    // Mismatched tag, treat as plain text from currentPos to end of matched tag
                    // or until the next opening tag
                    String plainText = tempFragment.substring(currentPos, tagMatcher.end()); // Include the unmatched opening tag itself
                    addPlainTextPart(parts, plainText);
                    currentPos = tagMatcher.end(); // Move past the unmatched tag
                }
            } else {
                // No opening tag found at current position, treat as plain text until next tag or end
                Integer nextTagStart = tempFragment.indexOf('<', currentPos);
                String plainText;
                if(nextTagStart == -1){ // No more tags
                    plainText = tempFragment.substring(currentPos);
                    currentPos = tempFragment.length();
                } else {
                    plainText = tempFragment.substring(currentPos, nextTagStart);
                    currentPos = nextTagStart;
                }
                addPlainTextPart(parts, plainText);
            }
        }
        return parts;
    }

    // Helper to add a plain text part to the list
    private static void addPlainTextPart(List<Map<String, Object>> parts, String text) {
        if (!String.isBlank(text.trim())) {
            parts.add(new Map<String, Object>{
                'type' => 'text',
                'text' => text.trim(),
                'marks' => new List<Map<String, String>>() // Initialize as empty list
            });
        }
    }


    // Helper to find the matching closing tag for a given opening tag
    // Basic implementation, will not handle complex nested same-type tags perfectly
    private static Integer findMatchingClosingTag(String html, Integer startIndex, String tagName) {
        String openingTag = '<' + tagName + '>';
        String closingTag = '</' + tagName + '>';
        Integer currentSearchIndex = startIndex;
        Integer nestLevel = 1;

        while (currentSearchIndex < html.length()) { // Added boundary check for loop
            Integer nextOpen = html.indexOfIgnoreCase(openingTag, currentSearchIndex);
            Integer nextClose = html.indexOfIgnoreCase(closingTag, currentSearchIndex);

            if (nextClose == -1) {
                return -1; // No closing tag found from this point onwards
            }

            if (nextOpen != -1 && nextOpen < nextClose) {
                // Found a nested opening tag before the next closing tag
                nestLevel++;
                currentSearchIndex = nextOpen + openingTag.length();
            } else {
                // Found a closing tag
                nestLevel--;
                if (nestLevel == 0) {
                    return nextClose; // Found matching closing tag
                }
                currentSearchIndex = nextClose + closingTag.length();
            }
        }
        return -1; // Added: If loop finishes without finding a match, return -1
    }


    // Helper to process a block of plain HTML (potentially with <br>) into paragraphs
    private static void processPlainHtmlIntoParagraphs(JSONGenerator gen, String htmlSegment) {
        if (String.isBlank(htmlSegment.trim())) return;

        // Split by <br> tags to create separate paragraphs. (?i) for case-insensitive <br>.
        String[] lines = Pattern.compile('(?i)<br\\s*/*>').split(htmlSegment, 0); 
        for (String line : lines) {
            if (!String.isBlank(line.trim())) {
                writeParagraphNode(gen, line.trim());
            } else {
                // For consecutive <br> tags or empty lines, add an empty paragraph for spacing
                gen.writeStartObject(); 
                gen.writeFieldName('type'); gen.writeString('paragraph');
                gen.writeFieldName('content'); gen.writeStartArray(); gen.writeEndArray(); 
                gen.writeEndObject();
            }
        }
    }


    // A simpler HTML tag stripper for final cleanup or plain text fallback
    public static String stripHtmlTags(String htmlString) {
        if (String.isBlank(htmlString)) {
            return '';
        }
        // Remove all HTML tags
        String cleanedString = htmlString.replaceAll('<[^>]*>', '');
        return cleanedString.trim();
    }
    
    
    /**
     * @description Handles after update trigger events for Ticket_Comment__c records
     * Identifies comments that have been modified and need to be synchronized back to Jira
     * @param newCommentMap Map of updated comment records with new values
     * @param oldCommentMap Map of comment records with previous values
     */
    public static void handleAfterUpdate(Map<Id, Ticket_Comment__c> newCommentMap, Map<Id, Ticket_Comment__c> oldCommentMap) {
        Set<Id> ticketIds = new Set<Id>();
        for (Ticket_Comment__c comment : newCommentMap.values()) {
            ticketIds.add(comment.TicketId__c);
        }

        Map<Id, Ticket__c> ticketMap = new Map<Id, Ticket__c>(
            [SELECT Id, JiraTicketKeyTxt__c FROM Ticket__c WHERE Id IN :ticketIds]
        );

        List<Id> commentIdsToUpdate = new List<Id>();
        for (Id commentId : newCommentMap.keySet()) {
            Ticket_Comment__c newComment = newCommentMap.get(commentId);
            Ticket_Comment__c oldComment = oldCommentMap.get(commentId);
            Ticket__c ticket = ticketMap.get(newComment.TicketId__c);

            // Sync only if the body has changed, it's not from Jira, and it has a Jira Comment ID
            if (newComment.BodyTxt__c != oldComment.BodyTxt__c &&
                newComment.SourcePk__c != 'Jira' &&
                !String.isBlank(newComment.JiraCommentIdTxt__c) && // Must have a Jira ID to update
                ticket != null &&
                !String.isBlank(ticket.JiraTicketKeyTxt__c)) 
            {
                commentIdsToUpdate.add(newComment.Id);
            }
        }

        if (!commentIdsToUpdate.isEmpty()) {
            System.enqueueJob(new JiraCommentUpdateQueueable(commentIdsToUpdate));
        }
    }

    /**
     * @description Queueable class for updating existing comments in Jira when Salesforce comments are modified
     * This class handles the asynchronous processing of comment updates to Jira via API callouts
     */
    public class JiraCommentUpdateQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> commentIds;

        public JiraCommentUpdateQueueable(List<Id> commentIds) {
            this.commentIds = commentIds;
        }

        public void execute(QueueableContext context) {
            List<Ticket_Comment__c> commentsToProcess = [
                SELECT Id, BodyTxt__c, JiraCommentIdTxt__c, TicketId__r.JiraTicketKeyTxt__c
                FROM Ticket_Comment__c
                WHERE Id IN :this.commentIds
            ];

            List<Ticket_Comment__c> commentsToUpdateStatus = new List<Ticket_Comment__c>();
            for (Ticket_Comment__c comment : commentsToProcess) {
                String status;
                try {
                    String jiraKey = comment.TicketId__r.JiraTicketKeyTxt__c;
                    String jiraCommentId = comment.JiraCommentIdTxt__c;
                    String adfJsonBody = JiraCommentSyncHelper.convertHtmlToAdf(comment.BodyTxt__c);

                    // Make the callout to UPDATE the comment in Jira
                    HttpResponse res = JiraCallout.updateComment(jiraKey, jiraCommentId, adfJsonBody);

                    if (res != null && res.getStatusCode() == 200) {
                        status = 'Success';
                    } else {
                        status = 'Error: ' + (res == null ? 'No response' : res.getStatusCode() + ' ' + res.getBody());
                    }
                } catch (Exception e) {
                    status = 'Exception: ' + e.getMessage();
                }
                
                comment.JiraSyncStatusTxt__c = status;
                commentsToUpdateStatus.add(comment);
            }
            
            if (!commentsToUpdateStatus.isEmpty()) {
                update commentsToUpdateStatus;
            }
        }
    }
}