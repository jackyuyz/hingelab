# HingeLab visual design spec (for Claude Design / Claude Code)

Foundation UI is **functional placeholders** with system styling. Do not treat current screens as visual direction. Replace placeholders in place; **do not change engine packages** (`Packages/Synth`, `HingeInput`, `Instruments`, `Looper`, `MIDIOut`, `Store`).

Consume every color, image, symbol, and animation through `ThemeProviding` (`Packages/ThemeKit`). Dropping in real assets should be a new theme + catalog files, not engine edits.

## Duo form-factor rules

Read **runtime** `DisplayMetrics` (point size, `displayScale`, safe areas). Never hardcode layout to these reference pixel sizes:

| Panel | Pixels | Orientation | Ratio | Where used |
|---|---|---|---|---|
| Inner unfolded | 2670 × 1878 | Landscape | ~1.42:1 | Design reference only (`DuoDisplaySpec.inner`) |
| Outer cover | 1398 × 2034 | Portrait | ~1:1.455 | Design reference only (`DuoDisplaySpec.outer`) |

Unknown (leave unset, do not invent): crease width, point sizes, `UIScreen.scale`. Layout uses `GeometryReader` + `@Environment(\.displayScale)` + safe-area insets.

**Crease:** `reservedRegions(kind: .division)` is active **only while half-folded** and empty on the first layout pass. Re-query. Slot: `CreaseGuideSlot` / a11y `slot.crease`.

**Postures** (`FoldPosture`):

| Posture | Layout | Notes |
|---|---|---|
| `partiallyOpen` | Two halves, `DuoSplitStack` (later `ArrangementView(.split)`). Horizontal like a book, vertical like a laptop (`settings.splitAxesHorizontal`). | Primary performance layout. Hinge drives sound. |
| `fullyOpen` | Full keyboard + hint `instrument.foldHint` (“Fold a little to play”). | Accordion still works from flat. |
| `closed` | Compact player on the outer cover (`instrument.coverTitle`). Hinge inactive; ribbon/tilt. MIDI may keep running. | Cover art must fit portrait cover safe area. |
| `noHinge` | Same instruments + side ribbon (`ribbon.slider`). | Reviewers and non-Duo. |

Touch targets for keys ≥ 60 pt. Left-handed swap mirrors halves (`settings.leftHanded`).

`ArrangementView` must sit in a `NavigationStack`, never in `List`/`ScrollView`. Keep the `TODO(verify-api)` comments if the SDK name differs — do not invent APIs.

## Direction

Playful lab-instrument: precision gauges + warm instrument textures on a dark stage. One hue per instrument (accordion red, guitar amber, filter cyan, theremin violet). SF Pro / SF Pro Rounded; monospaced digits for angle/BPM. Dynamic Type in Settings and Looper; instrument surfaces stay fixed-size with labels scaling up to a limit. Reduce Motion → static meters.

## Theming plug-in points

| Token / slot | Type | Code | Catalog / name |
|---|---|---|---|
| `ColorToken.stageBackground` | color | `ThemeProviding.color` | apply via `ThemeColor.swiftUI` |
| `ColorToken.accordionHue` etc. | color | same | per-instrument |
| `ImageSlot.appIcon` | 1024³ PNG | `Assets.xcassets/AppIcon.appiconset` | `AppIcon-1024.png` |
| `ImageSlot.accordionBellows` | image | `theme.imageAssetName(.accordionBellows)` | `placeholder.accordionBellows` → replace |
| `ImageSlot.guitarFretboard` | image | `slot.fretboard` | `placeholder.guitarFretboard` |
| `ImageSlot.thereminAntenna` | image | `slot.antenna` | `placeholder.thereminAntenna` |
| `ImageSlot.particleSpark` | image sequence or Lottie later | `AnimationSlot.foldParticle` | hinge-angle particles |
| `ImageSlot.angleGaugeFace` | image | `slot.angleGauge` | |
| `ImageSlot.waveformOverlay` | image | `slot.waveform` | |
| `ImageSlot.paywallHero` | image | `slot.paywallHero` | |
| `SymbolSlot.*` | SF Symbol or custom | `theme.systemImage` | keep identifiers |
| `AnimationSlot.bellowsPulse` | animation | visualizer | amplitude / velocity |
| `AnimationSlot.stringVibrate` | animation | strum pad | |
| `AnimationSlot.filterBloom` | animation | cutoff | |
| `AnimationSlot.thereminGlow` | animation | pitch + volume | |

Asset catalog names **must** match `theme.imageAssetName(_)` (default `placeholder.<slot>`). After adding real files, change `PlaceholderTheme.imageAssetName` or add `DesignedTheme` and inject it in `HingeLabApp`.

## Screens and states

### S1 Calibration (`CalibrationView`)
- `noHinge`: ribbon explanation (`cal.noHinge`).
- Steps 1–3: closed rest, open rest, confirm. Angle gauge slot live.
- Assets: none required beyond gauge face.

### S2 Instrument picker (`InstrumentPickerView`)
- Four cards (`picker.accordion` …). Locked cards show lock symbol + paywall.
- Cover (`closed`): compact player, accordion shortcut, looper, ribbon.
- Unfolded/half: 2-up grid. Inner landscape should feel like a wide lab bench, not a stretched iPhone list.
- App icon in chrome later; currently SF Symbol.

### S3 Instrument (`InstrumentPlayView` + per-instrument views)

Shared chrome: Looper / MIDI / Settings. Overlays: interrupted, headphones unplugged, no output, Bluetooth latency.

**Accordion**
- Left: chord grid (8, ≥60 pt) + `slot.bellows`. Velocity → bellows stripes.
- Right: 2×6 melody keys + gauge + waveform.
- Hint after 3 s of keys without flex (`instrument.bellowsHint`).
- Particles/stripes follow `HingeSample.velocityDegPerSec` and `value01`.

**Guitar**
- Left: 8-chord grid.
- Right: `slot.fretboard` + 6 strings (swipe) + bend readout `guitar.bend`.
- Hinge relative angle → pitch bend; dead zone ±0.5° holds center.

**Filter Sweep**
- Left: cutoff/res readouts `filter.cutoff`.
- Right: 8-step sequencer placeholder.
- Cutoff maps exponentially; visual “bloom” follows cutoff.

**Theremin**
- Left: volume slider `theremin.volume`.
- Right: `slot.antenna` + Hz `theremin.frequency`.
- Optional haptic ticks at quantized scale notes (Reduce Motion off).

### S4 Looper (`LooperView`)
States: empty, recording, overdub, saving, export failed. Track rows later (`LoopTrackRow`).

### S5 MIDI (`MIDIView`)
States: no destinations, connected, Bluetooth advertising. Do not request local-network/Bluetooth until this screen.

### S6 Paywall (`PaywallView`)
States: loading, offline, pending, purchased. Full is a one-time **$4.99** (`com.jackyu.hingelab.full`). **Never hardcode the price in UI strings** — use `StoreProduct.displayPrice` / StoreKit `ProductView`. Hero slot `slot.paywallHero`.

### S7 Settings (`SettingsView`)
Buffer 128/256, bend ±2/±12, scale, A4, haptics, left-handed, language (en / zh-Hans), restore, calibrate.

## Assets to produce

### App icon
- 1024 × 1024 PNG, no alpha, sRGB.
- Path: `App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- Add `"filename": "AppIcon-1024.png"` to `Contents.json`.
- Concept: hinge shaped like a musical note / bellows. Avoid dating-app “Hinge” branding.

### Instrument skins (PDF or PNG @1x/@2x/@3x — prefer PDF)
Use **point** sizes from runtime layout, not 2670 px. Suggested masters @3x of a ~half-pane:

| Asset | Suggested pixel master | Format | Catalog name |
|---|---|---|---|
| Bellows stripes | 1200 × 1800 | PDF/PNG | `placeholder.accordionBellows` |
| Accordion wood/skin | 1200 × 1800 | PDF | `placeholder.accordionSkin` |
| Guitar fretboard | 1200 × 1800 | PDF | `placeholder.guitarFretboard` |
| Guitar body skin | 1200 × 1800 | PDF | `placeholder.guitarSkin` |
| Filter panel | 1200 × 1800 | PDF | `placeholder.filterSkin` |
| Theremin antenna | 600 × 1800 | PDF | `placeholder.thereminAntenna` |
| Theremin panel | 1200 × 1800 | PDF | `placeholder.thereminSkin` |
| Gauge face | 512 × 512 | PDF | `placeholder.angleGaugeFace` |
| Waveform overlay | 1024 × 256 | PDF | `placeholder.waveformOverlay` |
| Spark particle | 128 × 128 | PNG (premultiplied) | `placeholder.particleSpark` |
| Paywall hero | 1600 × 1000 | PDF | `placeholder.paywallHero` |

Also produce **cover-compact** variants that read at ~5.4" portrait.

### Motion
- Bellows: fold count / stripe offset from `value01`.
- Particles: emit rate from `|velocity|`; freeze when Reduce Motion.
- Closing fully: 200 ms visual release matching audio release.

## Accessibility
VoiceOver labels on keys (“C major chord”). `.allowsDirectInteraction` on key surfaces. Color + label for state. zh-Hans: note names stay letters; chords like “C 大调”.

## What not to do
- Do not bake 2670×1878 or 1398×2034 into Auto Layout constants.
- Do not call `onHingeChange` / `reservedRegions` outside `HingeBridge` / `ReservedRegionProbe`.
- Do not add a backend, login, or analytics.
- No PNG mockups in `docs/` — live UI only.
