# HingeLab — Claude onboarding

You are taking over **visuals and sound** for HingeLab, a native iOS instrument that uses the iPhone Duo hinge. The foundation (engine, mappings, StoreKit/MIDI scaffolds, placeholder SwiftUI, tests) is already in this repo.

## What this app is

Four hinge instruments (Accordion free; Guitar / Filter / Theremin behind `com.jackyu.hingelab.full`), loop recorder, CoreMIDI out. No backend, no login, no analytics, no third-party SDKs.

## Read first

1. `docs/spec/hingelab-spec.md` — product + API facts. Anything **UNCONFIRMED** stays behind protocols / `TODO(verify-api):`.
2. `docs/handoff/visual-design-spec.md` — screens, postures, asset slots, Duo rules.
3. `docs/handoff/audio-design-spec.md` — samples, latency, how to plug into `Synth`.
4. `README.md` — build and test.

FoldCheck (`jackyuyz/foldcheck`) is the sibling Duo app. Copy **patterns**, not screens.

## Architecture (do not break)

```
Packages/                 # swift test on Linux — no SwiftUI / UIKit / AVAudioEngine required
  FoldKit                 # FoldState, mocks, -FoldMock parsing, DuoDisplaySpec (reference only)
  HingeInput              # relative angle, velocity, calibration, ribbon parity
  Synth                   # DSP + OfflineAudioEngine + AudioEngineControlling
  Instruments             # mappings + four instruments
  Looper / MIDIOut / Store / SettingsKit / ThemeKit / HingeL10n
App/                      # SwiftUI, XcodeGen project.yml
  Shared/HingeBridge.swift    # ONLY place for onHingeChange / UIHingeInteraction
  Shared/DuoLayout.swift      # ArrangementView + reservedRegions guards
  Audio/AVAudioEngineHost.swift
```

Platform-independent logic stays in packages. The app is a thin host.

## Where assets go

| Kind | Path | How code finds it |
|---|---|---|
| App icon | `App/Resources/Assets.xcassets/AppIcon.appiconset/` | Xcode app icon |
| Skins / gauges | `App/Resources/Assets.xcassets/` named as `ThemeProviding.imageAssetName` | `PlaceholderTheme` |
| Samples | `App/Resources/Samples/*.caf` | `AudioAssetProviding` |
| Copy | `Packages/HingeL10n/Sources/HingeL10n/Locales/{en,zh-Hans}.json` | `L10nKey` |

Add a `DesignedTheme: ThemeProviding` and inject it in `HingeLabApp` instead of editing every view.

## How to run tests

```bash
# Linux or Mac — required after every engine/mapping/theme-protocol change
./scripts/test-packages.sh

# One package
cd Packages/Synth && swift test
```

App / UI tests need Xcode 26+ and iOS 27 SDK:

```bash
brew install xcodegen
xcodegen generate
open HingeLab.xcodeproj
# Scheme HingeLab-MockHinge: -UITestMode 1 -FoldMock half:90
```

`-FoldMock` values: `nohinge`, `closed`, `open`, `half:<deg>`, `sweep:<from>-<to>:<seconds>`. DEBUG overlay: `-FoldDebugOverlay` (ids `fold.closed`, `fold.half`, `fold.open`, `fold.nohinge`, `fold.sweep`).

## What not to break

- **Never hardcode** Duo pixel sizes (2670×1878, 1398×2034) into layout. `DuoDisplaySpec` is documentation.
- **Never** call `onHingeChange` / `UIHingeInteraction` / `reservedRegions` outside the guarded app wrappers. If the SDK fails to compile, stop and leave `TODO(verify-api):` — do not invent names.
- **Never** map absolute hinge degrees to pitch/cutoff; use `HingeCalibration` + `HingeSample.value01`.
- Ribbon/tilt must keep **identical** `value01` results as the hinge (`HingeInputPipelineTests`).
- Keep `swift test` green on Linux. Don’t import AVFoundation/StoreKit/SwiftUI into packages.
- StoreKit: never hardcode `$3.99` in UI strings; use `displayPrice`. `.unverified` grants nothing.
- Privacy: Data Not Collected. No tracking. Local network / Bluetooth strings only on the MIDI screen.
- Accordion stays free; other instruments stay gated on `Entitlements.hasFull`.
- Audio-thread render: no allocations. Close-while-playing must not click (jump < 0.1).

## Suggested first visual/audio PR

1. App icon + `DesignedTheme` colors/symbols.
2. Replace `PlaceholderSlot` interiors (bellows, fretboard, antenna, gauge) without renaming a11y ids.
3. Accordion reed CAF files + `SampleVoice` behind `AudioAssetProviding`.
4. Then guitar KS excitation, filter drone, theremin patch.

Keep milestone order in the spec if you touch remaining engine gaps (real AVAudioEngine graph, CoreMIDI client, StoreKit `Transaction.updates`).
