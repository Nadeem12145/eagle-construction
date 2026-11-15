import SwiftUI

// MARK: - Buttons

enum ButtonKind {
    case primary, secondary, outline, danger, dangerSoft, success, disabled

    var background: Color {
        switch self {
        case .primary: Palette.primary
        case .secondary: Palette.primary50
        case .outline: .white
        case .danger: Tone.danger.foreground
        case .dangerSoft: Tone.danger.background
        case .success: Tone.success.foreground
        case .disabled: Palette.divider
        }
    }

    var foreground: Color {
        switch self {
        case .primary, .danger, .success: .white
        case .secondary, .outline: Palette.primary
        case .dangerSoft: Tone.danger.foreground
        case .disabled: Palette.muted
        }
    }
}

struct AppButton: View {
    let title: String
    var kind: ButtonKind = .primary
    var icon: String? = nil
    var height: CGFloat = 52
    var fontSize: CGFloat = 16
    var badge = false
    var isLoading = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(kind.foreground)
                } else {
                    if let icon { Image(systemName: icon).font(.system(size: fontSize, weight: .semibold)) }
                    Text(title).font(.system(size: fontSize, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    if badge { Circle().fill(Tone.danger.foreground).frame(width: 9, height: 9).offset(y: -6) }
                }
            }
            .foregroundStyle(kind.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(kind.background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                if kind == .outline {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Palette.border, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(kind == .disabled || isLoading)
    }
}

struct IconButton: View {
    let icon: String
    var size: CGFloat = 40
    var background: Color = Palette.background
    var foreground: Color = Palette.ink
    var badge = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(background, in: Circle())
                .overlay(alignment: .topTrailing) {
                    if badge {
                        Circle()
                            .fill(Tone.danger.foreground)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(background, lineWidth: 2))
                            .padding(size * 0.2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// Sticky bottom bar holding one or more rows of buttons.
struct ActionBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 12) { content }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(.white)
            .overlay(alignment: .top) { Rectangle().fill(Palette.border).frame(height: 1) }
    }
}

// MARK: - Inputs

struct AppField: View {
    var label: String? = nil
    @Binding var text: String
    var placeholder = ""
    var leading: String? = nil
    var trailing: String? = nil
    var options: [String]? = nil
    var height: CGFloat = 52
    var multiline = false
    var maxLength: Int? = nil
    var note: String? = nil
    var fill: Color = .white
    var valueColor = Palette.ink
    var secure = false
    var readOnly = false
    var keyboard: UIKeyboardType = .default
    /// People's and company names: capitalised words, never autocorrected.
    var isName = false
    var onTrailing: (() -> Void)? = nil
    /// Makes the whole field a button (date pickers, map pickers).
    var onTap: (() -> Void)? = nil

    @State private var isHidden = true
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label { Text(label).type(13, .medium, Palette.text2) }
            if let options {
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(option) { text = option }
                    }
                } label: {
                    box {
                        Text(text.isEmpty ? placeholder : text)
                            .type(15, .regular, text.isEmpty ? Palette.muted : valueColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.down").type(14, .semibold, Palette.text3)
                    }
                }
            } else if let onTap {
                Button(action: onTap) {
                    box {
                        Text(text.isEmpty ? placeholder : text)
                            .type(15, .regular, text.isEmpty ? Palette.muted : valueColor)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let trailing { Image(systemName: trailing).type(17, .medium, Palette.primary) }
                    }
                }
                .buttonStyle(.plain)
            } else {
                // The whole box focuses the field, not just its first line.
                box { input }
                    .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .onTapGesture { if !readOnly { isFocused = true } }
            }
            if let note { Text(note).type(12, .regular, Palette.text3) }
        }
    }

    @ViewBuilder
    private var input: some View {
        if readOnly {
            Text(text).type(15, .regular, Palette.text2).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                Button { onTrailing?() } label: { Text(trailing).type(14, .semibold, Palette.primary) }.buttonStyle(.plain)
            }
        } else if multiline {
            ZStack(alignment: .bottomTrailing) {
                TextField("", text: $text, prompt: prompt, axis: .vertical)
                    .focused($isFocused)
                    .font(.system(size: 15))
                    .foregroundStyle(valueColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .onChange(of: text) { _, value in
                        if let maxLength, value.count > maxLength { text = String(value.prefix(maxLength)) }
                    }
                if let maxLength { Text("\(text.count)/\(maxLength)").type(12, .regular, Palette.muted) }
            }
        } else {
            Group {
                if secure && isHidden {
                    SecureField("", text: $text, prompt: prompt)
                } else {
                    TextField("", text: $text, prompt: prompt)
                }
            }
            .focused($isFocused)
            .font(.system(size: 15))
            .foregroundStyle(valueColor)
            .keyboardType(keyboard)
            .textInputAutocapitalization([.emailAddress, .URL].contains(keyboard) ? .never : isName ? .words : .sentences)
            .autocorrectionDisabled(isName || [.emailAddress, .URL, .numberPad, .decimalPad].contains(keyboard))

            if secure {
                Button { isHidden.toggle() } label: {
                    Image(systemName: isHidden ? "eye" : "eye.slash").type(16, .medium, Palette.primary)
                }
                .buttonStyle(.plain)
            } else if let trailing {
                Button { onTrailing?() } label: {
                    Image(systemName: trailing).type(17, .medium, Palette.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var prompt: Text {
        Text(placeholder).foregroundStyle(Palette.muted)
    }

    private func box<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: multiline ? .top : .center, spacing: 12) {
            if let leading {
                Image(systemName: leading).type(16, .regular, Palette.text3)
            }
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, multiline ? 14 : 0)
        .frame(height: height)
        .background(readOnly ? Palette.background : fill, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Palette.border, lineWidth: 1))
    }
}

struct TermsCheckbox: View {
    @Binding var agreed: Bool
    var onOpenTerms: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Button { agreed.toggle() } label: {
                Image(systemName: "checkmark")
                    .type(12, .heavy, agreed ? .white : .clear)
                    .frame(width: 22, height: 22)
                    .background(agreed ? Palette.primary : .white, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(agreed ? .clear : Palette.muted))
            }
            .buttonStyle(.plain)
            Button(action: onOpenTerms) {
                Text.joined(Text("I agree to the ").foregroundStyle(Palette.text2), Text("Terms and conditions").fontWeight(.semibold).foregroundStyle(Palette.primary))
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
    }
}

struct RadioMark: View {
    let selected: Bool

    var body: some View {
        Circle()
            .stroke(selected ? Palette.primary : Palette.muted, lineWidth: 1.5)
            .frame(width: 22, height: 22)
            .overlay { if selected { Circle().fill(Palette.primary).frame(width: 12, height: 12) } }
    }
}

// MARK: - Status and tabs

struct StatusBadge: View {
    let label: String
    var tone: Tone? = nil
    var showsDot = true

    var body: some View {
        let tone = tone ?? Tone.forStatus(label)
        HStack(spacing: 5) {
            if showsDot { Circle().fill(tone.foreground).frame(width: 6, height: 6) }
            Text(label).type(12, .semibold, tone.foreground).lineLimit(1).fixedSize()
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(tone.background, in: Capsule())
    }
}

struct RatingPill: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").type(11, .regular, Palette.star)
            Text(String(format: "%.1f", rating)).type(12, .bold)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Palette.starBackground, in: Capsule())
    }
}

struct SegmentedTabs: View {
    let items: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = index }
                } label: {
                    Text(items[index])
                        .type(14, .semibold, selection == index ? .white : Palette.text2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            if selection == index {
                                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Palette.primary)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Palette.background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Palette.border))
    }
}

// MARK: - Headers

/// Rounded navy band that runs under the status bar.
struct NavyBand: View {
    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous)
            .fill(Palette.primary)
            .overlay(alignment: .topTrailing) {
                Circle().fill(.white.opacity(0.04)).frame(width: 240, height: 240).offset(x: 80, y: -60)
            }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous))
            .ignoresSafeArea(edges: .top)
    }
}

struct AppBar<Trailing: View>: View {
    let title: String
    var showsBack = true
    var showsBorder = true
    @ViewBuilder var trailing: Trailing
    @Environment(Navigator.self) private var nav

    var body: some View {
        ZStack {
            Text(title).type(17, .semibold).lineLimit(1).padding(.horizontal, 60)
            HStack {
                if showsBack {
                    IconButton(icon: "chevron.left") { nav.pop() }
                }
                Spacer()
                trailing
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 56)
        .background(.white)
        .overlay(alignment: .bottom) {
            if showsBorder { Rectangle().fill(Palette.divider).frame(height: 1) }
        }
    }
}

extension AppBar where Trailing == EmptyView {
    init(title: String, showsBack: Bool = true, showsBorder: Bool = true) {
        self.init(title: title, showsBack: showsBack, showsBorder: showsBorder) { EmptyView() }
    }
}

/// "Eagle Jobs" wordmark or page title on navy, with menu and notification buttons.
struct BrandHeader: View {
    var title: String = "Eagle Jobs"
    var hasUnread = false
    var onMenu: () -> Void = {}
    var onBell: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            IconButton(icon: "line.3.horizontal", background: Palette.navyButton, foreground: .white, action: onMenu)
            Text(title).font(.system(size: 21, weight: .heavy)).italic().foregroundStyle(.white)
            Spacer()
            IconButton(icon: "bell", background: Palette.navyButton, foreground: .white, badge: hasUnread, action: onBell)
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
    }
}

/// App bar + scrolling body + optional sticky bottom bar.
struct ListScreen<Content: View, Trailing: View, Bottom: View>: View {
    let title: String
    var background: Color = Palette.background
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content
    @ViewBuilder var bottom: Bottom

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: title) { trailing }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .background(background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { bottom }
        .darkStatusBar()
    }
}

extension ListScreen where Trailing == EmptyView, Bottom == EmptyView {
    init(title: String, background: Color = Palette.background, @ViewBuilder content: () -> Content) {
        self.init(title: title, background: background, trailing: { EmptyView() }, content: content, bottom: { EmptyView() })
    }
}

extension ListScreen where Trailing == EmptyView {
    init(title: String, background: Color = Palette.background,
         @ViewBuilder content: () -> Content, @ViewBuilder bottom: () -> Bottom) {
        self.init(title: title, background: background, trailing: { EmptyView() }, content: content, bottom: bottom)
    }
}

// MARK: - Bottom navigation

struct NavItem {
    let title: String
    let icon: String
}

struct BottomNav: View {
    let items: [NavItem]
    @Binding var selection: Int
    var onPost: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                if onPost != nil && index == items.count / 2 {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
                Button { selection = index } label: {
                    VStack(spacing: 4) {
                        Image(systemName: items[index].icon)
                            .type(17, .medium, selection == index ? Palette.primary : Palette.muted)
                            .frame(width: 52, height: 30)
                            .background(selection == index ? Palette.primary50 : .clear, in: Capsule())
                        Text(items[index].title)
                            .type(11, selection == index ? .bold : .medium, selection == index ? Palette.primary : Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            Color.white
                .shadow(color: Palette.ink.opacity(0.06), radius: 8, y: -3)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            if let onPost {
                Button(action: onPost) {
                    Image(systemName: "plus")
                        .type(22, .semibold, .white)
                        .frame(width: 50, height: 50)
                        .background(Palette.primary, in: Circle())
                        .padding(5)
                        .background(.white, in: Circle())
                        .shadow(color: Palette.ink.opacity(0.08), radius: 6, y: -2)
                }
                .buttonStyle(.plain)
                .offset(y: -30)
            }
        }
    }
}

// MARK: - Overlays

extension View {
    /// Centered modal over a dimmed screen.
    func appDialog<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        overlay {
            ZStack {
                if isPresented.wrappedValue {
                    Palette.ink.opacity(0.5).ignoresSafeArea().transition(.opacity)
                    content().padding(.horizontal, 30).transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.easeOut(duration: 0.2), value: isPresented.wrappedValue)
        }
    }

    /// Bottom sheet over a dimmed screen.
    func appSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        overlay {
            ZStack(alignment: .bottom) {
                if isPresented.wrappedValue {
                    Palette.ink.opacity(0.5)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { isPresented.wrappedValue = false }
                    VStack(spacing: 0) {
                        Capsule().fill(Palette.border).frame(width: 36, height: 5).padding(.top, 8)
                        content()
                    }
                    .frame(maxWidth: .infinity)
                    .background {
                        UnevenRoundedRectangle(topLeadingRadius: Radius.xl, topTrailingRadius: Radius.xl, style: .continuous)
                            .fill(.white)
                            .ignoresSafeArea(edges: .bottom)
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeOut(duration: 0.25), value: isPresented.wrappedValue)
        }
    }
}

struct DialogAction {
    let title: String
    var kind: ButtonKind = .primary
    var action: () -> Void = {}
}

struct AppDialog<Extra: View>: View {
    let title: String
    var message: String? = nil
    var titleColor: Color = Palette.ink
    var icon: String? = nil
    var tone: Tone = .brand
    var art: String? = nil
    var artSize = CGSize(width: 150, height: 134)
    var onClose: (() -> Void)? = nil
    var actions: [DialogAction] = []
    @ViewBuilder var extra: Extra

    var body: some View {
        VStack(spacing: 0) {
            if let icon {
                Image(systemName: icon)
                    .type(24, .medium, tone.foreground)
                    .frame(width: 56, height: 56)
                    .background(tone.background, in: Circle())
                    .padding(.bottom, 12)
            }
            if let art {
                Image(art).resizable().scaledToFit().frame(width: artSize.width, height: artSize.height).padding(.bottom, 12)
            }
            Text(title)
                .type(20, .bold, titleColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, onClose == nil ? 0 : 20)
            if let message {
                Text(message)
                    .type(15, .regular, Palette.text2)
                    .multilineTextAlignment(message.count > 120 ? .leading : .center)
                    .lineSpacing(3)
                    .padding(.top, 8)
            }
            extra.padding(.top, 16)
            if !actions.isEmpty {
                HStack(spacing: 12) {
                    ForEach(actions.indices, id: \.self) { index in
                        AppButton(title: actions[index].title, kind: actions[index].kind, action: actions[index].action)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let onClose {
                IconButton(icon: "xmark", size: 36, foreground: Palette.text2, action: onClose).padding(12)
            }
        }
    }
}

extension AppDialog where Extra == EmptyView {
    init(title: String, message: String? = nil, titleColor: Color = Palette.ink, icon: String? = nil, tone: Tone = .brand,
         art: String? = nil, onClose: (() -> Void)? = nil, actions: [DialogAction] = []) {
        self.init(title: title, message: message, titleColor: titleColor, icon: icon, tone: tone, art: art,
                  onClose: onClose, actions: actions) { EmptyView() }
    }
}

struct DrawerItem {
    let title: String
    let icon: String
    var action: () -> Void = {}
}

/// Slide-in side menu.
struct SideDrawer: View {
    @Binding var isOpen: Bool
    let items: [DrawerItem]
    var name = ""
    var email = ""
    var avatar = ""
    var onLogout: () -> Void = {}

    var body: some View {
        ZStack(alignment: .leading) {
            if isOpen {
                Palette.ink.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { isOpen = false }
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading) {
                        Spacer()
                        HStack(spacing: 14) {
                            AvatarView(name: name, url: avatar, size: 60)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: name).type(18, .bold, .white).lineLimit(1)
                                Text(verbatim: email).type(14, .regular, Palette.onNavy).lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 28)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 196)
                    .background(Palette.primary.ignoresSafeArea(edges: .top))

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items.indices, id: \.self) { index in
                            Button {
                                isOpen = false
                                items[index].action()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: items[index].icon)
                                        .type(17, .regular, index == 0 ? Palette.primary : Palette.text2)
                                        .frame(width: 24)
                                    Text(items[index].title).type(15, index == 0 ? .semibold : .medium, index == 0 ? Palette.primary : Palette.ink)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 48)
                                .background(index == 0 ? Palette.primary50 : .clear, in: RoundedRectangle(cornerRadius: Radius.md))
                            }
                            .buttonStyle(.plain)
                        }
                        Rectangle().fill(Palette.divider).frame(height: 1).padding(.vertical, 10).padding(.horizontal, 8)
                        Button {
                            isOpen = false
                            onLogout()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .type(17, .regular, Tone.danger.foreground)
                                    .frame(width: 24)
                                Text("Logout").type(15, .semibold, Tone.danger.foreground)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    Spacer()
                }
                .frame(width: 300)
                .background(.white)
                .transition(.move(edge: .leading))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.25), value: isOpen)
    }
}
