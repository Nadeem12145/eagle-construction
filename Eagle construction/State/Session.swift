import SwiftUI

/// Who is signed in and which screen of onboarding comes next. The token lives in the Keychain.
@Observable
final class Session {
    var me: Me?
    var isRestoring = true
    var restoreError: String?
    var summary: Summary?
    /// Choices made on the Signup / "Your are a?" screens, sent with the login code request.
    var signupRole = "client"
    var signupAccountType = "individual"
    /// Bumped on sign-out so every navigation stack starts over.
    var resetCount = 0

    init() {
        APIClient.shared.onUnauthorized = { [weak self] in self?.signOutLocally() }
    }

    var isWorker: Bool { me?.isWorker ?? (signupRole == "worker") }

    func restore() async {
        restoreError = nil
        guard TokenStore.token != nil else {
            isRestoring = false
            return
        }
        isRestoring = true
        do {
            me = try await API.me()
        } catch let error as APIError where [401, 403].contains(error.status) {
            signOutLocally()
        } catch {
            restoreError = error.userMessage
        }
        isRestoring = false
    }

    func signedIn(_ result: AuthResult) {
        TokenStore.token = result.token
        me = result.user
    }

    func refresh() async {
        if let fresh = try? await API.me() { me = fresh }
    }

    func refreshSummary() async {
        if let value = try? await API.summary() { summary = value }
    }

    func logout() async {
        try? await API.logout()
        signOutLocally()
    }

    func signOutLocally() {
        TokenStore.token = nil
        me = nil
        summary = nil
        resetCount += 1
    }
}

/// Short messages shown at the top of the screen after an action.
@Observable
final class Toaster {
    var message: String?
    var isError = false
    private var hideTask: Task<Void, Never>?

    func show(_ message: String, error: Bool = false) {
        guard !message.isEmpty else { return }
        self.message = message
        isError = error
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { self.message = nil }
        }
    }

    func show(_ error: Error) {
        guard !error.isCancellation else { return }
        show(error.userMessage, error: true)
    }
}

struct ToastOverlay: ViewModifier {
    @Environment(Toaster.self) private var toaster

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message = toaster.message {
                HStack(spacing: 10) {
                    Image(systemName: toaster.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(toaster.isError ? Tone.danger.foreground : Tone.success.foreground)
                    Text(message).type(14, .medium).multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.white, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .shadow(color: Palette.ink.opacity(0.15), radius: 12, y: 4)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { toaster.message = nil }
            }
        }
        .animation(.easeOut(duration: 0.25), value: toaster.message)
    }
}

/// Loading / error / content for a screen that fetches its data.
enum LoadState<Value> {
    case loading
    case failed(String)
    case loaded(Value)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

struct LoadView<Value, Content: View>: View {
    let state: LoadState<Value>
    var retry: () async -> Void
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        switch state {
        case .loading:
            ProgressView().tint(Palette.primary).controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark").type(34, .regular, Palette.muted)
                Text(message).type(15, .regular, Palette.text2).multilineTextAlignment(.center)
                AppButton(title: "Try Again", kind: .secondary, height: 44) { Task { await retry() } }.frame(width: 160)
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let value):
            content(value)
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .type(26, .regular, Palette.primary)
                .frame(width: 64, height: 64)
                .background(Palette.primary50, in: Circle())
            Text(title).type(16, .semibold)
            if let message { Text(message).type(14, .regular, Palette.text3).multilineTextAlignment(.center) }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

/// Runs a load for a screen: shows an error only when there is nothing on screen yet, so a failed refresh keeps the old data.
func fetch<Value>(_ state: Binding<LoadState<Value>>, _ load: () async throws -> Value) async {
    do {
        state.wrappedValue = .loaded(try await load())
    } catch {
        if error.isCancellation { return }
        if state.wrappedValue.value == nil { state.wrappedValue = .failed(error.userMessage) }
    }
}

/// Dates and times as the API sends and wants them.
enum Formats {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    static let apiDate = formatter("yyyy-MM-dd")
    static let apiTime = formatter("HH:mm")
    static let showDate = formatter("d MMM, yyyy")
    static let showTime = formatter("h:mm a")
    static let chatTime = formatter("HH:mm")

    static func isoDate(_ text: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: text)
    }

    static func money(_ value: Double) -> String {
        value.rounded() == value ? "£\(Int(value))" : String(format: "£%.2f", value)
    }
}
