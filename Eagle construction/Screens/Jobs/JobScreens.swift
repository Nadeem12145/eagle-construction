import SwiftUI

// MARK: - Job details (client: candidates; worker: accept / decline)

struct JobDetailScreen: View {
    let jobId: Int
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var state: LoadState<JobDetail> = .loading
    @State private var busy = ""
    @State private var showsClose = false

    var body: some View {
        DetailLoading(state: state, retry: load) { detail in
            let job = detail.job
            DetailScaffold(summary: summary(detail), showsActions: hasActions(detail), onPerson: job.isOwner ? nil : {
                nav.push(PersonProfileScreen(userId: job.postedBy.id))
            }, onRefresh: load) {
                if let candidates = detail.candidates, job.isOwner {
                    candidatesSection(candidates, job: job, booked: (detail.bookingId ?? 0) > 0)
                }
            } actions: {
                actionButtons(detail)
            }
        }
        .appDialog(isPresented: $showsClose) {
            AppDialog(title: "Close Request", message: "Workers will no longer see this request. Close it?", icon: "xmark.circle", tone: .danger,
                      onClose: { showsClose = false }, actions: [
                          DialogAction(title: "Cancel", kind: .outline) { showsClose = false },
                          DialogAction(title: "Close", kind: .danger) {
                              showsClose = false
                              Task { await run("close") { try await API.closeJob(jobId); return "Request closed" } }
                          },
                      ])
        }
        .task { await load() }
    }

    private func summary(_ detail: JobDetail) -> DetailSummary {
        let job = detail.job
        let status = job.isOwner ? job.statusLabel : (job.hasApplied ? "Already Applied" : "")
        return DetailSummary(category: job.category, images: job.images, title: job.title.isEmpty ? job.category.name : job.title, status: status,
                             price: job.priceLabel, unit: job.unitLabel, addressLabel: job.addressLabel, address: job.addressText,
                             startDate: job.startDateLabel, endDate: job.endDateLabel, startTime: job.startTimeLabel, endTime: job.endTimeLabel,
                             person: job.isOwner ? nil : job.postedBy, description: job.description, footerDate: job.isOwner ? "" : job.postedAtShort)
    }

    private func hasActions(_ detail: JobDetail) -> Bool {
        if (detail.bookingId ?? 0) > 0 { return true }
        if detail.job.isOwner { return detail.job.status == "open" }
        return true
    }

    @ViewBuilder
    private func actionButtons(_ detail: JobDetail) -> some View {
        let job = detail.job
        if let bookingId = detail.bookingId, bookingId > 0 {
            AppButton(title: session.me?.isWorker == true ? "View Order" : "View Booking") { nav.push(BookingDetailScreen(bookingId: bookingId)) }
        } else if job.isOwner {
            HStack(spacing: 12) {
                AppButton(title: "Edit Request", kind: .secondary) { nav.push(NewRequestScreen(category: job.category, editing: job)) }
                AppButton(title: "Close Request", kind: .dangerSoft, isLoading: busy == "close") { showsClose = true }
            }
        } else if job.hasApplied {
            HStack(spacing: 12) {
                AppButton(title: "Withdraw", kind: .dangerSoft, isLoading: busy == "withdraw") {
                    Task { await run("withdraw") { try await API.withdraw(from: jobId); return "Application withdrawn" } }
                }
                AppButton(title: "Accept", kind: .disabled)
            }
        } else if job.status == "open" {
            HStack(spacing: 12) {
                AppButton(title: "Decline", kind: .dangerSoft, isLoading: busy == "decline") {
                    Task {
                        await run("decline") { try await API.decline(jobId); return "Declined" }
                        nav.pop()
                    }
                }
                AppButton(title: "Accept", kind: .success, isLoading: busy == "apply") {
                    Task { await run("apply") { try await API.apply(to: jobId); return "Applied. The client will be notified." } }
                }
            }
        } else {
            AppButton(title: job.statusLabel, kind: .disabled)
        }
    }

    private func candidatesSection(_ candidates: [Candidate], job: Job, booked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select a Candidate").type(17, .semibold)
            if candidates.isEmpty {
                EmptyState(icon: "person.2", title: "No candidates yet", message: "Workers who accept your request will show here.").card()
            } else {
                VStack(spacing: 0) {
                    ForEach(candidates.indices, id: \.self) { index in
                        let worker = candidates[index].worker
                        if index > 0 { Rectangle().fill(Palette.divider).frame(height: 1).padding(.horizontal, 14) }
                        HStack(spacing: 12) {
                            Button {
                                nav.push(PersonProfileScreen(userId: worker.id, title: "Worker Profile"))
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(name: worker.name, url: worker.avatar, size: 40, online: worker.isOnline)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(worker.name).type(15, .semibold).lineLimit(1)
                                        if worker.rating > 0 {
                                            HStack(spacing: 3) {
                                                Image(systemName: "star.fill").type(10, .regular, Palette.star)
                                                Text(String(format: "%.1f (%d)", worker.rating, worker.ratingCount)).type(12, .medium, Palette.text3)
                                            }
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            if candidates[index].status == "selected" {
                                StatusBadge(label: "Selected", tone: .success)
                            } else if !booked && job.status == "open" {
                                AppButton(title: "Select", kind: .secondary, height: 36, fontSize: 14) {
                                    nav.push(PersonProfileScreen(userId: worker.id, title: "Worker Profile", selectFor: job))
                                }
                                .frame(width: 84)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 64)
                    }
                }
                .card()
            }
        }
    }

    private func load() async {
        await fetch($state) { try await API.job(jobId) }
    }

    private func run(_ name: String, _ action: () async throws -> String) async {
        busy = name
        defer { busy = "" }
        do {
            toaster.show(try await action())
            await load()
        } catch {
            toaster.show(error)
        }
    }
}

// MARK: - Post a request

struct CategoryScreen: View {
    @Environment(Navigator.self) private var nav
    @State private var state: LoadState<[Category]> = .loading

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "")
            LoadView(state: state, retry: load) { categories in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Select a category for which post you want to add").type(20, .bold).lineSpacing(3).padding(.bottom, 12)
                        ForEach(categories) { category in
                            Button { nav.push(NewRequestScreen(category: category)) } label: {
                                HStack(spacing: 14) {
                                    CategoryThumb(category: category, size: 44, radius: 22)
                                    Text(category.name).type(16, .medium)
                                    Spacer()
                                    Image(systemName: "chevron.right").type(13, .semibold, Palette.muted)
                                }
                                .frame(height: 60)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Rectangle().fill(Palette.divider).frame(height: 1).padding(.leading, 58)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .darkStatusBar()
        .task { await load() }
    }

    private func load() async {
        await fetch($state) { try await API.categories() }
    }
}

struct NewRequestScreen: View {
    let category: Category
    /// Set when editing an open request instead of posting a new one.
    var editing: Job? = nil
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var images: [PickedImage] = []
    @State private var description = ""
    @State private var price = ""
    @State private var unit = "Per Day"
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var startTime: Date?
    @State private var endTime: Date?
    @State private var postalCode = ""
    @State private var place: PickedPlace?
    @State private var isPublishing = false
    @State private var showsPublished = false
    @State private var keptImages: [String] = []
    @State private var didPrefill = false

    var body: some View {
        ListScreen(title: editing == nil ? "Add New Request" : "Edit Request", background: .white) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 4) {
                    Text("Add images").type(16, .semibold)
                    Text("(01 to 10)").type(14, .regular, Palette.text3)
                }
                if !keptImages.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(keptImages, id: \.self) { url in
                                RemoteImage(url: url)
                                    .frame(width: 68, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        Button { keptImages.removeAll { $0 == url } } label: {
                                            Image(systemName: "xmark")
                                                .type(8, .heavy, .white)
                                                .frame(width: 18, height: 18)
                                                .background(Tone.danger.foreground, in: Circle())
                                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                        }
                                        .buttonStyle(.plain)
                                        .padding(3)
                                    }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                PhotoPickerRow(images: $images, limit: max(0, 10 - keptImages.count))
                Text("Add More Details").type(16, .semibold).padding(.top, 4)
                AppField(label: "Service Category", text: .constant(category.name), readOnly: true)
                AppField(label: "Description", text: $description, placeholder: "Enter Description About Service", height: 112, multiline: true, maxLength: 500)
                HStack(alignment: .bottom, spacing: 12) {
                    AppField(label: "Offer Price", text: $price, placeholder: "Enter Price £", keyboard: .decimalPad)
                    AppField(text: $unit, options: ["Per Day", "Per Hour"]).frame(width: 136)
                }
                HStack(spacing: 12) {
                    DateField(label: "Start Date", placeholder: "Select", value: $startDate, futureOnly: true)
                    DateField(label: "End Date", placeholder: "Select", value: $endDate, futureOnly: true)
                }
                HStack(spacing: 12) {
                    DateField(label: "Start Time", placeholder: "Select", value: $startTime, time: true)
                    DateField(label: "End Time", placeholder: "Select", value: $endTime, time: true)
                }
                AppField(label: "Job Postal Code", text: $postalCode, placeholder: "Enter Postal Code")
                AppField(label: "Job Address", text: .constant(place?.address ?? ""), placeholder: "Select Address", trailing: "scope", onTap: {
                    nav.push(MapPickerScreen(title: "Location", buttonTitle: "Save") { picked in
                        place = picked
                        if postalCode.isEmpty { postalCode = picked.postalCode }
                        nav.pop()
                    })
                })
                InfoNote(label: "Disclaimer", text: "Your exact location is used to match nearby workers, but for privacy, only your town (e.g., Ilford, Whitechapel) will be shown. The full address will only be shared once a worker accepts and starts the job", tinted: false)
            }
        } bottom: {
            FormButtonBar(title: editing == nil ? "Publish" : "Update", isLoading: isPublishing) { Task { await publish() } }
        }
        .appDialog(isPresented: $showsPublished) {
            AppDialog(title: "Published!", titleColor: Palette.primary, art: "illus_published", actions: [
                DialogAction(title: "Back to home") {
                    showsPublished = false
                    nav.popToRoot()
                },
            ])
        }
        .task {
            if let job = editing, !didPrefill {
                didPrefill = true
                description = job.description
                price = job.price == job.price.rounded() ? String(Int(job.price)) : String(job.price)
                unit = job.priceUnit == "hour" ? "Per Hour" : "Per Day"
                startDate = Formats.apiDate.date(from: job.startDate)
                endDate = Formats.apiDate.date(from: job.endDate)
                startTime = Formats.apiTime.date(from: job.startTime)
                endTime = Formats.apiTime.date(from: job.endTime)
                postalCode = job.postalCode
                place = PickedPlace(lat: job.lat, lng: job.lng, address: job.address, postalCode: job.postalCode)
                keptImages = job.images
                return
            }
            if place == nil, let me = session.me, me.lat != 0 || me.lng != 0 {
                place = PickedPlace(lat: me.lat, lng: me.lng, address: me.address, postalCode: me.postcode)
                postalCode = me.postcode
            }
        }
    }

    private func publish() async {
        let amount = Double(price.replacingOccurrences(of: "£", with: "").trimmed) ?? 0
        let problem: String? = if description.trimmed.count < 10 { "Description must be at least 10 characters" }
            else if amount <= 0 { "Enter your offer price" }
            else if startDate == nil || endDate == nil { "Select the start and end date" }
            else if startTime == nil || endTime == nil { "Select the start and end time" }
            else if let startDate, let endDate, endDate < Calendar.current.startOfDay(for: startDate) { "End date can't be before the start date" }
            else if postalCode.trimmed.isEmpty { "Enter the job postal code" }
            else if place == nil { "Select the job address" }
            else { nil }
        if let problem {
            toaster.show(problem, error: true)
            return
        }
        guard let startDate, let endDate, let startTime, let endTime, let place else { return }
        var fields = [
            "categoryId": "\(category.id)", "description": description.trimmed, "price": "\(amount)",
            "priceUnit": unit == "Per Hour" ? "hour" : "day",
            "startDate": Formats.apiDate.string(from: startDate), "endDate": Formats.apiDate.string(from: endDate),
            "startTime": Formats.apiTime.string(from: startTime), "endTime": Formats.apiTime.string(from: endTime),
            "postalCode": postalCode.trimmed, "address": place.address,
        ]
        fields["lat"] = "\(place.lat)"
        fields["lng"] = "\(place.lng)"
        isPublishing = true
        defer { isPublishing = false }
        do {
            if let job = editing {
                toaster.show(try await API.updateJob(job.id, fields, keepImages: keptImages, images: images.map(\.data)).message)
                nav.pop()
                return
            }
            _ = try await API.postJob(fields, images: images.map(\.data))
            showsPublished = true
        } catch {
            toaster.show(error)
        }
    }
}
