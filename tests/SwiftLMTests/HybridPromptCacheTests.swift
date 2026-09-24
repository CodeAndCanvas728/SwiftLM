import XCTest
import MLX
import MLXLMCommon
@testable import SwiftLM

/// Hybrid (MambaCache + KVCacheSimple) models such as Qwen3.5/3.6 got no prompt reuse,
/// so every agent turn re-prefilled the whole conversation. Recurrent state can't be
/// trimmed, so reuse is exact-prefix only, snapshotted at a turn boundary.
final class HybridPromptCacheTests: XCTestCase {

    private let imStart = 7

    private func makeHybridCache(seqLen T: Int, fill: Float) -> [any KVCache] {
        let attn = KVCacheSimple()
        _ = attn.update(keys: MLXArray.ones([1, 2, T, 4], dtype: .float16) * fill,
                        values: MLXArray.ones([1, 2, T, 4], dtype: .float16) * fill)
        let mamba = MambaCache()
        mamba.state = [MLXArray.ones([1, 3, 8]) * fill, MLXArray.ones([1, 2, 4, 4]) * fill]
        return [attn, mamba]
    }

    // MARK: - Boundary

    func testBoundaryIsLastImStartForHybridCache() {
        let tokens = [imStart, 1, 2, imStart, 3, 4, imStart, 5]
        XCTAssertEqual(hybridCacheBoundary(promptTokens: tokens, imStartId: imStart,
                                           cache: [KVCacheSimple(), MambaCache()]), 6)
    }

    func testNoBoundaryForNonHybridOrNonChatML() {
        let tokens = [imStart, 1, imStart, 2]
        XCTAssertNil(hybridCacheBoundary(promptTokens: tokens, imStartId: imStart, cache: [KVCacheSimple()]),
                     "pure-attention models keep the generic prompt cache")
        XCTAssertNil(hybridCacheBoundary(promptTokens: tokens, imStartId: nil,
                                         cache: [KVCacheSimple(), MambaCache()]))
        XCTAssertNil(hybridCacheBoundary(promptTokens: [imStart, 1], imStartId: imStart,
                                         cache: [KVCacheSimple(), MambaCache()]),
                     "no history before the only turn start")
    }

    // MARK: - Save / exact-prefix restore

    func testRestoresExactPrefixIntoFreshCache() async {
        let pc = PromptCache()
        await pc.save(tokens: [1, 2, 3], cache: makeHybridCache(seqLen: 3, fill: 2), allowRecurrent: true)

        let fresh: [any KVCache] = [KVCacheSimple(), MambaCache()]
        let n = await pc.restoreExactPrefix(newTokens: [1, 2, 3, 4, 5], limit: 4, into: fresh)

        XCTAssertEqual(n, 3)
        XCTAssertEqual(fresh[0].offset, 3, "attention layer resumes at the snapshot length")
        let recurrent = fresh[1].state
        XCTAssertEqual(recurrent.count, 2)
        XCTAssertEqual(recurrent[1].sum().item(Float.self), 2 * 32, "recurrent state restored verbatim")
    }

    func testMissesWhenPrefixDiverges() async {
        let pc = PromptCache()
        await pc.save(tokens: [1, 2, 3], cache: makeHybridCache(seqLen: 3, fill: 1), allowRecurrent: true)
        let n = await pc.restoreExactPrefix(newTokens: [1, 9, 3, 4], limit: 4,
                                            into: [KVCacheSimple(), MambaCache()])
        XCTAssertNil(n, "recurrent state cannot be rolled back to a shorter common prefix")
    }

    func testMissesWhenSnapshotExtendsPastLimit() async {
        let pc = PromptCache()
        await pc.save(tokens: [1, 2, 3], cache: makeHybridCache(seqLen: 3, fill: 1), allowRecurrent: true)
        let n = await pc.restoreExactPrefix(newTokens: [1, 2, 3, 4], limit: 2,
                                            into: [KVCacheSimple(), MambaCache()])
        XCTAssertNil(n)
    }

    func testGenericSaveStillRefusesRecurrentState() async {
        let pc = PromptCache()
        await pc.save(tokens: [1, 2, 3], cache: makeHybridCache(seqLen: 3, fill: 1))
        let n = await pc.restoreExactPrefix(newTokens: [1, 2, 3, 4], limit: 4,
                                            into: [KVCacheSimple(), MambaCache()])
        XCTAssertNil(n, "only the boundary snapshot may persist recurrent state")
    }
}
