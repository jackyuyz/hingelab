import Foundation
import Combine
import FoldKit
import HingeInput
import HingeL10n
import Instruments
import Looper
import MIDIOut
import SettingsKit
import Store
import Synth
import ThemeKit

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: UserSettings
    @Published var foldState: FoldState = .noHinge
    @Published var displayMetrics: DisplayMetrics = .zero
    @Published var selectedInstrument: InstrumentID = .accordion
    @Published var currentParams: InstrumentParams = InstrumentParams()
    @Published var audioOverlay: AudioOverlay?
    @Published var language: AppLanguage
    @Published var ribbon = RibbonControl()
    @Published var showPaywall = false
    @Published var showSettings = false
    @Published var showMIDI = false
    @Published var showLooper = false
    @Published var showCalibration = false
    @Published var creaseProvider: any CreaseRegionProviding = UnavailableCreaseRegionProvider()

    let store: any StoreServicing
    let engine: any AudioEngineControlling
    let midi: any MIDISending
    let theme: any ThemeProviding
    let audioAssets: any AudioAssetProviding
    let recorder: LoopRecorder
    private let settingsStore: any SettingsStoring
    private var pipeline: HingeInputPipeline
    private var instrument: any Instrument
    private var engineStarted = false

    enum AudioOverlay: Equatable {
        case interrupted
        case headphonesUnplugged
        case noOutput
        case bluetoothLatency
        case cpuOverload
    }

    init(
        settingsStore: any SettingsStoring,
        store: any StoreServicing,
        engine: any AudioEngineControlling,
        midi: any MIDISending,
        theme: any ThemeProviding,
        audioAssets: any AudioAssetProviding
    ) {
        self.settingsStore = settingsStore
        self.store = store
        self.engine = engine
        self.midi = midi
        self.theme = theme
        self.audioAssets = audioAssets
        let loaded = settingsStore.load()
        self.settings = loaded
        self.language = AppLanguage(languageCode: loaded.languageCode) ?? .en
        self.pipeline = HingeInputPipeline(calibration: loaded.calibration)
        self.instrument = InstrumentFactory.make(.accordion, settings: loaded)
        self.recorder = LoopRecorder(isPro: store.entitlements.hasFull)
        engine.setVoiceKind(InstrumentID.accordion.defaultVoice)
    }

    var entitlements: Entitlements { store.entitlements }

    func isUnlocked(_ id: InstrumentID) -> Bool {
        entitlements.isUnlocked(id)
    }

    func select(_ id: InstrumentID) {
        guard isUnlocked(id) else {
            showPaywall = true
            return
        }
        selectedInstrument = id
        instrument = InstrumentFactory.make(id, settings: settings)
        engine.setVoiceKind(id.defaultVoice)
        startEngineIfNeeded()
    }

    func startEngineIfNeeded() {
        guard !engineStarted else { return }
        do {
            try engine.start()
            engineStarted = true
        } catch {
            audioOverlay = .noOutput
        }
    }

    func ingestFold(_ state: FoldState) {
        foldState = state
        creaseProvider = MockCreaseRegionProvider(isHalfFolded: state.posture == .partiallyOpen)
        let sample: HingeSample
        if state.hasHinge, state.angleDegrees != nil, state.posture != .closed {
            sample = pipeline.ingest(state)
        } else {
            sample = pipeline.ingestFallback(value01: ribbon.value01, timestamp: Date().timeIntervalSince1970, source: state.posture == .closed ? .ribbon : .ribbon)
        }
        apply(sample)
        if state.posture == .closed {
            instrument.allNotesOff(release: true)
            engine.setRelease(true)
        }
    }

    func ingestRibbon(_ value01: Double) {
        ribbon.set(value01)
        let sample = pipeline.ingestFallback(
            value01: ribbon.value01,
            timestamp: Date().timeIntervalSince1970,
            source: .ribbon
        )
        apply(sample)
    }

    func noteOn(_ note: UInt8, velocity: UInt8 = 100) {
        startEngineIfNeeded()
        instrument.noteOn(note, velocity: velocity)
        if let hz = instrument.params.frequencyHz {
            engine.noteOn(frequencyHz: hz, velocity: Double(velocity) / 127)
        }
        flushMIDI()
        currentParams = instrument.params
    }

    func noteOff(_ note: UInt8) {
        instrument.noteOff(note)
        if instrument.params.amplitude == 0 {
            engine.noteOff()
        }
        flushMIDI()
        currentParams = instrument.params
    }

    func setThereminVolume(_ value: Double) {
        if let theremin = instrument as? ThereminInstrument {
            theremin.setVolume(value)
            engine.setParameters(theremin.params.asVoice)
            currentParams = theremin.params
        }
    }

    func handleAudioSession(_ event: AudioSessionEvent) {
        switch AudioSessionPolicy.action(for: event) {
        case .stopEngine:
            engine.stop()
            engineStarted = false
            audioOverlay = .interrupted
        case .resumeEngine:
            startEngineIfNeeded()
            audioOverlay = nil
        case .pauseOutputForSafety:
            engine.stop()
            engineStarted = false
            audioOverlay = .headphonesUnplugged
        case .showBluetoothLatencyWarning:
            audioOverlay = .bluetoothLatency
        case .rebuildGraph:
            engine.stop()
            engineStarted = false
            startEngineIfNeeded()
        case .increaseBufferTo256:
            settings.audioBuffer = .normal
            persistSettings()
            audioOverlay = .cpuOverload
        case .showNoOutput:
            audioOverlay = .noOutput
        case .none:
            break
        }
    }

    func updateSettings(_ mutate: (inout UserSettings) -> Void) {
        mutate(&settings)
        language = AppLanguage(languageCode: settings.languageCode) ?? .en
        pipeline.calibration = settings.calibration
        persistSettings()
        instrument = InstrumentFactory.make(selectedInstrument, settings: settings)
    }

    func persistSettings() {
        settingsStore.save(settings)
    }

    func calibrationFinished(_ calibration: HingeCalibration) {
        updateSettings { $0.calibration = calibration }
        pipeline = HingeInputPipeline(calibration: calibration)
    }

    private func apply(_ sample: HingeSample) {
        instrument.handle(sample)
        currentParams = instrument.params
        engine.setParameters(instrument.params.asVoice)
        if recorder.state == .recording || recorder.state == .overdubbing,
           let last = engine.lastRender {
            _ = recorder.append(last.samples)
        }
        flushMIDI()
    }

    private func flushMIDI() {
        guard entitlements.midiEnabled else { return }
        for event in instrument.midiEvents {
            midi.send(event)
        }
    }
}

extension AppModel {
    static var preview: AppModel {
        AppModel(
            settingsStore: MemorySettingsStore(),
            store: MockStore(),
            engine: OfflineAudioEngine(),
            midi: NullMIDISender(),
            theme: PlaceholderTheme(),
            audioAssets: PlaceholderAudioAssets()
        )
    }
}
