import SwiftUI
import FoldKit
import HingeInput
import HingeL10n
import SettingsKit
import Store
import Synth
import ThemeKit

@main
struct HingeLabApp: App {
    @State private var foldStateProvider = SystemFoldStateProvider()
    @State private var mockFoldStateProvider: MockFoldStateProvider?
    @StateObject private var model: AppModel

    init() {
        let mock = Self.makeMockProviderIfRequested()
        _mockFoldStateProvider = State(initialValue: mock)
        let settingsStore = UserDefaultsSettingsStore()
        let store = MockStore(entitlements: EntitlementCache.load() ?? Entitlements())
        _model = StateObject(wrappedValue: AppModel(
            settingsStore: settingsStore,
            store: store,
            engine: OfflineAudioEngine(),
            midi: NullMIDISender(),
            theme: PlaceholderTheme(),
            audioAssets: PlaceholderAudioAssets()
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.foldStateProvider, currentProvider)
                .environmentObject(model)
                .modifier(HingeBridgeModifier(provider: foldStateProvider))
        }
    }

    private var currentProvider: any FoldStateProvider {
        mockFoldStateProvider ?? foldStateProvider
    }

    /// `-FoldMock <value>` swaps in the mock provider in DEBUG, or whenever
    /// `-UITestMode 1` is present (spec §8).
    private static func makeMockProviderIfRequested() -> MockFoldStateProvider? {
        guard Self.shouldHonorFoldMock() else { return nil }
        guard let mockValue = getMockValue() else { return nil }
        let (posture, angle, script) = MockFoldStateProvider.parseArgument(mockValue)
        let mock = MockFoldStateProvider(initialState: FoldState(posture: posture, angleDegrees: angle))
        if let script {
            Task { await mock.play(script) }
        }
        return mock
    }

    private static func shouldHonorFoldMock() -> Bool {
        let args = CommandLine.arguments
        if args.contains("-UITestMode") { return true }
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private static func getMockValue() -> String? {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "-FoldMock"), index + 1 < args.count {
            return args[index + 1]
        }
        return nil
    }
}

// MARK: - Environment

private struct FoldStateProviderKey: EnvironmentKey {
    static let defaultValue: any FoldStateProvider = SystemFoldStateProvider()
}

extension EnvironmentValues {
    var foldStateProvider: any FoldStateProvider {
        get { self[FoldStateProviderKey.self] }
        set { self[FoldStateProviderKey.self] = newValue }
    }
}
