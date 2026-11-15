import MapKit
import PhotosUI
import SwiftUI
import UIKit

/// A field that opens a wheel picker for a date or a time.
struct DateField: View {
    var label: String? = nil
    let placeholder: String
    @Binding var value: Date?
    var time = false
    /// Birth dates: nothing after today. Job dates: nothing before today.
    var pastOnly = false
    var futureOnly = false

    @State private var isPicking = false
    @State private var draft = Date()

    var body: some View {
        AppField(label: label, text: .constant(display), placeholder: placeholder, trailing: time ? "clock" : "calendar", onTap: {
            draft = value ?? (pastOnly ? Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now : .now)
            isPicking = true
        })
        .sheet(isPresented: $isPicking) {
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { isPicking = false }.foregroundStyle(Palette.text2)
                    Spacer()
                    Text(label ?? placeholder).type(16, .semibold)
                    Spacer()
                    Button("Done") {
                        value = draft
                        isPicking = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.primary)
                }
                .padding(.horizontal, 20)
                .frame(height: 52)
                picker.datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
            }
            .presentationDetents([.height(300)])
        }
    }

    @ViewBuilder
    private var picker: some View {
        let components: DatePickerComponents = time ? .hourAndMinute : .date
        if pastOnly {
            DatePicker("", selection: $draft, in: ...Date.now, displayedComponents: components)
        } else if futureOnly {
            DatePicker("", selection: $draft, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: components)
        } else {
            DatePicker("", selection: $draft, displayedComponents: components)
        }
    }

    private var display: String {
        guard let value else { return "" }
        return time ? Formats.showTime.string(from: value) : Formats.showDate.string(from: value)
    }
}

/// "Add images" row: a plus tile and the picked photos with remove buttons.
struct PhotoPickerRow: View {
    @Binding var images: [PickedImage]
    var limit = 10

    @State private var items: [PhotosPickerItem] = []

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if images.count < limit {
                    PhotosPicker(selection: $items, maxSelectionCount: limit - images.count, matching: .images) {
                        Image(systemName: "plus")
                            .type(20, .semibold, Palette.primary)
                            .frame(width: 68, height: 68)
                            .background(Palette.primary50, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Palette.primary100, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }
                }
                ForEach(images) { image in
                    Image(uiImage: image.preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Button { images.removeAll { $0.id == image.id } } label: {
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
        .onChange(of: items) { _, picked in
            guard !picked.isEmpty else { return }
            Task {
                let loaded = await PickedImage.load(picked)
                images.append(contentsOf: loaded.prefix(limit - images.count))
                items = []
            }
        }
    }
}

/// Row of remote photos (delivery work, dispute proof, cancellation proof).
struct PhotoStrip: View {
    let urls: [String]
    var height: CGFloat = 64

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(urls, id: \.self) { url in
                    RemoteImage(url: url)
                        .frame(width: height * 1.2, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

struct InfoNote: View {
    let label: String
    let text: String
    var tinted = true

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").type(15, .regular, tinted ? Tone.info.foreground : Palette.text2)
            Text.joined(Text("\(label): ").fontWeight(.bold).foregroundStyle(Palette.ink), Text(text).foregroundStyle(Palette.text2))
                .font(.system(size: 13))
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tinted ? Tone.info.background : Palette.background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

/// White pill search field with a round action button, on the navy header.
struct SearchRow: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var onAction: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").type(16, .regular, Palette.text3)
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Palette.muted))
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .tapToFocus()
                if !text.isEmpty {
                    Button { text = "" } label: { Image(systemName: "xmark.circle.fill").type(16, .regular, Palette.muted) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(.white, in: Capsule())
            IconButton(icon: icon, size: 50, background: Palette.navyAccent, foreground: .white, action: onAction)
        }
    }
}

/// Bottom bar with one primary button, used under forms.
struct FormButtonBar: View {
    let title: String
    var kind: ButtonKind = .primary
    var isLoading = false
    var background: Color = .white
    let action: () -> Void

    var body: some View {
        AppButton(title: title, kind: kind, isLoading: isLoading, action: action)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(background.ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Map

/// Full-screen map with a centre pin. Search, current location, and the address under the pin.
struct MapPickerScreen: View {
    let title: String
    let buttonTitle: String
    var showsSearch = true
    var onPick: (PickedPlace) async -> Void

    @Environment(Navigator.self) private var nav
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                                                                                latitudinalMeters: 3000, longitudinalMeters: 3000))
    @State private var center: CLLocationCoordinate2D?
    @State private var place: PickedPlace?
    @State private var isLooking = false
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSaving = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
        }
        .mapControls {}
        .onMapCameraChange(frequency: .onEnd) { context in
            center = context.region.center
        }
        .overlay {
            Image(systemName: "mappin")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.primary)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                .offset(y: -17)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { bottomBar }
        .task(id: center.map { "\(($0.latitude * 10_000).rounded()),\(($0.longitude * 10_000).rounded())" }) {
            guard let center else { return }
            isLooking = true
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            place = await LocationService.shared.place(at: center)
            isLooking = false
        }
        .task { await goToCurrentLocation() }
        .task(id: query) {
            let text = query.trimmingCharacters(in: .whitespaces)
            guard text.count > 1 else {
                results = []
                return
            }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            results = Array(await LocationService.shared.search(text, near: nil).prefix(6))
        }
        .darkStatusBar()
    }

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                IconButton(icon: "chevron.left", size: 44, background: .white) { nav.pop() }
                Text(title)
                    .type(16, .semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(.white, in: Capsule())
                IconButton(icon: "location.fill", size: 44, background: .white, foreground: Palette.primary) {
                    Task { await goToCurrentLocation() }
                }
            }
            if showsSearch {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").type(16, .regular, Palette.text3)
                        TextField("", text: $query, prompt: Text("Search location here...").foregroundStyle(Palette.muted))
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.ink)
                            .focused($searchFocused)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    ForEach(results, id: \.self) { item in
                        Rectangle().fill(Palette.divider).frame(height: 1)
                        Button {
                            choose(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "").type(14, .semibold).lineLimit(1)
                                Text(item.address?.shortAddress ?? "").type(12, .regular, Palette.text3).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.white, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse").type(16, .regular, Palette.primary)
                if isLooking && place == nil {
                    ProgressView().controlSize(.small)
                    Spacer()
                } else {
                    Text(place?.address ?? "Move the map to place the pin")
                        .type(14, .medium, place == nil ? Palette.text3 : Palette.ink)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .shadow(color: Palette.ink.opacity(0.1), radius: 8, y: 3)
            AppButton(title: buttonTitle, kind: place == nil ? .disabled : .primary, isLoading: isSaving) {
                guard let place else { return }
                Task {
                    isSaving = true
                    await onPick(place)
                    isSaving = false
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func choose(_ item: MKMapItem) {
        searchFocused = false
        query = ""
        results = []
        let coordinate = item.location.coordinate
        position = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 600, longitudinalMeters: 600))
        center = coordinate
    }

    private func goToCurrentLocation() async {
        guard let location = await LocationService.shared.currentLocation() else { return }
        position = .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 600, longitudinalMeters: 600))
        center = location.coordinate
    }
}


/// Makes a whole field box focus its text field when tapped, not just the text line.
private struct TapToFocus: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
    }
}

extension View {
    func tapToFocus() -> some View { modifier(TapToFocus()) }
}
