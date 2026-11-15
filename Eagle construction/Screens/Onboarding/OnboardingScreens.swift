import PhotosUI
import SwiftUI
import UIKit

/// Navy hero with logo and title above a rounded white sheet.
struct AuthScaffold<Content: View, Bottom: View>: View {
    let title: String
    var subtitle: String? = nil
    var showsBack = false
    var showsLogo = true
    var onBack: (() -> Void)? = nil
    @ViewBuilder var content: Content
    @ViewBuilder var bottom: Bottom
    @Environment(Navigator.self) private var nav

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                if showsLogo {
                    Image("logo_mark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .frame(width: 92, height: 92)
                        .background(.white, in: Circle())
                }
                Text(title).type(28, .bold, .white).multilineTextAlignment(.center)
                if let subtitle {
                    Text(verbatim: subtitle).type(15, .regular, Palette.onNavy).multilineTextAlignment(.center).lineSpacing(3)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, showsLogo ? 36 : 44)
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) { content }
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                bottom.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                    .fill(.white)
                    .ignoresSafeArea(edges: .bottom)
            }
            .padding(.top, -28)
        }
        .background(alignment: .topTrailing) {
            Circle().fill(.white.opacity(0.04)).frame(width: 240, height: 240).offset(x: 80, y: -100)
        }
        .background(Palette.primary.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            if showsBack {
                IconButton(icon: "chevron.left", background: Palette.navyButton, foreground: .white) {
                    if let onBack { onBack() } else { nav.pop() }
                }
                .padding(.leading, 12)
                .padding(.top, 8)
            }
        }
        .lightStatusBar()
    }
}

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("logo_full").resizable().scaledToFit().frame(width: 260)
            VStack {
                Spacer()
                ProgressView().tint(Palette.primary).controlSize(.large).padding(.bottom, 40)
            }
        }
        .darkStatusBar()
    }
}

struct ChoiceOption {
    let title: String
    let icon: String
}

struct ChoiceScreen: View {
    let title: String
    let options: [ChoiceOption]
    var showsBack = false
    let onNext: (Int) -> Void
    @State private var selected: Int

    init(title: String, options: [ChoiceOption], selected: Int, showsBack: Bool = false, onNext: @escaping (Int) -> Void) {
        self.title = title
        self.options = options
        self.showsBack = showsBack
        self.onNext = onNext
        _selected = State(initialValue: selected)
    }

    var body: some View {
        AuthScaffold(title: title, showsBack: showsBack) {
            ForEach(options.indices, id: \.self) { index in
                let isOn = index == selected
                Button { selected = index } label: {
                    HStack(spacing: 16) {
                        Image(systemName: options[index].icon)
                            .type(19, .medium, Palette.primary)
                            .frame(width: 44, height: 44)
                            .background(isOn ? .white : Palette.background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        Text(options[index].title).type(16, .semibold)
                        Spacer()
                        RadioMark(selected: isOn)
                    }
                    .padding(16)
                    .background(isOn ? Palette.primary50 : .white, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(isOn ? Palette.primary : Palette.border, lineWidth: isOn ? 1.5 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } bottom: {
            AppButton(title: "Next") { onNext(selected) }
        }
    }
}

// MARK: - Sign in

struct SignupRoleScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session

    var body: some View {
        ChoiceScreen(title: "Signup",
                     options: [ChoiceOption(title: "As a Client", icon: "briefcase"), ChoiceOption(title: "As a Worker", icon: "hammer")],
                     selected: session.signupRole == "worker" ? 1 : 0) { role in
            if role == 0 {
                session.signupRole = "client"
                nav.push(AccountTypeScreen())
            } else {
                session.signupRole = "worker"
                session.signupAccountType = "individual"
                nav.push(EmailLoginScreen())
            }
        }
    }
}

private struct AccountTypeScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session

    var body: some View {
        ChoiceScreen(title: "Your are a?",
                     options: [ChoiceOption(title: "Company", icon: "building.2"), ChoiceOption(title: "Individual", icon: "person")],
                     selected: session.signupAccountType == "individual" ? 1 : 0,
                     showsBack: true) { kind in
            session.signupAccountType = kind == 0 ? "company" : "individual"
            nav.push(EmailLoginScreen())
        }
    }
}

struct EmailLoginScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var email = ""
    @State private var isSending = false

    var body: some View {
        AuthScaffold(title: "Login", showsBack: true) {
            VStack(spacing: 10) {
                Text("Let's Get It Started!").type(20, .bold)
                Text("Please enter your email address to verify your identity. You will receive a code on this email.")
                    .type(15, .regular, Palette.text3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity)
            AppField(text: $email, placeholder: "Email Address", leading: "envelope", keyboard: .emailAddress)
                .padding(.top, 8)
                .onSubmit { Task { await send() } }
        } bottom: {
            AppButton(title: "Send Code", isLoading: isSending) { Task { await send() } }
        }
    }

    private func send() async {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.contains("@"), value.contains(".") else {
            toaster.show("Enter a valid email address", error: true)
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            let sent = try await API.sendCode(email: value, role: session.signupRole, accountType: session.signupAccountType)
            nav.push(VerificationScreen(email: value, sentTo: sent.sentTo, resendAfter: sent.resendAfterSeconds, debugCode: sent.otp))
        } catch {
            toaster.show(error)
        }
    }
}

struct VerificationScreen: View {
    let email: String
    @State var sentTo: String
    @State var resendAfter: Int
    /// Only a local test server (OTP_DEBUG) sends the code back; debug builds fill it in.
    var debugCode: String?

    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var code = ""
    @State private var remaining = 0
    @State private var resendRound = 0
    @State private var isVerifying = false
    @State private var isResending = false
    @FocusState private var focused: Bool

    var body: some View {
        AuthScaffold(title: "Verification", subtitle: "Enter the code sent to your email \(sentTo)", showsBack: true, showsLogo: false) {
            ZStack {
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focused)
                    .foregroundStyle(.clear)
                    .tint(.clear)
                    .frame(height: 56)
                    .accessibilityLabel("Verification code")
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { index in
                        let digits = Array(code)
                        let isCurrent = index == min(code.count, 5) && focused
                        Text(index < digits.count ? String(digits[index]) : "")
                            .type(22, .semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.white, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .stroke(isCurrent ? Palette.primary : Palette.border, lineWidth: isCurrent ? 1.5 : 1))
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            .onChange(of: code) { _, value in
                let digits = String(value.filter(\.isNumber).prefix(6))
                if digits != value { code = digits }
            }

            VStack(spacing: 8) {
                Text("Did not receive a code?").type(15, .regular, Palette.text2)
                Button {
                    Task { await resend() }
                } label: {
                    Text(remaining > 0 ? "RESEND (\(remaining)s)" : "RESEND")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(remaining > 0 ? Palette.muted : Palette.primary)
                }
                .buttonStyle(.plain)
                .disabled(remaining > 0 || isResending)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
        } bottom: {
            AppButton(title: "Verify", isLoading: isVerifying) { Task { await verify() } }
        }
        .task {
            #if DEBUG
            if let debugCode { code = debugCode }
            #endif
            focused = true
        }
        .task(id: resendRound) {
            remaining = resendAfter
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remaining -= 1
            }
        }
    }

    private func verify() async {
        guard code.count == 6 else {
            toaster.show("Enter the 6-digit code from your email", error: true)
            return
        }
        isVerifying = true
        defer { isVerifying = false }
        do {
            session.signedIn(try await API.verifyCode(email: email, code: code))
        } catch {
            toaster.show(error)
        }
    }

    private func resend() async {
        isResending = true
        defer { isResending = false }
        do {
            let sent = try await API.resendCode(email: email)
            sentTo = sent.sentTo
            resendAfter = sent.resendAfterSeconds
            resendRound += 1
            code = ""
            #if DEBUG
            if let otp = sent.otp { code = otp }
            #endif
            toaster.show("A new code was sent to \(sent.sentTo)")
        } catch let error as APIError {
            if let wait = error.retryAfterSeconds {
                resendAfter = wait
                resendRound += 1
            }
            toaster.show(error)
        } catch {
            toaster.show(error)
        }
    }
}

// MARK: - Onboarding steps after sign in

/// The screen for `me.nextStep`; finishing a step updates `session.me`, and the root moves on.
struct OnboardingStepView: View {
    let step: String
    @Environment(Session.self) private var session

    var body: some View {
        switch step {
        case "complete_profile": CompleteProfileScreen()
        case "identity_proof": IdentityProofScreen()
        case "select_categories": SelectCategoriesScreen()
        case "allow_location": AllowLocationScreen()
        case "account_request": AccountRequestScreen()
        default:
            VStack(spacing: 16) {
                Text("Please update the app to continue.").type(16, .semibold)
                AppButton(title: "Logout", kind: .outline, height: 44) { Task { await session.logout() } }.frame(width: 160)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

enum ProfileKind {
    case company, client, worker

    init(_ me: Me) {
        self = me.isWorker ? .worker : (me.isCompany ? .company : .client)
    }
}

/// The editable fields of the three profile forms.
struct ProfileDraft {
    var firstName = ""
    var lastName = ""
    var companyName = ""
    var registrationNumber = ""
    var website = ""
    var dob: Date?
    var gender = ""
    var postcode = ""
    var address = ""
    var overview = ""

    init(_ me: Me) {
        firstName = me.firstName
        lastName = me.lastName
        companyName = me.companyName
        registrationNumber = me.registrationNumber
        website = me.website
        dob = Formats.apiDate.date(from: String(me.dob.prefix(10)))
        gender = me.gender
        postcode = me.postcode
        address = me.address
        overview = me.overview
    }

    func fields(_ kind: ProfileKind) -> [String: String] {
        var fields: [String: String] = ["address": address.trimmed, "overview": overview.trimmed]
        switch kind {
        case .company:
            fields["companyName"] = companyName.trimmed
            fields["registrationNumber"] = registrationNumber.trimmed
            fields["website"] = website.trimmed
        case .client, .worker:
            fields["firstName"] = firstName.trimmed
            fields["lastName"] = lastName.trimmed
            fields["gender"] = gender
            if let dob { fields["dob"] = Formats.apiDate.string(from: dob) }
            if kind == .worker { fields["postcode"] = postcode.trimmed }
        }
        return fields
    }

    /// The first required field that is still empty, as the form labels it.
    func missing(_ kind: ProfileKind) -> String? {
        switch kind {
        case .company:
            if companyName.trimmed.isEmpty { return "Company Name" }
            if registrationNumber.trimmed.isEmpty { return "Company Registration Number" }
            if address.trimmed.isEmpty { return "Company Address" }
            if overview.trimmed.isEmpty { return "Company Description" }
        case .client, .worker:
            if firstName.trimmed.isEmpty { return "First Name" }
            if lastName.trimmed.isEmpty { return "Last Name" }
            if kind == .worker && postcode.trimmed.isEmpty { return "Home Postcode" }
            if dob == nil { return "Date of birth" }
            if gender.isEmpty { return "Gender" }
            if address.trimmed.isEmpty { return "Location" }
            if kind == .worker && overview.trimmed.isEmpty { return "Service description" }
        }
        return nil
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// Avatar with a camera / plus badge that opens the photo library.
struct AvatarPicker: View {
    let name: String
    let url: String
    @Binding var picked: PickedImage?
    var placeholderIcon: String? = nil
    var size: CGFloat = 92
    @State private var item: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let picked {
                        Image(uiImage: picked.preview).resizable().scaledToFill()
                    } else if url.isEmpty, let placeholderIcon {
                        Image(systemName: placeholderIcon)
                            .type(36, .regular, Palette.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Palette.primary50)
                    } else {
                        AvatarView(name: name, url: url, size: size)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Palette.primary100, lineWidth: 1.5))
                Image(systemName: placeholderIcon == nil ? "camera.fill" : "plus")
                    .type(12, .bold, .white)
                    .frame(width: 30, height: 30)
                    .background(Palette.primary, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
            }
        }
        .buttonStyle(.plain)
        .onChange(of: item) { _, value in
            guard let value else { return }
            Task {
                picked = await PickedImage.load([value]).first
                item = nil
            }
        }
    }
}

/// The form fields shared by Complete Profile (placeholders) and Edit Profile (labels).
struct ProfileFormFields: View {
    let kind: ProfileKind
    @Binding var draft: ProfileDraft
    let email: String
    var labelled = false
    var onChangeEmail: (() -> Void)? = nil
    @Environment(Navigator.self) private var nav

    var body: some View {
        switch kind {
        case .company:
            field("Company Name", $draft.companyName)
            field("Company Registration Number", $draft.registrationNumber)
            emailField("Company Email")
            AppField(label: labelled ? "Company Website Link" : nil, text: $draft.website, placeholder: "Company Website Link", leading: "globe",
                     valueColor: Tone.info.foreground, keyboard: .URL)
            if !labelled { locationField("Company Address") }
            AppField(label: labelled ? "Company Description" : nil, text: $draft.overview, placeholder: "Company Description", height: 96, multiline: true, maxLength: 1000)
            if labelled { locationField("Company Address") }
        case .client, .worker:
            AppField(label: labelled ? "First Name" : nil, text: $draft.firstName, placeholder: "First Name",
                     note: kind == .worker && !labelled ? "Note: Enter your name as it appears on your government issued ID" : nil, isName: true)
            field("Last Name", $draft.lastName)
            emailField("Email")
            if kind == .worker {
                AppField(label: labelled ? "Home Postcode" : nil, text: $draft.postcode, placeholder: "Home Postcode")
            }
            DateField(label: labelled ? "Date of Birth" : nil, placeholder: "Date of birth", value: $draft.dob, pastOnly: true)
            AppField(label: labelled ? "Gender" : nil, text: $draft.gender, placeholder: "Gender", options: ["Male", "Female"])
            if kind == .worker {
                if !labelled { locationField("Select Location") }
                AppField(label: labelled ? "Service Description" : nil, text: $draft.overview, placeholder: "Service description", height: 96, multiline: true, maxLength: 1000)
                if labelled { locationField("Location") }
            } else {
                if labelled {
                    AppField(label: "Profile Overview", text: $draft.overview, placeholder: "Profile Overview", height: 88, multiline: true, maxLength: 1000)
                    locationField("Location")
                } else {
                    locationField("Select Location")
                    AppField(text: $draft.overview, placeholder: "Profile Overview", height: 96, multiline: true, maxLength: 1000)
                }
            }
        }
    }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        AppField(label: labelled ? title : nil, text: text, placeholder: title, isName: title.hasSuffix("Name"))
    }

    private func emailField(_ title: String) -> some View {
        AppField(label: labelled ? title : nil, text: .constant(email), placeholder: title, leading: "envelope",
                 trailing: onChangeEmail == nil ? nil : "Change", readOnly: true, onTrailing: onChangeEmail)
    }

    private func locationField(_ title: String) -> some View {
        AppField(label: labelled ? title : nil, text: .constant(draft.address), placeholder: title, trailing: "scope", onTap: {
            nav.push(MapPickerScreen(title: "Location", buttonTitle: "Save") { place in
                draft.address = place.address
                if draft.postcode.isEmpty { draft.postcode = place.postalCode }
                nav.pop()
            })
        })
    }
}

struct CompleteProfileScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var draft: ProfileDraft?
    @State private var avatar: PickedImage?
    @State private var agreed = false
    @State private var isSaving = false

    var body: some View {
        if let me = session.me {
            let kind = ProfileKind(me)
            AuthScaffold(title: "Let's Complete Profile", showsBack: true, showsLogo: false, onBack: { Task { await session.logout() } }) {
                VStack(spacing: 10) {
                    AvatarPicker(name: me.name, url: me.avatar, picked: $avatar, placeholderIcon: kind == .company ? "building.2" : "person")
                    Text(kind == .company ? "Add Company Profile" : "Add Profile Image").type(14, .semibold, Palette.primary)
                }
                .frame(maxWidth: .infinity)
                ProfileFormFields(kind: kind, draft: Binding(get: { draft ?? ProfileDraft(me) }, set: { draft = $0 }), email: me.email)
                TermsCheckbox(agreed: $agreed) { nav.push(LegalScreen(key: "terms", title: "Terms & Conditions")) }
            } bottom: {
                AppButton(title: kind == .worker ? "Next" : "Done", isLoading: isSaving) { Task { await save(me, kind) } }
            }
        }
    }

    private func save(_ me: Me, _ kind: ProfileKind) async {
        let form = draft ?? ProfileDraft(me)
        if let missing = form.missing(kind) {
            toaster.show("Please fill \(missing)", error: true)
            return
        }
        guard agreed else {
            toaster.show("Please accept the Terms & Conditions", error: true)
            return
        }
        isSaving = true
        defer { isSaving = false }
        var fields = form.fields(kind)
        fields["termsAccepted"] = "true"
        do {
            session.me = try await API.updateProfile(fields, avatar: avatar?.data)
        } catch {
            toaster.show(error)
        }
    }
}

struct IdentityProofScreen: View {
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var addressProof: PickedImage?
    @State private var front: PickedImage?
    @State private var back: PickedImage?
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "Identity Proof", showsBack: false) {
                Button("Logout") { Task { await session.logout() } }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tone.danger.foreground)
                    .padding(.trailing, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    IdentityUpload(title: "Upload Proof of Address", note: "(Electricity Bill etc.)", art: "illus_bill", picked: $addressProof)
                    IdentityUpload(title: "Upload Your National ID", note: "(Front)", art: "illus_id_front", picked: $front)
                    IdentityUpload(title: "Upload Your National ID", note: "(Back)", art: "illus_id_back", picked: $back)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.white.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FormButtonBar(title: "Next", isLoading: isSaving) { Task { await save() } }
        }
        .darkStatusBar()
    }

    private func save() async {
        guard let addressProof, let front, let back else {
            toaster.show("Please upload your proof of address and both sides of your national ID", error: true)
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            session.me = try await API.submitIdentity(addressProof: addressProof.data, front: front.data, back: back.data)
        } catch {
            toaster.show(error)
        }
    }
}

private struct IdentityUpload: View {
    let title: String
    let note: String
    let art: String
    @Binding var picked: PickedImage?
    @State private var item: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text.joined(Text(title + " ").fontWeight(.semibold).foregroundStyle(Palette.ink), Text(note).foregroundStyle(Palette.text3))
                .font(.system(size: 15))
            PhotosPicker(selection: $item, matching: .images) {
                Group {
                    if let picked {
                        Image(uiImage: picked.preview)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 132)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                Text("Change").type(12, .semibold, .white).padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Palette.ink.opacity(0.6), in: Capsule()).padding(8)
                            }
                    } else {
                        VStack(spacing: 8) {
                            Image(art).resizable().scaledToFit().frame(width: 80, height: 58)
                            Text("Click for add").type(13, .semibold, Palette.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 132)
                        .background(Palette.primary50, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(Palette.primary100, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onChange(of: item) { _, value in
                guard let value else { return }
                Task {
                    picked = await PickedImage.load([value]).first
                    item = nil
                }
            }
        }
    }
}

struct SelectCategoriesScreen: View {
    var isEditing = false
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster
    @State private var state: LoadState<[Category]> = .loading
    @State private var selected: Set<Int> = []
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "", showsBack: isEditing, showsBorder: false) {
                if !isEditing {
                    Button("Logout") { Task { await session.logout() } }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tone.danger.foreground)
                        .padding(.trailing, 8)
                }
            }
            LoadView(state: state, retry: load) { categories in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What kind of work are you interested in engaging with?").type(22, .bold).lineSpacing(3).padding(.bottom, 8)
                        ForEach(categories) { category in
                            row(category)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FormButtonBar(title: "Done", isLoading: isSaving) { Task { await save() } }
        }
        .darkStatusBar()
        .task {
            if selected.isEmpty { selected = Set(session.me?.categories.map(\.id) ?? []) }
            await load()
        }
    }

    private func row(_ category: Category) -> some View {
        let isOn = selected.contains(category.id)
        return Button {
            if isOn { selected.remove(category.id) } else { selected.insert(category.id) }
        } label: {
            HStack(spacing: 12) {
                CategoryThumb(category: category, size: 40, radius: 20)
                Text(category.name).type(15, isOn ? .semibold : .medium)
                Spacer()
                Image(systemName: isOn ? "xmark" : "plus")
                    .type(12, .bold, isOn ? .white : Palette.primary)
                    .frame(width: 26, height: 26)
                    .background(isOn ? Palette.primary : .white, in: Circle())
                    .overlay(Circle().stroke(isOn ? .clear : Palette.border))
            }
            .padding(.horizontal, 10)
            .frame(height: 60)
            .background(isOn ? Palette.primary50 : .white, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(isOn ? Palette.primary : Palette.border, lineWidth: isOn ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        await fetch($state) { try await API.categories() }
    }

    private func save() async {
        guard !selected.isEmpty else {
            toaster.show("Select at least one category", error: true)
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            session.me = try await API.setCategories(Array(selected).sorted())
            if isEditing {
                toaster.show("Categories updated")
                nav.pop()
            }
        } catch {
            toaster.show(error)
        }
    }
}

struct AllowLocationScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session
    @Environment(Toaster.self) private var toaster

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Palette.primary50).frame(width: 192, height: 192)
                Circle().fill(Palette.primary100).frame(width: 128, height: 128)
                Image(systemName: "mappin.circle.fill").type(70, .regular, Palette.primary)
            }
            Text("Allow \"Eagle Jobs\" to use your location")
                .type(22, .bold)
                .multilineTextAlignment(.center)
                .padding(.top, 32)
                .padding(.horizontal, 40)
            Text("This app requires access to your location to match with the nearest \(session.isWorker ? "Client Requests" : "Worker")!")
                .type(15, .regular, Palette.text3)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 12)
                .padding(.horizontal, 30)
            Spacer()
            VStack(spacing: 12) {
                AppButton(title: "Allow") { allow() }
                AppButton(title: "Allow while using app", kind: .secondary) { allow() }
                AppButton(title: "Don't Allow", kind: .outline) { openMap() }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(Color.white.ignoresSafeArea())
        .darkStatusBar()
    }

    private func allow() {
        Task {
            await LocationService.shared.requestPermission()
            openMap()
        }
    }

    private func openMap() {
        nav.push(MapPickerScreen(title: "Location", buttonTitle: "Save") { place in
            do {
                session.me = try await API.setLocation(lat: place.lat, lng: place.lng, address: place.address, postalCode: place.postalCode)
            } catch {
                toaster.show(error)
            }
        })
    }
}

struct AccountRequestScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Session.self) private var session

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Spacer()
                Button("Logout") { Task { await session.logout() } }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tone.danger.foreground)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            Spacer()
            ZStack {
                Circle().fill(Palette.primary50).frame(width: 300, height: 300)
                Image("illus_account_request").resizable().scaledToFit().frame(width: 280, height: 303)
            }
            VStack(spacing: 12) {
                Text("Thank you for your trust, your request has been sent, we will try to approve you as soon as possible.")
                    .type(18, .semibold)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                if let me = session.me, me.status == "rejected" || me.status == "suspended" {
                    Text(me.statusNote.isEmpty ? me.statusLabel : "\(me.statusLabel): \(me.statusNote)")
                        .type(14, .medium, Tone.danger.foreground)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 30)
            Spacer()
            AppButton(title: "Chat with Admin", icon: "message", badge: (session.summary?.unreadMessages ?? 0) > 0) {
                nav.push(ChatScreen(admin: true))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(Color.white.ignoresSafeArea())
        .darkStatusBar()
        .task {
            // Approval happens in the Support app; check every few seconds while this screen is open.
            while !Task.isCancelled {
                await session.refresh()
                await session.refreshSummary()
                try? await Task.sleep(for: .seconds(8))
            }
        }
    }
}
