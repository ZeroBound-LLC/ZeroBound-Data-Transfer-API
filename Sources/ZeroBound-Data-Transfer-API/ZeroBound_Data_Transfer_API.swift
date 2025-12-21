// The Swift Programming Language
// https://docs.swift.org/swift-book
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

// Token storage (could be Keychain, actor, etc.)
actor TokenStore {
    private var token: String?
    
    func setToken(_ token: String?) {
        self.token = token
    }
    
    func getToken() -> String? {
        token
    }
}

let tokenStore = TokenStore()

// Create client with middleware
let client = Client(
    serverURL: URL(string: "https://api.zerobound.app/v1")!,
    transport: URLSessionTransport(),
    middlewares: [
        AuthenticationMiddleware { await tokenStore.getToken() }
    ]
)