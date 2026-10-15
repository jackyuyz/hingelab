import Foundation
import Synth
import ThemeKit

/// Reads the bundled reed CAFs on the main thread with the package's pure
/// Swift decoder and hands them to the engine once. A missing or empty name
/// keeps the synth fallback (audio-design-spec.md).
enum BuiltinSampleLoader {
    @MainActor
    static func load(into engine: any SampleLoading, assets: any AudioAssetProviding, bundle: Bundle = .main) {
        var reeds: [SampleBuffer] = []
        for slot in SampleSlot.allCases where slot.isAccordionReed {
            let name = assets.sampleName(slot)
            guard !name.isEmpty else { continue }
            let ext = assets.sampleFileExtension(slot)
            let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Samples")
                ?? bundle.url(forResource: name, withExtension: ext)
            guard let url, let data = try? Data(contentsOf: url),
                  let decoded = try? CAFCodec.decode(data) else { continue }
            reeds.append(decoded.sampleBuffer(defaultRootMIDINote: slot.rootMIDINote))
        }
        if !reeds.isEmpty {
            engine.loadSamples(reeds, for: .reed)
        }
    }
}
