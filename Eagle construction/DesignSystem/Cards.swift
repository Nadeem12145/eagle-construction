import MapKit
import SwiftUI
import UIKit

// MARK: - Imagery

enum Imagery {
    /// Design photos used when a job has no uploaded pictures yet.
    static let jobPhoto: [String: String] = [
        "Laundry": "photo_laundry_red", "Waiters": "photo_waiter", "Painter": "photo_painter", "Cleaners": "photo_cleaner",
        "Automotive": "photo_automotive", "Furniture Maker": "photo_furniture_maker", "General Labor": "photo_general_labor",
    ]

    /// Asset for a category: the API's `icon` names the asset (cat_general_labor ...).
    static func categoryAsset(_ category: Category) -> String? {
        if let photo = jobPhoto[category.name] { return photo }
        return UIImage(named: category.icon) != nil ? category.icon : nil
    }
}

/// Fills its frame with a remote image, or the given asset while loading / when there is none.
struct RemoteImage: View {
    let url: String?
    var fallbackAsset: String? = nil

    var body: some View {
        Color.clear
            .overlay {
                if let url, !url.isEmpty, let link = URL(string: url) {
                    AsyncImage(url: link, transaction: SwiftUI.Transaction(animation: .easeOut(duration: 0.2))) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            fallback
                        }
                    }
                } else {
                    fallback
                }
            }
            .clipped()
    }

    @ViewBuilder
    private var fallback: some View {
        if let fallbackAsset {
            Image(fallbackAsset).resizable().scaledToFill()
        } else {
            Palette.primary50.overlay(Image(systemName: "photo").type(20, .regular, Palette.primary100))
        }
    }
}

struct FillImage: View {
    let name: String

    var body: some View {
        Color.clear.overlay(Image(name).resizable().scaledToFill()).clipped()
    }
}

struct AvatarView: View {
    let name: String
    var url: String = ""
    var size: CGFloat = 40
    var online = false
    var ring = false

    var body: some View {
        Group {
            if !url.isEmpty {
                RemoteImage(url: url)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.primary100)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .padding(ring ? 4 : 0)
        .background { if ring { Circle().fill(.white) } }
        .overlay(alignment: .bottomTrailing) {
            if online {
                Circle()
                    .fill(Tone.success.foreground)
                    .frame(width: max(10, size * 0.28), height: max(10, size * 0.28))
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

extension AvatarView {
    init(user: UserBrief, size: CGFloat = 40, showsOnline: Bool = false, ring: Bool = false) {
        self.init(name: user.name, url: user.avatar, size: size, online: showsOnline && user.isOnline, ring: ring)
    }
}

struct CategoryThumb: View {
    let category: Category
    var imageURL: String? = nil
    var size: CGFloat = 56
    var radius: CGFloat = Radius.md

    var body: some View {
        Group {
            if imageURL != nil || Imagery.categoryAsset(category) != nil {
                RemoteImage(url: imageURL, fallbackAsset: Imagery.categoryAsset(category))
            } else {
                Image(systemName: "party.popper")
                    .type(size * 0.42, .regular, Palette.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.primary50)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// A real map centred on a coordinate.
struct LocationMap: View {
    let lat: Double
    let lng: Double
    var showsPulse = true
    var span = 0.01

    var body: some View {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)))) {
            Annotation("", coordinate: coordinate) {
                ZStack {
                    if showsPulse { Circle().fill(Palette.primary.opacity(0.18)).frame(width: 52, height: 52) }
                    Circle().fill(.white).frame(width: 18, height: 18)
                    Circle().fill(Palette.primary).frame(width: 12, height: 12)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Job and booking cards

struct JobRow {
    let icon: String
    let text: String
}

struct JobCard: View {
    let category: Category
    var imageURL: String? = nil
    var title: String? = nil
    var status: String? = nil
    var rightMeta: String? = nil
    var rows: [JobRow] = []
    var descriptionText: String? = nil
    var postedBy: UserBrief? = nil
    var date: (label: String, value: String)? = nil
    var price: String? = nil
    var unit: String? = nil
    var rating: Double? = nil
    var buttonTitle: String? = nil
    var onButton: () -> Void = {}
    var onTap: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 14) {
                        CategoryThumb(category: category, imageURL: imageURL)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top) {
                                Text(title ?? category.name).type(16, .semibold).lineLimit(1).minimumScaleFactor(0.85)
                                Spacer(minLength: 6)
                                if let status, !status.isEmpty {
                                    StatusBadge(label: status)
                                } else if let rightMeta {
                                    Text(rightMeta).type(12, .medium, Palette.text3)
                                }
                            }
                            ForEach(rows.indices, id: \.self) { index in
                                HStack(spacing: 6) {
                                    Image(systemName: rows[index].icon).type(11, .regular, Palette.text3).frame(width: 15)
                                    Text(rows[index].text).type(13, .regular, Palette.text2).lineLimit(1).minimumScaleFactor(0.85)
                                }
                            }
                            if let descriptionText, !descriptionText.isEmpty {
                                Text(descriptionText).type(13, .regular, Palette.text3).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            if let rating, rating > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill").type(11, .regular, Palette.star)
                                    Text(String(format: "%.1f", rating)).type(13, .semibold)
                                }
                            }
                            if let postedBy {
                                HStack(spacing: 6) {
                                    AvatarView(user: postedBy, size: 18)
                                    Text("By \(postedBy.name)").type(12, .medium, Palette.text3)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)

                    if date != nil || price != nil {
                        Rectangle().fill(Palette.divider).frame(height: 1).padding(.horizontal, 14)
                        HStack(alignment: .firstTextBaseline) {
                            if let date {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(date.label).type(11, .medium, Palette.text3)
                                    Text(date.value).type(13, .semibold)
                                }
                            }
                            Spacer()
                            if let price {
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(price).type(18, .bold, Palette.primary)
                                    if let unit { Text(unit).type(12, .medium, Palette.text3) }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let buttonTitle {
                AppButton(title: buttonTitle, height: 40, fontSize: 15, action: onButton)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
        .card()
    }
}

extension JobCard {
    /// A job as it appears on My Requests (client) and Live Jobs (worker).
    init(job: Job, forWorker: Bool, onTap: @escaping () -> Void) {
        self.init(category: job.category, imageURL: job.images.first,
                  status: forWorker ? (job.hasApplied ? job.statusLabel : nil) : job.statusLabel,
                  rightMeta: forWorker && !job.hasApplied ? job.postedAtShort : nil,
                  rows: [JobRow(icon: "clock", text: "Start time: \(job.startsAtLabel)"),
                         JobRow(icon: "mappin.and.ellipse", text: "\(job.addressLabel): \(job.addressText)")],
                  price: job.priceLabel, unit: job.unitLabel, onTap: onTap)
    }

    /// A booking / order row (Bookings and Orders tabs, Cancellation Requests).
    init(row: BookingRow, showsStatus: Bool = true, showsPerson: Bool = true, buttonTitle: String? = nil, onButton: @escaping () -> Void = {},
         onTap: @escaping () -> Void) {
        self.init(category: row.category, imageURL: row.images.first, title: row.title.isEmpty ? nil : row.title, status: showsStatus ? row.statusLabel : nil,
                  descriptionText: row.description, postedBy: showsPerson ? row.counterpart : nil, date: (row.dateTitle, row.dateLabel),
                  price: row.priceLabel, rating: row.rating, buttonTitle: buttonTitle, onButton: onButton, onTap: onTap)
    }
}

struct KeyValueRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var tone: Tone? = nil
}

extension Tone {
    /// `tone` strings sent by the API on dispute rows.
    static func named(_ name: String) -> Tone? {
        switch name {
        case "success": .success
        case "danger": .danger
        case "info": .info
        case "warning": .warning
        default: nil
        }
    }
}

struct DisputeCard: View {
    let dispute: Dispute
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    CategoryThumb(category: dispute.category, imageURL: dispute.jobImages.first, size: 40, radius: 10)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(dispute.title).type(16, .semibold)
                        Text(dispute.reason).type(13, .medium, Palette.text3)
                    }
                    Spacer(minLength: 4)
                    StatusBadge(label: dispute.tag)
                }
                VStack(spacing: 8) {
                    ForEach(dispute.rows) { row in
                        HStack {
                            Text(row.label).type(13, .regular, Palette.text3)
                            Spacer()
                            if let tone = Tone.named(row.tone) {
                                StatusBadge(label: row.value, tone: tone)
                            } else {
                                Text(row.value).type(13, .semibold)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
    }
}

struct ReviewCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarView(user: review.reviewer, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.reviewer.name).type(14, .semibold)
                    Text(review.dateLabel).type(12, .regular, Palette.text3)
                }
                Spacer()
                RatingPill(rating: review.rating)
            }
            if !review.comment.isEmpty {
                Text(review.comment).type(13, .regular, Palette.text2).lineSpacing(3).lineLimit(3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct SectionTitle: View {
    let title: String
    var count: Int? = nil
    var action: String? = nil
    var onAction: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            Text(title).type(17, .semibold)
            if let count { Text("(\(count))").type(15, .medium, Palette.text3) }
            Spacer()
            if let action {
                Button(action, action: onAction).buttonStyle(.plain).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.primary)
            }
        }
    }
}

/// Grouped list row with a tinted icon tile and chevron.
struct MenuRow: View {
    let title: String
    let icon: String
    var danger = false
    var showsChevron = true
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .type(16, .medium, danger ? Tone.danger.foreground : Palette.primary)
                    .frame(width: 36, height: 36)
                    .background(danger ? Tone.danger.background : Palette.primary50, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title).type(15, .semibold, danger ? Tone.danger.foreground : Palette.ink)
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.right").type(13, .semibold, Palette.muted)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct TransactionList: View {
    let items: [Transaction]

    var body: some View {
        if items.isEmpty {
            EmptyState(icon: "clock.arrow.circlepath", title: "No payments yet").card()
        } else {
            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    let tone: Tone = item.isCredit ? .success : .danger
                    HStack(spacing: 14) {
                        Image(systemName: item.isCredit ? "arrow.up" : "arrow.down")
                            .type(15, .semibold, tone.foreground)
                            .frame(width: 36, height: 36)
                            .background(tone.background, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).type(15, .semibold).lineLimit(1)
                            Text(item.dateTimeLabel).type(12, .regular, Palette.text3)
                        }
                        Spacer()
                        Text(item.amountLabel).type(16, .bold, tone.foreground)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 64)
                    if index < items.count - 1 {
                        Rectangle().fill(Palette.divider).frame(height: 1).padding(.leading, 64)
                    }
                }
            }
            .card()
        }
    }
}
