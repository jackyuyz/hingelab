import SwiftUI
import FoldKit

/// Attached once at the root of every scene. The only place that may mention
/// `onHingeChange` / `UIHingeInteraction`. Feature views use `FoldStateProvider`.
struct HingeBridgeModifier: ViewModifier {
    let provider: SystemFoldStateProvider

    func body(content: Content) -> some View {
        // TODO(verify-api): `View.onHingeChange(isEnabled:_:)` is confirmed in
        // docs/talks but assumed `@available(iOS 27.1, *)`. Do not invent a
        // different API name if this fails to compile — leave this note.
        //
        // TODO(verify-api): `UIHingeInteraction(updateHandler:)` is the UIKit
        // equivalent (angle in radians, extra `.unknown` status). Same rule.
        content
            .onAppear {
                provider.ingestNoHinge()
            }
        // if #available(iOS 27.1, *) {
        //     content.onHingeChange { _, ctx in
        //         provider.ingest(ctx.hinge)
        //     }
        // } else {
        //     content.onAppear { provider.ingestNoHinge() }
        // }
    }
}

extension SystemFoldStateProvider {
    func ingestNoHinge() {
        updateState(.noHinge)
    }

    // TODO(verify-api): DeviceHinge / DeviceHingeContext types from iOS 27.1 SDK.
    // func ingest(_ hinge: DeviceHinge?) {
    //     guard let hinge else {
    //         ingestNoHinge()
    //         return
    //     }
    //     let posture: FoldPosture
    //     switch hinge.status {
    //     case .closed: posture = .closed
    //     case .partiallyOpen: posture = .partiallyOpen
    //     case .fullyOpen: posture = .fullyOpen
    //     @unknown default: posture = .unknown
    //     }
    //     updateState(FoldState(posture: posture, angleDegrees: hinge.angle.degrees, timestamp: .now))
    // }
}

extension View {
    func observeFoldState(_ binding: Binding<FoldState>) -> some View {
        modifier(FoldStateObserver(state: binding))
    }
}

private struct FoldStateObserver: ViewModifier {
    @Environment(\.foldStateProvider) private var provider
    @Binding var state: FoldState

    func body(content: Content) -> some View {
        content.task {
            state = provider.state
            for await next in provider.states() {
                state = next
            }
        }
    }
}
