import XCTest
import MLX
import MLXLMCommon
@testable import SwiftLM

/// The prompt cache keeps several entries so interleaved sessions (a side request between
/// two agent turns) don't evict each other's prefix.
final class PromptCacheLRUTests: XCTestCase {

    private func makeCache(seqLen T: Int, fill: Float) -> [any KVCache] {
        let attn = KVCacheSimple()
        _ = attn.update(keys: MLXArray.ones([1, 2, T, 4], dtype: .float16) * fill,
                        values: MLXArray.ones([1, 2, T, 4], dtype: .float16) * fill)
        return [attn]
    }

    private func makeHybrid(seqLen T: Int, fill: Float) -> [any KVCache] {
        let mamba = MambaCache()
        mamba.state = [MLXArray.ones([1, 3, 8]) * fill, MLXArray.ones([1, 2, 4, 4]) * fill]
        return makeCache(seqLen: T, fill: fill) + [mamba]
    }

    private func hit(_ pc: PromptCache, _ tokens: [Int]) async -> Int? {
        await pc.restore(newTokens: tokens, into: [KVCacheSimple()])
    }

    func testTwoUnrelatedPromptsBothHitWithTwoEntries() async {
        let pc = PromptCache(maxEntries: 2)
        await pc.save(tokens: [1, 2, 3, 4], cache: makeCache(seqLen: 4, fill: 1))
        await pc.save(tokens: [9, 8, 7, 6], cache: makeCache(seqLen: 4, fill: 2))
        let a = await hit(pc, [1, 2, 3, 4, 5])
        let b = await hit(pc, [9, 8, 7, 6, 5])
        XCTAssertEqual(a, 4)
        XCTAssertEqual(b, 4)
    }

    func testSingleEntryKeepsTodaysBehaviour() async {
        let pc = PromptCache()
        await pc.save(tokens: [1, 2, 3, 4], cache: makeCache(seqLen: 4, fill: 1))
        await pc.save(tokens: [9, 8, 7, 6], cache: makeCache(seqLen: 4, fill: 2))
        let first = await hit(pc, [1, 2, 3, 4, 5])
        XCTAssertNil(first)
    }

    func testHitRefreshesRecencyAndLeastRecentIsDropped() async {
        let pc = PromptCache(maxEntries: 2)
        await pc.save(tokens: [1, 2, 3, 4], cache: makeCache(seqLen: 4, fill: 1))
        await pc.save(tokens: [9, 8, 7, 6], cache: makeCache(seqLen: 4, fill: 2))
        _ = await hit(pc, [1, 2, 3, 4, 5])  // [1..] is now most recent
        await pc.save(tokens: [5, 5, 5, 5], cache: makeCache(seqLen: 4, fill: 3))  // evicts [9..]
        let kept = await hit(pc, [1, 2, 3, 4, 5])
        let dropped = await hit(pc, [9, 8, 7, 6, 5])
        XCTAssertEqual(kept, 4)
        XCTAssertNil(dropped)
    }

    func testExtensionReplacesItsPrefixEntry() async {
        let pc = PromptCache(maxEntries: 2)
        await pc.save(tokens: [1, 2, 3], cache: makeCache(seqLen: 3, fill: 1))
        await pc.save(tokens: [9, 9, 9], cache: makeCache(seqLen: 3, fill: 2))
        await pc.save(tokens: [1, 2, 3, 4, 5], cache: makeCache(seqLen: 5, fill: 1))
        // The other session must survive: the linear conversation replaced its own entry.
        let other = await hit(pc, [9, 9, 9, 1])
        let conv = await hit(pc, [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(other, 3)
        XCTAssertEqual(conv, 5)
    }

    func testRestorePicksLongestMatch() async {
        let pc = PromptCache(maxEntries: 3)
        await pc.save(tokens: [1, 2, 3, 4, 5, 6], cache: makeCache(seqLen: 6, fill: 1))
        await pc.save(tokens: [1, 2, 9, 9, 9, 9], cache: makeCache(seqLen: 6, fill: 2))
        let n = await hit(pc, [1, 2, 3, 4, 7, 8])
        XCTAssertEqual(n, 4)
    }

    func testHybridExactPrefixPicksLongestEntry() async {
        let pc = PromptCache(maxEntries: 3)
        await pc.save(tokens: [1, 2, 3], cache: makeHybrid(seqLen: 3, fill: 1), allowRecurrent: true)
        await pc.save(tokens: [7, 7, 7, 7], cache: makeHybrid(seqLen: 4, fill: 3), allowRecurrent: true)
        await pc.save(tokens: [1, 2, 3, 4, 5], cache: makeHybrid(seqLen: 5, fill: 2), allowRecurrent: true)
        // The 5-token entry replaced the 3-token one, so [1,2,3,4,5,...] reuses all 5.
        let fresh: [any KVCache] = [KVCacheSimple(), MambaCache()]
        let n = await pc.restoreExactPrefix(newTokens: [1, 2, 3, 4, 5, 6], limit: 5, into: fresh)
        XCTAssertEqual(n, 5)
        let other = await pc.restoreExactPrefix(newTokens: [7, 7, 7, 7, 1], limit: 4,
                                                into: [KVCacheSimple(), MambaCache()])
        XCTAssertEqual(other, 4, "the other session's snapshot survives")
    }

    func testEvictKeepMostRecentAndEvictAll() async {
        let pc = PromptCache(maxEntries: 3)
        await pc.save(tokens: [1, 2, 3, 4], cache: makeCache(seqLen: 4, fill: 1))
        await pc.save(tokens: [9, 8, 7, 6], cache: makeCache(seqLen: 4, fill: 2))
        await pc.evict(keepMostRecent: true)
        let old = await hit(pc, [1, 2, 3, 4, 5])
        let recent = await hit(pc, [9, 8, 7, 6, 5])
        XCTAssertNil(old)
        XCTAssertEqual(recent, 4)
        await pc.evict(keepMostRecent: false)
        let none = await hit(pc, [9, 8, 7, 6, 5])
        XCTAssertNil(none)
    }
}
