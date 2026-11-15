import CoreLocation
import SwiftUI

// MARK: - Booking payment (client selects a worker)

struct BookingPaymentScreen: View {
    let jobId: Int
    let workerId: Int
    @Environment(Navigator.self) private var nav
    @Environment(Toaster.self) private var toaster
    @State private var state: LoadState<Checkout> = .loading
    @State private var method = 0
    @State private var cardId: Int?
    @State private var isPaying = false
    @State private var showsSuccess = false

    var body: some View {
        ListScreen(title: "Booking Payment") {
            LoadView(state: state, retry: load) { checkout in
                content(checkout)
            }
        } bottom: {
            if state.value != nil {
                FormButtonBar(title: "Pay Now", isLoading: isPaying, background: Palette.background) { Task { await pay() } }
            }
        }
        .appSheet(isPresented: $showsSuccess) {
            VStack(spacing: 12) {
                Image("illus_booking_success").resizable().scaledToFit().frame(height: 134)
                Text("Congratulations!").type(24, .bold)
                Text("Your booking payment has been successfully processed, and we are delighted to inform you that your booking is now active.")
                    .type(15, .regular, Palette.text2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                AppButton(title: "Back to home") {
                    showsSuccess = false
                    nav.popToRoot()
                }
                .padding(.top, 12)
            }
            .padding(20)
            .padding(.bottom, 8)
        }
        .task { await load() }
    }

    private func content(_ checkout: Checkout) -> some View {
        let job = checkout.job
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    CategoryThumb(category: job.category, imageURL: job.images.first, size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.category.name).type(17, .semibold)
                        Text.joined(Text("\(job.addressLabel): ").foregroundStyle(Palette.text3), Text(job.addressText).foregroundStyle(Palette.ink))
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(2)
                    }
                }
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    GridRow { cell("Start Date", job.startDateLabel); cell("End Date", job.endDateLabel) }
                    GridRow { cell("Start Time", job.startTimeLabel); cell("End Time", job.endTimeLabel) }
                }
                Rectangle().fill(Palette.divider).frame(height: 1)
                HStack(spacing: 10) {
                    AvatarView(user: checkout.worker, size: 32)
                    Text(checkout.worker.name).type(14, .semibold)
                    Spacer()
                    if checkout.worker.rating > 0 { RatingPill(rating: checkout.worker.rating) }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            SectionTitle(title: "Payment Method")
            methodRow(0, "Credit/Debit Card", "creditcard", note: nil)
            if method == 0 {
                VStack(spacing: 8) {
                    ForEach(checkout.cards) { card in
                        Button { cardId = card.id } label: {
                            HStack(spacing: 12) {
                                Text(card.brand).type(14, .bold, Palette.primary).frame(width: 52, alignment: .leading)
                                Text(verbatim: card.masked).type(14, .semibold)
                                Spacer()
                                RadioMark(selected: cardId == card.id)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(.white, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Palette.border))
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        nav.push(AddCardScreen(title: "Add New Card", buttonTitle: "Add") { nav.pop() })
                    } label: {
                        Label("Add New Card", systemImage: "plus").type(14, .semibold, Palette.primary).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 12)
            }
            methodRow(1, "Eagle Wallet", "wallet.bifold", note: "Balance \(Formats.money(checkout.walletBalance))")

            SectionTitle(title: "Payment Details")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Payment").type(15, .medium, Palette.text2)
                    Spacer()
                    Text(checkout.totalLabel).type(18, .bold, Palette.primary)
                }
                if !checkout.breakdown.isEmpty { Text(checkout.breakdown).type(12, .regular, Palette.text3) }
            }
            .padding(16)
            .card()
        }
    }

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).type(12, .medium, Palette.text3)
            Text(value).type(14, .semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func methodRow(_ index: Int, _ title: String, _ icon: String, note: String?) -> some View {
        let isOn = method == index
        return Button { method = index } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .type(16, .regular, Palette.primary)
                    .frame(width: 36, height: 36)
                    .background(isOn ? .white : Palette.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).type(15, .semibold)
                    if let note { Text(note).type(12, .medium, Palette.text3) }
                }
                Spacer()
                RadioMark(selected: isOn)
            }
            .padding(.horizontal, 14)
            .frame(height: 60)
            .background(isOn ? Palette.primary50 : .white, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(isOn ? Palette.primary : Palette.border, lineWidth: isOn ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        await fetch($state) { try await API.checkout(jobId: jobId, workerId: workerId) }
        if let checkout = state.value, cardId == nil || !checkout.cards.contains(where: { $0.id == cardId }) {
            cardId = checkout.cards.first(where: \.isDefault)?.id ?? checkout.cards.first?.id
        }
    }

    private func pay() async {
        guard let checkout = state.value else { return }
        if method == 0 && cardId == nil {
            nav.push(AddCardScreen(title: "Add New Card", buttonTitle: "Add") { nav.pop() })
            return
        }
        if method == 1 && !checkout.walletEnough {
            toaster.show("Your wallet balance is not enough. Add balance or pay by card.", error: true)
            return
        }
        isPaying = true
        defer { isPaying = false }
        do {
            _ = try await API.book(jobId: jobId, workerId: workerId, method: method == 0 ? "card" : "wallet", cardId: method == 0 ? cardId : nil)
            showsSuccess = true
        } catch {
            toaster.show(error)
        }
    }
}

// MARK: - Booking / order details

struct BookingDetailScreen: View {
    let bookingId: Int
    var opensAcceptDelivery = false
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var state: LoadState<Booking> = .loading
    @State private var rating: RateKind?
    @State private var busy = ""
    @State private var didOpenAccept = false

    private var isWorker: Bool { session.me?.isWorker ?? false }

    enum RateKind: Identifiable {
        case acceptDelivery, review
        var id: Self { self }
    }

    var body: some View {
        DetailLoading(state: state, retry: load) { booking in
            DetailScaffold(summary: summary(booking), showsActions: !buttons(booking).isEmpty,
                           onPerson: { nav.push(PersonProfileScreen(userId: booking.counterpart.id, title: isWorker ? "Client Profile" : "Worker Profile")) },
                           onRefresh: load) {
                sections(booking)
            } actions: {
                let rows = buttons(booking).chunked(2)
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(rows[row], id: \.title) { button in
                            AppButton(title: button.title, kind: button.kind, isLoading: busy == button.title, action: button.action)
                        }
                    }
                }
            }
        }
        .appDialog(isPresented: Binding(get: { rating != nil }, set: { if !$0 { rating = nil } })) {
            if let rating {
                RateDialog(title: isWorker ? "Please rate your experience with this client" : "Please rate your experience with this worker",
                           onClose: { self.rating = nil }) { stars, comment in
                    await submitRating(rating, stars: stars, comment: comment)
                }
            }
        }
        .task { await load() }
        .task(id: liveKey) { await followLiveLocation() }
    }

    // MARK: Content

    private func summary(_ booking: Booking) -> DetailSummary {
        DetailSummary(category: booking.category, images: booking.images, title: booking.title.isEmpty ? booking.category.name : booking.title,
                      status: booking.statusLabel, price: booking.priceLabel, addressLabel: booking.addressLabel,
                      address: booking.addressText, startDate: booking.startDateLabel, endDate: booking.endDateLabel,
                      startTime: booking.startTimeLabel, endTime: booking.endTimeLabel, person: booking.counterpart,
                      description: booking.description, footerDate: booking.dateLabel)
    }

    @ViewBuilder
    private func sections(_ booking: Booking) -> some View {
        ForEach(booking.timeline.filter { ["moving", "arrived"].contains($0.type) && ($0.lat != 0 || $0.lng != 0) }) { event in
            mapCard(title: event.title, lat: event.lat, lng: event.lng, note: event.address, date: event.dateLabel)
        }
        if booking.stage == "moving" && booking.liveLocation.shared && !isWorker {
            mapCard(title: "Worker's live location", lat: booking.liveLocation.lat, lng: booking.liveLocation.lng, note: "", date: "Live")
        }
        if booking.delivery.delivered {
            DetailCard(title: "Delivery Work", date: booking.delivery.dateLabel) {
                if !booking.delivery.images.isEmpty { PhotoStrip(urls: booking.delivery.images, height: 56) }
                if !booking.delivery.description.isEmpty {
                    Text("Description").type(13, .semibold)
                    Text(booking.delivery.description).type(13, .regular, Palette.text2).lineSpacing(3)
                }
            }
        }
        if let cancellation = booking.cancellation, cancellation.id > 0 {
            DetailCard(title: cancellation.reason.isEmpty ? "Cancel Reason" : cancellation.reason, date: cancellation.dateLabel) {
                if !cancellation.title.isEmpty {
                    Text(cancellation.title).type(13, .semibold, cancellation.status == "pending" ? Tone.warning.foreground : Tone.danger.foreground)
                }
                if !cancellation.images.isEmpty { PhotoStrip(urls: cancellation.images, height: 56) }
                if !cancellation.description.isEmpty { Text(cancellation.description).type(13, .regular, Palette.text2).lineSpacing(3) }
            }
        }
        if let dispute = booking.dispute {
            Button { nav.push(DisputeDetailScreen(disputeId: dispute.id)) } label: {
                HStack {
                    Image(systemName: "scale.3d").type(16, .medium, Tone.danger.foreground)
                    Text(dispute.type == "cancellation" ? "Cancellation Dispute" : "Dispute").type(15, .semibold)
                    Spacer()
                    StatusBadge(label: dispute.status == "resolved" ? "Resolved" : "Not Resolved")
                    Image(systemName: "chevron.right").type(13, .semibold, Palette.muted)
                }
                .padding(14)
                .card()
            }
            .buttonStyle(.plain)
        }
        if let review = booking.myReview {
            reviewCard("My Review", review)
        }
        if let review = booking.theirReview {
            reviewCard(isWorker ? "Client Review" : "Worker Review", review)
        } else if booking.theirReviewHidden {
            InfoNote(label: "Review", text: "\(isWorker ? "The client" : "The worker") left a review. Rate your experience to see it.")
        }
        if booking.payment.refundAmount > 0 || !booking.payment.label.isEmpty {
            HStack {
                Text("Payment").type(14, .medium, Palette.text3)
                Spacer()
                Text(booking.payment.label).type(14, .semibold)
            }
            .padding(14)
            .card()
        }
    }

    private func mapCard(title: String, lat: Double, lng: Double, note: String, date: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin.and.ellipse").type(14, .medium, Palette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).type(14, .semibold)
                    if !note.isEmpty { Text(note).type(12, .regular, Palette.text3).lineLimit(2) }
                }
                Spacer()
                if !date.isEmpty { Text(date).type(12, .medium, Palette.text3) }
            }
            LocationMap(lat: lat, lng: lng)
                .frame(height: 138)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func reviewCard(_ title: String, _ review: Review) -> some View {
        DetailCard(title: title, date: review.dateLabel) {
            if !review.comment.isEmpty { Text(review.comment).type(13, .regular, Palette.text2).lineSpacing(3) }
            RatingPill(rating: review.rating).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: Buttons

    private struct ActionButton {
        let title: String
        var kind: ButtonKind = .primary
        let action: () -> Void
    }

    private func buttons(_ booking: Booking) -> [ActionButton] {
        var list: [ActionButton] = []
        if booking.canRespondToCancellation && booking.pendingCancellationId > 0 {
            list.append(ActionButton(title: "Decline", kind: .dangerSoft) { Task { await answer(booking, accept: false) } })
            list.append(ActionButton(title: "Accept", kind: .success) { Task { await answer(booking, accept: true) } })
        }
        for key in booking.actions {
            switch key {
            case "accept_delivery":
                list.append(ActionButton(title: "Accept Delivery") { rating = .acceptDelivery })
            case "go_for_work":
                list.append(ActionButton(title: "Go For Work") { shareLocation(booking, arriving: false) })
            case "arrive":
                list.append(ActionButton(title: "Arrive on Location") { shareLocation(booking, arriving: true) })
            case "finish":
                list.append(ActionButton(title: "Finish Work") { nav.push(FinishWorkScreen(bookingId: booking.id)) })
            case "message":
                list.append(ActionButton(title: "Message", kind: .secondary) { Task { await message(booking) } })
            case "cancel":
                list.append(ActionButton(title: "Cancel Booking", kind: .dangerSoft) {
                    nav.push(CancelBookingScreen(bookingId: booking.id, target: isWorker ? "Client" : "Worker"))
                })
            case "dispute":
                list.append(ActionButton(title: "Dispute", kind: .dangerSoft) { nav.push(AddDisputeScreen(bookingId: booking.id)) })
            case "rate":
                list.append(ActionButton(title: isWorker ? "Rate Your Experience" : "Rate Work Experience") { rating = .review })
            case "request_again":
                list.append(ActionButton(title: "Request Again", kind: .secondary) { nav.push(NewRequestScreen(category: booking.category)) })
            default:
                break
            }
        }
        // The API's order already matches the design: Message | Go For Work, then Cancel Booking.
        return list
    }

    private func shareLocation(_ booking: Booking, arriving: Bool) {
        nav.push(MapPickerScreen(title: "Share Current Location", buttonTitle: "Share Location", showsSearch: false) { place in
            do {
                if arriving {
                    _ = try await API.arrive(booking.id, lat: place.lat, lng: place.lng, address: place.address)
                    toaster.show("Arrival shared with the client")
                } else {
                    _ = try await API.startWork(booking.id, lat: place.lat, lng: place.lng, address: place.address)
                    toaster.show("You are on your way. The client can see your location.")
                }
                nav.pop()
            } catch {
                toaster.show(error)
            }
        })
    }

    private func message(_ booking: Booking) async {
        busy = "Message"
        defer { busy = "" }
        do {
            let conversation = try await API.openConversation(with: booking.counterpart.id)
            nav.push(ChatScreen(conversationId: conversation.id, preview: conversation))
        } catch {
            toaster.show(error)
        }
    }

    private func answer(_ booking: Booking, accept: Bool) async {
        busy = accept ? "Accept" : "Decline"
        defer { busy = "" }
        do {
            let result = try await API.answerCancellation(booking.pendingCancellationId, accept: accept)
            state = .loaded(result.booking)
            toaster.show(result.message)
        } catch {
            toaster.show(error)
        }
    }

    private func submitRating(_ kind: RateKind, stars: Int, comment: String) async {
        do {
            switch kind {
            case .acceptDelivery:
                state = .loaded(try await API.acceptDelivery(bookingId, rating: stars, comment: comment))
                toaster.show("Delivery accepted. Thank you for your review!")
            case .review:
                state = .loaded(try await API.review(bookingId, rating: stars, comment: comment))
                toaster.show("Thank you for your review!")
            }
            rating = nil
        } catch {
            toaster.show(error)
        }
    }

    // MARK: Loading and live location

    private func load() async {
        await fetch($state) { try await API.booking(bookingId) }
        if opensAcceptDelivery && !didOpenAccept, let booking = state.value, booking.actions.contains("accept_delivery") {
            didOpenAccept = true
            rating = .acceptDelivery
        }
    }

    /// Changes when the booking moves between stages, restarting the live-location loop.
    private var liveKey: String {
        guard let booking = state.value else { return "" }
        return "\(booking.status)-\(booking.stage)"
    }

    /// While a worker is on the way: the worker's phone sends its position, the client's screen refreshes the map.
    private func followLiveLocation() async {
        guard let booking = state.value, booking.status == "in_progress", booking.stage == "moving" else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(15))
            if Task.isCancelled { return }
            if isWorker {
                if let location = await LocationService.shared.currentLocation() {
                    try? await API.shareLocation(bookingId, lat: location.coordinate.latitude, lng: location.coordinate.longitude)
                }
            } else {
                await load()
            }
        }
    }
}

extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

struct RateDialog: View {
    let title: String
    var onClose: () -> Void = {}
    let onSubmit: (Int, String) async -> Void
    @State private var stars = 5
    @State private var review = ""
    @State private var isSending = false

    private var word: String { ["", "Poor", "Fair", "Average", "Good", "Excellent"][stars] }

    var body: some View {
        AppDialog(title: title, onClose: onClose) {
            VStack(spacing: 14) {
                Text(word).type(15, .semibold, Palette.primary)
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { value in
                        Button { stars = value } label: {
                            Image(systemName: "star.fill").type(30, .regular, value <= stars ? Palette.star : Palette.border)
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("", text: $review, prompt: Text("Write review").foregroundStyle(Palette.muted), axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(4, reservesSpace: true)
                    .padding(14)
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Palette.border))
                    .tapToFocus()
                AppButton(title: "Submit Review", isLoading: isSending) {
                    Task {
                        isSending = true
                        await onSubmit(stars, review.trimmed)
                        isSending = false
                    }
                }
            }
        }
    }
}

// MARK: - Forms

private let fallbackReasons = ["Poor Communication", "Technical Glitches", "Mind Change", "Wrong Address", "Safety Concerns"]

struct CancelBookingScreen: View {
    let bookingId: Int
    let target: String
    @Environment(Navigator.self) private var nav
    @Environment(Toaster.self) private var toaster
    @State private var images: [PickedImage] = []
    @State private var reason = ""
    @State private var details = ""
    @State private var reasons = fallbackReasons
    @State private var isSending = false
    @State private var showsCancelled = false

    var body: some View {
        ListScreen(title: "Cancel Booking", background: .white) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Attach pictures for proof").type(16, .semibold)
                PhotoPickerRow(images: $images, limit: 5)
                Text("Tap to select image for cover photo and hold for view.").type(12, .regular, Palette.text3)
                AppField(text: $reason, placeholder: "Select Reason", options: reasons)
                AppField(text: $details, placeholder: "Explain Cancel Reason...", height: 120, multiline: true, maxLength: 500)
                InfoNote(label: "Note", text: "Once you cancel this booking, your request will be sent to the \(target). If they accept your cancellation request, your booking will be successfully canceled. However, if they decline the request, you can utilize the dispute option.")
            }
        } bottom: {
            FormButtonBar(title: "Confirm", kind: .danger, isLoading: isSending) { Task { await send() } }
        }
        .appDialog(isPresented: $showsCancelled) {
            AppDialog(title: "Booking Cancelled!",
                      message: "Your cancellation request has been sent to the \(target.lowercased()). If they accept your cancellation request, your booking will be successfully canceled. However, if they decline the request, a dispute will be automatically created, and our Support team will promptly address and resolve the matter for you.",
                      titleColor: Tone.danger.foreground, icon: "xmark.circle", tone: .danger,
                      actions: [DialogAction(title: "Back to home") {
                          showsCancelled = false
                          nav.popToRoot()
                      }])
        }
        .task { if let options = try? await API.options(), !options.reasons.isEmpty { reasons = options.reasons } }
    }

    private func send() async {
        guard !reason.isEmpty else {
            toaster.show("Select a reason", error: true)
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            _ = try await API.requestCancellation(bookingId, reason: reason, description: details.trimmed, images: images.map(\.data))
            showsCancelled = true
        } catch {
            toaster.show(error)
        }
    }
}

struct FinishWorkScreen: View {
    let bookingId: Int
    @Environment(Navigator.self) private var nav
    @Environment(Toaster.self) private var toaster
    @State private var images: [PickedImage] = []
    @State private var details = ""
    @State private var isSending = false

    var body: some View {
        ListScreen(title: "Finish Work", background: .white) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 4) {
                    Text("Add images").type(16, .semibold)
                    Text("(01 to 10)").type(14, .regular, Palette.text3)
                }
                PhotoPickerRow(images: $images)
                Text("Add More Details").type(16, .semibold).padding(.top, 4)
                AppField(label: "Description", text: $details, placeholder: "Enter Description About Service", height: 120, multiline: true, maxLength: 500)
            }
        } bottom: {
            FormButtonBar(title: "Finish", isLoading: isSending) { Task { await send() } }
        }
    }

    private func send() async {
        guard !images.isEmpty else {
            toaster.show("Add at least one photo of the finished work", error: true)
            return
        }
        guard !details.trimmed.isEmpty else {
            toaster.show("Describe the work you delivered", error: true)
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            toaster.show(try await API.finishWork(bookingId, description: details.trimmed, images: images.map(\.data)))
            nav.pop()
        } catch {
            toaster.show(error)
        }
    }
}

struct AddDisputeScreen: View {
    let bookingId: Int
    @Environment(Navigator.self) private var nav
    @Environment(Toaster.self) private var toaster
    @State private var images: [PickedImage] = []
    @State private var reason = ""
    @State private var percent = "40%"
    @State private var details = ""
    @State private var reasons = fallbackReasons
    @State private var percents = ["25%", "40%", "50%", "65%", "100%"]
    @State private var isSending = false

    var body: some View {
        ListScreen(title: "Add Dispute", background: .white) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Attach pictures for proof").type(16, .semibold)
                PhotoPickerRow(images: $images, limit: 5)
                Text("Tap to select image for cover photo and hold for view.").type(12, .regular, Palette.text3)
                AppField(label: "Dispute Reason", text: $reason, placeholder: "Select Reason", options: reasons)
                AppField(label: "Return Payment", text: $percent, options: percents)
                AppField(label: "Description", text: $details, placeholder: "Enter Description About Service", height: 120, multiline: true, maxLength: 500)
            }
        } bottom: {
            FormButtonBar(title: "Dispute", kind: .danger, isLoading: isSending) { Task { await send() } }
        }
        .task {
            if let options = try? await API.options() {
                if !options.reasons.isEmpty { reasons = options.reasons }
                if !options.returnPaymentPercents.isEmpty { percents = options.returnPaymentPercents.map { "\($0)%" } }
            }
        }
    }

    private func send() async {
        guard !reason.isEmpty else {
            toaster.show("Select a dispute reason", error: true)
            return
        }
        guard !details.trimmed.isEmpty else {
            toaster.show("Describe the problem", error: true)
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            let value = Int(percent.replacingOccurrences(of: "%", with: "")) ?? 0
            toaster.show(try await API.raiseDispute(bookingId: bookingId, reason: reason, returnPercent: value, description: details.trimmed,
                                                    images: images.map(\.data)))
            nav.pop()
        } catch {
            toaster.show(error)
        }
    }
}

// MARK: - Cancellation requests

struct CancellationRequestsScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @State private var tab = 0
    @State private var state: LoadState<[BookingRow]> = .loading

    var body: some View {
        ListScreen(title: "Cancellation Requests") {
            VStack(spacing: 16) {
                SegmentedTabs(items: ["My Requests", session.me?.isWorker == true ? "Client Requests" : "Worker Requests"], selection: $tab)
                LoadView(state: state, retry: load) { rows in
                    VStack(spacing: 12) {
                        if rows.isEmpty { EmptyState(icon: "xmark.circle", title: "No cancellation requests") }
                        ForEach(rows) { row in
                            JobCard(row: row, showsStatus: tab == 0, showsPerson: tab == 0) {
                                nav.push(BookingDetailScreen(bookingId: row.id))
                            }
                        }
                    }
                }
            }
        }
        .task(id: tab) {
            state = .loading
            await load()
        }
    }

    private func load() async {
        let incoming = tab == 1
        await fetch($state) { try await API.cancellationRequests(incoming: incoming).items }
    }
}
