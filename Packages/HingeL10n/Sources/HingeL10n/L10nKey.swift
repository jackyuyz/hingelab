import Foundation

public enum L10nKey: String, CaseIterable, Sendable, Hashable {
    case appName = "app.name"
    case appSubtitle = "app.subtitle"
    case pickerTitle = "picker.title"
    case pickerCalibrate = "picker.calibrate"
    case pickerFree = "picker.free"
    case pickerLocked = "picker.locked"
    case instrumentAccordion = "instrument.accordion"
    case instrumentGuitar = "instrument.guitar"
    case instrumentFilter = "instrument.filter"
    case instrumentTheremin = "instrument.theremin"
    case instrumentFoldHint = "instrument.foldHint"
    case instrumentBellowsHint = "instrument.bellowsHint"
    case instrumentRibbon = "instrument.ribbon"
    case instrumentCoverTitle = "instrument.coverTitle"
    case instrumentInterrupted = "instrument.interrupted"
    case instrumentHeadphones = "instrument.headphones"
    case instrumentNoOutput = "instrument.noOutput"
    case instrumentBluetooth = "instrument.bluetooth"
    case instrumentLeft = "instrument.left"
    case instrumentRight = "instrument.right"
    case calTitle = "cal.title"
    case calStep1 = "cal.step1"
    case calStep2 = "cal.step2"
    case calStep3 = "cal.step3"
    case calNoHinge = "cal.noHinge"
    case calContinue = "cal.continue"
    case calDone = "cal.done"
    case looperTitle = "looper.title"
    case looperEmpty = "looper.empty"
    case looperRecording = "looper.recording"
    case looperOverdub = "looper.overdub"
    case looperSaving = "looper.saving"
    case looperExportFailed = "looper.exportFailed"
    case looperRecord = "looper.record"
    case looperStop = "looper.stop"
    case looperPlay = "looper.play"
    case looperExport = "looper.export"
    case midiTitle = "midi.title"
    case midiNoDestinations = "midi.noDestinations"
    case midiVirtualSource = "midi.virtualSource"
    case midiConnectMac = "midi.connectMac"
    case midiBluetooth = "midi.bluetooth"
    case midiNetwork = "midi.network"
    case midiConnected = "midi.connected"
    case paywallTitle = "paywall.title"
    case paywallHeadline = "paywall.headline"
    case paywallSubtitle = "paywall.subtitle"
    case paywallPurchase = "paywall.purchase"
    case paywallRestore = "paywall.restore"
    case paywallPending = "paywall.pending"
    case paywallOffline = "paywall.offline"
    case paywallLoading = "paywall.loading"
    case paywallPurchased = "paywall.purchased"
    case settingsTitle = "settings.title"
    case settingsBuffer = "settings.buffer"
    case settingsBufferLow = "settings.bufferLow"
    case settingsBufferNormal = "settings.bufferNormal"
    case settingsPitchBend = "settings.pitchBend"
    case settingsScale = "settings.scale"
    case settingsA4 = "settings.a4"
    case settingsHaptics = "settings.haptics"
    case settingsLeftHanded = "settings.leftHanded"
    case settingsLanguage = "settings.language"
    case settingsAbout = "settings.about"
    case commonClose = "common.close"
    case commonOK = "common.ok"
    case commonCancel = "common.cancel"
    case slotAngleGauge = "slot.angleGauge"
    case slotWaveform = "slot.waveform"
    case slotBellows = "slot.bellows"
    case slotFretboard = "slot.fretboard"
    case slotAntenna = "slot.antenna"
    case slotCrease = "slot.crease"
    case slotPaywallHero = "slot.paywallHero"
    case cardAccordion = "card.accordion"
    case cardGuitar = "card.guitar"
    case cardFilter = "card.filter"
    case cardTheremin = "card.theremin"
    case chordMajor = "chord.major"
    case chordMinor = "chord.minor"
    case chordA11yMajor = "chord.a11yMajor"
    case chordA11yMinor = "chord.a11yMinor"
    case instrumentChords = "instrument.chords"
    case instrumentMelody = "instrument.melody"
    case instrumentVolume = "instrument.volume"
    case instrumentPitch = "instrument.pitch"
    case instrumentRibbonHint = "instrument.ribbonHint"
    case guitarStrings = "guitar.strings"
    case guitarBend = "guitar.bend"
    case guitarStringA11y = "guitar.stringA11y"
    case filterCutoff = "filter.cutoff"
    case filterResonance = "filter.resonance"
    case filterSteps = "filter.steps"
    case filterStepA11y = "filter.stepA11y"
    case looperTrack = "looper.track"
    case looperTracksUsed = "looper.tracksUsed"
    case midiChannel = "midi.channel"
    case midiMapping = "midi.mapping"
    case paywallFeatureInstruments = "paywall.featureInstruments"
    case paywallFeatureMIDI = "paywall.featureMIDI"
    case paywallFeatureLoops = "paywall.featureLoops"
    case paywallOneTime = "paywall.oneTime"
    case calAngle = "cal.angle"
    case calStepOf = "cal.stepOf"
    case midiPitchBend = "midi.pitchBend"
    case settingsVersion = "settings.version"
    case settingsBundle = "settings.bundle"

    public func text(in language: AppLanguage) -> String {
        StringCatalog.text(for: rawValue, language: language)
    }
}

enum StringCatalog {
    private static let tables: [AppLanguage: [String: String]] = loadTables()

    static func text(for key: String, language: AppLanguage) -> String {
        if let value = tables[language]?[key], !value.isEmpty {
            return value
        }
        if language != .en, let english = tables[.en]?[key], !english.isEmpty {
            return english
        }
        return key
    }

    static func keys(in language: AppLanguage) -> Set<String> {
        Set(tables[language]?.keys.map { $0 } ?? [])
    }

    private static func loadTables() -> [AppLanguage: [String: String]] {
        var loaded: [AppLanguage: [String: String]] = [:]
        for language in AppLanguage.allCases {
            guard let url = resourceURL(for: language),
                  let data = try? Data(contentsOf: url),
                  let object = try? JSONDecoder().decode([String: String].self, from: data) else {
                continue
            }
            loaded[language] = object
        }
        return loaded
    }

    private static func resourceURL(for language: AppLanguage) -> URL? {
        let bundle = Bundle.module
        if let url = bundle.url(forResource: language.rawValue, withExtension: "json", subdirectory: "Locales") {
            return url
        }
        return bundle.url(forResource: language.rawValue, withExtension: "json")
    }
}
