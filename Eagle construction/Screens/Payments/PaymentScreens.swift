import SwiftUI

/// Client: wallet balance, top up, payment history.
struct WalletScreen: View {
    @Environment(Navigator.self) private var nav
    @Environment(Toaster.self) private var toaster
    @State private var state: LoadState<Wallet> = .loading
    @State private var showsAddBalance = false
    @State private var amount = ""

    var body: some View {
        ScrollView {
            LoadView(state: state, retry: load) { wallet in
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wallet Balance").type(13, .medium, Palette.text3)
                                Text(wallet.balanceLabel).type(30, .bold)
                            }
                            Spacer()
                            AppButton(title: "Add Balance", icon: "plus", height: 40, fontSize: 14) { showsAddBalance = true }.frame(width: 140)
                        }
                        Text(wallet.note.isEmpty ? "Note: You can add balance to your wallet for future bookings. If a booking is canceled by you or declined by the provider, the balance will be returned to your wallet for future use." : wallet.note)
                            .type(12, .regular, Palette.text3)
                            .lineSpacing(3)
                    }
                    .padding(20)
                    .card(radius: Radius.xl)
                    .padding(.top, 8)

                    SectionTitle(title: "Payment History")
                    TransactionList(items: wallet.history.items)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .padding(.top, 56)
        }
        .scrollIndicators(.hidden)
        .refreshable { await load() }
        .background(alignment: .top) { NavyBand().frame(height: 110) }
        .overlay(alignment: .top) {
            ZStack {
                Text("Wallet").type(17, .semibold, .white)
                HStack {
                    IconButton(icon: "chevron.left", background: Palette.navyButton, foreground: .white) { nav.pop() }
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 56)
        }
        .background(Palette.background.ignoresSafeArea())
        .appDialog(isPresented: $showsAddBalance) {
            AppDialog(title: "Add Balance", onClose: { showsAddBalance = false }, actions: [
                DialogAction(title: "Continue") {
                    let value = Double(amount.replacingOccurrences(of: "£", with: "").trimmed) ?? 0
                    guard value > 0 else {
                        toaster.show("Enter the amount to add", error: true)
                        return
                    }
                    showsAddBalance = false
                    amount = ""
                    nav.push(SelectCardScreen(topUpAmount: value))
                },
            ]) {
                TextField("", text: $amount, prompt: Text("Enter Amount").foregroundStyle(Palette.muted))
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Palette.border))
                    .tapToFocus()
            }
        }
        .lightStatusBar()
        .task { await load() }
    }

    private func load() async {
        await fetch($state) { try await API.wallet() }
    }
}

/// Saved cards: make default, delete, add. With an amount it is the top-up step ("Pay £X").
struct SelectCardScreen: View {
    var topUpAmount: Double? = nil
    @Environment(Navigator.self) private var nav
    @Environment(Toaster.self) private var toaster
    @State private var state: LoadState<[Card]> = .loading
    @State private var selected: Int?
    @State private var deleting: Card?
    @State private var isPaying = false

    var body: some View {
        ListScreen(title: "Select Card") {
            LoadView(state: state, retry: load) { cards in
                VStack(alignment: .trailing, spacing: 16) {
                    if cards.isEmpty {
                        EmptyState(icon: "creditcard", title: "No saved cards", message: "Tap + to add a card.")
                    }
                    ForEach(cards) { card in
                        cardView(card)
                        HStack(spacing: 10) {
                            if card.isDefault {
                                StatusBadge(label: "Default", tone: .success)
                            } else {
                                AppButton(title: "Make Default", kind: .secondary, height: 40, fontSize: 14) {
                                    Task { await makeDefault(card) }
                                }
                                .frame(width: 140)
                            }
                            AppButton(title: "Delete", kind: .dangerSoft, icon: "trash", height: 40, fontSize: 14) { deleting = card }.frame(width: 112)
                        }
                    }
                }
            }
        } bottom: {
            if let topUpAmount, state.value?.isEmpty == false {
                FormButtonBar(title: "Pay \(Formats.money(topUpAmount))", isLoading: isPaying, background: Palette.background) {
                    Task { await topUp(topUpAmount) }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            IconButton(icon: "plus", size: 56, background: Palette.primary, foreground: .white) {
                nav.push(AddCardScreen(title: "Add Card", buttonTitle: "Add Card") { nav.pop() })
            }
            .padding(20)
            .padding(.bottom, topUpAmount == nil ? 0 : 76)
        }
        .appDialog(isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            AppDialog(title: "Delete Card", message: "Remove the card ending \(deleting?.last4 ?? "")?", icon: "trash", tone: .danger, actions: [
                DialogAction(title: "Cancel", kind: .outline) { deleting = nil },
                DialogAction(title: "Delete", kind: .danger) {
                    guard let card = deleting else { return }
                    deleting = nil
                    Task { await delete(card) }
                },
            ])
        }
        .task { await load() }
    }

    private func cardView(_ card: Card) -> some View {
        let isOn = topUpAmount != nil && selected == card.id
        return Button { selected = card.id } label: {
            VStack(alignment: .leading) {
                HStack {
                    Text(card.brand).type(20, .bold, .white)
                    Spacer()
                    Text(verbatim: card.masked).type(18, .semibold, .white)
                }
                Spacer()
                HStack(alignment: .bottom) {
                    Text(String(format: "%02d/%02d", card.expMonth, card.expYear % 100)).type(14, .medium, .white.opacity(0.8))
                    Spacer()
                    Text(card.brand.uppercased()).font(.system(size: 34, weight: .heavy)).italic().foregroundStyle(.white.opacity(0.25))
                }
            }
            .padding(22)
            .frame(height: 196)
            .background(Palette.primary, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).stroke(isOn ? Palette.star : .clear, lineWidth: 3))
            .overlay(alignment: .bottomLeading) {
                if isOn {
                    Label("Selected", systemImage: "checkmark.circle.fill")
                        .type(13, .semibold, Palette.star)
                        .padding(.leading, 22)
                        .padding(.bottom, 52)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(topUpAmount == nil)
    }

    private func load() async {
        await fetch($state) { try await API.cards() }
        if let cards = state.value, selected == nil || !cards.contains(where: { $0.id == selected }) {
            selected = cards.first(where: \.isDefault)?.id ?? cards.first?.id
        }
    }

    private func makeDefault(_ card: Card) async {
        do {
            try await API.makeDefault(card.id)
            await load()
        } catch {
            toaster.show(error)
        }
    }

    private func delete(_ card: Card) async {
        do {
            try await API.deleteCard(card.id)
            toaster.show("Card deleted")
            await load()
        } catch {
            toaster.show(error)
        }
    }

    private func topUp(_ amount: Double) async {
        guard let selected else { return }
        isPaying = true
        defer { isPaying = false }
        do {
            toaster.show(try await API.topUp(amount: amount, cardId: selected))
            nav.pop()
        } catch {
            toaster.show(error)
        }
    }
}

struct AddCardScreen: View {
    let title: String
    let buttonTitle: String
    var onAdded: () -> Void = {}
    @Environment(Toaster.self) private var toaster
    @State private var number = ""
    @State private var expiry = ""
    @State private var cvv = ""
    @State private var country = "United States"
    @State private var zip = ""
    @State private var countries = ["United States", "United Kingdom"]
    @State private var isSaving = false

    var body: some View {
        ListScreen(title: title, background: .white) {
            VStack(alignment: .leading, spacing: 16) {
                AppField(label: "Card Number", text: $number, placeholder: "1234 5678 9012 3456", leading: "creditcard", keyboard: .numberPad)
                    .onChange(of: number) { _, value in
                        let digits = String(value.filter(\.isNumber).prefix(19))
                        let grouped = stride(from: 0, to: digits.count, by: 4).map { start -> String in
                            let from = digits.index(digits.startIndex, offsetBy: start)
                            let to = digits.index(from, offsetBy: min(4, digits.count - start))
                            return String(digits[from..<to])
                        }.joined(separator: " ")
                        if grouped != value { number = grouped }
                    }
                HStack(spacing: 12) {
                    AppField(label: "Exp. Date", text: $expiry, placeholder: "MM/YY", keyboard: .numberPad)
                        .onChange(of: expiry) { _, value in
                            let digits = String(value.filter(\.isNumber).prefix(4))
                            let formatted = digits.count > 2 ? "\(digits.prefix(2))/\(digits.dropFirst(2))" : digits
                            if formatted != value { expiry = formatted }
                        }
                    AppField(label: "CVV", text: $cvv, placeholder: "123", secure: true, keyboard: .numberPad)
                        .onChange(of: cvv) { _, value in
                            let digits = String(value.filter(\.isNumber).prefix(4))
                            if digits != value { cvv = digits }
                        }
                }
                AppField(label: "Country", text: $country, options: countries)
                AppField(label: "Zip Code", text: $zip, placeholder: "e.g 31200")
            }
        } bottom: {
            FormButtonBar(title: buttonTitle, isLoading: isSaving) { Task { await save() } }
        }
        .task {
            if let options = try? await API.options(), !options.countries.isEmpty {
                countries = options.countries
                if !countries.contains(country) { country = countries[0] }
            }
        }
    }

    private func save() async {
        let digits = number.filter(\.isNumber)
        guard digits.count >= 12 else { toaster.show("Enter a valid card number", error: true); return }
        guard expiry.count == 5 else { toaster.show("Enter the expiry date as MM/YY", error: true); return }
        guard cvv.count >= 3 else { toaster.show("Enter the CVV", error: true); return }
        guard !zip.trimmed.isEmpty else { toaster.show("Enter the zip code", error: true); return }
        isSaving = true
        defer { isSaving = false }
        do {
            toaster.show(try await API.addCard(number: digits, expiry: expiry, cvv: cvv, country: country, zip: zip.trimmed))
            onAdded()
        } catch {
            toaster.show(error)
        }
    }
}

/// Worker: earnings balance, Stripe link, withdraw, history.
struct EarningsScreen: View {
    @Environment(Toaster.self) private var toaster
    @State private var state: LoadState<Earnings> = .loading
    @State private var isLinking = false
    @State private var showsWithdraw = false
    @State private var amount = ""

    var body: some View {
        ListScreen(title: "Payment History") {
            LoadView(state: state, retry: load) { earnings in
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Total Balance").type(14, .medium, Palette.onNavy)
                        Text(earnings.balanceLabel).type(34, .bold, .white)
                        Button {
                            if earnings.stripeLinked { showsWithdraw = true } else { Task { await link() } }
                        } label: {
                            Group {
                                if isLinking { ProgressView().tint(Palette.primary) } else {
                                    Text(earnings.stripeLinked ? "Withdraw" : "Link Stripe Account").type(15, .semibold, Palette.primary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(.white, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        if earnings.stripeLinked {
                            Label("Stripe account linked", systemImage: "checkmark.seal.fill").type(13, .semibold, .white)
                        }
                        Text(earnings.note.isEmpty ? "Note: Payment transfer to your local bank account, connected through Eagle Jobs Stripe Connect Account, may take 2-3 business days." : earnings.note)
                            .type(12, .regular, Palette.primary100)
                            .lineSpacing(3)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.primary, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))

                    SectionTitle(title: "Payment History")
                    TransactionList(items: earnings.history.items)
                }
            }
        }
        .appDialog(isPresented: $showsWithdraw) {
            AppDialog(title: "Withdraw", message: "Balance: \(state.value?.balanceLabel ?? "")", onClose: { showsWithdraw = false }, actions: [
                DialogAction(title: "Withdraw") {
                    let value = Double(amount.replacingOccurrences(of: "£", with: "").trimmed) ?? 0
                    guard value > 0 else {
                        toaster.show("Enter an amount to withdraw", error: true)
                        return
                    }
                    if let balance = state.value?.balance, value > balance {
                        toaster.show("You can withdraw up to \(state.value?.balanceLabel ?? "your balance")", error: true)
                        return
                    }
                    showsWithdraw = false
                    amount = ""
                    Task { await withdraw(value) }
                },
            ]) {
                TextField("", text: $amount, prompt: Text("Enter Amount").foregroundStyle(Palette.muted))
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(Palette.border))
                    .tapToFocus()
            }
        }
        .task { await load() }
    }

    private func load() async {
        await fetch($state) { try await API.earnings() }
    }

    private func link() async {
        isLinking = true
        defer { isLinking = false }
        do {
            toaster.show(try await API.linkStripe())
            await load()
        } catch {
            toaster.show(error)
        }
    }

    private func withdraw(_ value: Double) async {
        do {
            toaster.show(try await API.withdraw(amount: value))
            await load()
        } catch {
            toaster.show(error)
        }
    }
}
