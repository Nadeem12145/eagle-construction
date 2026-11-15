import Foundation
import Security

enum APIConfig {
    static let productionURL = URL(string: "https://eagle.appistan.app/api")!

    /// Debug builds can point at a local server with the launch argument `-apiBaseURL http://127.0.0.1:3000/api`.
    static var baseURL: URL {
        #if DEBUG
        if let value = UserDefaults.standard.string(forKey: "apiBaseURL"), let url = URL(string: value) { return url }
        #endif
        return productionURL
    }
}

struct FieldError: Decodable {
    let field: String
    let message: String
    var retryAfterSeconds: Int? = nil
}

struct APIError: LocalizedError {
    let status: Int
    let code: String
    let message: String
    var fields: [FieldError] = []

    var errorDescription: String? { message }
    var retryAfterSeconds: Int? { fields.compactMap(\.retryAfterSeconds).first }

    static func network(_ error: Error) -> APIError {
        APIError(status: 0, code: "NETWORK", message: "Could not reach the server. Check your internet connection and try again.")
    }
}

/// `{ success, message, data }` or `{ success: false, code, message, errors }`
private struct Envelope<T: Decodable>: Decodable {
    let success: Bool
    let message: String?
    let code: String?
    let data: T?
    let errors: [FieldError]?
}

private struct ErrorEnvelope: Decodable {
    let message: String?
    let code: String?
    let errors: [FieldError]?
}

/// For endpoints whose `data` is `{}` or not needed.
struct Empty: Decodable {}

struct UploadFile {
    let field: String
    let data: Data
    var filename = "photo.jpg"
    var mimeType = "image/jpeg"
}

/// Saves the login token in the Keychain.
enum TokenStore {
    private static let account = "eagle.api.token"

    /// Kept in memory too, so a Keychain hiccup never signs the user out mid-session.
    private static var cached: String?
    #if DEBUG
    private static let debugKey = "debug.eagle.api.token"
    #endif

    static var token: String? {
        get {
            if let cached { return cached }
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account,
                                        kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
                #if DEBUG
                cached = UserDefaults.standard.string(forKey: debugKey)
                #endif
                return cached
            }
            cached = String(data: data, encoding: .utf8)
            return cached
        }
        set {
            cached = newValue
            let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account]
            SecItemDelete(base as CFDictionary)
            #if DEBUG
            UserDefaults.standard.removeObject(forKey: debugKey)
            #endif
            guard let newValue, let data = newValue.data(using: .utf8) else { return }
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let status = SecItemAdd(add as CFDictionary, nil)
            #if DEBUG
            // Simulator builds signed without Xcode have no Keychain access; keep test logins across launches.
            if status != errSecSuccess { UserDefaults.standard.set(newValue, forKey: debugKey) }
            #else
            _ = status
            #endif
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    /// Called when the server says the session is no longer valid.
    var onUnauthorized: () -> Void = {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        // Live data (chats, lists, balances) must never come from the local HTTP cache.
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await send("GET", path, query: query).data
    }

    func post<T: Decodable>(_ path: String, _ body: [String: Any] = [:]) async throws -> T {
        try await send("POST", path, json: body).data
    }

    func put<T: Decodable>(_ path: String, _ body: [String: Any] = [:]) async throws -> T {
        try await send("PUT", path, json: body).data
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await send("DELETE", path).data
    }

    func upload<T: Decodable>(_ method: String = "POST", _ path: String, fields: [String: String], files: [UploadFile]) async throws -> (data: T, message: String) {
        try await send(method, path, multipart: (fields, files))
    }

    /// Returns the decoded `data` and the server's `message` (shown on success toasts and dialogs).
    func send<T: Decodable>(_ method: String, _ path: String, query: [String: String] = [:], json: [String: Any]? = nil,
                            multipart: ([String: String], [UploadFile])? = nil) async throws -> (data: T, message: String) {
        var components = URLComponents(url: APIConfig.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        let items = query.filter { !$0.value.isEmpty }.map { URLQueryItem(name: $0.key, value: $0.value) }
        if !items.isEmpty { components.queryItems = items.sorted { $0.name < $1.name } }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = TokenStore.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let multipart {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.multipartBody(fields: multipart.0, files: multipart.1, boundary: boundary)
        } else if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // A screen that closed mid-request: not an error worth showing.
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw APIError.network(error)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let body = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            let error = APIError(status: status, code: body?.code ?? "HTTP_\(status)",
                                 message: body?.message ?? "Something went wrong (\(status)). Please try again.",
                                 fields: body?.errors ?? [])
            if status == 401 && TokenStore.token != nil { onUnauthorized() }
            throw error
        }
        do {
            let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
            guard let value = envelope.data else {
                throw APIError(status: status, code: "EMPTY", message: envelope.message ?? "The server sent an empty answer.")
            }
            return (value, envelope.message ?? "")
        } catch let error as APIError {
            throw error
        } catch {
            #if DEBUG
            print("Decoding \(T.self) from \(path) failed: \(error)")
            #endif
            throw APIError(status: status, code: "DECODING", message: "The app could not read the server's answer. Please update the app.")
        }
    }

    /// Raw bytes of a protected file (ID documents), sent with the login token.
    func authorizedData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        if let token = TokenStore.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        guard ((response as? HTTPURLResponse)?.statusCode ?? 0) < 300 else { throw APIError(status: 0, code: "FILE", message: "Could not load the file.") }
        return data
    }

    private static func multipartBody(fields: [String: String], files: [UploadFile], boundary: String) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        for (key, value) in fields {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n")
        }
        for file in files {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(file.field)\"; filename=\"\(file.filename)\"\r\n")
            append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        return body
    }
}

extension Error {
    /// The message to show the user for any thrown error.
    var userMessage: String {
        (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }

    /// True when the request was dropped because its screen went away.
    var isCancellation: Bool { self is CancellationError }
}
