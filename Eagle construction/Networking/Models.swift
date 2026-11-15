import Foundation

/// Decodes an object the API sends as `{}` when there is nothing (my review, dispute, cancellation ...) as `nil`.
@propertyWrapper
struct Lenient<T: Decodable>: Decodable {
    var wrappedValue: T?

    init(wrappedValue: T? = nil) { self.wrappedValue = wrappedValue }

    init(from decoder: Decoder) throws {
        wrappedValue = try? T(from: decoder)
    }
}

extension KeyedDecodingContainer {
    func decode<T>(_ type: Lenient<T>.Type, forKey key: Key) throws -> Lenient<T> {
        (try? decodeIfPresent(type, forKey: key)) ?? Lenient()
    }
}

struct Page<T: Decodable>: Decodable {
    let items: [T]
    let page: Int
    let total: Int
    let hasMore: Bool
}

struct ItemList<T: Decodable>: Decodable {
    let items: [T]
}

// MARK: - People

struct Category: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let icon: String
}

struct UserBrief: Decodable, Identifiable, Hashable {
    let id: Int
    let role: String
    let accountType: String
    let name: String
    let avatar: String
    let rating: Double
    let ratingCount: Int
    let address: String
    let isOnline: Bool
}

struct NotificationSwitches: Decodable, Equatable {
    var bookings: Bool
    var chat: Bool
    var updates: Bool
}

/// The signed-in user (GET /auth/me).
struct Me: Decodable, Identifiable {
    let id: Int
    let role: String
    let accountType: String
    let name: String
    let avatar: String
    let rating: Double
    let ratingCount: Int
    let address: String
    let phone: String
    let email: String
    let firstName: String
    let lastName: String
    let companyName: String
    let registrationNumber: String
    let website: String
    let dob: String
    let gender: String
    let postcode: String
    let lat: Double
    let lng: Double
    let overview: String
    let status: String
    let statusLabel: String
    let statusNote: String
    let nextStep: String
    let categories: [Category]
    let notifications: NotificationSwitches
    let walletBalance: Double
    let earningsBalance: Double
    let stripeLinked: Bool

    var isCompany: Bool { accountType == "company" }
    var isWorker: Bool { role == "worker" }
}

struct UserEnvelope: Decodable { let user: Me }

struct PublicUser: Decodable, Identifiable {
    let id: Int
    let role: String
    let accountType: String
    let name: String
    let avatar: String
    let rating: Double
    let ratingCount: Int
    let overview: String
    let from: String
    let categories: [Category]
    let memberSinceLabel: String
}

struct PublicProfile: Decodable {
    let user: PublicUser
    let completedBookings: Int
    let reviewsCount: Int
    let reviews: [Review]
    let recentBookings: [BookingRow]
    let otherJobs: OtherJobs
    let isBlocked: Bool

    struct OtherJobs: Decodable {
        let count: Int
        let items: [Job]
    }
}

struct Review: Decodable, Identifiable {
    let id: Int
    let rating: Double
    let comment: String
    let dateLabel: String
    let reviewer: UserBrief
}

struct ReviewPage: Decodable {
    let rating: Double
    let ratingCount: Int
    let items: [Review]
    let hasMore: Bool
}

struct PastWorker: Decodable, Identifiable {
    let id: Int
    let name: String
    let avatar: String
    let rating: Double
    let address: String
    let completedJobs: Int
    let lastWorkedAtLabel: String
}

// MARK: - Auth

struct OTPSent: Decodable {
    let email: String
    let sentTo: String
    let expiresInSeconds: Int
    let resendAfterSeconds: Int
    /// Only when the server runs with OTP_DEBUG=true (local testing). Never shown in the UI.
    let otp: String?
}

struct AuthResult: Decodable {
    let token: String
    let user: Me
}

// MARK: - Jobs

struct Job: Decodable, Identifiable, Hashable {
    let id: Int
    let category: Category
    let title: String
    let description: String
    let price: Double
    let priceLabel: String
    let priceUnit: String
    let unitLabel: String
    let startDate: String
    let endDate: String
    let startTime: String
    let endTime: String
    let startDateLabel: String
    let endDateLabel: String
    let startTimeLabel: String
    let endTimeLabel: String
    let startsAtLabel: String
    let address: String
    let addressLabel: String
    let addressText: String
    let addressHidden: Bool
    let postalCode: String
    let lat: Double
    let lng: Double
    let images: [String]
    let status: String
    let statusLabel: String
    let isOwner: Bool
    let postedBy: UserBrief
    let applicationsCount: Int
    let postedAtShort: String
    let distanceMiles: Double
    let hasApplied: Bool

}

struct Candidate: Decodable, Identifiable {
    var id: Int { applicationId }
    let applicationId: Int
    let status: String
    let worker: Worker

    struct Worker: Decodable {
        let id: Int
        let name: String
        let avatar: String
        let rating: Double
        let ratingCount: Int
        let isOnline: Bool
        let categories: [String]
    }
}

struct JobDetail: Decodable {
    let job: Job
    let candidates: [Candidate]?
    let bookingId: Int?
    let applicationStatus: String?
}

struct JobEnvelope: Decodable { let job: Job }

// MARK: - Payments

struct Card: Decodable, Identifiable {
    let id: Int
    let brand: String
    let last4: String
    let masked: String
    let expMonth: Int
    let expYear: Int
    let isDefault: Bool
}

struct Checkout: Decodable {
    let job: Job
    let worker: UserBrief
    let total: Double
    let totalLabel: String
    let breakdown: String
    let walletBalance: Double
    let walletEnough: Bool
    let cards: [Card]
}

struct Transaction: Decodable, Identifiable {
    let id: Int
    let type: String
    let amount: Double
    let amountLabel: String
    let isCredit: Bool
    let title: String
    let description: String
    let dateTimeLabel: String
}

struct Wallet: Decodable {
    let balance: Double
    let balanceLabel: String
    let note: String
    let history: Page<Transaction>
}

struct Earnings: Decodable {
    let balance: Double
    let balanceLabel: String
    let stripeLinked: Bool
    let note: String
    let history: Page<Transaction>
}

struct BalanceResult: Decodable {
    let balance: Double
    let balanceLabel: String
}

// MARK: - Bookings

struct Cancellation: Decodable {
    let id: Int
    let status: String
    let requestedByRole: String
    let requestedByMe: Bool
    let title: String
    let reason: String
    let description: String
    let images: [String]
    let dateLabel: String
}

struct TimelineEvent: Decodable, Identifiable {
    let id: Int
    let type: String
    let title: String
    let lat: Double
    let lng: Double
    let address: String
    let note: String
    let dateLabel: String
}

struct LiveLocation: Decodable {
    let shared: Bool
    let lat: Double
    let lng: Double
}

struct Delivery: Decodable {
    let description: String
    let images: [String]
    let dateLabel: String
    let delivered: Bool
}

struct PaymentInfo: Decodable {
    let method: String
    let status: String
    let amount: Double
    let refundAmount: Double
    let label: String
}

struct DisputeRef: Decodable {
    let id: Int
    let status: String
    let type: String
}

struct Booking: Decodable, Identifiable {
    let id: Int
    let code: String
    let status: String
    let statusLabel: String
    let stage: String
    let category: Category
    let title: String
    let description: String
    let images: [String]
    let amount: Double
    let priceLabel: String
    let unitLabel: String
    let jobId: Int
    let startDateLabel: String
    let endDateLabel: String
    let startTimeLabel: String
    let endTimeLabel: String
    let address: String
    let addressLabel: String
    let addressText: String
    let lat: Double
    let lng: Double
    let client: UserBrief
    let worker: UserBrief
    let counterpart: UserBrief
    let timeline: [TimelineEvent]
    let liveLocation: LiveLocation
    let delivery: Delivery
    @Lenient var cancellation: Cancellation?
    let hasPendingCancellation: Bool
    let pendingCancellationId: Int
    let canRespondToCancellation: Bool
    let payment: PaymentInfo
    @Lenient var myReview: Review?
    @Lenient var theirReview: Review?
    let theirReviewHidden: Bool
    let hasMyReview: Bool
    let rating: Double
    @Lenient var dispute: DisputeRef?
    let hasDispute: Bool
    let actions: [String]
    let dateTitle: String
    let dateLabel: String
}

struct BookingEnvelope: Decodable { let booking: Booking }

/// Short booking for list tabs and cancellation lists.
struct BookingRow: Decodable, Identifiable {
    let id: Int
    let code: String
    let status: String
    let statusLabel: String
    let category: Category
    let title: String
    let description: String
    let amount: Double
    let priceLabel: String
    let counterpart: UserBrief
    let dateTitle: String
    let dateLabel: String
    let rating: Double
    let actions: [String]
    let images: [String]
    @Lenient var cancellation: Cancellation?
    let cancellationId: Int?
}

// MARK: - Disputes

struct DisputeRow: Decodable, Identifiable {
    let label: String
    let value: String
    let tone: String
    var id: String { label }
}

struct Dispute: Decodable, Identifiable {
    let id: Int
    let type: String
    let typeLabel: String
    let tag: String
    let status: String
    let statusLabel: String
    let statusBadge: String
    let reason: String
    let returnPercent: Int
    let finalReturnPercent: Int
    let description: String
    let images: [String]
    let resolutionNote: String
    let rows: [DisputeRow]
    let dateLabel: String
    let bookingId: Int
    let category: Category
    let title: String
    let priceLabel: String
    let jobDescription: String
    let jobImages: [String]
    let startDateLabel: String
    let endDateLabel: String
    let startTimeLabel: String
    let endTimeLabel: String
    let address: String
    let addressLabel: String
    let addressText: String
    let bookingStatus: String
    let client: UserBrief
    let worker: UserBrief
    let raisedBy: UserBrief
    /// Cancellation disputes: the cancellation request that was declined. Empty for order disputes.
    @Lenient var cancellation: Cancellation?

    var isResolved: Bool { status == "resolved" }
    var cancellationRequest: Cancellation? { cancellation.flatMap { $0.id > 0 ? $0 : nil } }
}

struct DisputeEnvelope: Decodable { let dispute: Dispute }

// MARK: - Chat and notifications

struct Conversation: Decodable, Identifiable, Hashable {
    let id: Int
    let kind: String
    let user: UserBrief
    let lastMessage: String
    let unreadCount: Int
    let isBlocked: Bool
    let blockedByMe: Bool
    let canMessage: Bool
    let subtitle: String
    let canBlock: Bool

}

struct ConversationList: Decodable {
    let items: [Conversation]
    let note: String
}

struct ConversationEnvelope: Decodable { let conversation: Conversation }

struct Message: Decodable, Identifiable, Equatable {
    let id: Int
    let mine: Bool
    let type: String
    let text: String
    let attachment: String
    let lat: Double
    let lng: Double
    let createdAt: String
    let isRead: Bool
}

struct MessagePage: Decodable {
    let conversation: Conversation
    let items: [Message]
    let hasMore: Bool
}

struct MessageEnvelope: Decodable { let message: Message }

struct AppNotification: Decodable, Identifiable {
    let id: Int
    let type: String
    let title: String
    let body: String
    let refType: String
    let refId: Int
    var isRead: Bool
    let dateLabel: String
}

struct NotificationPage: Decodable {
    var items: [AppNotification]
    let hasMore: Bool
    let unreadCount: Int
}

struct Summary: Decodable {
    let unreadNotifications: Int
    let unreadMessages: Int
    let pendingCancellationRequests: Int
}

// MARK: - Content and lookups

struct Options: Decodable {
    let reasons: [String]
    let returnPaymentPercents: [Int]
    let genders: [String]
    let priceUnits: [String]
    let jobSort: [SortOption]
    let distanceMiles: [Int]
    let countries: [String]

    struct SortOption: Decodable, Hashable {
        let key: String
        let title: String
    }
}

struct ContentPage: Decodable {
    let title: String
    let body: String
    let lastUpdatedLabel: String
}

struct AppInfo: Decodable {
    let name: String
    let poweredBy: String
    let version: String
    let about: String
    let website: String
    let email: String
    let loggedInAs: String
    let responseNote: String
}
