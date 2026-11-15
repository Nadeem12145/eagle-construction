import SwiftUI

private let clientNav = [NavItem(title: "Home", icon: "house"), NavItem(title: "Bookings", icon: "briefcase"),
                         NavItem(title: "Message", icon: "message"), NavItem(title: "Profile", icon: "person")]
private let workerNav = [NavItem(title: "Home", icon: "house"), NavItem(title: "Orders", icon: "briefcase"),
                         NavItem(title: "Message", icon: "message"), NavItem(title: "Profile", icon: "person")]

/// Tabs, side menu and logout for both the Client and the Worker app.
struct MainView: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @State private var tab = 0
    @State private var isDrawerOpen = false
    @State private var showsLogout = false

    private var isWorker: Bool { session.me?.isWorker ?? false }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case 0:
                    if isWorker { WorkerHomeTab(onMenu: openDrawer) } else { ClientHomeTab(onMenu: openDrawer) }
                case 1:
                    BookingsTab(onMenu: openDrawer)
                case 2:
                    InboxView()
                default:
                    ProfileTabView { showsLogout = true }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            BottomNav(items: isWorker ? workerNav : clientNav, selection: $tab, onPost: isWorker ? nil : { nav.push(CategoryScreen()) })
        }
        .background(Palette.background.ignoresSafeArea())
        .overlay {
            SideDrawer(isOpen: $isDrawerOpen, items: drawerItems, name: session.me?.name ?? "", email: session.me?.email ?? "",
                       avatar: session.me?.avatar ?? "") { showsLogout = true }
        }
        .appDialog(isPresented: $showsLogout) {
            AppDialog(title: "Logout", message: "Are you sure you want to Logout?", icon: "rectangle.portrait.and.arrow.right", tone: .danger,
                      onClose: { showsLogout = false },
                      actions: [DialogAction(title: "Logout", kind: .danger) {
                          showsLogout = false
                          Task { await session.logout() }
                      }])
        }
        .statusBar(light: tab != 2 || isDrawerOpen)
        .task {
            // Bell and chat badges.
            while !Task.isCancelled {
                await session.refreshSummary()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    private func openDrawer() { isDrawerOpen = true }

    private var drawerItems: [DrawerItem] {
        if isWorker {
            return [
                DrawerItem(title: "Home", icon: "house") { tab = 0 },
                DrawerItem(title: "Chat History", icon: "message") { tab = 2 },
                DrawerItem(title: "Payment History", icon: "clock.arrow.circlepath") { nav.push(EarningsScreen()) },
                DrawerItem(title: "Cancellation Requests", icon: "xmark.circle") { nav.push(CancellationRequestsScreen()) },
                DrawerItem(title: "Blocked Users", icon: "nosign") { nav.push(BlockedUsersScreen()) },
                DrawerItem(title: "Contacts Us", icon: "questionmark.circle") { nav.push(ContactScreen()) },
            ]
        }
        return [
            DrawerItem(title: "Home", icon: "house") { tab = 0 },
            DrawerItem(title: "Past Workers", icon: "person.2") { nav.push(PastWorkersScreen()) },
            DrawerItem(title: "Payment History", icon: "clock.arrow.circlepath") { nav.push(WalletScreen()) },
            DrawerItem(title: "Cancellation Requests", icon: "xmark.circle") { nav.push(CancellationRequestsScreen()) },
            DrawerItem(title: "Blocked Users", icon: "nosign") { nav.push(BlockedUsersScreen()) },
            DrawerItem(title: "Contacts Us", icon: "questionmark.circle") { nav.push(ContactScreen()) },
        ]
    }
}

/// Navy header with the bell badge from `/summary`.
private struct TabHeader<Below: View>: View {
    var title = "Eagle Jobs"
    let onMenu: () -> Void
    @ViewBuilder var below: Below
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session

    var body: some View {
        VStack(spacing: 8) {
            BrandHeader(title: title, hasUnread: (session.summary?.unreadNotifications ?? 0) > 0, onMenu: onMenu) {
                nav.push(NotificationsScreen())
            }
            below
        }
        .background(NavyBand())
    }
}

// MARK: - Client home

struct ClientHomeTab: View {
    let onMenu: () -> Void
    @Environment(Navigator.self) private var nav
    @State private var state: LoadState<[Job]> = .loading
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(onMenu: onMenu) {
                SearchRow(text: $query, placeholder: "Search Job here..", icon: "magnifyingglass")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
            }
            LoadView(state: state, retry: load) { jobs in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "My Requests")
                        if jobs.isEmpty {
                            EmptyState(icon: "doc.text.magnifyingglass", title: query.isEmpty ? "No requests yet" : "No results",
                                       message: query.isEmpty ? "Tap + to post your first request." : nil)
                        }
                        ForEach(jobs) { job in
                            JobCard(job: job, forWorker: false) { nav.push(JobDetailScreen(jobId: job.id)) }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .refreshable { await load() }
            }
        }
        .task(id: query) {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(400)) }
            if Task.isCancelled { return }
            await load()
        }
    }

    private func load() async {
        await fetch($state) { try await API.myJobs(search: query.trimmed).items }
    }
}

// MARK: - Worker home

struct FeedFilter: Equatable {
    var location = ""
    var distance = 0
    var sort = "new"
}

struct WorkerHomeTab: View {
    let onMenu: () -> Void
    @Environment(Navigator.self) private var nav
    @State private var state: LoadState<[Job]> = .loading
    @State private var query = ""
    @State private var filter = FeedFilter()
    @State private var showsFilter = false
    @State private var options: Options?

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(onMenu: onMenu) {
                SearchRow(text: $query, placeholder: "Search Job here...", icon: "slider.horizontal.3") { showsFilter = true }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
            }
            LoadView(state: state, retry: load) { jobs in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Live Jobs Near Me?")
                        if jobs.isEmpty {
                            EmptyState(icon: "briefcase", title: "No live jobs", message: "New requests near you will show here.")
                        }
                        ForEach(jobs) { job in
                            JobCard(job: job, forWorker: true) { nav.push(JobDetailScreen(jobId: job.id)) }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .refreshable { await load() }
            }
        }
        .appSheet(isPresented: $showsFilter) {
            FilterSheet(filter: filter, options: options) { value in
                filter = value
                showsFilter = false
            }
        }
        .task(id: "\(query)|\(filter.location)|\(filter.distance)|\(filter.sort)") {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(400)) }
            if Task.isCancelled { return }
            await load()
        }
        .task { if options == nil { options = try? await API.options() } }
    }

    private func load() async {
        await fetch($state) {
            try await API.feed(search: query.trimmed, location: filter.location.trimmed, distance: filter.distance, sort: filter.sort).items
        }
    }
}

struct FilterSheet: View {
    let options: Options?
    let onApply: (FeedFilter) -> Void
    @State private var draft: FeedFilter

    init(filter: FeedFilter, options: Options?, onApply: @escaping (FeedFilter) -> Void) {
        self.options = options
        self.onApply = onApply
        _draft = State(initialValue: filter)
    }

    private var distances: [Int] { options?.distanceMiles ?? [10, 30, 50] }
    private var sorts: [Options.SortOption] {
        options?.jobSort ?? [Options.SortOption(key: "new", title: "New Posts")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filter by").type(18, .bold).frame(maxWidth: .infinity)
            AppField(label: "Location / Postal Code", text: $draft.location, placeholder: "Location / Postal Code", trailing: "magnifyingglass")
            HStack {
                Text("Distance Under").type(15, .semibold)
                Spacer()
                Menu {
                    Button("Any distance") { draft.distance = 0 }
                    ForEach(distances, id: \.self) { miles in
                        Button("\(miles) Miles") { draft.distance = miles }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(draft.distance == 0 ? "Any" : "\(draft.distance) Miles").type(14, .semibold)
                        Image(systemName: "chevron.down").type(12, .semibold, Palette.text2)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Palette.background, in: Capsule())
                    .overlay(Capsule().stroke(Palette.border))
                }
            }
            Slider(value: Binding(get: { sliderValue }, set: { setSlider($0) }), in: 0...Double(distances.count), step: 1)
                .tint(Palette.primary)
            Text("Sort by").type(15, .semibold)
            VStack(spacing: 0) {
                ForEach(sorts.indices, id: \.self) { index in
                    if index > 0 { Rectangle().fill(Palette.divider).frame(height: 1) }
                    Button { draft.sort = sorts[index].key } label: {
                        HStack {
                            Text(sorts[index].title).type(15, .medium)
                            Spacer()
                            RadioMark(selected: draft.sort == sorts[index].key)
                        }
                        .frame(height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 12) {
                AppButton(title: "Reset", kind: .outline) { onApply(FeedFilter()) }
                AppButton(title: "Apply") { onApply(draft) }
            }
        }
        .padding(20)
    }

    /// 0 = any distance, then one step per option.
    private var sliderValue: Double {
        Double((distances.firstIndex(of: draft.distance) ?? -1) + 1)
    }

    private func setSlider(_ value: Double) {
        let index = Int(value.rounded())
        draft.distance = index == 0 ? 0 : distances[min(index, distances.count) - 1]
    }
}

// MARK: - Bookings / Orders

struct BookingsTab: View {
    let onMenu: () -> Void
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @State private var tab = 0
    @State private var state: LoadState<[BookingRow]> = .loading

    private let keys = ["active", "cancelled", "delivered"]
    private var isWorker: Bool { session.me?.isWorker ?? false }

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(title: isWorker ? "Orders" : "Bookings", onMenu: onMenu) { EmptyView() }
            SegmentedTabs(items: ["Active", "Cancelled", "Delivered"], selection: $tab)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 4)
            LoadView(state: state, retry: load) { rows in
                ScrollView {
                    VStack(spacing: 12) {
                        if rows.isEmpty {
                            EmptyState(icon: "briefcase", title: "Nothing here yet")
                        }
                        ForEach(rows) { row in card(row) }
                    }
                    .padding(20)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .refreshable { await load() }
            }
        }
        .task(id: tab) {
            state = .loading
            await load()
        }
    }

    @ViewBuilder
    private func card(_ row: BookingRow) -> some View {
        let open = { nav.push(BookingDetailScreen(bookingId: row.id)) }
        if isWorker {
            JobCard(row: row, showsPerson: false, buttonTitle: tab == 2 ? "View Details" : nil, onButton: open, onTap: open)
        } else if row.actions.contains("accept_delivery") {
            JobCard(row: row, showsPerson: tab == 0, buttonTitle: "Accept Delivery", onButton: {
                nav.push(BookingDetailScreen(bookingId: row.id, opensAcceptDelivery: true))
            }, onTap: open)
        } else if row.actions.contains("request_again") {
            JobCard(row: row, showsPerson: tab == 0, buttonTitle: "Request Again", onButton: {
                nav.push(NewRequestScreen(category: row.category))
            }, onTap: open)
        } else {
            JobCard(row: row, showsPerson: tab == 0, onTap: open)
        }
    }

    private func load() async {
        let key = keys[tab]
        await fetch($state) { try await API.bookings(tab: key).items }
    }
}
