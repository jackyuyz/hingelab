import SwiftUI
import FoldKit
import HingeInput
import HingeL10n
import ThemeKit

struct CalibrationView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var session = CalibrationSession()

    var body: some View {
        let theme = model.theme
        ScrollView {
            VStack(spacing: 22) {
                if model.foldState.posture == .noHinge {
                    Image(systemName: theme.systemImage(.ribbon))
                        .font(.system(size: 44))
                        .foregroundStyle(theme.ui(.accordionHue))
                        .accessibilityHidden(true)
                    Text(L10nKey.calNoHinge.text(in: model.language))
                        .font(.system(.title3, design: .rounded))
                        .multilineTextAlignment(.center)
                    RibbonFallback(
                        value: Binding(
                            get: { model.ribbon.value01 },
                            set: { model.ingestRibbon($0) }
                        ),
                        language: model.language
                    )
                } else {
                    StepDots(current: stepIndex, tint: theme.ui(.accordionHue), theme: theme)
                    Text(L10nKey.calStepOf.text(in: model.language, "\(stepIndex + 1)"))
                        .stageLabelStyle(theme)
                    Text(stepCopy)
                        .font(StageFont.display(26, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.ui(.primaryText))
                        .fixedSize(horizontal: false, vertical: true)
                    AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language)
                        .frame(maxWidth: 420)
                    Button {
                        capture()
                    } label: {
                        Text(session.step == .confirm ? L10nKey.calDone.text(in: model.language) : L10nKey.calContinue.text(in: model.language))
                            .font(StageFont.display(18, weight: .semibold))
                            .frame(maxWidth: 360, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.ui(.accordionHue))
                    .foregroundStyle(theme.ui(.onHue))
                    .accessibilityIdentifier("cal.continue")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(theme.ui(.stageBackground).ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .navigationTitle(L10nKey.calTitle.text(in: model.language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10nKey.commonClose.text(in: model.language)) { dismiss() }
            }
        }
    }

    private var stepIndex: Int {
        switch session.step {
        case .restClosed: return 0
        case .restOpen: return 1
        case .confirm: return 2
        }
    }

    private var stepCopy: String {
        switch session.step {
        case .restClosed: return L10nKey.calStep1.text(in: model.language)
        case .restOpen: return L10nKey.calStep2.text(in: model.language)
        case .confirm: return L10nKey.calStep3.text(in: model.language)
        }
    }

    private func capture() {
        if session.step == .confirm {
            if let finished = session.finish() {
                model.calibrationFinished(finished)
            }
            dismiss()
            return
        }
        session.capture(degrees: model.foldState.angleDegrees ?? model.ribbon.value01 * 180)
    }
}

private struct StepDots: View {
    var current: Int
    var tint: Color
    var theme: any ThemeProviding

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? tint : theme.ui(.surfaceRaised))
                    .frame(width: index == current ? 28 : 10, height: 10)
            }
        }
        .animation(.easeOut(duration: 0.2), value: current)
        .accessibilityHidden(true)
    }
}
