import SwiftUI

// MARK: - Notifications

struct NotificationsScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @State private var state: LoadState<NotificationPage> = .loading

    var body: some View {
        ListScreen(title: "Notifications") {
            if let page = state.value, page.items.contains(where: { !$0.isRead }) {
                Button("Mark all read") { Task { await markAllRead() } }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.primary)
            }
        } content: {
            LoadView(state: state, retry: load) { page in
                VStack(spacing: 10) {
                    if page.items.isEmpty { EmptyState(icon: "bell", title: "No notifications yet") }
                    ForEach(page.items) { item in
                        Button { open(item) } label: { row(item) }.buttonStyle(.plain)
                    }
                }
            }
        } bottom: {
            EmptyView()
        }
        .task { await load() }
    }

    private func markAllRead() async {
        do {
            try await API.markAllNotificationsRead()
            if case .loaded(var page) = state {
                for index in page.items.indices { page.items[index].isRead = true }
                state = .loaded(page)
            }
            await session.refreshSummary()
        } catch {
            if !error.isCancellation { await load() }
        }
    }

    private func row(_ item: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isRead ? "envelope.open" : "envelope")
                .type(16, .regular, item.isRead ? Palette.text3 : Palette.primary)
                .frame(width: 40, height: 40)
                .background(item.isRead ? Palette.divider : Palette.primary50, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title).type(15, item.isRead ? .medium : .semibold, item.isRead ? Palette.text2 : Palette.ink)
                    Spacer(minLength: 6)
                    Text(item.dateLabel).type(11, .medium, Palette.muted)
                }
                Text(item.body).type(13, .regular, Palette.text3).lineSpacing(2).multilineTextAlignment(.leading)
            }
            if !item.isRead { Circle().fill(Tone.danger.foreground).frame(width: 9, height: 9).padding(.top, 6) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(item.isRead ? Palette.background : .white, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(item.isRead ? Palette.border : Palette.primary100))
    }

    private func open(_ item: AppNotification) {
        if !item.isRead {
            Task {
                try? await API.markNotificationRead(item.id)
                await session.refreshSummary()
            }
            if case .loaded(var page) = state, let index = page.items.firstIndex(where: { $0.id == item.id }) {
                page.items[index].isRead = true
                state = .loaded(page)
            }
        }
        guard item.refId > 0 else { return }
        switch item.refType {
        case "booking": nav.push(BookingDetailScreen(bookingId: item.refId))
        case "job": nav.push(JobDetailScreen(jobId: item.refId))
        case "conversation": nav.push(ChatScreen(conversationId: item.refId))
        case "dispute": nav.push(DisputeDetailScreen(disputeId: item.refId))
        case "user" where item.refId != session.me?.id: nav.push(PersonProfileScreen(userId: item.refId))
        default: break
        }
    }

    private func load() async {
        await fetch($state) { try await API.notifications() }
    }
}

// MARK: - Profile tab

struct ProfileTabView: View {
    let onLogout: () -> Void
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session

    var body: some View {
        let me = session.me
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(me?.name ?? "").type(20, .bold).padding(.top, 54)
                    Text(verbatim: me?.email ?? "").type(14, .regular, Palette.text3)
                    if let me, me.rating > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").type(12, .regular, Palette.star)
                            Text(String(format: "%.1f (%d reviews)", me.rating, me.ratingCount)).type(13, .medium, Palette.text2)
                        }
                    }
                }
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
                .card(radius: Radius.xl)
                .overlay(alignment: .top) {
                    AvatarView(name: me?.name ?? "", url: me?.avatar ?? "", size: 84, ring: true).offset(y: -46)
                }
                .padding(.top, 96)

                VStack(spacing: 0) {
                    ForEach(entries.indices, id: \.self) { index in
                        if index > 0 { Rectangle().fill(Palette.divider).frame(height: 1).padding(.leading, 64) }
                        let entry = entries[index]
                        MenuRow(title: entry.title, icon: entry.icon, danger: entry.danger, showsChevron: !entry.danger, action: entry.action)
                    }
                }
                .card()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await session.refresh() }
        .background(alignment: .top) { NavyBand().frame(height: 150) }
        .overlay(alignment: .top) {
            Text("Profile").type(17, .semibold, .white).padding(.top, 12).allowsHitTesting(false)
        }
        .background(Palette.background.ignoresSafeArea())
        .task { await session.refresh() }
    }

    private struct Entry {
        let title: String
        let icon: String
        var danger = false
        let action: () -> Void
    }

    private var entries: [Entry] {
        var list = [Entry(title: "Edit Profile", icon: "pencil") { nav.push(EditProfileScreen()) }]
        if session.me?.isWorker == true {
            list.append(Entry(title: "My Categories", icon: "square.grid.2x2") { nav.push(SelectCategoriesScreen(isEditing: true)) })
        }
        list += [
            Entry(title: "Disputes", icon: "scale.3d") { nav.push(DisputesScreen()) },
            Entry(title: "Settings", icon: "gearshape") { nav.push(SettingsScreen()) },
            Entry(title: "Contacts Us", icon: "questionmark.circle") { nav.push(ContactScreen()) },
            Entry(title: "Logout", icon: "power", danger: true, action: onLogout),
        ]
        return list
    }
}

struct EditProfileScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var draft: ProfileDraft?
    @State private var avatar: PickedImage?
    @State private var isSaving = false

    var body: some View {
        if let me = session.me {
            let kind = ProfileKind(me)
            ListScreen(title: "Edit Profile", background: .white) {
                VStack(spacing: 16) {
                    AvatarPicker(name: me.name, url: me.avatar, picked: $avatar, size: 88)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                    ProfileFormFields(kind: kind, draft: Binding(get: { draft ?? ProfileDraft(me) }, set: { draft = $0 }), email: me.email,
                                      labelled: true, onChangeEmail: { nav.push(ChangeEmailScreen()) })
                }
            } bottom: {
                FormButtonBar(title: "Update", isLoading: isSaving) { Task { await save(me, kind) } }
            }
        }
    }

    private func save(_ me: Me, _ kind: ProfileKind) async {
        let form = draft ?? ProfileDraft(me)
        if let missing = form.missing(kind) {
            toaster.show("\(missing) cannot be empty", error: true)
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            session.me = try await API.updateProfile(form.fields(kind), avatar: avatar?.data)
            toaster.show("Profile updated")
            nav.pop()
        } catch {
            toaster.show(error)
        }
    }
}

/// Email is the login, so a new one is confirmed with a code sent to it.
struct ChangeEmailScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var email = ""
    @State private var code = ""
    @State private var sentTo = ""
    @State private var isBusy = false

    var body: some View {
        ListScreen(title: "Change Email", background: .white) {
            VStack(alignment: .leading, spacing: 16) {
                Text("We will send a 6-digit code to the new email address. Your email changes once you enter it.")
                    .type(14, .regular, Palette.text3)
                    .lineSpacing(3)
                AppField(label: "Current Email", text: .constant(session.me?.email ?? ""), leading: "envelope", readOnly: true)
                AppField(label: "New Email", text: $email, placeholder: "New email address", leading: "envelope", readOnly: !sentTo.isEmpty, keyboard: .emailAddress)
                if !sentTo.isEmpty {
                    AppField(label: "Verification Code", text: $code, placeholder: "6-digit code", leading: "number", maxLength: 6, note: "Sent to \(sentTo)",
                             keyboard: .numberPad)
                }
            }
        } bottom: {
            FormButtonBar(title: sentTo.isEmpty ? "Send Code" : "Verify", isLoading: isBusy) { Task { await next() } }
        }
    }

    private func next() async {
        isBusy = true
        defer { isBusy = false }
        do {
            if sentTo.isEmpty {
                let sent = try await API.sendEmailChangeCode(to: email.trimmed.lowercased())
                sentTo = sent.sentTo
                #if DEBUG
                if let otp = sent.otp { code = otp }
                #endif
            } else {
                session.me = try await API.verifyEmailChange(email: email.trimmed.lowercased(), code: code.trimmed)
                toaster.show("Email updated")
                nav.pop()
            }
        } catch {
            toaster.show(error)
        }
    }
}

// MARK: - Settings and information

struct SettingsScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var showsDelete = false

    var body: some View {
        ListScreen(title: "Settings") {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    MenuRow(title: "Notification Settings", icon: "bell") { nav.push(NotificationSettingsScreen()) }
                    divider
                    MenuRow(title: "Terms & Conditions", icon: "doc.text") { nav.push(LegalScreen(key: "terms", title: "Terms & Conditions")) }
                    divider
                    MenuRow(title: "Privacy Policy", icon: "checkmark.shield") { nav.push(LegalScreen(key: "privacy", title: "Privacy Policy")) }
                    divider
                    MenuRow(title: "About", icon: "info.circle") { nav.push(AboutScreen()) }
                }
                .card()
                MenuRow(title: "Delete Account", icon: "person.crop.circle.badge.xmark", danger: true) { showsDelete = true }.card()
            }
        }
        .appDialog(isPresented: $showsDelete) {
            AppDialog(title: "Delete Account", message: "Are you sure you want to Delete Account?", icon: "person.crop.circle.badge.xmark", tone: .danger,
                      onClose: { showsDelete = false },
                      actions: [DialogAction(title: "Yes, Delete", kind: .danger) {
                          showsDelete = false
                          Task { await deleteAccount() }
                      }])
        }
    }

    private var divider: some View {
        Rectangle().fill(Palette.divider).frame(height: 1).padding(.leading, 64)
    }

    private func deleteAccount() async {
        do {
            try await API.deleteAccount()
            session.signOutLocally()
            toaster.show("Your account was deleted")
        } catch {
            toaster.show(error)
        }
    }
}

struct NotificationSettingsScreen: View {
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var state: LoadState<NotificationSwitches> = .loading

    private var labels: [String] {
        session.me?.isWorker == true
            ? ["Order Notifications", "Message Notifications", "Review Notifications"]
            : ["Booking Notifications", "Chat Notifications", "Delivery Notifications"]
    }

    var body: some View {
        ListScreen(title: "Notification Settings") {
            LoadView(state: state, retry: load) { switches in
                VStack(spacing: 0) {
                    toggle(labels[0], switches.bookings) { $0.bookings = $1 }
                    divider
                    toggle(labels[1], switches.chat) { $0.chat = $1 }
                    divider
                    toggle(labels[2], switches.updates) { $0.updates = $1 }
                }
                .card()
            }
        }
        .task { await load() }
    }

    private var divider: some View { Rectangle().fill(Palette.divider).frame(height: 1).padding(.horizontal, 16) }

    private func toggle(_ title: String, _ isOn: Bool, _ set: @escaping (inout NotificationSwitches, Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: { value in
            guard var switches = state.value else { return }
            let old = switches
            set(&switches, value)
            state = .loaded(switches)
            Task {
                do {
                    state = .loaded(try await API.saveNotificationSettings(switches))
                } catch {
                    state = .loaded(old)
                    toaster.show(error)
                }
            }
        })) {
            Text(title).type(15, .medium)
        }
        .tint(Palette.primary)
        .padding(.horizontal, 16)
        .frame(height: 64)
    }

    private func load() async {
        await fetch($state) { try await API.notificationSettings() }
    }
}

struct LegalScreen: View {
    let key: String
    let title: String
    @State private var state: LoadState<ContentPage> = .loading

    var body: some View {
        ListScreen(title: title) {
            LoadView(state: state, retry: load) { page in
                VStack(alignment: .leading, spacing: 16) {
                    if !page.lastUpdatedLabel.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "clock").type(13, .regular, Palette.text3)
                            Text(page.lastUpdatedLabel).type(13, .medium, Palette.text3)
                        }
                    }
                    Text(page.body).type(14, .regular, Palette.text2).lineSpacing(5)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        await fetch($state) { try await API.content(key) }
    }
}

struct AboutScreen: View {
    @State private var state: LoadState<AppInfo> = .loading

    var body: some View {
        ListScreen(title: "About", background: .white) {
            LoadView(state: state, retry: load) { info in
                VStack(spacing: 24) {
                    Image("logo_full").resizable().scaledToFit().frame(width: 220)
                    Text(info.about).type(15, .regular, Palette.text2).multilineTextAlignment(.center).lineSpacing(3).padding(.horizontal, 20)
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Powered by").type(12, .semibold, Palette.text3)
                            Text(info.poweredBy).type(15, .semibold)
                        }
                        Rectangle().fill(Palette.border).frame(height: 1)
                        Text("Contact us").type(12, .semibold, Palette.text3)
                        ContactLine(icon: "globe", text: info.website)
                        ContactLine(icon: "envelope", text: info.email)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.background, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    VStack(spacing: 6) {
                        Text("Version \(info.version)").type(13, .semibold, Palette.text2)
                        if !info.loggedInAs.isEmpty { Text(verbatim: "Logged in as \(info.loggedInAs)").type(13, .regular, Palette.text3) }
                    }
                    .padding(.top, 24)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .task { await load() }
    }

    private func load() async {
        await fetch($state) { try await API.appInfo() }
    }
}

struct ContactLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).type(16, .regular, Palette.primary).frame(width: 22)
            Text(verbatim: text).type(15, .medium)
        }
    }
}

struct ContactScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var name = ""
    @State private var subject = ""
    @State private var email = ""
    @State private var message = ""
    @State private var info: AppInfo?
    @State private var isSending = false

    var body: some View {
        ListScreen(title: "Contacts Us", background: .white) {
            VStack(spacing: 14) {
                AppField(text: $name, placeholder: "Your Name", isName: true)
                AppField(text: $subject, placeholder: "Subject")
                AppField(text: $email, placeholder: "Your Email", keyboard: .emailAddress)
                AppField(text: $message, placeholder: "Your feedback is important to us.", height: 128, multiline: true, maxLength: 2000)
                AppButton(title: "Send", isLoading: isSending) { Task { await send() } }
                Text(info?.responseNote.isEmpty == false ? info!.responseNote : "You will get a response in 24 hours").type(13, .regular, Palette.text3)
                VStack(alignment: .leading, spacing: 8) {
                    Text("We Are Available On").type(14, .semibold, Palette.text2)
                    ForEach([("globe", info?.website ?? "www.Eaglejobs.com"), ("envelope", info?.email ?? "Eaglejobs86@gmail.com")], id: \.0) { line in
                        ContactLine(icon: line.0, text: line.1)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .background(Palette.background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                }
                .padding(.top, 10)
            }
        }
        .task {
            if name.isEmpty { name = session.me?.name ?? "" }
            if email.isEmpty { email = session.me?.email ?? "" }
            info = try? await API.appInfo()
        }
    }

    private func send() async {
        guard !name.trimmed.isEmpty, !subject.trimmed.isEmpty, email.contains("@"), !message.trimmed.isEmpty else {
            toaster.show("Please fill your name, subject, email and message", error: true)
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            toaster.show(try await API.contact(name: name.trimmed, subject: subject.trimmed, email: email.trimmed, message: message.trimmed))
            nav.pop()
        } catch {
            toaster.show(error)
        }
    }
}

struct BlockedUsersScreen: View {
    @Environment(Toaster.self) private var toaster
    @State private var state: LoadState<[UserBrief]> = .loading
    @State private var unblocking: UserBrief?

    var body: some View {
        ListScreen(title: "Blocked Users", background: .white) {
            LoadView(state: state, retry: load) { users in
                VStack(spacing: 0) {
                    if users.isEmpty { EmptyState(icon: "nosign", title: "No blocked users") }
                    ForEach(users) { user in
                        HStack(spacing: 12) {
                            AvatarView(user: user, size: 48)
                            Text(user.name).type(15, .semibold)
                            Spacer()
                            AppButton(title: "Unblock", kind: .outline, height: 36, fontSize: 14) { unblocking = user }.frame(width: 96)
                        }
                        .frame(height: 64)
                        Rectangle().fill(Palette.divider).frame(height: 1).padding(.leading, 60)
                    }
                }
            }
        }
        .appDialog(isPresented: Binding(get: { unblocking != nil }, set: { if !$0 { unblocking = nil } })) {
            AppDialog(title: "Unblock", message: "Are you sure you want to unblock this user?", icon: "nosign", actions: [
                DialogAction(title: "Cancel", kind: .outline) { unblocking = nil },
                DialogAction(title: "Yes") {
                    guard let user = unblocking else { return }
                    unblocking = nil
                    Task {
                        do {
                            try await API.unblock(user.id)
                            toaster.show("\(user.name) unblocked")
                            await load()
                        } catch {
                            toaster.show(error)
                        }
                    }
                },
            ])
        }
        .task { await load() }
    }

    private func load() async {
        await fetch($state) { try await API.blockedUsers() }
    }
}

// MARK: - Disputes

struct DisputesScreen: View {
    @Environment(Navigator.self) private var nav
    @State private var state: LoadState<[Dispute]> = .loading

    var body: some View {
        ListScreen(title: "Disputes") {
            LoadView(state: state, retry: load) { disputes in
                VStack(spacing: 12) {
                    if disputes.isEmpty { EmptyState(icon: "scale.3d", title: "No disputes") }
                    ForEach(disputes) { dispute in
                        DisputeCard(dispute: dispute) { nav.push(DisputeDetailScreen(disputeId: dispute.id)) }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        await fetch($state) { try await API.disputes().items }
    }
}

struct DisputeDetailScreen: View {
    let disputeId: Int
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @State private var state: LoadState<Dispute> = .loading

    var body: some View {
        DetailLoading(state: state, retry: load) { dispute in
            let isWorker = session.me?.isWorker ?? false
            let other = isWorker ? dispute.client : dispute.worker
            DetailScaffold(summary: DetailSummary(category: dispute.category, images: dispute.jobImages, title: dispute.title,
                                                  status: dispute.statusBadge, price: dispute.priceLabel, addressLabel: dispute.addressLabel,
                                                  address: dispute.addressText, startDate: dispute.startDateLabel, endDate: dispute.endDateLabel,
                                                  startTime: dispute.startTimeLabel, endTime: dispute.endTimeLabel, person: other,
                                                  description: dispute.jobDescription),
                           showsActions: true,
                           onPerson: { nav.push(PersonProfileScreen(userId: other.id)) },
                           onRefresh: load) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(dispute.reason).type(16, .semibold)
                        Spacer()
                        StatusBadge(label: dispute.tag)
                    }
                    if !dispute.images.isEmpty { PhotoStrip(urls: dispute.images, height: 56) }
                    if !dispute.description.isEmpty { Text(dispute.description).type(13, .regular, Palette.text2).lineSpacing(3) }
                    VStack(spacing: 0) {
                        ForEach(dispute.rows) { row in
                            Rectangle().fill(Palette.divider).frame(height: 1)
                            HStack {
                                Text(row.label).type(13, .medium, Palette.text3)
                                Spacer()
                                if let tone = Tone.named(row.tone) {
                                    StatusBadge(label: row.value, tone: tone)
                                } else {
                                    Text(row.value).type(13, .semibold)
                                }
                            }
                            .frame(height: 34)
                        }
                    }
                    if !dispute.resolutionNote.isEmpty {
                        InfoNote(label: "Support", text: dispute.resolutionNote)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            } actions: {
                AppButton(title: isWorker ? "View Order" : "View Booking", kind: .secondary) {
                    nav.push(BookingDetailScreen(bookingId: dispute.bookingId))
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        await fetch($state) { try await API.dispute(disputeId) }
    }
}

// MARK: - People

struct PersonProfileScreen: View {
    let userId: Int
    var title: String? = nil
    /// Client choosing a worker for this job: shows "Select", which opens the payment.
    var selectFor: Job? = nil

    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var state: LoadState<PublicProfile> = .loading
    @State private var isOpeningChat = false
    @State private var showsMenu = false
    @State private var showsBlock = false

    var body: some View {
        ListScreen(title: screenTitle) {
            if state.value != nil {
                Menu {
                    if let profile = state.value {
                        Button(profile.isBlocked ? "Unblock" : "Block", systemImage: "nosign", role: profile.isBlocked ? nil : .destructive) { showsBlock = true }
                    }
                } label: {
                    Image(systemName: "ellipsis").rotationEffect(.degrees(90)).type(16, .semibold).frame(width: 40, height: 40)
                }
            }
        } content: {
            LoadView(state: state, retry: load) { profile in content(profile) }
        } bottom: {
            EmptyView()
        }
        .appDialog(isPresented: $showsBlock) {
            let blocking = !(state.value?.isBlocked ?? false)
            AppDialog(title: blocking ? "Block User" : "Unblock", message: "Are you sure you want to \(blocking ? "block" : "unblock") this user?",
                      icon: "nosign", tone: blocking ? .danger : .brand, actions: [
                          DialogAction(title: "Cancel", kind: .outline) { showsBlock = false },
                          DialogAction(title: "Yes", kind: blocking ? .danger : .primary) {
                              showsBlock = false
                              Task { await toggleBlock(blocking) }
                          },
                      ])
        }
        .task { await load() }
    }

    private var screenTitle: String {
        if let title { return title }
        guard let user = state.value?.user else { return "" }
        if user.role == "worker" { return "Worker Profile" }
        return user.accountType == "company" ? "Company Profile" : "Client Profile"
    }

    @ViewBuilder
    private func content(_ profile: PublicProfile) -> some View {
        let user = profile.user
        let isWorkerProfile = user.role == "worker"
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                AvatarView(name: user.name, url: user.avatar, size: 88, ring: true)
                Text(user.name).type(20, .bold)
                if !user.overview.isEmpty {
                    Text(user.overview).type(14, .regular, Palette.text3).multilineTextAlignment(.center).lineLimit(3).lineSpacing(2).padding(.horizontal, 20)
                }
                if !user.categories.isEmpty {
                    Text(user.categories.map(\.name).joined(separator: " · ")).type(12, .medium, Palette.primary).multilineTextAlignment(.center)
                }
                if let job = selectFor {
                    AppButton(title: "Select", icon: "checkmark", height: 44, fontSize: 15) {
                        nav.push(BookingPaymentScreen(jobId: job.id, workerId: user.id))
                    }
                    .frame(width: 180)
                    .padding(.top, 8)
                } else if !profile.isBlocked {
                    AppButton(title: "Message", icon: "message", height: 44, fontSize: 15, isLoading: isOpeningChat) {
                        Task { await openChat(user.id) }
                    }
                    .frame(width: 180)
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)

            SectionTitle(title: isWorkerProfile ? "User Information" : "Other Information")
            HStack(spacing: 0) {
                infoCell(icon: "mappin.and.ellipse", tint: Palette.primary, fill: Palette.primary50, label: "From", value: user.from.isEmpty ? "—" : user.from)
                Rectangle().fill(Palette.divider).frame(width: 1, height: 40)
                infoCell(icon: "star.fill", tint: Palette.star, fill: Palette.starBackground, label: "Rating",
                         value: user.rating > 0 ? String(format: "%.1f", user.rating) : "New")
            }
            .padding(.vertical, 16)
            .card()
            HStack(spacing: 0) {
                infoCell(icon: "checkmark.seal", tint: Tone.success.foreground, fill: Tone.success.background, label: "Completed", value: "\(profile.completedBookings)")
                Rectangle().fill(Palette.divider).frame(width: 1, height: 40)
                infoCell(icon: "calendar", tint: Palette.primary, fill: Palette.primary50, label: "Member since", value: user.memberSinceLabel)
            }
            .padding(.vertical, 16)
            .card()

            if !profile.recentBookings.isEmpty {
                SectionTitle(title: "My Recent Bookings")
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(profile.recentBookings) { row in recentBooking(row) }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
            }

            if !isWorkerProfile && profile.otherJobs.count > 0 {
                SectionTitle(title: "Other Job", count: profile.otherJobs.count, action: profile.otherJobs.count > profile.otherJobs.items.count ? "See all" : nil) {
                    nav.push(ClientJobsScreen(userId: user.id, name: user.name))
                }
                ForEach(profile.otherJobs.items) { job in
                    JobCard(job: job, forWorker: session.me?.isWorker ?? false) { nav.push(JobDetailScreen(jobId: job.id)) }
                }
            }

            SectionTitle(title: isWorkerProfile ? "Reviews" : "Worker Reviews", count: profile.reviewsCount, action: profile.reviewsCount > 0 ? "See all" : nil) {
                nav.push(ReviewsScreen(userId: user.id))
            }
            if profile.reviews.isEmpty {
                Text("No reviews yet").type(14, .regular, Palette.text3)
            }
            ForEach(profile.reviews) { review in ReviewCard(review: review) }
        }
    }

    private func infoCell(icon: String, tint: Color, fill: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).type(16, .regular, tint).frame(width: 40, height: 40).background(fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).type(12, .medium, Palette.text3)
                Text(value).type(15, .semibold).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
    }

    private func recentBooking(_ row: BookingRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                CategoryThumb(category: row.category, imageURL: row.images.first, size: 40, radius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.category.name).type(15, .semibold)
                    Text("\(row.dateTitle): \(row.dateLabel)").type(12, .regular, Palette.text3)
                }
                Spacer()
                if row.rating > 0 { StatusBadge(label: String(format: "%.1f", row.rating), tone: .warning, showsDot: false) }
            }
            Text(row.description).type(12, .regular, Palette.text2).lineLimit(2)
            Text(row.priceLabel).type(13, .bold, Palette.primary).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        .frame(width: 240)
        .card()
    }

    private func load() async {
        await fetch($state) { try await API.profile(of: userId) }
    }

    private func openChat(_ userId: Int) async {
        isOpeningChat = true
        defer { isOpeningChat = false }
        do {
            let conversation = try await API.openConversation(with: userId)
            nav.push(ChatScreen(conversationId: conversation.id, preview: conversation))
        } catch {
            toaster.show(error)
        }
    }

    private func toggleBlock(_ blocking: Bool) async {
        do {
            if blocking { try await API.block(userId) } else { try await API.unblock(userId) }
            toaster.show(blocking ? "User blocked" : "User unblocked")
            await load()
        } catch {
            toaster.show(error)
        }
    }
}

struct ReviewsScreen: View {
    let userId: Int
    @State private var state: LoadState<ReviewPage> = .loading

    var body: some View {
        ListScreen(title: "Reviews") {
            LoadView(state: state, retry: load) { page in
                VStack(spacing: 10) {
                    if page.items.isEmpty { EmptyState(icon: "star", title: "No reviews yet") }
                    ForEach(page.items) { review in ReviewCard(review: review) }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        await fetch($state) { try await API.reviews(of: userId) }
    }
}

/// "Other Job → See all" on a client profile.
struct ClientJobsScreen: View {
    let userId: Int
    let name: String
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @State private var state: LoadState<[Job]> = .loading

    var body: some View {
        ListScreen(title: "Other Job") {
            LoadView(state: state, retry: load) { jobs in
                VStack(spacing: 12) {
                    if jobs.isEmpty { EmptyState(icon: "briefcase", title: "No open requests") }
                    ForEach(jobs) { job in
                        JobCard(job: job, forWorker: session.me?.isWorker ?? false) { nav.push(JobDetailScreen(jobId: job.id)) }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        await fetch($state) { try await API.openJobs(of: userId).items }
    }
}

struct PastWorkersScreen: View {
    @Environment(Navigator.self) private var nav
    @State private var state: LoadState<[PastWorker]> = .loading
    @State private var isSearching = false
    @State private var query = ""

    var body: some View {
        ListScreen(title: "Past Workers") {
            IconButton(icon: isSearching ? "xmark" : "magnifyingglass") {
                isSearching.toggle()
                if !isSearching { query = "" }
            }
        } content: {
            VStack(spacing: 10) {
                if isSearching {
                    AppField(text: $query, placeholder: "Search worker", leading: "magnifyingglass", height: 46)
                }
                LoadView(state: state, retry: load) { workers in
                    VStack(spacing: 10) {
                        if workers.isEmpty { EmptyState(icon: "person.2", title: "No past workers yet") }
                        ForEach(workers) { worker in
                            Button { nav.push(PersonProfileScreen(userId: worker.id, title: "Past Workers Profile")) } label: {
                                HStack(spacing: 12) {
                                    AvatarView(name: worker.name, url: worker.avatar, size: 48)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(worker.name).type(15, .semibold)
                                        Text.joined(Text("Address: ").foregroundStyle(Palette.text3), Text(worker.address).foregroundStyle(Palette.text2))
                                            .font(.system(size: 12))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    RatingPill(rating: worker.rating)
                                }
                                .padding(12)
                                .card()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        } bottom: {
            EmptyView()
        }
        .task(id: query) {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(350)) }
            if Task.isCancelled { return }
            await load()
        }
    }

    private func load() async {
        await fetch($state) { try await API.pastWorkers(search: query.trimmed).items }
    }
}
