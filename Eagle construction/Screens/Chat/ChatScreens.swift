import MapKit
import PhotosUI
import SwiftUI
import UIKit

/// Message tab: conversations with search.
struct InboxView: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @State private var isSearching = false
    @State private var query = ""
    @State private var state: LoadState<ConversationList> = .loading

    private var hasUnread: Bool { (session.summary?.unreadNotifications ?? 0) > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isSearching {
                    HStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").type(16, .regular, Palette.text3)
                            TextField("", text: $query, prompt: Text("Search here...").foregroundStyle(Palette.muted))
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.ink)
                                .autocorrectionDisabled()
                                .tapToFocus()
                            Button {
                                query = ""
                                isSearching = false
                            } label: { Image(systemName: "xmark.circle.fill").type(16, .regular, Palette.muted) }
                                .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Palette.background, in: Capsule())
                        .overlay(Capsule().stroke(Palette.border))
                        IconButton(icon: "bell", badge: hasUnread) { nav.push(NotificationsScreen()) }
                    }
                    Text("Inbox").type(28, .bold)
                } else {
                    HStack {
                        Text("Inbox").type(28, .bold)
                        Spacer()
                        IconButton(icon: "magnifyingglass") { isSearching = true }
                        IconButton(icon: "bell", badge: hasUnread) { nav.push(NotificationsScreen()) }
                    }
                }
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.shield").type(17, .regular, Tone.info.foreground)
                    Text(state.value?.note.isEmpty == false ? state.value!.note
                         : "Note: Please don't share personal info - insurance won't apply to tasks not done through Eagle Jobs.")
                        .type(12, .regular, Tone.info.foreground)
                        .lineSpacing(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tone.info.background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                LoadView(state: state, retry: load) { list in
                    VStack(spacing: 0) {
                        if list.items.isEmpty {
                            EmptyState(icon: "message", title: query.isEmpty ? "No messages yet" : "No results",
                                       message: query.isEmpty ? "Chats with your workers and clients show here." : nil)
                        }
                        ForEach(list.items.indices, id: \.self) { index in
                            let conversation = list.items[index]
                            if index > 0 { Rectangle().fill(Palette.divider).frame(height: 1).padding(.leading, 66) }
                            Button {
                                nav.push(ChatScreen(conversationId: conversation.id, preview: conversation))
                            } label: {
                                ConversationRow(conversation: conversation)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(minHeight: 200)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .refreshable { await load() }
        .background(Color.white)
        .task(id: query) {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(350)) }
            if Task.isCancelled { return }
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private func load() async {
        await fetch($state) { try await API.conversations(search: query.trimmed) }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(user: conversation.user, size: 52, showsOnline: true)
            VStack(alignment: .leading, spacing: 5) {
                Text(conversation.user.name).type(16, .semibold).lineLimit(1)
                Text(conversation.lastMessage.isEmpty ? conversation.subtitle : conversation.lastMessage)
                    .type(14, conversation.unreadCount > 0 ? .medium : .regular, conversation.unreadCount > 0 ? Palette.ink : Palette.text3)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                if conversation.isBlocked {
                    Image(systemName: "nosign").type(13, .semibold, Tone.danger.foreground)
                }
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)").type(11, .bold, .white).frame(minWidth: 20, minHeight: 20).background(Palette.primary, in: Capsule())
                }
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// One conversation: polls for new messages, sends text / photos / location, block and unblock.
struct ChatScreen: View {
    var conversationId: Int?
    var preview: Conversation?
    /// Account Request → "Chat with Admin".
    var admin = false

    @Environment(Navigator.self) private var nav
    @Environment(Toaster.self) private var toaster
    @State private var conversation: Conversation?
    @State private var messages: [Message] = []
    @State private var loadError: String?
    @State private var draft = ""
    @State private var isSending = false
    @State private var showsAttachments = false
    @State private var showsBlockDialog = false
    @State private var showsGallery = false
    @State private var showsCamera = false
    @State private var galleryItem: PhotosPickerItem?
    @FocusState private var isComposerFocused: Bool

    init(conversationId: Int, preview: Conversation? = nil) {
        self.conversationId = conversationId
        self.preview = preview
    }

    init(admin: Bool) {
        self.admin = admin
    }

    private var current: Conversation? { conversation ?? preview }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if let loadError, messages.isEmpty {
                            Text(loadError).type(14, .regular, Palette.text3).padding(.top, 40)
                        }
                        ForEach(messages) { message in
                            MessageBubble(message: message).id(message.id)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.last?.id) { _, id in
                    guard let id else { return }
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .overlay(alignment: .bottomLeading) {
            if showsAttachments { attachmentMenu.padding(.leading, 20).padding(.bottom, 70) }
        }
        .appDialog(isPresented: $showsBlockDialog) {
            let blocking = !(current?.blockedByMe ?? false)
            AppDialog(title: blocking ? "Block User" : "Unblock", message: "Are you sure you want to \(blocking ? "block" : "unblock") this user?",
                      icon: "nosign", tone: blocking ? .danger : .brand, actions: [
                          DialogAction(title: "Cancel", kind: .outline) { showsBlockDialog = false },
                          DialogAction(title: "Yes", kind: blocking ? .danger : .primary) {
                              showsBlockDialog = false
                              Task { await toggleBlock(blocking) }
                          },
                      ])
        }
        .photosPicker(isPresented: $showsGallery, selection: $galleryItem, matching: .images)
        .onChange(of: galleryItem) { _, item in
            guard let item else { return }
            Task {
                if let image = await PickedImage.load([item]).first { await send(image: image) }
                galleryItem = nil
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { image in
                if let picked = PickedImage(image: image) { Task { await send(image: picked) } }
            }
            .ignoresSafeArea()
        }
        .darkStatusBar()
        .task { await poll() }
    }

    // MARK: Header and composer

    private var header: some View {
        HStack(spacing: 10) {
            IconButton(icon: "chevron.left") { nav.pop() }
            if let user = current?.user {
                Button {
                    if user.role != "support" { nav.push(PersonProfileScreen(userId: user.id)) }
                } label: {
                    HStack(spacing: 10) {
                        AvatarView(user: user, size: 40, showsOnline: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name).type(16, .semibold).lineLimit(1)
                            if let subtitle = current?.subtitle, !subtitle.isEmpty {
                                Text(subtitle).type(12, .regular, Palette.text3).lineLimit(1)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                ProgressView()
            }
            Spacer()
            if let current, current.canBlock {
                Button(current.blockedByMe ? "Unblock" : "Block") { showsBlockDialog = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tone.danger.foreground)
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .background(Tone.danger.background, in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(.white)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.border).frame(height: 1) }
    }

    @ViewBuilder
    private var composer: some View {
        if let current, !current.canMessage {
            Text(current.blockedByMe ? "You blocked this user. Unblock to send messages." : "You can't reply to this conversation.")
                .type(13, .medium, Palette.text3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.white.ignoresSafeArea(edges: .bottom))
        } else {
            HStack(spacing: 8) {
                IconButton(icon: "paperclip", size: 44, foreground: showsAttachments ? Palette.primary : Palette.text2) {
                    showsAttachments.toggle()
                }
                TextField("", text: $draft, prompt: Text("Type here..").foregroundStyle(Palette.muted))
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink)
                    .submitLabel(.send)
                    .focused($isComposerFocused)
                    .onSubmit { Task { await sendText() } }
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Palette.background, in: Capsule())
                    .overlay(Capsule().stroke(Palette.border))
                    .contentShape(Capsule())
                    .onTapGesture { isComposerFocused = true }
                Button {
                    Task { await sendText() }
                } label: {
                    Group {
                        if isSending { ProgressView().tint(.white) } else { Image(systemName: "paperplane.fill").font(.system(size: 18, weight: .semibold)) }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Palette.primary, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isSending || current == nil)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background { Color.white.ignoresSafeArea(edges: .bottom) }
            .overlay(alignment: .top) { Rectangle().fill(Palette.border).frame(height: 1) }
        }
    }

    private var attachmentMenu: some View {
        HStack(spacing: 28) {
            attachment("Camera", icon: "camera", tone: .warning) {
                if CameraPicker.isAvailable { showsCamera = true } else { toaster.show("This device has no camera", error: true) }
            }
            attachment("Gallery", icon: "photo", tone: .danger) { showsGallery = true }
            attachment("Location", icon: "mappin.and.ellipse", tone: .success) { Task { await sendLocation() } }
        }
        .padding(16)
        .card()
    }

    private func attachment(_ title: String, icon: String, tone: Tone, action: @escaping () -> Void) -> some View {
        Button {
            showsAttachments = false
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).type(18, .regular, tone.foreground).frame(width: 44, height: 44).background(tone.background, in: Circle())
                Text(title).type(12, .medium, Palette.text2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Data

    private func poll() async {
        if conversationId == nil && admin {
            do {
                conversation = try await API.adminConversation()
            } catch {
                loadError = error.userMessage
                if !error.isCancellation { toaster.show(error) }
                return
            }
        }
        guard let id = conversationId ?? conversation?.id else { return }
        while !Task.isCancelled {
            do {
                let page = try await API.messages(in: id, after: messages.last?.id)
                conversation = page.conversation
                let known = Set(messages.map(\.id))
                let fresh = page.items.filter { !known.contains($0.id) }
                if !fresh.isEmpty {
                    messages.append(contentsOf: fresh)
                    messages.sort { $0.id < $1.id }
                }
                if fresh.contains(where: { !$0.mine }) || messages.count == fresh.count {
                    try? await API.markRead(id)
                }
                loadError = nil
            } catch {
                if error.isCancellation { return }
                if messages.isEmpty { loadError = error.userMessage }
            }
            try? await Task.sleep(for: .seconds(4))
        }
    }

    private var activeId: Int? { conversationId ?? conversation?.id }

    private func append(_ message: Message) {
        if !messages.contains(where: { $0.id == message.id }) { messages.append(message) }
    }

    private func sendText() async {
        let text = draft.trimmed
        guard !text.isEmpty, let id = activeId else { return }
        isSending = true
        defer { isSending = false }
        do {
            append(try await API.sendText(text, in: id))
            draft = ""
        } catch {
            toaster.show(error)
        }
    }

    private func send(image: PickedImage) async {
        guard let id = activeId else { return }
        isSending = true
        defer { isSending = false }
        do {
            append(try await API.sendImage(image.data, in: id))
        } catch {
            toaster.show(error)
        }
    }

    private func sendLocation() async {
        guard let id = activeId else { return }
        guard let location = await LocationService.shared.currentLocation() else {
            toaster.show("Allow location access in Settings to share your location", error: true)
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            append(try await API.sendLocation(lat: location.coordinate.latitude, lng: location.coordinate.longitude, in: id))
        } catch {
            toaster.show(error)
        }
    }

    private func toggleBlock(_ blocking: Bool) async {
        guard let user = current?.user else { return }
        do {
            if blocking { try await API.block(user.id) } else { try await API.unblock(user.id) }
            toaster.show(blocking ? "User blocked" : "User unblocked")
            if let id = activeId, let page = try? await API.messages(in: id, after: messages.last?.id) { conversation = page.conversation }
        } catch {
            toaster.show(error)
        }
    }
}

private struct MessageBubble: View {
    let message: Message

    var body: some View {
        VStack(alignment: message.mine ? .trailing : .leading, spacing: 3) {
            content
            Text(time).type(10, .medium, Palette.muted)
        }
        .frame(maxWidth: 270, alignment: message.mine ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: message.mine ? .trailing : .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch message.type {
        case "image":
            RemoteImage(url: message.attachment)
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        case "location":
            Button {
                let item = MKMapItem(location: CLLocation(latitude: message.lat, longitude: message.lng), address: nil)
                item.openInMaps()
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    LocationMap(lat: message.lat, lng: message.lng, showsPulse: false).frame(width: 220, height: 130)
                    Label("Shared location", systemImage: "mappin.and.ellipse")
                        .type(13, .semibold, message.mine ? .white : Palette.ink)
                        .padding(10)
                }
                .background(message.mine ? Palette.primary : .white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        default:
            Text(message.text)
                .type(15, .regular, message.mine ? .white : Palette.ink)
                .lineSpacing(2)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.mine ? Palette.primary : .white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    if !message.mine { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.border) }
                }
        }
    }

    private var time: String {
        guard let date = Formats.isoDate(message.createdAt) else { return "" }
        return Formats.chatTime.string(from: date)
    }
}
