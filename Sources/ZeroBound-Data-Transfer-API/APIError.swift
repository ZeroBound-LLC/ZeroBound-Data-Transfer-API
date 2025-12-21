import Foundation

/// Errors that can be thrown from ZeroBound API server responses.
///
/// Each case corresponds to an HTTP status code defined in the OpenAPI specification,
/// with associated values for error details where applicable.
public enum APIError: Error, Sendable {

    // MARK: - Client Errors (4xx)

    /// HTTP 400 - The request was malformed or contained invalid parameters.
    ///
    /// Thrown when the server cannot process the request due to client error,
    /// such as invalid JSON or missing required fields.
    case badRequest(message: String)

    /// HTTP 401 - Authentication is required or the provided token is invalid.
    ///
    /// Thrown when:
    /// - No authentication token is provided
    /// - The token has expired
    /// - The token is malformed or invalid
    case unauthorized(message: String)

    /// HTTP 403 - The operation is not permitted.
    ///
    /// Thrown for various forbidden scenarios with specific reasons.
    case forbidden(reason: ForbiddenReason)

    /// HTTP 404 - The requested resource was not found.
    ///
    /// Thrown when attempting to access an account, payment, or other resource
    /// that does not exist.
    case notFound(resourceType: String?, resourceId: String?)

    /// HTTP 422 - Validation failed for one or more fields.
    ///
    /// Thrown when the request body contains values that fail validation rules,
    /// such as APR outside the valid range.
    case validationFailed(message: String, fieldErrors: [FieldError])

    // MARK: - Server Errors (5xx)

    /// HTTP 500 - An internal server error occurred.
    ///
    /// Thrown when the server encounters an unexpected condition,
    /// such as failure to create a Plaid link token.
    case internalServerError(message: String?)

    // MARK: - Unknown/Undocumented

    /// An undocumented HTTP status code was returned.
    ///
    /// Used as a fallback for any status code not explicitly defined in the API spec.
    case undocumented(statusCode: Int, message: String?)
}

// MARK: - Forbidden Reason

extension APIError {

    /// Specific reasons why an operation is forbidden (HTTP 403).
    public enum ForbiddenReason: Sendable, Equatable {

        /// Attempted to modify fields that are managed by Plaid and cannot be changed manually.
        ///
        /// Plaid-linked accounts have certain fields (balance, APR, etc.) that are
        /// automatically synced and cannot be manually overridden.
        case cannotModifyPlaidManagedFields

        /// Attempted to delete a Plaid-linked account.
        ///
        /// Plaid-linked accounts cannot be deleted directly. Users must unlink
        /// the institution via `DELETE /plaid/items/{itemId}` instead.
        case cannotDeletePlaidLinkedAccount

        /// Attempted to manually update the balance of a Plaid-linked account.
        ///
        /// Plaid account balances are updated automatically via webhooks.
        case cannotUpdatePlaidAccountBalance

        /// Attempted to delete a payment that was detected by Plaid.
        ///
        /// Only manually-recorded payments can be deleted.
        case cannotDeletePlaidDetectedPayment

        /// The requested feature requires a premium subscription.
        ///
        /// Features like Plaid linking are only available to premium subscribers.
        case premiumRequired

        /// A generic forbidden reason with a custom message.
        case other(message: String)
    }
}

// MARK: - Field Error

extension APIError {

    /// Represents a validation error for a specific field.
    public struct FieldError: Sendable, Equatable {

        /// The name of the field that failed validation.
        public let field: String

        /// A human-readable message describing the validation failure.
        public let message: String

        public init(field: String, message: String) {
            self.field = field
            self.message = message
        }
    }
}

// MARK: - Error Codes

extension APIError {

    /// String error codes as defined in the API specification.
    ///
    /// These codes are returned in the `error_code` field of error responses.
    public enum ErrorCode: String, Sendable {
        case unauthorized = "UNAUTHORIZED"
        case badRequest = "BAD_REQUEST"
        case validationError = "VALIDATION_ERROR"
        case notFound = "NOT_FOUND"
        case forbidden = "FORBIDDEN"
        case premiumRequired = "PREMIUM_REQUIRED"
        case internalServerError = "INTERNAL_SERVER_ERROR"
    }

    /// The error code associated with this error.
    public var errorCode: ErrorCode {
        switch self {
        case .badRequest:
            return .badRequest
        case .unauthorized:
            return .unauthorized
        case .forbidden(let reason):
            if case .premiumRequired = reason {
                return .premiumRequired
            }
            return .forbidden
        case .notFound:
            return .notFound
        case .validationFailed:
            return .validationError
        case .internalServerError:
            return .internalServerError
        case .undocumented:
            return .internalServerError
        }
    }
}

// MARK: - HTTP Status Code

extension APIError {

    /// The HTTP status code associated with this error.
    public var statusCode: Int {
        switch self {
        case .badRequest:
            return 400
        case .unauthorized:
            return 401
        case .forbidden:
            return 403
        case .notFound:
            return 404
        case .validationFailed:
            return 422
        case .internalServerError:
            return 500
        case .undocumented(let code, _):
            return code
        }
    }
}

// MARK: - LocalizedError

extension APIError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .badRequest(let message):
            return message

        case .unauthorized(let message):
            return message

        case .forbidden(let reason):
            return reason.description

        case .notFound(let resourceType, let resourceId):
            if let type = resourceType, let id = resourceId {
                return "\(type) with ID '\(id)' was not found"
            } else if let type = resourceType {
                return "\(type) was not found"
            }
            return "The requested resource was not found"

        case .validationFailed(let message, let fieldErrors):
            if fieldErrors.isEmpty {
                return message
            }
            let details = fieldErrors.map { "\($0.field): \($0.message)" }.joined(separator: "; ")
            return "\(message) (\(details))"

        case .internalServerError(let message):
            return message ?? "An internal server error occurred"

        case .undocumented(let statusCode, let message):
            return message ?? "Unexpected error (HTTP \(statusCode))"
        }
    }
}

// MARK: - ForbiddenReason Description

extension APIError.ForbiddenReason: CustomStringConvertible {

    public var description: String {
        switch self {
        case .cannotModifyPlaidManagedFields:
            return "Cannot modify Plaid-managed fields"
        case .cannotDeletePlaidLinkedAccount:
            return "Cannot delete Plaid-linked account. Unlink the institution instead."
        case .cannotUpdatePlaidAccountBalance:
            return "Cannot manually update Plaid-linked account balance"
        case .cannotDeletePlaidDetectedPayment:
            return "Cannot delete Plaid-detected payment"
        case .premiumRequired:
            return "This feature requires a premium subscription"
        case .other(let message):
            return message
        }
    }
}

// MARK: - Equatable

extension APIError: Equatable {

    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.badRequest(let lhsMsg), .badRequest(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.unauthorized(let lhsMsg), .unauthorized(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.forbidden(let lhsReason), .forbidden(let rhsReason)):
            return lhsReason == rhsReason
        case (.notFound(let lhsType, let lhsId), .notFound(let rhsType, let rhsId)):
            return lhsType == rhsType && lhsId == rhsId
        case (.validationFailed(let lhsMsg, let lhsErrors), .validationFailed(let rhsMsg, let rhsErrors)):
            return lhsMsg == rhsMsg && lhsErrors == rhsErrors
        case (.internalServerError(let lhsMsg), .internalServerError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.undocumented(let lhsCode, let lhsMsg), .undocumented(let rhsCode, let rhsMsg)):
            return lhsCode == rhsCode && lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// MARK: - Factory Methods

extension APIError {

    /// Creates a `notFound` error for an account.
    public static func accountNotFound(id: String) -> APIError {
        .notFound(resourceType: "Account", resourceId: id)
    }

    /// Creates a `notFound` error for a payment.
    public static func paymentNotFound(id: String) -> APIError {
        .notFound(resourceType: "Payment", resourceId: id)
    }

    /// Creates a `notFound` error for a Plaid item.
    public static func plaidItemNotFound(id: String) -> APIError {
        .notFound(resourceType: "PlaidItem", resourceId: id)
    }

    /// Creates a `notFound` error for a user profile.
    public static func userProfileNotFound() -> APIError {
        .notFound(resourceType: "UserProfile", resourceId: nil)
    }

    /// Creates an `unauthorized` error with the default message.
    public static var invalidToken: APIError {
        .unauthorized(message: "Invalid or expired authentication token")
    }

    /// Creates a `badRequest` error with the default message.
    public static var invalidRequestParameters: APIError {
        .badRequest(message: "Invalid request parameters")
    }

    /// Creates a `validationFailed` error with field-specific errors.
    public static func validation(errors: [FieldError]) -> APIError {
        .validationFailed(message: "One or more fields failed validation", fieldErrors: errors)
    }

    /// Creates a `validationFailed` error for a single field.
    public static func validation(field: String, message: String) -> APIError {
        .validationFailed(
            message: "One or more fields failed validation",
            fieldErrors: [FieldError(field: field, message: message)]
        )
    }
}
