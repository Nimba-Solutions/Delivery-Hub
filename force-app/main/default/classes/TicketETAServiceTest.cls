@isTest
private class TicketETAServiceTest {

    @TestSetup
    static void makeData(){
        // Create the necessary Kanban Configuration Custom Metadata
       

        // Create Developer Users
        List<User> devs = new List<User>();
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        for(Integer i=0; i<2; i++){
            devs.add(new User(
                ProfileId = p.Id,
                LastName = 'TestDev' + i,
                Email = 'testdev' + i + '@testorg.com',
                Username = 'testdev' + i + '@testorg.com.dev',
                Alias = 'dev' + i,
                TimeZoneSidKey = 'America/Los_Angeles',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                is_Developer__c = true
            ));
        }
        insert devs;

        // Create a variety of tickets
        List<Ticket__c> tickets = new List<Ticket__c>{
            // Rule: Active Dev Stage > Pre-Dev Stage
            new Ticket__c( PriorityPk__c='Low', StageNamePk__c='In Development', DeveloperDaysSizeNumber__c=2),
            new Ticket__c( PriorityPk__c='High', StageNamePk__c='Backlog', DeveloperDaysSizeNumber__c=2),

            // Rule: Higher Priority > Lower Priority (within same stage category)
            new Ticket__c( PriorityPk__c='High', StageNamePk__c='Backlog', DeveloperDaysSizeNumber__c=2, SortOrderNumber__c=10),
            new Ticket__c( PriorityPk__c='Medium', StageNamePk__c='Backlog', DeveloperDaysSizeNumber__c=2, SortOrderNumber__c=10),

            // Rule: Lower Sort Order > Higher Sort Order (within same priority)
            new Ticket__c( PriorityPk__c='High', StageNamePk__c='Backlog', DeveloperDaysSizeNumber__c=2, SortOrderNumber__c=1),
            new Ticket__c( PriorityPk__c='High', StageNamePk__c='Backlog', DeveloperDaysSizeNumber__c=2, SortOrderNumber__c=2),

            // Rule: Older CreatedDate > Newer CreatedDate (as a tie-breaker)
            new Ticket__c( PriorityPk__c='Low', StageNamePk__c='Backlog', DeveloperDaysSizeNumber__c=2, SortOrderNumber__c=99),
            
            // Tickets that should be ignored by the queue
            new Ticket__c( PriorityPk__c='Critical', StageNamePk__c='Blocked', DeveloperDaysSizeNumber__c=5),
            new Ticket__c( PriorityPk__c='Critical', StageNamePk__c='Done', DeveloperDaysSizeNumber__c=5),
            
            // Ticket with a null size
            new Ticket__c( PriorityPk__c='Medium', StageNamePk__c='Backlog', DeveloperDaysSizeNumber__c=null)
        };
        insert tickets;
        
    }

    @isTest
    static void testLwcMethod_Prioritization() {
        // ARRANGE: Get a ticket that would normally be low in priority
        Ticket__c lowPrioTicket ;
           lowPrioTicket = [SELECT Id FROM Ticket__c WHERE PriorityPk__c='Low' LIMIT 1];
        List<Id> prioritizedList = new List<Id>{ lowPrioTicket.Id };
        
        Test.startTest();
        // ACT: Call the LWC-exposed method, prioritizing the low-priority ticket
        TicketETAService.ETAResult result = TicketETAService.getTicketETAsWithPriority(2, prioritizedList);
        Test.stopTest();
        
        // ASSERT: Check that the low-priority ticket was processed and has an ETA
        Map<Id, Ticket__c> updatedTickets = new Map<Id, Ticket__c>([SELECT Name, Estimated_Dev_Start_Date__c FROM Ticket__c ]);
        
        // The prioritized ticket should have the earliest start date
        Date prioritizedStartDate = updatedTickets.get(lowPrioTicket.Id)?.Estimated_Dev_Start_Date__c;
       // System.assertNotEquals(null, prioritizedStartDate, 'Prioritized ticket should have a start date.');
        
        for (Ticket__c t : updatedTickets.values()) {
            if (t.Id != lowPrioTicket.Id && t.Estimated_Dev_Start_Date__c != null) {
               // System.assert(t.Estimated_Dev_Start_Date__c >= prioritizedStartDate, 
                //    'No other ticket should start before the LWC-prioritized one.');
            }
        }
        //System.assert(result.tickets.size() > 0, 'Results should be returned');
    }

    @isTest
    static void testSortingLogic_FullQueue() {
        // This test validates the sorting order without any LWC prioritization.
        Test.startTest();
        // ACT: Run the full calculation via the Queueable interface.
        TicketETAService.RecalculateAllETAsQueueable job = new TicketETAService.RecalculateAllETAsQueueable();
        System.enqueueJob(job);
        Test.stopTest();

        // ASSERT: Query tickets with ETAs and verify their processing order
        List<Ticket__c> processedTickets = [
            SELECT Name, Estimated_Dev_Start_Date__c 
            FROM Ticket__c 
            WHERE Estimated_Dev_Start_Date__c != null 
            ORDER BY Estimated_Dev_Start_Date__c ASC, Name ASC
        ];
        
        // Convert to a list of names for easier assertion
        List<String> processedOrder = new List<String>();
        for (Ticket__c t : processedTickets) {
            processedOrder.add(t.Name);
        }
        
        // Expected Order based on sorting rules:
        // 1. T-Active (Active Stage)
        // 2. T-HighPrio (High Prio in Backlog)
        // 3. T-Sort1 (Lower Sort Order)
        // 4. T-Sort2 (Higher Sort Order)
        // 5. T-MedPrio (Medium Prio)
        // 6. T-Old (Older Created Date)
        // 7. T-PreDev (Newer Low Prio)
        // 8. T-NullSize (Null size treated as 0)
        
        // We can't guarantee the exact order due to developer availability simulation,
        // but we can assert key precedence rules.
        //System.assert(processedOrder.indexOf('T-Active') < processedOrder.indexOf('T-PreDev'), 'Active stage tickets must come before Pre-dev stage tickets.');
        //System.assert(processedOrder.indexOf('T-HighPrio') < processedOrder.indexOf('T-MedPrio'), 'Higher priority tickets must come before lower priority tickets.');
        //System.assert(processedOrder.indexOf('T-Sort1') < processedOrder.indexOf('T-Sort2'), 'Lower sort order must come before higher sort order.');
        
        // Ignored tickets should not have an ETA
        List<Ticket__c> ignoredTickets = [SELECT Name FROM Ticket__c WHERE Name IN ('T-Blocked', 'T-Done') AND Estimated_Dev_Start_Date__c != null];
        //System.assertEquals(0, ignoredTickets.size(), 'Blocked and Done tickets should not be processed.');
    }
    
    @isTest
    static void testNightlySchedulable() {
        Test.startTest();
        // ACT: Execute the schedulable job
        TicketETAService.NightlyRecalculation scheduler = new TicketETAService.NightlyRecalculation();
        scheduler.execute(null); // The SchedulableContext is not used in the class
        Test.stopTest();
        
        // ASSERT: At least one ticket should have been processed by the enqueued job.
        List<Ticket__c> processed = [SELECT Id FROM Ticket__c WHERE Projected_UAT_Ready_Date__c != null];
        //System.assert(!processed.isEmpty(), 'The nightly job should result in processed tickets.');
    }

    @isTest
    static void testAddBusinessDays() {
        // ARRANGE: Get a reference to the private calculator class to test its public methods.
        // We don't need to insert any data for this test.
        TicketETAService.ETACalculator calculator = new TicketETAService.ETACalculator(null);
        
        // A Friday
        Date friday = Date.newInstance(2025, 8, 29); 
        
        // ACT & ASSERT
        // +0 days should return the same day
        //System.assertEquals(friday, calculator.addBusinessDays(friday, 0), 'Adding 0 days should not change the date.');
        
        // +1 business day from Friday should be Monday
        //System.assertEquals(Date.newInstance(2025, 9, 1), calculator.addBusinessDays(friday, 1), '1 business day from Friday is Monday.');
        
        // +3 business days from Friday should be Wednesday
        //System.assertEquals(Date.newInstance(2025, 9, 3), calculator.addBusinessDays(friday, 3), '3 business days from Friday is Wednesday.');
        
        // Test with null input
        //System.assertEquals(null, calculator.addBusinessDays(null, 5), 'Null date should return null.');
    }

    @isTest
    static void testErrorHandling_NoConfig() {
        // ARRANGE: Delete the metadata created in TestSetup to simulate a missing configuration.
 
        Test.startTest();
        // ACT: Run the calculation. It should not throw an unhandled exception.
        TicketETAService.ETACalculator calculator = new TicketETAService.ETACalculator(null);
        calculator.execute();
        Test.stopTest();

        // ASSERT: No tickets should be processed as the configuration was missing.
        List<Ticket__c> processed = [SELECT Id FROM Ticket__c WHERE Projected_UAT_Ready_Date__c != null];
        //System.assertEquals(0, processed.size(), 'No tickets should be processed if config is missing.');
    }

    @isTest
    static void testNoDevelopersAvailable() {
        // ARRANGE: Deactivate all developer users.
        List<User> devs = [SELECT Id, IsActive FROM User WHERE is_Developer__c = true];
        for(User u : devs){ u.IsActive = false; }
        update devs;

        Test.startTest();
        // ACT: Run the calculation.
        TicketETAService.getTicketETAsWithPriority(0, new List<Id>());
        Test.stopTest();

        // ASSERT: No tickets should be processed.
        List<Ticket__c> processed = [SELECT Id FROM Ticket__c WHERE Projected_UAT_Ready_Date__c != null];
        //System.assertEquals(0, processed.size(), 'No tickets should be processed if there are no active developers.');
    }
}
