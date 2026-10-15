import SwiftUI
import FoldKit
import HingeL10n
import Instruments
import ThemeKit

struct InstrumentPickerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let theme = model.theme
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if model.foldState.posture == .closed {
                    compactCover
                } else {
                    bench
                }
                if model.foldState.posture == .noHinge {
                    RibbonFallback(value: ribbonBinding, language: model.language)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(theme.ui(.stageBackground).ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .navigationTitle(L10nKey.appName.text(in: model.language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.ui(.stageBackground), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { toolbar }
    }

    private var ribbonBinding: Binding<Double> {
        Binding(
            get: { model.ribbon.value01 },
            set: { model.ingestRibbon($0) }
        )
    }

    /// Brand mark, name, subtitle, and the live hinge dial.
    private var header: some View {
        let theme = model.theme
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                brand
                Spacer(minLength: 12)
                AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language)
                    .frame(maxWidth: 300)
            }
            VStack(alignment: .leading, spacing: 14) {
                brand
                AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language, compact: true)
            }
        }
        .foregroundStyle(theme.ui(.primaryText))
    }

    private var brand: some View {
        let theme = model.theme
        return HStack(spacing: 14) {
            HingeLabMark(theme: theme)
                .frame(width: 64, height: 64)
                .background(theme.ui(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(L10nKey.appName.text(in: model.language))
                    .font(StageFont.display(30))
                    .foregroundStyle(theme.ui(.primaryText))
                    .accessibilityAddTraits(.isHeader)
                Text(L10nKey.appSubtitle.text(in: model.language))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(theme.ui(.secondaryText))
            }
        }
    }

    /// Four cards: one row on the wide inner display, 2×2 otherwise.
    private var bench: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10nKey.pickerTitle.text(in: model.language))
                .stageLabelStyle(model.theme)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    ForEach(InstrumentID.allCases, id: \.self) { id in
                        InstrumentCard(id: id).frame(minWidth: 190)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(InstrumentID.allCases, id: \.self) { id in
                        InstrumentCard(id: id)
                    }
                }
            }
        }
    }

    private var compactCover: some View {
        let theme = model.theme
        let hue = theme.ui(.accordionHue)
        return VStack(alignment: .leading, spacing: 12) {
            Text(L10nKey.instrumentCoverTitle.text(in: model.language))
                .stageLabelStyle(theme)
            NavigationLink {
                InstrumentPlayView(id: .accordion)
            } label: {
                HStack(spacing: 14) {
                    InstrumentGlyph(id: .accordion, hue: hue, theme: theme)
                        .frame(width: 64, height: 44)
                    Text(L10nKey.instrumentAccordion.text(in: model.language))
                        .font(StageFont.display(22))
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.title2)
                }
                .foregroundStyle(theme.ui(.primaryText))
                .padding(16)
                .background(theme.ui(.surface), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(hue.opacity(0.6)))
            }
            .buttonStyle(.plain)
            Button {
                model.showLooper = true
            } label: {
                Label(L10nKey.looperTitle.text(in: model.language), systemImage: theme.systemImage(.looper))
                    .font(StageFont.display(17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)
            .tint(theme.ui(.primaryText))
            RibbonFallback(value: ribbonBinding, language: model.language)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cover.compact")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                model.showCalibration = true
            } label: {
                Label(L10nKey.pickerCalibrate.text(in: model.language), systemImage: model.theme.systemImage(.calibrate))
            }
            .accessibilityIdentifier("picker.calibrate")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                model.showSettings = true
            } label: {
                Label(L10nKey.settingsTitle.text(in: model.language), systemImage: model.theme.systemImage(.settings))
            }
            .accessibilityIdentifier("picker.settings")
        }
    }
}

struct InstrumentCard: View {
    let id: InstrumentID
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let theme = model.theme
        let locked = !model.isUnlocked(id)
        let hue = theme.ui(id.hueToken)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        Group {
            if locked {
                Button { model.showPaywall = true } label: { card(locked: true, hue: hue, theme: theme, shape: shape) }
            } else {
                NavigationLink {
                    InstrumentPlayView(id: id)
                } label: {
                    card(locked: false, hue: hue, theme: theme, shape: shape)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("picker.\(id.rawValue)")
        .accessibilityHint(locked ? L10nKey.pickerLocked.text(in: model.language) : id.taglineKey.text(in: model.language))
    }

    private func card(locked: Bool, hue: Color, theme: any ThemeProviding, shape: RoundedRectangle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            InstrumentGlyph(id: id, hue: locked ? hue.opacity(0.45) : hue, theme: theme)
                .frame(height: 64)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            Text(id.titleKey.text(in: model.language))
                .font(StageFont.display(19))
                .foregroundStyle(theme.ui(.primaryText))
                .fixedSize(horizontal: false, vertical: true)
            Text(id.taglineKey.text(in: model.language))
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(theme.ui(.secondaryText))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            status(locked: locked, hue: hue, theme: theme)
        }
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .padding(16)
        .background {
            shape.fill(theme.ui(.surface))
            shape.fill(LinearGradient(colors: [hue.opacity(locked ? 0.06 : 0.16), .clear], startPoint: .top, endPoint: .center))
        }
        .overlay(shape.strokeBorder(theme.ui(.hairline)))
        .contentShape(shape)
    }

    @ViewBuilder
    private func status(locked: Bool, hue: Color, theme: any ThemeProviding) -> some View {
        if locked {
            Label(L10nKey.pickerLocked.text(in: model.language), systemImage: theme.systemImage(.lock))
                .font(StageFont.label)
                .foregroundStyle(theme.ui(.secondaryText))
                .lineLimit(2)
        } else if id.isFree {
            Text(L10nKey.pickerFree.text(in: model.language))
                .font(StageFont.label)
                .foregroundStyle(theme.ui(.onHue))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(hue, in: Capsule())
        }
    }
}
