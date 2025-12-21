// The Swift Programming Language
// https://docs.swift.org/swift-book
import OpenAPIRuntime
import HTTPTypes

/// Middleware that adds Bearer token authentication to requests
struct AuthenticationMiddleware: ClientMiddleware {
    
    private let tokenProvider: @Sendable () async -> String?
    
    init(tokenProvider: @escaping @Sendable () async -> String?) {
        self.tokenProvider = tokenProvider
    }
    
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        
        if let token = await tokenProvider() {
            request.headerFields[.authorization] = "Bearer \(token)"
        }
        
        return try await next(request, body, baseURL)
    }
}