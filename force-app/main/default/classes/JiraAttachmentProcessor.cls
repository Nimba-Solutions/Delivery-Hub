public without sharing class JiraAttachmentProcessor implements Queueable, Database.AllowsCallouts {

    private Id ticketId;
    private String contentUrl;
    private String filename;

    public JiraAttachmentProcessor(Id ticketId, String contentUrl, String filename) {
        System.debug('JiraAttachmentProcessor JiraAttachmentProcessor ticketId'+ticketId);
        System.debug('contentUrl'+contentUrl);
        System.debug('filename'+filename);
        this.ticketId = ticketId;
        this.contentUrl = contentUrl;
        this.filename = filename;
    }

    public void execute(QueueableContext context) {
        System.debug('JiraAttachmentProcessor executing for ticket: ' + ticketId);
        
        try {
            // The callout is now in a separate transaction from the initial ticket update
            Blob fileBody = JiraAttachmentHandler.downloadAttachment(contentUrl, 0);
			
            if (fileBody != null) {
                /*File_Creation_Request__e event = new File_Creation_Request__e(
                    Parent_ID__c = this.ticketId,
                    FilenameTxt__c = this.filename,
                    File_Body_Base64__c = EncodingUtil.base64Encode(fileBody)
                );
                
                EventBus.publish(event);*/
                JiraAttachmentHandler.createSalesforceFile(ticketId,filename,fileBody);
                System.debug('Successfully processed attachment: ' + filename);
            }
        } catch (Exception e) {
            System.debug('JiraAttachmentProcessor failed: ' + e.getMessage());
            // Optionally, add error logging here
        }
    }
}