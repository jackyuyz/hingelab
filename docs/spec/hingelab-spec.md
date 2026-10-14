# HingeLab: Implementation Spec (iOS)

> **Instructions for the coding agent**
> 1. Read this whole spec before writing any code, including §3 (fold-state matrix), §7 (edge cases), §8 (tests and acceptance criteria) and §11 (assumptions).
> 2. Implement strictly in the milestone order in §10. Finish each milestone's tests before starting the next one, and keep `main` buildable at every step.
> 3. Keep everything local and on-device: no backend, no server, no database beyond local files / SwiftData / UserDefaults, no login, no analytics or ad SDKs, no third-party networking.
> 4. Write unit tests alongside each module (not at the end). UI tests drive the app through the mockable `FoldStateProvider` and launch arguments described in §8.
> 5. Any API marked **UNCONFIRMED** in this spec must be wrapped in a runtime capability check with the fallback described next to it. Never call it unguarded, and never "fix" a compile error by inventing a different API name: stop and leave a `// TODO(verify-api):` note instead.
> 6. Use the hinge only for interactions and effects. Use size classes, `ArrangementView`, and reserved regions for layout (Apple's guidance).
> 7. Do not add a backend, login, cloud sync service, or remote config. If something seems to need one, stop and add it to §11 as an open question.

## 0. Header

| Field | Value |
|---|---|
| Project codename | **HingeLab** (Notion: "HingeLab 铰链乐器"; ideas doc §4.5) |
| Official App Store name | **HingeLab: Fold Instruments** (26 chars) |
| Subtitle | **Play music by folding** (21 chars) |
| Name check (US App Store, 2026-10-13) | No app named "HingeLab". Related: "Hinge" (the dating app) is a famous trademark. "HingeLab" is a distinct compound, but keep the dating brand in mind (low risk). Fallback: "FoldTone: Hinge Instruments". |
| Recommended repo | `hingelab-ios` |
| Bundle ID | `com.jackyu.hingelab` |
| Platform / min OS | iOS, iPhone only, **min iOS 27.0**; slider/tilt fallback without a hinge |
| Priority | **Low** |
| Target | ≈2.5 weeks |
| Overlap | **FoldCheck** (hinge diagnostics) and **FoldPlay** (G1–G3 reuse HingeLab mechanics) share `FoldKit` + `HingeInput`. HingeLab is the musical instrument; FoldCheck the inspector; FoldPlay the games. Keep the synth engine in a shared package (`Synth`) used by FoldPlay too. |

**Platform API status (checked 2026-10-13, ET).** Sources: Apple tech talks 111463 / 111464 / 111465 on developer.apple.com/videos (transcript summaries at wwdc.ai), Apple's "Prepare your app for iPhone Duo" page (developer.apple.com/iphone-duo/prepare/), Apple doc content for `UIHingeInteraction` and `onHingeChange` (developer.apple.com pages render with JavaScript, so their text was read through a doc mirror and the tech talks), and the Apple-engineer answers in the Sept 23–24 iPhone Duo Photos & Camera forum Q&A.

| API / fact | Status | Notes |
|---|---|---|
| `View.onHingeChange(isEnabled:_:)` → `(DeviceHingeContext, DeviceHingeContext)`; `context.hinge: DeviceHinge?`; `DeviceHinge.angle: Angle`; `DeviceHinge.status` ∈ `.closed / .partiallyOpen / .fullyOpen` | **Confirmed** | `hinge == nil` means no hinge (any non-Duo device). Exact `@available` version is assumed to be iOS 27.1: guard with `if #available(iOS 27.1, *)`. |
| `UIHingeInteraction(updateHandler:)`, `update.hinge` (`UIHinge`, angle in radians `CGFloat`, status includes extra `.unknown`) | **Confirmed** | `hinge` becomes nil when the interaction leaves a hierarchy that provides hinge updates. |
| Hinge angle range, update rate, precision | **Not documented** ("system policy") | Never map absolute angles to outcomes. Use relative angle from an anchor, plus a calibration step. Smooth between samples. |
| `ArrangementView { } secondary: { }`, `.arrangementViewStyle(.split)`, `.split.axes(.horizontal)`, `.overlay`, `@Environment(\.overlayArrangementZIndex)`; UIKit `UIArrangementViewController` | **Confirmed** (iOS 27.1) | Put it inside a `NavigationStack`, never inside `List` / `ScrollView`. |
| `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`, kinds `.division` (fold) and `.occlusion` (cameras), option `.includeInactive`; `UIView.reservedRegions(kind:options:)` | **Confirmed** | The fold region is active only while the device is partially folded and has zero width when flat. Reported to be empty on the first layout pass, so re-query with `onGeometryChange`. |
| `.sceneAccessory { CameraCaptureAccessory(isEnabled:) { … } .onAvailabilityChange { } }`; UIKit `UISceneAccessory.cameraCapture(sceneConfiguration:userInfo:)` + `registerSceneAccessory(_:)` | **SwiftUI confirmed**; UIKit names are from a third-party write-up (**verify**) | Available only while the app is full screen on the inner display, in the foreground, with an active capture session (an `ARSession` also qualifies). Goes away when the device closes. Whether accessory views receive touches is **UNCONFIRMED**: treat them as display-only. |
| Non-camera scene accessories for third parties (outer display UI without a camera session) | **UNCONFIRMED / not available as far as public docs show** | Don't design around it. |
| `.builtInOuterUltraWideCamera`, `.builtInInnerUltraWideCamera`, Virtual Front Camera (position `.front`), `AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)`, `AVCaptureDeviceDescriptor`, `AVCaptureDevice.dynamicAspectRatio`, `AVCaptureDeviceRotationCoordinator`, `AVCapturePhotoOutput.isCameraSensorOrientationCompensationEnabled` | **Confirmed** (tech talk 111465) | Inner camera: 1080p up to 60 fps. Outer front: up to 4K/120. The inner camera is unavailable while closed. Ask the direction coordinator; don't infer from the hinge. |
| `AVCaptureMultiCamSession` on Duo | **Confirmed in principle** (Apple engineer: up to 3 physical cameras) | Specific combinations: **runtime only** via `AVCaptureMultiCamSession.isMultiCamSupported` and `AVCaptureDevice.DiscoverySession.supportedMultiCamDeviceSets`. |
| New windows on the outer display | **Not allowed** | Use `UIWindowSceneActivation` for new-window UI; it hides itself when unavailable. Handle scene-request errors. |
| A public "which display am I on" API | **Not found** | For layout use size/traits. For cameras use the direction coordinator. For behavior, treat `hinge.status == .closed` as "on outer display" (heuristic, **verify on device**). |
| Background hinge events / lifetime fold count | **Not found** | Count only while the app is in the foreground. |
| Simulator posture control from CLI | **No official command** (`simctl` has no posture/hinge subcommand) | Device Hub UI has Closed / Open / Rotate buttons and an Option-key hinge slider. The third-party `hinge` CLI (github.com/artemnovichkov/hinge) uses a private protocol. Use it for local experiments only, never in CI gates. |

**HingeLab-specific notes:** Apple itself demoed "hinge angle → guitar pitch bend" in tech talk 111464, so the direction is sanctioned. **Latency is the risk:** the end-to-end hinge → sound latency must be measured on device (target ≤ 30 ms audio path + unknown hinge update interval). Use relative angles and calibration; smooth with parameter ramps in the audio thread to avoid zipper noise when samples are sparse.

## 1. PRD background

**Positioning:** Your iPhone Duo is a musical instrument. Squeeze it like an accordion, bend notes like a guitar, sweep a filter like a DJ, or play a theremin, and send it all as MIDI to GarageBand or Logic.

**Target users:** music hobbyists and producers with a Duo; performers wanting a novel expressive controller; casual users who want a fun "wow" demo; music teachers.

**Pain point / demand evidence:** novelty-driven product. Apple's own demo (https://wwdc.ai/iphone-duo/111464); foldable novelty apps (Protractor, Hinge Guess https://github.com/erkamyaman/hinge-guess, Kami https://www.androidauthority.com/kami-foldable-phone-game-3632416/) show interest; Reddit: users asking what apps they want for the Duo (https://www.reddit.com/r/iPhoneFold/comments/1wl52zm/, r/iPhoneFold 1wckyrj developer asks needs); the DS-fold nostalgia in the same thread. The ideas doc rates HingeLab/FoldPlay as "novel, easy press, good for brand lead generation" (32 pts).

**Selling points:** (1) four instruments built around the hinge; (2) real expressive MIDI controller (CC, pitch bend, notes) to any CoreMIDI app; (3) loop recorder; (4) low latency; (5) offline, private, no account.

**Pricing:** Free: Accordion + loop recorder (1 loop), no MIDI. **HingeLab Full, one-time $4.99**: all instruments (Pitch-Bend Guitar, Filter Sweep, Theremin), MIDI out, 8-track loops, export audio. (Jack confirmed $4.99; an earlier impulse-price idea was $3.99.)

**Success metrics:** 5,000 downloads in 60 days; ≥5% conversion; ≥4.5★; press mentions; MIDI users ≥ 15% of paid (local counter only).

## 2. MVP scope

| ID | Feature | Detail |
|---|---|---|
| F1 | Calibration | Same 3-step flow as FoldPlay (shared `HingeCalibration` component; stored per app). |
| F2 | **Accordion** (free) | Hinge **velocity** (open/close speed) drives bellows pressure → amplitude; buttons on the two halves play chords (left) and melody keys (right, 2 rows × 6). Direction change produces a subtle articulation. Reeds via a sample-based or additive synth (2–3 oscillators detuned "musette"). |
| F3 | **Pitch-Bend Guitar** | Strum/pluck chords on the right half (6 strings, swipe), hinge relative angle = pitch bend (±2 semitones default, ±12 option), the left half picks chords (grid of 8). Karplus-Strong plucked string synthesis. |
| F4 | **Filter Sweep** | A step sequencer/drone; the hinge angle maps to a low-pass cutoff (exponential mapping), velocity to resonance spikes; tempo + key controls. |
| F5 | **Theremin** | Continuous pitch from the hinge angle (scale quantization optional: off / chromatic / major / minor / pentatonic), volume by touch pressure-area or a hold slider on the other half; vibrato from device motion (optional). |
| F6 | Loop recorder | Record instrument output into loops (AVAudioEngine tap), overdub, 1 loop free / 8 Pro, tempo-sync, export M4A/WAV (ShareLink, Files). |
| F7 | **MIDI out** (Pro) | CoreMIDI virtual source "HingeLab" + network session (`MIDINetworkSession`) for Mac. Mappings: hinge → CC1/CC11/CC74 or pitch bend (14-bit), keys → notes; MIDI channel; MPE off in MVP. Bluetooth MIDI via `CABTMIDILocalPeripheralViewController` (advertise). |
| F8 | Visual feedback | Angle gauge, waveform/spectrum mini-scope, note names. |
| F9 | Paywall, Settings | Pro; audio buffer size (Low latency 128 / Normal 256), pitch-bend range, scale, A4 tuning, haptics, left-handed swap, calibration. |

**Non-goals:** full DAW; AUv3 plug-in (post-MVP); Audio Unit hosting; MPE; online sharing; samples downloaded from servers.

**Backlog:** AUv3 MIDI processor extension; MPE; more instruments (harmonica "breath" via mic? no, keep hinge), duet over local network, Ableton Link (license required; check).

## 3. Fold-state behavior matrix

| State | Behavior |
|---|---|
| `partiallyOpen` | **Primary.** Two halves = two control surfaces (`ArrangementView(.split)`, horizontal axes when the device is held like a book, vertical when held like a laptop; user can toggle). Hinge drives the instrument. |
| `fullyOpen` | Instruments use the hinge at the "open end" of the range. Accordion still works (flexing from flat). The screen shows the full keyboard; a hint "Fold a little to play". |
| `closed` | Outer screen: compact player/looper; hinge input inactive; slider/tilt mode offered; MIDI keeps running (sends nothing from the hinge). |
| Transitions | Sound continues smoothly (ramp parameters 20 ms); closing fully during play triggers a gentle release (no click). |
| Rotation | Layouts adapt; instrument mappings stay. |
| Split View | Works with compact layout; hinge input allowed when the hinge context is delivered. |
| `noHinge` | Slider (vertical ribbon on one side) or tilt replaces the hinge; full functionality (great for review and for non-Duo users as a "ribbon synth"). |
| iPad compat | Same as noHinge. |

## 4. Flows and screens

Root: Instrument picker (4 cards) → Instrument screen (full-screen) with a top bar: Looper, MIDI, Settings.

| Screen | States |
|---|---|
| S1 Calibration | as FoldPlay; noHinge → ribbon explanation |
| S2 Instrument picker | locked cards |
| S3 Instrument | playing; audio session interrupted (call/Siri) → muted overlay; **audio route change** (headphones unplugged → pause output for safety); **no audio output available**; latency warning (Bluetooth headphones: "Bluetooth adds delay, use wired or built-in speaker") |
| S4 Looper | empty; recording; overdub; saving; export failed |
| S5 MIDI | no destinations (explain virtual source + "Connect to Mac"); connected; Bluetooth MIDI advertising |
| S6 Paywall | loading; offline; pending; purchased |
| S7 Settings | — |

Offline: fully offline. Local network permission is only needed for network MIDI (`NSLocalNetworkUsageDescription`), requested only when the user opens network MIDI.

## 5. UI / design brief

- **Direction:** a playful lab-instrument aesthetic: precision gauges plus warm instrument textures (accordion bellows stripes, guitar fretboard, theremin antenna). A dark stage background makes performance views glow.
- **Layout:** each half is a control surface; the hinge line visually echoes the instrument (bellows folds; guitar nut). Respect `reservedRegions`. Big touch targets (≥ 60 pt for keys).
- **Components:** BellowsVisualizer, ChordGrid, StringStrumPad, Ribbon (fallback), AngleGauge, Scope, LoopTrackRow, MIDIStatusPill.
- **Type:** SF Pro / SF Pro Rounded; monospaced digits for angle/BPM; Dynamic Type in settings and looper; instrument surfaces fixed-size with labels scaling up to a limit.
- **Color:** one hue per instrument (accordion red, guitar amber, filter cyan, theremin violet) over dark; dark and light modes for non-performance screens.
- **Motion:** visualizers follow audio; Reduce Motion → static meters.
- **Accessibility:** VoiceOver labels on keys ("C major chord"), audio feedback is inherent; haptic tick at scale notes in theremin (option); Switch Control can trigger keys; color + label for state.
- **Localization:** en + zh-Hans (note names stay letter names; zh-Hans uses "C 大调").
- **Screenshots:** half-open Duo as an accordion; guitar bend with an angle gauge; MIDI to a Mac DAW (generic screen); looper. **Icon:** a hinge shaped like a musical note/bellows.

## 6. Technical architecture

**Stack:** Swift 6, SwiftUI, AVAudioEngine with `AVAudioSourceNode` (real-time synth render blocks in Swift with no allocations/locks; or C for the DSP core if Swift realtime safety is a concern), CoreMIDI, CoreAudioKit (BLE MIDI UI), Core Haptics, CoreMotion (tilt fallback), StoreKit 2, FoldKit. No AudioKit dependency in MVP (keep zero third-party deps; AudioKit is MIT and acceptable later).

All fold logic goes through one small local Swift package, **`FoldKit`**. It's the same package in every iOS project in this portfolio: copy it in as `Packages/FoldKit`. Nothing else in the app may call `onHingeChange` / `UIHingeInteraction` directly.

```swift
// Packages/FoldKit/Sources/FoldKit/FoldState.swift
import SwiftUI
import Observation

public enum FoldPosture: String, Codable, Sendable, CaseIterable {
    case noHinge        // non-Duo iPhone, iPad, Mac ("Designed for iPad"), or hinge context unavailable
    case closed         // folded; app is (assumed) on the outer display
    case partiallyOpen  // flexed / half-folded (laptop, book, tent… system does not tell which)
    case fullyOpen      // flat; app on inner display
    case unknown        // UIKit `.unknown`, or transient states
}

public struct FoldState: Equatable, Sendable {
    public var posture: FoldPosture
    /// Degrees exactly as reported by the system. `nil` when there is no hinge.
    /// The range is NOT documented. Never compare to absolute thresholds without calibration.
    public var angleDegrees: Double?
    public var timestamp: Date
    public init(posture: FoldPosture, angleDegrees: Double?, timestamp: Date = .now) {
        self.posture = posture; self.angleDegrees = angleDegrees; self.timestamp = timestamp
    }
    public static let noHinge = FoldState(posture: .noHinge, angleDegrees: nil, timestamp: .distantPast)
    public var hasHinge: Bool { posture != .noHinge }
}

@MainActor
public protocol FoldStateProvider: AnyObject, Observable {
    var state: FoldState { get }
    /// Yields the current value immediately, then every change.
    func states() -> AsyncStream<FoldState>
}

/// Production provider. Fed by `HingeBridge`, attached once at the root of every scene.
@MainActor @Observable
public final class SystemFoldStateProvider: FoldStateProvider { /* stores state, fans out to continuations */ }

/// Test / preview / UI-test provider. Driven by code or by launch arguments (see §8).
@MainActor @Observable
public final class MockFoldStateProvider: FoldStateProvider {
    public func set(_ posture: FoldPosture, angle: Double? = nil)
    public func play(_ script: [FoldScriptStep]) async   // e.g. sweep 180→0 over 2 s at 30 Hz
}

public struct HingeBridge: ViewModifier {
    let provider: SystemFoldStateProvider
    public func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {                     // availability version assumed. Verify in Xcode 27.1
            content.onHingeChange { _, ctx in provider.ingest(ctx.hinge) }   // maps DeviceHinge → FoldState
        } else {
            content.onAppear { provider.ingestNoHinge() }
        }
    }
}

/// Converts noisy absolute angles into a stable 0…1 control value.
public struct RelativeAngleTracker: Sendable {
    public var anchorDegrees: Double?             // set when the interaction starts
    public var observedMin: Double, observedMax: Double   // learned during calibration
    public var smoothing: Double = 0.25           // EMA factor; animate between samples
    public mutating func begin(at degrees: Double)
    public mutating func update(_ degrees: Double) -> Double     // returns normalized progress 0…1
    public mutating func delta(_ degrees: Double) -> Double       // signed degrees since anchor
    public mutating func reset()
}
```

Rules:
- `DeviceHinge.status` mapping: `.closed → .closed`, `.partiallyOpen → .partiallyOpen`, `.fullyOpen → .fullyOpen`, `@unknown default → .unknown`. A `nil` hinge maps to `.noHinge`.
- Inject the provider through the SwiftUI environment: `@Environment(\.foldState)`. Feature code depends on the `FoldStateProvider` protocol, never on the concrete class.
- Launch argument `-FoldMock <value>` swaps in `MockFoldStateProvider`. Values: `nohinge`, `closed`, `open`, `half:<deg>`, `sweep:<from>-<to>:<seconds>`, `script:<bundled-json-name>`. It is only honored in DEBUG builds or when `-UITestMode 1` is present.
- Every hinge-driven interaction must also have a non-hinge control (slider, buttons, drag, or tilt) with identical results. This covers non-Duo devices, VoiceOver users, and App Review on devices without a hinge.

**Modules:** `FoldKit`; `HingeInput` (shared with FoldPlay; value01, velocity, filtered, calibration); `Synth` (voices: reed, Karplus-Strong, subtractive filter, theremin sine/triangle; parameter smoothing; lock-free parameter ring buffer from main → audio thread); `Instruments` (Accordion, PitchBendGuitar, FilterSweep, Theremin: map inputs → synth params + MIDI events); `Looper` (AVAudioEngine tap → circular buffers → file export); `MIDIOut` (virtual source, network session, BLE advertise, mapping); `Store`; `App`.

**Key types:**
```swift
enum InstrumentID: String, CaseIterable, Codable { case accordion, pitchBendGuitar, filterSweep, theremin; var isFree: Bool { self == .accordion } }
struct InstrumentParams: Equatable { var pitchBendSemitones: Double; var amplitude: Double; var cutoffHz: Double; var resonance: Double; var frequencyHz: Double? }
protocol Instrument: AnyObject { static var id: InstrumentID { get }; func handle(_ sample: HingeSample); func noteOn(_ n: UInt8, velocity: UInt8); func noteOff(_ n: UInt8); var params: InstrumentParams { get } ; var midiEvents: AsyncStream<MIDIEvent> { get } }
enum MIDIEvent: Equatable { case noteOn(ch: UInt8, note: UInt8, vel: UInt8), noteOff(ch: UInt8, note: UInt8), cc(ch: UInt8, number: UInt8, value: UInt8), pitchBend(ch: UInt8, value14: UInt16) }
struct MIDIMapping: Codable, Equatable { var hingeTarget: HingeTarget /* .pitchBend, .cc(UInt8) */; var channel: UInt8; var range: ClosedRange<Double> }
struct Loop: Codable, Identifiable { var id: UUID; var fileName: String; var bars: Int; var bpm: Double; var createdAt: Date }
```
Mapping functions are pure and unit-tested (e.g., `pitchBend(value01:range:) -> UInt16`, `cutoff(value01:) -> Hz` exponential).

**Audio session:** `.playback` with `.mixWithOthers` option off by default (`.playAndRecord` not needed: no mic); preferred IO buffer 128 frames (≈2.7 ms @48 kHz) in Low latency mode; handle interruptions and route changes.

**Persistence:** settings + mappings + calibration in UserDefaults; loops in Application Support/Loops.

**Permissions:** `NSLocalNetworkUsageDescription` (network MIDI only): "HingeLab can send MIDI to music apps on your Mac over your local network." / "HingeLab 可以通过局域网把 MIDI 发送到你 Mac 上的音乐 App。" + `NSBonjourServices` `_apple-midi._udp`. `NSBluetoothAlwaysUsageDescription` (Bluetooth MIDI advertising): "HingeLab can appear as a Bluetooth MIDI instrument for your other devices." / "HingeLab 可以作为蓝牙 MIDI 乐器连接你的其他设备。" No mic, camera, location.

Privacy stance: **no tracking, no data collection off-device.** App Store privacy label: **Data Not Collected.** No third-party SDKs. No `NSUserTrackingUsageDescription`, no ATT prompt.

Base `PrivacyInfo.xcprivacy` (add a required-reason entry only for APIs the app actually touches. The reason codes below are Apple's published codes; re-check against the current list when submitting):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyTrackingDomains</key><array/>
  <key>NSPrivacyCollectedDataTypes</key><array/>
  <key>NSPrivacyAccessedAPITypes</key><array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array>
    </dict>
    <!-- add FileTimestamp (C617.1) if you read file modification dates in the app container -->
    <!-- add DiskSpace (E174.1) if you check free space before writing large files -->
  </array>
</dict></plist>
```
Widget / app extensions get their own copy of the manifest.
HingeLab entries: UserDefaults CA92.1, FileTimestamp C617.1 (loops list).

**StoreKit:** `com.jackyu.hingelab.full` non-consumable $4.99.
StoreKit 2 implementation (shared pattern, `Store` module):
- `@MainActor @Observable final class Store`: loads products with `Product.products(for:)`, starts a `Transaction.updates` listener at launch, and recomputes entitlements from `Transaction.currentEntitlements`. Every `VerificationResult` is checked; `.unverified` grants nothing.
- Purchase: `product.purchase()`. Handle `.success(.verified)` (then `transaction.finish()`), `.pending` (Ask to Buy / SCA: show a "Waiting for approval" state), and `.userCancelled` (silently return).
- Restore: a "Restore Purchases" button calls `AppStore.sync()`. Also show it in Settings.
- Refunds / revocation: a transaction with `revocationDate != nil` removes the entitlement immediately (next launch at the latest).
- Family Sharing: enable it in App Store Connect for the non-consumable unlock(s). The code doesn't change.
- Offline: cache the last computed entitlement set in `UserDefaults` only to avoid a paywall flash, and always re-verify when `currentEntitlements` arrives.
- The paywall uses SwiftUI `ProductView` / `StoreView` where it fits (it localizes prices automatically). Never hardcode prices in UI strings.
- Local testing: a `Configuration.storekit` file in the repo, selected in the Run scheme. Unit tests use `StoreKitTest.SKTestSession` (purchase, Ask-to-Buy, refund, expire, failure).

**Project tree:**
```
hingelab-ios/
├─ HingeLab.xcodeproj
├─ App/ (Picker/, InstrumentViews/{Accordion,Guitar,Filter,Theremin}, Looper/, MIDI/, Calibration/, Paywall/, Settings/)
│  ├─ Resources/ Localizable.xcstrings, Assets.xcassets, Samples/*.caf (if used)
│  ├─ Info.plist, PrivacyInfo.xcprivacy
├─ Packages/ FoldKit/ HingeInput/ Synth/ Instruments/ Looper/ MIDIOut/ Store/
├─ Tests/ UITests/
└─ Configuration.storekit
```

## 7. Edge cases

- Sparse hinge updates → audio-thread parameter smoothing (one-pole, 10–30 ms); velocity estimate clamps outliers.
- Hinge jitter at rest → dead-zone (±0.5°) on pitch bend; theremin quantization option.
- Accordion with no movement → silence (as a real accordion); show a hint after 3 s of key presses without flexing.
- Closing fully while notes sound → release envelope 200 ms; no click.
- Audio interruptions (calls, Siri, alarms) → stop engine, resume on `.ended` with `shouldResume`.
- Headphones unplugged → stop output (Apple guidance); Bluetooth latency warning.
- Silent switch → `.playback` plays anyway (it's an instrument; documented).
- Sample-rate changes (route to 44.1 kHz device) → rebuild engine graph.
- CPU overload (xruns) → auto increase buffer to 256 and show a toast.
- MIDI: no destinations → virtual source still exists; network session disabled until permission; mappings persisted.
- Pitch-bend 14-bit clamp and center on release.
- Looper: memory cap (5 min per loop), disk full on export → error.
- Left-handed swap mirrors halves.
- VoiceOver users: instruments playable via touch exploration with direct-touch traits (`.allowsDirectInteraction`) on key areas.
- StoreKit refund → instruments lock; loops remain playable.

## 8. Testing plan

How to simulate fold states and hinge angles:
1. **Unit tests (fast, CI):** inject `MockFoldStateProvider`. Drive `set(.closed)`, `set(.partiallyOpen, angle: 95)`, `set(.fullyOpen)`, `set(.noHinge)` and scripted sweeps, and assert on view-model state. No simulator posture needed.
2. **UI tests (XCUITest, CI):** launch with `-UITestMode 1 -FoldMock <value>`. A hidden DEBUG-only "Fold debug" overlay (toggled with `-FoldDebugOverlay 1`) exposes buttons with accessibility identifiers `fold.closed`, `fold.half`, `fold.open`, `fold.nohinge`, `fold.sweep`, so a UI test can change the mocked posture mid-flow. Mocking changes hinge signals only. It does **not** resize the window.
3. **Real layout changes (manual or semi-automated):** run on the **iPhone Duo simulator** (Xcode 27.1, Device Hub). Use the Closed / Open / Rotate buttons, and hold Option for the hinge-angle slider. This is the only official way to test true outer↔inner resizing, reserved regions, and split view. `simctl` has no posture command.
4. **Optional local helper:** the third-party `hinge` CLI (`hinge 120`, `hinge sweep 180 0 2`) sets the simulator hinge through a private, undocumented protocol. Use it for local exploration only, and never make a CI gate depend on it.
5. **Non-Duo fallback:** run the same UI tests on an iPhone 17/18 simulator with `-FoldMock nohinge`, and without any mock, to verify `hinge == nil` handling.

**Unit:** mapping functions (pitch bend, cutoff, theremin frequency with/without quantization; calibrations); accordion pressure from velocity; Karplus-Strong deterministic output for a seed (golden RMS/peak tests); parameter smoothing (no step > threshold between buffers); MIDI encoding (bytes of note/CC/14-bit bend); looper buffer logic; Store gating.

**Offline audio render tests:** use `AVAudioEngine.enableManualRenderingMode(.offline…)` to render 1 s of each instrument with a scripted hinge sweep → assert non-silent, no clipping (peak < 0 dBFS), no NaNs, spectral centroid rises with cutoff sweep.

**UI tests:** `-UITestMode 1 -FoldMock half:90` → accordion screen, `sweep` script → level meter accessibility value > 0; `-FoldMock nohinge` → ribbon present; MIDI screen shows "HingeLab" virtual source state; paywall gating.

**Real device needed:** hinge → sound latency (record the click of a fast close and the sound with an external mic; measure), hinge update rate, ergonomics of each instrument, BLE MIDI with a Mac, network MIDI.

**Acceptance criteria:**
- AC1: On device, median hinge-movement-to-audible-change latency ≤ 50 ms (method: high-speed video + audio), with Low latency buffer.
- AC2: Offline render tests pass for all 4 instruments (non-silent, no clipping, no NaN).
- AC3: Pitch bend maps the calibrated range to the configured ±N semitones within ±5 cents at both ends and center.
- AC4: MIDI out: a Mac running Logic/GarageBand receives notes, CC74, and 14-bit pitch bend from HingeLab via network MIDI and BLE MIDI (manual).
- AC5: `noHinge` ribbon mode gives full functionality for all instruments.
- AC6: Closing the device while playing produces no click (render test with a scripted close → no sample-to-sample jump > 0.1).
- AC7: Free = Accordion + 1 loop; Full unlock immediate (StoreKit test).
- AC8: Audio interruption and route change are handled (simulated notifications in tests).
- AC9: en + zh-Hans complete; VoiceOver labels for every key.

## 9. App Store review risks

| Risk | Mitigation |
|---|---|
| Reviewer without a Duo | Ribbon/tilt fallback; Review Notes. |
| 4.2 novelty only | Four instruments, MIDI controller, looper: substantive. |
| Bluetooth/local network permission rationale | Requested only on the MIDI screen with precise strings. |
| Name similarity to "Hinge" dating app (trademark) | "HingeLab" is descriptive of the hinge; avoid dating-like branding; fallback name ready. |

## 10. Milestones

| # | Milestone | Tasks | Est. |
|---|---|---|---|
| M0 | Latency spike | Hinge update rate in the simulator; AVAudioSourceNode prototype with a scripted sweep; buffer settings | 0.5 d |
| M1 | Skeleton | FoldKit, HingeInput (shared with FoldPlay), Synth scaffolding, picker, settings, CI | 1.5 d |
| M2 | Accordion | Reed synth, bellows mapping, buttons, visualizer (AC2 partial) | 2 d |
| M3 | Guitar + Theremin | Karplus-Strong, strum pad, chord grid, theremin + quantization (AC3) | 2.5 d |
| M4 | Filter Sweep | Sequencer, filter mapping | 1 d |
| M5 | Looper | Record/overdub/export | 1.5 d |
| M6 | MIDI | Virtual source, network session, BLE, mappings (AC4) | 1.5 d |
| M7 | Store + polish | Paywall, a11y, zh-Hans, screenshots | 1.5 d |
| M8 | Device tuning | Latency measurement (AC1), ergonomics | 0.5 d |
| | **Total** | | **≈12.5 dev-days** |

## 11. Open questions & assumptions

1. Hinge sample rate and latency on device: if updates are slow (< 30 Hz), the accordion velocity model needs heavier smoothing.
2. Does the hinge report while the user holds the device in a book posture with both hands moving it rhythmically (no throttling)?
3. Bluetooth MIDI peripheral advertising on iOS 27 (CoreAudioKit view controller still supported?). Verify.
4. Price **$4.99** (Jack confirmed 2026-10-14). Earlier $3.99 impulse idea is retired.
5. Should HingeLab and FoldPlay be bundled (App Store app bundle)? Possible after both ship.


---
*Spec version 1.0 · 2026-10-13 · Prepared for Jack Yu. API facts were checked against Apple developer sources on that date (see the API status table). Items marked UNCONFIRMED or "verify" must be validated in M0 or on a real device.*
