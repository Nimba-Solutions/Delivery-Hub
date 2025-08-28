/**
 * @description Service class for Account operations
 * @author Delivery Hub Team
 * @date 2025
 */
public with sharing class AccountService {
    /**
     * @description Retrieves an Account record by its ID
     * @param accountId The ID of the Account to retrieve
     * @return Account record with basic fields
     */
    public static Account getAccountById(String accountId) {
        return [SELECT Id, Name, Type, Phone, Industry FROM Account WHERE Id = :accountId WITH SECURITY_ENFORCED];
    }
    
    /**
     * @description Creates a new Account record
     * @param newAccount The Account record to create
     * @return The created Account record with ID populated
     */
    public static Account createAccount(Account newAccount) {
        // Perform any necessary validation or business logic here
        // Check FLS permissions before insert
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<Account>{newAccount});
        insert decision.getRecords();
        newAccount = (Account)decision.getRecords()[0];
        return newAccount;
    }
}