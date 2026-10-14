# HingeLab: Fold Instruments

A native iOS musical instrument for Apple’s iPhone Duo. Fold it like an accordion, bend notes like a guitar, sweep a filter, or play a theremin — and send MIDI to GarageBand or Logic.

Foundation only: engine, mappings, StoreKit/MIDI scaffolds, Duo-aware placeholder UI, and handoff specs for Claude (visuals + sound). **No final artwork or sample library in this tree.**

## Project layout

```
hingelab/
├── project.yml                 # XcodeGen (regenerate the .xcodeproj on a Mac)
├── App/                        # SwiftUI host (thin)
│   ├── Picker/                 # Instrument picker + cover compact player
│   ├── InstrumentViews/        # Accordion, Guitar, Filter, Theremin placeholders
│   ├── Looper/ MIDI/ Calibration/ Paywall/ Settings/
│   ├── Shared/                 # HingeBridge, Duo layout, theme adapter
│   └── Audio/                  # AVAudioEngine / StoreKit / CoreMIDI hosts
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
xcodebuild test -scheme HingeLab -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
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

## Architecture

All fold traffic goes through **FoldKit**. Nothing else calls `onHingeChange` / `UIHingeInteraction`. Crease layout goes through `CreaseRegionProviding` (real `reservedRegions(kind: .division)` is iOS 27.1, half-folded only). Display bounds, scale, and safe areas are read at runtime (`DisplayMetrics`); `DuoDisplaySpec` is a documented reference (inner 2670×1878 landscape ~1.42:1, outer 1398×2034) and is never used as layout constants.

**HingeInput** turns `FoldState` into `HingeSample` (calibrated 0…1, velocity, EMA, dead zone). Ribbon and tilt use the same 0…1.

**Synth** renders offline on Linux. The iOS host (`AVAudioEngineHost`) is a scaffold around the same `AudioEngineControlling` protocol.

**ThemeKit** / **AudioAssetProviding** are how designed visuals and samples drop in without engine changes.

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
6. Real `AVAudioEngine` graph + measured xruns on Duo (placeholder engine is offline-capable only until the Mac host is filled in).
7. Point size / scale of inner and outer panels (still `DuoDisplaySpec.Assumption` = nil).

## Test results (Linux, Swift 6.4.1)

| Package | Tests | Status |
|---------|-------|--------|
| FoldKit | 47 | Pass |
| HingeInput | 9 | Pass |
| Synth | 9 | Pass |
| MIDIOut | 5 | Pass |
| SettingsKit | 6 | Pass |
| Instruments | 11 | Pass |
| Looper | 6 | Pass |
| Store | 10 | Pass |
| ThemeKit | 1 | Pass |
| HingeL10n | 4 | Pass |
| **Total** | **108** | **Pass** |

App unit tests (`Tests/HingeLabTests.swift`) and UI tests need Xcode.

## License

Proprietary — all rights reserved.
