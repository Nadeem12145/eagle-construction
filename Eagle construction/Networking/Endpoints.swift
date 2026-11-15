import Foundation

/// Every Eagle Jobs API call the Client and Worker apps make (see SCREEN_MAP.md of the API).
enum API {
    private static var client: APIClient { .shared }

    // MARK: Auth

    static func sendCode(email: String, role: String?, accountType: String?) async throws -> OTPSent {
        var body: [String: Any] = ["email": email]
        if let role { body["role"] = role }
        if let accountType { body["accountType"] = accountType }
        return try await client.post("auth/send-otp", body)
    }

    static func resendCode(email: String) async throws -> OTPSent {
        try await client.post("auth/resend-otp", ["email": email])
    }

    static func verifyCode(email: String, code: String) async throws -> AuthResult {
        try await client.post("auth/verify-otp", ["email": email, "code": code])
    }

    static func me() async throws -> Me {
        let result: UserEnvelope = try await client.get("auth/me")
        return result.user
    }

    static func logout() async throws {
        let _: Empty = try await client.post("auth/logout")
    }

    static func deleteAccount() async throws {
        let _: Empty = try await client.delete("auth/account")
    }

    // MARK: Profile and onboarding

    static func updateProfile(_ fields: [String: String], avatar: Data?) async throws -> Me {
        let files = avatar.map { [UploadFile(field: "avatar", data: $0)] } ?? []
        let result: (data: UserEnvelope, message: String) = try await client.upload("PUT", "profile", fields: fields, files: files)
        return result.data.user
    }

    static func setLocation(lat: Double, lng: Double, address: String, postalCode: String) async throws -> Me {
        let result: UserEnvelope = try await client.put("profile/location", ["lat": lat, "lng": lng, "address": address, "postalCode": postalCode])
        return result.user
    }

    static func sendEmailChangeCode(to email: String) async throws -> OTPSent {
        try await client.post("profile/email/send-code", ["email": email])
    }

    static func verifyEmailChange(email: String, code: String) async throws -> Me {
        let result: UserEnvelope = try await client.post("profile/email/verify", ["email": email, "code": code])
        return result.user
    }

    static func submitIdentity(addressProof: Data, front: Data, back: Data) async throws -> Me {
        let files = [UploadFile(field: "addressProof", data: addressProof), UploadFile(field: "front", data: front), UploadFile(field: "back", data: back)]
        let result: (data: UserEnvelope, message: String) = try await client.upload("POST", "worker/identity", fields: [:], files: files)
        return result.data.user
    }

    static func setCategories(_ ids: [Int]) async throws -> Me {
        let result: UserEnvelope = try await client.put("worker/categories", ["categoryIds": ids])
        return result.user
    }

    static func categories() async throws -> [Category] {
        let result: ItemList<Category> = try await client.get("categories")
        return result.items
    }

    static func options() async throws -> Options {
        try await client.get("options")
    }

    static func summary() async throws -> Summary {
        try await client.get("summary")
    }

    static func notificationSettings() async throws -> NotificationSwitches {
        try await client.get("settings/notifications")
    }

    static func saveNotificationSettings(_ value: NotificationSwitches) async throws -> NotificationSwitches {
        try await client.put("settings/notifications", ["bookings": value.bookings, "chat": value.chat, "updates": value.updates])
    }

    // MARK: People

    static func profile(of userId: Int) async throws -> PublicProfile {
        try await client.get("users/\(userId)")
    }

    static func reviews(of userId: Int, page: Int = 1) async throws -> ReviewPage {
        try await client.get("users/\(userId)/reviews", query: ["page": "\(page)", "limit": "30"])
    }

    static func openJobs(of userId: Int) async throws -> Page<Job> {
        try await client.get("users/\(userId)/jobs", query: ["limit": "50"])
    }

    static func pastWorkers(search: String = "") async throws -> Page<PastWorker> {
        try await client.get("past-workers", query: ["search": search, "limit": "50"])
    }

    static func blockedUsers() async throws -> [UserBrief] {
        let result: ItemList<UserBrief> = try await client.get("blocks")
        return result.items
    }

    static func block(_ userId: Int) async throws {
        let _: Empty = try await client.post("users/\(userId)/block")
    }

    static func unblock(_ userId: Int) async throws {
        let _: Empty = try await client.delete("users/\(userId)/block")
    }

    // MARK: Jobs

    static func myJobs(search: String = "") async throws -> Page<Job> {
        try await client.get("jobs/mine", query: ["search": search, "limit": "50"])
    }

    static func feed(search: String = "", location: String = "", distance: Int = 0, sort: String = "new") async throws -> Page<Job> {
        try await client.get("jobs/feed", query: ["search": search, "location": location, "distance": distance > 0 ? "\(distance)" : "",
                                                   "sort": sort, "limit": "50"])
    }

    static func job(_ id: Int) async throws -> JobDetail {
        try await client.get("jobs/\(id)")
    }

    static func postJob(_ fields: [String: String], images: [Data]) async throws -> (job: Job, message: String) {
        let files = images.enumerated().map { UploadFile(field: "images", data: $1, filename: "photo\($0).jpg") }
        let result: (data: JobEnvelope, message: String) = try await client.upload("POST", "jobs", fields: fields, files: files)
        return (result.data.job, result.message)
    }

    /// Edit an open request. `keepImages` are the current photo URLs to keep; new photos are added after them.
    static func updateJob(_ id: Int, _ fields: [String: String], keepImages: [String], images: [Data]) async throws -> (job: Job, message: String) {
        var fields = fields
        let kept = (try? JSONSerialization.data(withJSONObject: keepImages)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        fields["keepImages"] = kept
        let files = images.enumerated().map { UploadFile(field: "images", data: $1, filename: "photo\($0).jpg") }
        let result: (data: JobEnvelope, message: String) = try await client.upload("PUT", "jobs/\(id)", fields: fields, files: files)
        return (result.data.job, result.message)
    }

    static func closeJob(_ id: Int) async throws {
        let _: Empty = try await client.post("jobs/\(id)/close")
    }

    static func apply(to jobId: Int) async throws {
        let _: Empty = try await client.post("jobs/\(jobId)/apply")
    }

    static func withdraw(from jobId: Int) async throws {
        let _: Empty = try await client.delete("jobs/\(jobId)/apply")
    }

    static func decline(_ jobId: Int) async throws {
        let _: Empty = try await client.post("jobs/\(jobId)/decline")
    }

    // MARK: Bookings

    static func checkout(jobId: Int, workerId: Int) async throws -> Checkout {
        try await client.get("bookings/checkout", query: ["jobId": "\(jobId)", "workerId": "\(workerId)"])
    }

    static func book(jobId: Int, workerId: Int, method: String, cardId: Int?) async throws -> (booking: Booking, message: String) {
        var body: [String: Any] = ["jobId": jobId, "workerId": workerId, "paymentMethod": method]
        if let cardId { body["cardId"] = cardId }
        let result: (data: BookingEnvelope, message: String) = try await client.send("POST", "bookings", json: body)
        return (result.data.booking, result.message)
    }

    static func bookings(tab: String) async throws -> Page<BookingRow> {
        try await client.get("bookings", query: ["tab": tab, "limit": "50"])
    }

    static func booking(_ id: Int) async throws -> Booking {
        let result: BookingEnvelope = try await client.get("bookings/\(id)")
        return result.booking
    }

    static func startWork(_ id: Int, lat: Double, lng: Double, address: String) async throws -> Booking {
        let result: BookingEnvelope = try await client.post("bookings/\(id)/start", ["lat": lat, "lng": lng, "address": address])
        return result.booking
    }

    static func arrive(_ id: Int, lat: Double, lng: Double, address: String) async throws -> Booking {
        let result: BookingEnvelope = try await client.post("bookings/\(id)/arrive", ["lat": lat, "lng": lng, "address": address])
        return result.booking
    }

    static func shareLocation(_ id: Int, lat: Double, lng: Double) async throws {
        let _: Empty = try await client.post("bookings/\(id)/location", ["lat": lat, "lng": lng])
    }

    static func finishWork(_ id: Int, description: String, images: [Data]) async throws -> String {
        let files = images.enumerated().map { UploadFile(field: "images", data: $1, filename: "work\($0).jpg") }
        let result: (data: BookingEnvelope, message: String) = try await client.upload("POST", "bookings/\(id)/finish", fields: ["description": description], files: files)
        return result.message
    }

    static func acceptDelivery(_ id: Int, rating: Int, comment: String) async throws -> Booking {
        let result: BookingEnvelope = try await client.post("bookings/\(id)/accept-delivery", ["rating": rating, "comment": comment])
        return result.booking
    }

    static func review(_ id: Int, rating: Int, comment: String) async throws -> Booking {
        let result: BookingEnvelope = try await client.post("bookings/\(id)/review", ["rating": rating, "comment": comment])
        return result.booking
    }

    static func requestCancellation(_ id: Int, reason: String, description: String, images: [Data]) async throws -> String {
        let files = images.enumerated().map { UploadFile(field: "images", data: $1, filename: "proof\($0).jpg") }
        let result: (data: Empty, message: String) = try await client.upload("POST", "bookings/\(id)/cancel",
                                                                             fields: ["reason": reason, "description": description], files: files)
        return result.message
    }

    static func cancellationRequests(incoming: Bool) async throws -> Page<BookingRow> {
        try await client.get("cancellation-requests", query: ["tab": incoming ? "incoming" : "mine", "limit": "50"])
    }

    static func answerCancellation(_ requestId: Int, accept: Bool) async throws -> (booking: Booking, message: String) {
        let result: (data: BookingEnvelope, message: String) = try await client.send("POST", "cancellation-requests/\(requestId)/\(accept ? "accept" : "decline")", json: [:])
        return (result.data.booking, result.message)
    }

    // MARK: Disputes

    static func raiseDispute(bookingId: Int, reason: String, returnPercent: Int, description: String, images: [Data]) async throws -> String {
        let files = images.enumerated().map { UploadFile(field: "images", data: $1, filename: "proof\($0).jpg") }
        let fields = ["bookingId": "\(bookingId)", "reason": reason, "returnPercent": "\(returnPercent)", "description": description]
        let result: (data: Empty, message: String) = try await client.upload("POST", "disputes", fields: fields, files: files)
        return result.message
    }

    static func disputes() async throws -> Page<Dispute> {
        try await client.get("disputes", query: ["limit": "50"])
    }

    static func dispute(_ id: Int) async throws -> Dispute {
        let result: DisputeEnvelope = try await client.get("disputes/\(id)")
        return result.dispute
    }

    // MARK: Payments

    static func cards() async throws -> [Card] {
        let result: ItemList<Card> = try await client.get("cards")
        return result.items
    }

    static func addCard(number: String, expiry: String, cvv: String, country: String, zip: String) async throws -> String {
        let result: (data: Empty, message: String) = try await client.send("POST", "cards",
                                                                          json: ["cardNumber": number, "expDate": expiry, "cvv": cvv, "country": country, "zip": zip])
        return result.message
    }

    static func deleteCard(_ id: Int) async throws {
        let _: Empty = try await client.delete("cards/\(id)")
    }

    static func makeDefault(_ cardId: Int) async throws {
        let _: Empty = try await client.put("cards/\(cardId)/default")
    }

    static func wallet() async throws -> Wallet {
        try await client.get("wallet", query: ["limit": "50"])
    }

    static func topUp(amount: Double, cardId: Int) async throws -> String {
        let result: (data: BalanceResult, message: String) = try await client.send("POST", "wallet/topup", json: ["amount": amount, "cardId": cardId])
        return result.message
    }

    static func earnings() async throws -> Earnings {
        try await client.get("earnings", query: ["limit": "50"])
    }

    static func linkStripe() async throws -> String {
        let result: (data: Empty, message: String) = try await client.send("POST", "earnings/stripe/link", json: [:])
        return result.message
    }

    static func withdraw(amount: Double) async throws -> String {
        let result: (data: BalanceResult, message: String) = try await client.send("POST", "earnings/withdraw", json: ["amount": amount])
        return result.message
    }

    // MARK: Chat

    static func conversations(search: String = "") async throws -> ConversationList {
        try await client.get("conversations", query: ["search": search])
    }

    static func openConversation(with userId: Int) async throws -> Conversation {
        let result: ConversationEnvelope = try await client.post("conversations", ["userId": userId])
        return result.conversation
    }

    static func adminConversation() async throws -> Conversation {
        let result: ConversationEnvelope = try await client.get("conversations/admin")
        return result.conversation
    }

    static func messages(in conversationId: Int, after: Int? = nil) async throws -> MessagePage {
        try await client.get("conversations/\(conversationId)/messages", query: ["after": after.map { "\($0)" } ?? "", "limit": "100"])
    }

    static func sendText(_ text: String, in conversationId: Int) async throws -> Message {
        let result: (data: MessageEnvelope, message: String) = try await client.upload("POST", "conversations/\(conversationId)/messages", fields: ["text": text], files: [])
        return result.data.message
    }

    static func sendImage(_ data: Data, in conversationId: Int) async throws -> Message {
        let result: (data: MessageEnvelope, message: String) = try await client.upload("POST", "conversations/\(conversationId)/messages", fields: [:],
                                                                                       files: [UploadFile(field: "attachment", data: data)])
        return result.data.message
    }

    static func sendLocation(lat: Double, lng: Double, in conversationId: Int) async throws -> Message {
        let result: MessageEnvelope = try await client.post("conversations/\(conversationId)/messages", ["type": "location", "lat": lat, "lng": lng])
        return result.message
    }

    static func markRead(_ conversationId: Int) async throws {
        let _: Empty = try await client.post("conversations/\(conversationId)/read")
    }

    // MARK: Notifications and content

    static func notifications() async throws -> NotificationPage {
        try await client.get("notifications", query: ["limit": "50"])
    }

    static func markNotificationRead(_ id: Int) async throws {
        let _: Empty = try await client.post("notifications/\(id)/read")
    }

    static func markAllNotificationsRead() async throws {
        let _: Empty = try await client.post("notifications/read-all")
    }

    static func content(_ key: String) async throws -> ContentPage {
        try await client.get("content/\(key)")
    }

    static func appInfo() async throws -> AppInfo {
        try await client.get("app-info")
    }

    static func contact(name: String, subject: String, email: String, message: String) async throws -> String {
        let result: (data: Empty, message: String) = try await client.send("POST", "contact",
                                                                          json: ["name": name, "subject": subject, "email": email, "message": message])
        return result.message
    }
}
