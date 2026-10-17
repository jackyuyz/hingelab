# HingeLab: Fold Instruments

A native iOS musical instrument for Apple’s iPhone Duo. Fold it like an accordion, bend notes like a guitar, sweep a filter, or play a theremin — and send MIDI to GarageBand or Logic.

Engine, mappings, StoreKit/MIDI scaffolds, the designed Duo UI (lab-instrument look, drawn and animated from the hinge), designed synth patches, built-in accordion reed samples, the app icon, and a real AVAudioEngine host.

## Project layout

```
hingelab/
├── project.yml                 # XcodeGen (regenerate the .xcodeproj on a Mac)
├── App/                        # SwiftUI host (thin)
│   ├── Picker/                 # Instrument picker (lab bench) + cover pocket player
│   ├── InstrumentViews/        # Accordion, Guitar, Filter, Theremin surfaces
│   ├── Design/                 # Stage components + vector instrument art
│   ├── Looper/ MIDI/ Calibration/ Paywall/ Settings/
│   ├── Shared/                 # HingeBridge, Duo layout, theme adapter
│   ├── Resources/Samples/      # Built-in accordion reed CAFs (looped, 48 kHz/24-bit)
│   └── Audio/                  # AVAudioEngine / StoreKit / CoreMIDI hosts, sample loader
├── Packages/                   # Platform-independent; `swift test` on Linux
│   ├── FoldKit/                # Fold state, mocks, -FoldMock, display spec (reference)
│   ├── HingeInput/             # Relative angle, velocity, calibration, ribbon
│   ├── Synth/                  # DSP + OfflineAudioEngine
│   ├── Instruments/            # Four instruments + pure mappings
│   ├── Looper/ MIDIOut/ Store/ SettingsKit/ ThemeKit/ HingeL10n/
├── Tests/  UITests/
├── Configuration.storekit
└── docs/
    ├── spec/hingelab-spec.md
    └── handoff/                # visual-design-spec, audio-design-spec, CLAUDE.md
```

## Building on a Mac

### Prerequisites

- Xcode with the **iOS 27** SDK (app `IPHONEOS_DEPLOYMENT_TARGET` is 27.0; hinge APIs are assumed 27.1)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Swift 6 (`swift test` for packages also works on Linux)

### Steps

```bash
git clone <repo-url>
cd hingelab
xcodegen generate
open HingeLab.xcodeproj
```

Select the `HingeLab` scheme. Point the Run scheme’s StoreKit configuration at `Configuration.storekit`.

### Package tests (Linux and macOS)

```bash
./scripts/test-packages.sh
```

Or per package:

```bash
cd Packages/FoldKit && swift test
cd Packages/HingeInput && swift test
cd Packages/Synth && swift test
cd Packages/Instruments && swift test
cd Packages/Looper && swift test
cd Packages/MIDIOut && swift test
cd Packages/Store && swift test
cd Packages/SettingsKit && swift test
cd Packages/ThemeKit && swift test
cd Packages/HingeL10n && swift test
```

### App / UI tests (Xcode)

```bash
xcodebuild test -scheme HingeLab -destination 'platform=iOS Simulator,name=iPhone Duo'
```

There is no official `simctl` hinge command. Use Device Hub (Closed / Open / Option-key slider) on the **iPhone Duo simulator**, or launch arguments:

```
-UITestMode 1 -FoldMock open
-UITestMode 1 -FoldMock closed
-UITestMode 1 -FoldMock half:90
-UITestMode 1 -FoldMock sweep:10-180:6
-UITestMode 1 -FoldMock nohinge
-FoldDebugOverlay 1
```

Scheme `HingeLab-MockHinge` has these pre-ticked.

## Integration status

`main` combines `cursor/hingelab-foundation-4b51` (`b1dfff4`) with
`claude/friendly-hamilton-hktvx6` (`b070495`). The Claude branch already
contains the complete Cursor history, including the confirmed $4.99 price.
The integration preserves both histories and the final accordion key layout.
It also fixes Swift 6 compilation of the StoreKit scaffold and spark drawing,
and gives the guitar ribbon test a Full entitlement and time for input smoothing.

This is a foundation plus design/audio build. Production hinge events and
reserved regions are still stubbed; the app uses `MockStore` and
`NullMIDISender`; live looper capture, playback, and sharing still need wiring.
The existing package tests cover these modules in isolation, not those missing
device integrations. Real audio latency and realtime allocation/locking behavior
still need hardware profiling.

## Architecture

All fold traffic goes through **FoldKit**. Nothing else calls `onHingeChange` / `UIHingeInteraction`. Crease layout goes through `CreaseRegionProviding` (real `reservedRegions(kind: .division)` is iOS 27.1, half-folded only). Display bounds, scale, and safe areas are read at runtime (`DisplayMetrics`); `DuoDisplaySpec` is a documented reference (inner 2670×1878 landscape ~1.42:1, outer 1398×2034) and is never used as layout constants.

**HingeInput** turns `FoldState` into `HingeSample` (calibrated 0…1, velocity, EMA, dead zone). Ribbon and tilt use the same 0…1.

**Synth** renders offline on Linux. On iOS, `AVAudioEngineHost` pulls the same `SynthBank` from an `AVAudioSourceNode` (allocation-free render path, unfair lock held for microseconds) and maps interruptions / route changes to `AudioSessionEvent`.

**ThemeKit** / **AudioAssetProviding** are how designed visuals and samples drop in without engine changes. `DesignedTheme` and `BuiltinAudioAssets` are injected in `HingeLabApp`.

## Design and sound

- **Look:** dark lab stage, ivory precision dials, one lacquer hue per instrument (accordion red, guitar amber, filter cyan, theremin violet). Tokens live in `DesignedTheme` (contrast-checked in tests). Instrument art is vector (`App/Design/`), driven by `HingeSample` through `InstrumentMotion` (tested on Linux); Reduce Motion freezes meters and sparks.
- **Icon:** `scripts/assets/AppIcon.svg` → `node scripts/render-icon.mjs` writes `AppIcon-1024.png` (no alpha) and the spark sprite.
- **Patches:** band-limited reed with a constant 1.25 Hz musette beat, six-string bendable Karplus-Strong, resonant SVF filter drone, shaped theremin with vibrato (`Packages/Synth/Sources/Synth/DesignedVoices.swift`).
- **Samples:** `python3 scripts/render-reed-samples.py` renders the four built-in reed roots (C3, G3, C4, G4) with seamless sustain loops in the CAF `mark` chunk and the root note in `inst`. `CAFCodec` (pure Swift) reads them on every platform.

## Unverified APIs

| API | Status | Fallback |
|---|---|---|
| `View.onHingeChange` / `UIHingeInteraction` | Confirmed in talks; `@available` assumed **iOS 27.1** | `MockFoldStateProvider`, `TODO(verify-api)` in `HingeBridge` |
| `reservedRegions(kind: .division)` | Confirmed; empty first pass; only while half-folded | `MockCreaseRegionProvider` |
| `ArrangementView` | Confirmed iOS 27.1 | `HStack`/`VStack` split |
| Hinge range / rate | Undocumented | Relative calibration + smoothing |
| BLE MIDI `CABTMIDILocalPeripheralViewController` on iOS 27 | Verify | MIDI screen scaffold only |
| “Which display am I on?” | Not found | `hinge.status == .closed` ⇒ outer (heuristic) |

## Open questions

Copied from the spec, plus foundation follow-ups:

1. Hinge sample rate and latency on device — accordion velocity smoothing if updates are sparse.
2. Does the hinge keep reporting in a two-handed book posture (no throttling)?
3. Bluetooth MIDI peripheral advertising on iOS 27 — still `CABTMIDILocalPeripheralViewController`?
4. Price **$4.99** (Jack confirmed; Notion had floated $3.99).
5. App Store bundle with FoldPlay later?
6. Measured xruns and hinge→audible latency on a Duo (the AVAudioEngine graph exists; not yet run on hardware). Looper capture still needs an output tap.
7. Point size / scale of inner and outer panels (still `DuoDisplaySpec.Assumption` = nil).

## Test results (macOS, Swift 6.4; 2026-10-16)

| Package | Tests | Status |
|---------|-------|--------|
| FoldKit | 47 | Pass |
| HingeInput | 9 | Pass |
| Synth | 21 | Pass |
| MIDIOut | 5 | Pass |
| SettingsKit | 6 | Pass |
| Instruments | 12 | Pass |
| Looper | 6 | Pass |
| Store | 10 | Pass |
| ThemeKit | 9 | Pass |
| HingeL10n | 8 | Pass |
| **Total** | **133** | **Pass** |

App verification with Xcode 27.1 on a dedicated iPhone Duo simulator (iOS 27.1):
**9 app unit tests and 5 UI tests passed**. UI tests use `-FoldMock` to check
half-folded instrument slots, the closed pocket player, the no-hinge ribbon,
launch, and Settings. These checks do not verify real hinge events or hardware
latency.

## License

Proprietary — all rights reserved.
