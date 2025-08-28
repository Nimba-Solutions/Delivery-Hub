/**
 * @description Wrapper class for API error responses
 * @author Delivery Hub Team
 * @date 2025
 */
public class ErrorResponse {
    public String errorMessage;
    
    /**
     * @description Constructor for ErrorResponse
     * @param message The error message to include in the response
     */
    public ErrorResponse(String message) {
        this.errorMessage = message;
    }
}