@IsTest
private class DeliveryHubSetupControllerTest {

    @TestSetup
    static void makeData() {
        // 1. Create the Test User
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        User u = new User(
            Alias = 'sysadm', 
            Email='admin@testorg.com',
            EmailEncodingKey='UTF-8', 
            LastName='Testing', 
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', 
            ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='admin' + DateTime.now().getTime() + '@testorg.com'
        );
        insert u;

        // 2. DYNAMIC PERMISSION SET ASSIGNMENT
        // This grants the user Read/Edit access to the necessary objects/fields
        // so that 'WITH USER_MODE' does not crash the test.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            assignObjectPermissions(u);
        }
    }

    /**
     * @description Helper to create a temporary Permission Set for the test run.
     */
    static void assignObjectPermissions(User u) {
        PermissionSet ps = new PermissionSet(
            Name = 'DeliveryHubTestPerms', 
            Label = 'Delivery Hub Test Perms'
        );
        insert ps;

        // Grant Object Permissions (Read/Create/Edit)
        List<ObjectPermissions> objPerms = new List<ObjectPermissions>();
        objPerms.add(createObjPerm(ps.Id, 'Network_Entity__c'));
        objPerms.add(createObjPerm(ps.Id, 'Ticket__c'));
        objPerms.add(createObjPerm(ps.Id, 'Request__c'));
        insert objPerms;

        // Grant Field Permissions
        List<FieldPermissions> fieldPerms = new List<FieldPermissions>();
        // Network Entity Fields
        fieldPerms.add(createFieldPerm(ps.Id, 'Network_Entity__c', 'StatusPk__c'));
        fieldPerms.add(createFieldPerm(ps.Id, 'Network_Entity__c', 'IntegrationEndpointUrlTxt__c'));
        fieldPerms.add(createFieldPerm(ps.Id, 'Network_Entity__c', 'OrgIdTxt__c'));
        fieldPerms.add(createFieldPerm(ps.Id, 'Network_Entity__c', 'RemoteExternalIdTxt__c'));
        fieldPerms.add(createFieldPerm(ps.Id, 'Network_Entity__c', 'EntityTypePk__c'));
        
        // Ticket Fields
        fieldPerms.add(createFieldPerm(ps.Id, 'Ticket__c', 'WorkItemNameTxt__c'));
        fieldPerms.add(createFieldPerm(ps.Id, 'Ticket__c', 'BriefDescriptionTxt__c'));
        fieldPerms.add(createFieldPerm(ps.Id, 'Ticket__c', 'StageNamePk__c'));
        
        // Request Fields
        fieldPerms.add(createFieldPerm(ps.Id, 'Request__c', 'TicketId__c'));
        fieldPerms.add(createFieldPerm(ps.Id, 'Request__c', 'DeliveryEntityId__c'));
        fieldPerms.add(createFieldPerm(ps.Id, 'Request__c', 'RemoteTicketIdTxt__c'));
        fieldPerms.add(createFieldPerm(ps.Id, 'Request__c', 'StatusPk__c'));

        if (!fieldPerms.isEmpty()) {
            insert fieldPerms;
        }

        // Assign to User
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
    }

    static ObjectPermissions createObjPerm(Id psId, String objName) {
        // Resolve dynamic namespace if necessary
        String objApi = Schema.getGlobalDescribe().get(objName) != null ? objName : 'delivery__' + objName;
        return new ObjectPermissions(
            ParentId = psId,
            SobjectType = objApi,
            PermissionsRead = true,
            PermissionsCreate = true,
            PermissionsEdit = true
        );
    }

    static FieldPermissions createFieldPerm(Id psId, String objName, String fieldName) {
        // Resolve dynamic namespace for SObject
        String objApi = Schema.getGlobalDescribe().get(objName) != null ? objName : 'delivery__' + objName;
        // Resolve dynamic namespace for Field
        String fieldApi = fieldName;
        // Simple check: if the raw field doesn't exist, try adding prefix
        if (Schema.getGlobalDescribe().get(objApi).getDescribe().fields.getMap().get(fieldName) == null) {
            fieldApi = 'delivery__' + fieldName;
        }

        return new FieldPermissions(
            ParentId = psId,
            SobjectType = objApi,
            Field = objApi + '.' + fieldApi,
            PermissionsRead = true,
            PermissionsEdit = true
        );
    }

    @IsTest
    static void testGetStatusDisconnected() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            DeliveryHubSetupController.SetupStatus result = DeliveryHubSetupController.getSetupStatus();
            Test.stopTest();

            System.assertEquals(false, result.isConnected, 'Should not be connected initially');
            // Check that it's returning a string (empty or URL), not null
            System.assert(result.requiredRemoteSite != null, 'Remote site URL should be returned (even if empty string)');
        }
    }

    @IsTest
    static void testConnectSuccess() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

            Test.startTest();
            DeliveryHubSetupController.connectToDefaultMothership();
            Test.stopTest(); 

            DeliveryHubSetupController.SetupStatus result = DeliveryHubSetupController.getSetupStatus();

            System.assertEquals(true, result.isConnected, 'Should be connected after setup');
            System.assertNotEquals(null, result.entity, 'Entity object should be returned');
            
            Network_Entity__c created = [SELECT Id, Name FROM Network_Entity__c WHERE Id = :result.entity.Id];
            System.assert(created.Name.contains('Cloud Nimbus'), 'Name should match new branding');
        }
    }

    @IsTest
    static void testConnectDuplicateHandling() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
        System.runAs(testUser) {
            Network_Entity__c existing = new Network_Entity__c(
                Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)',
                StatusPk__c = 'Active',
                EntityTypePk__c = 'Vendor',
                IntegrationEndpointUrlTxt__c = 'https://old.url',
                RemoteExternalIdTxt__c = 'OLD_ID',
                OrgIdTxt__c = 'OLD_ORG_ID' 
            );
            insert existing;

            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

            Test.startTest();
            DeliveryHubSetupController.connectToDefaultMothership();
            Test.stopTest();

            Integer count = [SELECT COUNT() FROM Network_Entity__c WHERE Name LIKE 'Cloud Nimbus%'];
            System.assertEquals(1, count, 'Should not duplicate entities');
            
            Network_Entity__c updated = [SELECT RemoteExternalIdTxt__c FROM Network_Entity__c WHERE Id = :existing.Id];
            System.assertEquals('E-REMOTE-456', updated.RemoteExternalIdTxt__c, 'Should update the existing record with new Remote ID');
        }
    }

    public class MockResponseSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // Ensure orgId is included so the de-dupe logic works!
            String jsonBody = '{' +
                '"success": true,' +
                '"ticketId": "T-REMOTE-123",' +
                '"entityId": "E-REMOTE-456",' +
                '"orgId": "00D_MOCK_ORG_ID",' + 
                '"status": "Backlog"' +
            '}';
            res.setBody(jsonBody);
            return res;
        }
    }
}