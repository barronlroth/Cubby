// Run on an Apple Intelligence-enabled Apple Silicon Mac with Xcode 26+:
// swiftc -parse-as-library -target arm64-apple-macos26.0 \
//   Cubby/Views/Home/FoundationModelEmojiService.swift tools/EmojiPrewarmBenchmark.swift \
//   -o /tmp/cubby-emoji-benchmark && /tmp/cubby-emoji-benchmark
// Uses only fixed public sample names. Does not open or mutate any app inventory.
// Measures a warm-process comparison, not a cold-boot or iPhone performance claim.
import Foundation
import FoundationModels

// Satisfies the production service's logger dependency for this standalone executable.
struct DebugLogger { static func info(_ message: String) { print(message) } }

@main struct EmojiPrewarmBenchmark {
    static func main() async throws {
        guard case .available = SystemLanguageModel.default.availability else {
            print("Benchmark not run: \(SystemLanguageModel.default.availability)")
            return
        }
        var samples: [Bool: [Double]] = [false: [], true: []]
        // Reverse treatment order on the second pass to reduce order bias.
        for pass in 0..<2 {
            for title in ["Dog", "Flashlight", "Passport", "Coffee mug"] {
                for prewarm in (pass == 0 ? [false, true] : [true, false]) {
                    let session = LanguageModelSession(instructions: FoundationModelEmojiService.instructions)
                    if prewarm { session.prewarm() }
                    // Equal time to simulate composing an item in both treatments.
                    try await Task.sleep(for: .seconds(2))
                    let start = ContinuousClock.now
                    do {
                        let response = try await session.respond(to: "Title: \(title)\nReturn one emoji.")
                        let duration = start.duration(to: .now).components
                        let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
                        let emoji = FoundationModelEmojiService.validatedEmoji(response.content)
                        if emoji != nil { samples[prewarm, default: []].append(seconds) }
                        print("pass=\(pass) prewarm=\(prewarm) title=\(title) seconds=\(seconds) emoji=\(emoji ?? "INVALID")")
                    } catch {
                        print("pass=\(pass) prewarm=\(prewarm) title=\(title) failed")
                    }
                }
            }
        }
        for prewarm in [false, true] {
            let values = samples[prewarm, default: []].sorted()
            guard !values.isEmpty else { continue }
            let median = (values[(values.count - 1) / 2] + values[values.count / 2]) / 2
            print("SUMMARY prewarm=\(prewarm) successes=\(values.count)/8 medianSeconds=\(median)")
        }
    }
}
