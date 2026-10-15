import SwiftUI
import HingeL10n
import Instruments
import Store
import ThemeKit

struct PaywallView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var working = false

    var body: some View {
        let theme = model.theme
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    PaywallHero(theme: theme)
                        .frame(maxWidth: 520)
                        .accessibilityElement()
                        .accessibilityIdentifier("slot.paywallHero")
                        .accessibilityLabel(L10nKey.slotPaywallHero.text(in: model.language))
                    VStack(spacing: 8) {
                        Text(L10nKey.paywallHeadline.text(in: model.language))
                            .font(StageFont.display(28))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.ui(.primaryText))
                        Text(L10nKey.paywallSubtitle.text(in: model.language))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(theme.ui(.secondaryText))
                            .multilineTextAlignment(.center)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        feature(.paywallFeatureInstruments, symbol: theme.systemImage(.guitar), tint: theme.ui(.guitarHue))
                        feature(.paywallFeatureMIDI, symbol: theme.systemImage(.midi), tint: theme.ui(.filterHue))
                        feature(.paywallFeatureLoops, symbol: theme.systemImage(.looper), tint: theme.ui(.thereminHue))
                    }
                    .padding(16)
                    .frame(maxWidth: 520, alignment: .leading)
                    .background(theme.ui(.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    // Price always comes from StoreKit (`displayPrice`), never a literal.
                    if let product = model.store.products.first(where: { $0.id == .full }) {
                        VStack(spacing: 2) {
                            Text(product.displayPrice)
                                .font(StageFont.readout(34))
                                .foregroundStyle(theme.ui(.primaryText))
                                .accessibilityIdentifier("paywall.price")
                            Text(L10nKey.paywallOneTime.text(in: model.language))
                                .font(StageFont.caption)
                                .foregroundStyle(theme.ui(.secondaryText))
                        }
                    }
                    status
                    Button {
                        Task { await purchase() }
                    } label: {
                        HStack {
                            if working { ProgressView().tint(theme.ui(.onHue)) }
                            Text(L10nKey.paywallPurchase.text(in: model.language))
                        }
                        .font(StageFont.display(18, weight: .semibold))
                        .frame(maxWidth: 420, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.ui(.accordionHue))
                    .foregroundStyle(theme.ui(.onHue))
                    .disabled(working)
                    .accessibilityIdentifier("paywall.purchase")
                    Button(L10nKey.paywallRestore.text(in: model.language)) {
                        Task { await model.store.restore() }
                    }
                    .tint(theme.ui(.secondaryText))
                    .accessibilityIdentifier("paywall.restore")
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(theme.ui(.stageBackground).ignoresSafeArea())
            .environment(\.colorScheme, .dark)
            .navigationTitle(L10nKey.paywallTitle.text(in: model.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.ui(.stageBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10nKey.commonClose.text(in: model.language)) { dismiss() }
                }
            }
            .task { await model.store.loadProducts() }
        }
    }

    private func feature(_ key: L10nKey, symbol: String, tint: Color) -> some View {
        Label {
            Text(key.text(in: model.language))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(model.theme.ui(.primaryText))
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 28)
        }
    }

    @ViewBuilder
    private var status: some View {
        let theme = model.theme
        Group {
            switch model.store.purchaseState {
            case .loading:
                ProgressView(L10nKey.paywallLoading.text(in: model.language))
            case .pending:
                Label(L10nKey.paywallPending.text(in: model.language), systemImage: "hourglass")
            case .offline:
                Label(L10nKey.paywallOffline.text(in: model.language), systemImage: "wifi.slash")
            case .purchased:
                Label(L10nKey.paywallPurchased.text(in: model.language), systemImage: "checkmark.seal.fill")
                    .foregroundStyle(theme.ui(.waveform))
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.ui(.destructive))
            default:
                EmptyView()
            }
        }
        .font(.system(.subheadline, design: .rounded))
        .foregroundStyle(theme.ui(.secondaryText))
        .multilineTextAlignment(.center)
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

/// Hero (slot.paywallHero): the four instruments on the stage, each in its
/// hue, around the brand mark.
struct PaywallHero: View {
    var theme: any ThemeProviding

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(theme.ui(.surface))
            RadialGradient(colors: [theme.ui(.accordionHue).opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 320)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            HStack(spacing: 0) {
                VStack(spacing: 18) {
                    glyph(.accordion)
                    glyph(.filterSweep)
                }
                HingeLabMark(theme: theme)
                    .frame(width: 130, height: 130)
                VStack(spacing: 18) {
                    glyph(.pitchBendGuitar)
                    glyph(.theremin)
                }
            }
            .padding(20)
        }
        .aspectRatio(1.6, contentMode: .fit)
    }

    private func glyph(_ id: InstrumentID) -> some View {
        InstrumentGlyph(id: id, hue: theme.ui(id.hueToken), theme: theme)
            .frame(width: 96, height: 56)
            .padding(10)
            .background(theme.ui(.surfaceRaised), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
