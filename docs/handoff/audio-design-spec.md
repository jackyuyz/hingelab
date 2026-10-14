# HingeLab audio design spec (for Claude)

Foundation uses a **placeholder sine / additive reed / Karplus-Strong / subtractive / theremin** synth in `Packages/Synth`. Real samples and patches plug in through `AudioAssetProviding` + `SynthRendering` without changing mapping or MIDI.

## Latency budgets

| Path | Budget | Notes |
|---|---|---|
| Audio IO buffer (Low) | 128 frames ≈ 2.7 ms @ 48 kHz | `AudioBufferMode.lowLatency` |
| Audio IO buffer (Normal) | 256 frames | Auto after xruns |
| Parameter ramp | 10–30 ms one-pole | `AudioConstants.parameterRampSeconds` (20 ms) |
| Close-while-playing release | 200 ms | `AudioConstants.closeReleaseSeconds` |
| End-to-end hinge → audible | ≤ 50 ms median on device (AC1) | Measure with high-speed video; unknown hinge interval |
| Bluetooth headphones | warn, don’t optimize | Overlay `instrument.bluetooth` |

No allocations/locks in the render block. Main thread publishes `VoiceParams` via `ParameterMailbox`; audio thread only `load()`s.

## Engine plug-in

```
AudioEngineControlling  ← App hosts AVAudioEngine (AVAudioEngineHost) or OfflineAudioEngine (tests)
  SynthBank
    PlaceholderSineVoice      SynthVoiceKind.placeholderSine
    ReedVoice                 .reed          (accordion)
    KarplusStrongVoice        .karplusStrong (guitar)
    SubtractiveVoice          .subtractive   (filter)
    ThereminVoice             .theremin
```

To add samples:

1. Drop CAF/WAV into `App/Resources/Samples/` using `AudioAssetProviding.sampleName`.
2. Implement `SynthRendering` (e.g. `SampleVoice`) that reads the file **on the main thread** into a preallocated buffer, then plays from that buffer in `render`.
3. Switch `InstrumentID.defaultVoice` or wrap inside `SynthBank` — **do not change** `HingeInput` or mapping functions.

`PlaceholderAudioAssets` currently returns `placeholder.<slot>` + `.caf` (files not shipped). Empty name → keep synth fallback.

## Sample format

| Field | Required |
|---|---|
| Container | CAF (preferred) or WAV |
| Sample rate | 48 kHz (resample at load if 44.1) |
| Bit depth | 24-bit PCM or 16-bit PCM |
| Channels | Mono for reeds/strings; stereo only for beds |
| Loop points | CAF `loopStart` / `loopEnd` frames; document below |
| Peak | < −0.3 dBFS (leave headroom for musette detune / overdub) |
| Naming | `hl_<pack>_<instrument>_<note>_<variant>.caf` |

Example: `hl_builtin_accordion_C3_reed.caf`

Pack IDs match Store products:

| Pack | Product ID | Slots |
|---|---|---|
| Built-in (free accordion) | — | `SampleSlot.accordionReedC3`, `accordionReedG3` |
| Reed pack | `com.jackyu.hingelab.pack.reeds` | extra musette notes |
| Guitar pack | `com.jackyu.hingelab.pack.guitar` | `guitarPluckE2` + 6 strings |
| Filter pack | `com.jackyu.hingelab.pack.filter` | `filterNoise` + wavetables |
| Theremin pack | `com.jackyu.hingelab.pack.theremin` | `thereminSine` + triangle |

## Instruments

### Accordion (free)
- **Driver:** hinge **velocity** → bellows pressure → amplitude. Rest = silence (`AccordionMapping.pressure`, threshold 2°/s).
- **Articulation:** direction change pulse.
- **Keys:** left chords (`AccordionLayout.leftChords`), right 2×6 from MIDI 60.
- **Sound:** 2–3 detuned oscillators (`ReedVoice`, ± ~3 cents). Replace with looped reed samples; keep the same amplitude envelope.
- **Suggested loops:** sustain loops 0.4–0.8 s, crossfade 32–64 ms.

### Pitch-Bend Guitar (Full)
- **Driver:** relative angle → ±2 st default (±12 option). Dead zone ±0.5°.
- **Keys:** 8 chords left, 6-string strum right.
- **Sound:** Karplus-Strong (`KarplusStrongVoice`). Sample pack replaces the noise burst with a short pluck (80–200 ms, no loop) then KS or convolution tail.
- Seeded RNG makes KS deterministic in tests — keep that path for `swift test`.

### Filter Sweep (Full)
- **Driver:** angle → exponential cutoff 20 Hz–20 kHz; velocity → resonance.
- **Sound:** saw + one-pole LP (`SubtractiveVoice`). Pack may supply a looping drone (4 bars @ 120 BPM = 8 s loop).
- Sequencer steps are MIDI notes 48…70 (placeholder).

### Theremin (Full)
- **Driver:** angle → frequency (`ThereminMapping`, optional scale quantize); other half = volume.
- **Sound:** sine (`ThereminVoice`). Optional triangle mix. Vibrato from CoreMotion is post-MVP.

## Looper
- Tap instrument output (`AVAudioEngine` tap on iOS; `OfflineAudioEngine.lastRender` in tests).
- Cap 5 minutes/track (`LoopLimits.maxDurationSeconds`).
- Free: 1 track; Full: 8. Export WAV now; M4A via `AVAudioFile` on iOS later (`ShareLink`).
- WAV encoder: 16-bit PCM, little-endian, `Looper/WAVEncoder`.

## MIDI
Virtual source name **`HingeLab`**. Mappings: hinge → pitch bend or CC1/CC11/CC74; keys → notes. 14-bit bend, center 8192. Channel in `MIDIMapping`. MPE off. Network session and BLE advertise only from the MIDI screen.

## Tests that audio changes must still pass
- Offline 0.2 s render of every `SynthVoiceKind`: non-silent, peak < 1.0, no NaN.
- KS identical for seed 99.
- Cutoff sweep raises spectral centroid.
- Close-release: sample-to-sample jump < 0.1 (AC6).
- Pitch bend ends/center within ±5 cents (AC3).

Run: `scripts/test-packages.sh` (Linux/macOS). Device latency (AC1) needs a Mac + Duo.
