import SwiftUI
import HingeL10n
import Store

struct PaywallView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var working = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "latch.2.case")
                        .font(.system(size: 56))
                    Text(L10nKey.paywallHeadline.text(in: model.language))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(L10nKey.paywallSubtitle.text(in: model.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    PlaceholderSlot(
                        title: "Paywall hero (placeholder)",
                        systemImage: "photo",
                        accessibilityID: "slot.paywallHero"
                    )
                    if let product = model.store.products.first(where: { $0.id == .full }) {
                        Text(product.displayPrice)
                            .font(.title.bold())
                            .accessibilityIdentifier("paywall.price")
                    }
                    status
                    Button(L10nKey.paywallPurchase.text(in: model.language)) {
                        Task { await purchase() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(working)
                    .accessibilityIdentifier("paywall.purchase")
                    Button(L10nKey.paywallRestore.text(in: model.language)) {
                        Task { await model.store.restore() }
                    }
                    .accessibilityIdentifier("paywall.restore")
                }
                .padding()
            }
            .navigationTitle(L10nKey.paywallTitle.text(in: model.language))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10nKey.commonClose.text(in: model.language)) { dismiss() }
                }
            }
            .task { await model.store.loadProducts() }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch model.store.purchaseState {
        case .loading:
            Text(L10nKey.paywallLoading.text(in: model.language))
        case .pending:
            Text(L10nKey.paywallPending.text(in: model.language))
        case .offline:
            Text(L10nKey.paywallOffline.text(in: model.language))
        case .purchased:
            Text(L10nKey.paywallPurchased.text(in: model.language))
        case .failed(let message):
            Text(message).foregroundStyle(.red)
        default:
            EmptyView()
        }
    }

    private func purchase() async {
        working = true
        _ = await model.store.purchase(.full)
        EntitlementCache.save(model.store.entitlements)
        working = false
        if model.store.entitlements.hasFull {
            dismiss()
        }
    }
}
