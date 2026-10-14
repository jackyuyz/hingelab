import SwiftUI
import FoldKit
import HingeInput
import HingeL10n

struct CalibrationView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var session = CalibrationSession()

    var body: some View {
        VStack(spacing: 24) {
            if model.foldState.posture == .noHinge {
                Text(L10nKey.calNoHinge.text(in: model.language))
                    .multilineTextAlignment(.center)
                    .padding()
                RibbonFallback(
                    value: Binding(
                        get: { model.ribbon.value01 },
                        set: { model.ingestRibbon($0) }
                    ),
                    language: model.language
                )
            } else {
                Text(stepCopy)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language)
                Button(session.step == .confirm ? L10nKey.calDone.text(in: model.language) : L10nKey.calContinue.text(in: model.language)) {
                    capture()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("cal.continue")
            }
            Spacer()
        }
        .padding()
        .navigationTitle(L10nKey.calTitle.text(in: model.language))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10nKey.commonClose.text(in: model.language)) { dismiss() }
            }
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
