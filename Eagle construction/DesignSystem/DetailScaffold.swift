import SwiftUI

/// What the detail header shows for a job, booking or dispute.
struct DetailSummary {
    let category: Category
    let images: [String]
    let title: String
    var status: String = ""
    let price: String
    var unit: String = ""
    let addressLabel: String
    let address: String
    let startDate: String
    let endDate: String
    let startTime: String
    let endTime: String
    var person: UserBrief? = nil
    let description: String
    var footerDate: String = ""
}

/// Photo carousel, price, address, schedule and description, then the screen's own sections and buttons.
struct DetailScaffold<Sections: View, Actions: View>: View {
    let summary: DetailSummary
    var showsActions = true
    var onPerson: (() -> Void)? = nil
    var onRefresh: (() async -> Void)? = nil
    @ViewBuilder var sections: Sections
    @ViewBuilder var actions: Actions

    @Environment(Navigator.self) private var nav
    @State private var page = 0
    /// True once the photo has scrolled away: the status bar then needs its own background.
    @State private var isPastHero = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                summaryView
                VStack(spacing: 12) { sections }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await onRefresh?() }
        .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 240 } action: { _, past in
            withAnimation(.easeOut(duration: 0.15)) { isPastHero = past }
        }
        .ignoresSafeArea(edges: .top)
        .background(Palette.background.ignoresSafeArea())
        .overlay(alignment: .top) {
            if isPastHero {
                Color.clear
                    .frame(height: 0)
                    .background(Palette.background.ignoresSafeArea(edges: .top))
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            IconButton(icon: "chevron.left", background: .white) { nav.pop() }
                .padding(.leading, 16)
                .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsActions {
                ActionBar { actions }
            }
        }
        .statusBar(light: !isPastHero)
    }

    private var photos: [String] { summary.images.isEmpty ? [""] : summary.images }

    private var hero: some View {
        TabView(selection: $page) {
            ForEach(photos.indices, id: \.self) { index in
                RemoteImage(url: photos[index], fallbackAsset: Imagery.categoryAsset(summary.category) ?? "photo_general_labor").tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 300)
        .overlay(alignment: .top) {
            LinearGradient(colors: [Palette.ink.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            if photos.count > 1 {
                HStack(spacing: 6) {
                    ForEach(photos.indices, id: \.self) { index in
                        Capsule()
                            .fill(.white.opacity(page == index ? 1 : 0.6))
                            .frame(width: page == index ? 22 : 8, height: 8)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 20)
                .background(Palette.ink.opacity(0.35), in: Capsule())
                .padding(.bottom, 44)
            }
        }
    }

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(summary.title).type(22, .bold)
                Spacer()
                if !summary.status.isEmpty { StatusBadge(label: summary.status).padding(.top, 3) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(summary.price).type(24, .bold, Palette.primary)
                if !summary.unit.isEmpty { Text(summary.unit).type(14, .medium, Palette.text3) }
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin.and.ellipse").type(14, .regular, Palette.text3)
                Text.joined(Text("\(summary.addressLabel): ").foregroundStyle(Palette.text3), Text(summary.address).foregroundStyle(Palette.ink))
                    .font(.system(size: 14, weight: .medium))
            }
            schedule
            if let person = summary.person {
                Button { onPerson?() } label: {
                    HStack(spacing: 10) {
                        AvatarView(user: person, size: 36, showsOnline: true)
                        Text.joined(Text("By ").foregroundStyle(Palette.text3).fontWeight(.medium), Text(person.name).foregroundStyle(Palette.ink).fontWeight(.semibold))
                            .font(.system(size: 14))
                        if person.rating > 0 { RatingPill(rating: person.rating) }
                    }
                }
                .buttonStyle(.plain)
                .disabled(onPerson == nil)
            }
            if !summary.description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description").type(16, .semibold)
                    Text(summary.description).type(14, .regular, Palette.text2).lineSpacing(4)
                }
            }
            if !summary.footerDate.isEmpty {
                Text(summary.footerDate).type(12, .medium, Palette.text3).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: Radius.xl, topTrailingRadius: Radius.xl, style: .continuous)
                .fill(Palette.background)
        }
        .padding(.top, -24)
    }

    private var schedule: some View {
        let cells = [("calendar", "Start Date", summary.startDate), ("calendar", "End Date", summary.endDate),
                     ("clock", "Start Time", summary.startTime), ("clock", "End Time", summary.endTime)]
        return Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 16) {
            ForEach([0, 2], id: \.self) { start in
                GridRow {
                    ForEach(start..<(start + 2), id: \.self) { index in
                        HStack(spacing: 10) {
                            Image(systemName: cells[index].0)
                                .type(14, .regular, Palette.primary)
                                .frame(width: 32, height: 32)
                                .background(Palette.primary50, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cells[index].1).type(12, .medium, Palette.text3)
                                Text(cells[index].2).type(14, .semibold).lineLimit(1).minimumScaleFactor(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(16)
        .card()
    }
}

extension DetailScaffold where Actions == EmptyView {
    init(summary: DetailSummary, onPerson: (() -> Void)? = nil, onRefresh: (() async -> Void)? = nil, @ViewBuilder sections: () -> Sections) {
        self.init(summary: summary, showsActions: false, onPerson: onPerson, onRefresh: onRefresh, sections: sections, actions: { EmptyView() })
    }
}

/// Section card with a title and an optional date on the right.
struct DetailCard<Content: View>: View {
    let title: String
    var date: String = ""
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).type(16, .semibold)
                Spacer()
                if !date.isEmpty { Text(date).type(12, .medium, Palette.text3) }
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// Full-screen loading / error state with a back button, for detail screens before their data arrives.
struct DetailLoading<Value, Content: View>: View {
    let state: LoadState<Value>
    var retry: () async -> Void
    @ViewBuilder var content: (Value) -> Content
    @Environment(Navigator.self) private var nav

    var body: some View {
        if let value = state.value {
            content(value)
        } else {
            LoadView(state: state, retry: retry) { _ in EmptyView() }
                .background(Palette.background.ignoresSafeArea())
                .overlay(alignment: .topLeading) {
                    IconButton(icon: "chevron.left", background: .white) { nav.pop() }.padding(.leading, 16).padding(.top, 4)
                }
                .darkStatusBar()
        }
    }
}
