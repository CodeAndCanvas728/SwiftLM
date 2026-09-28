// StreamingDirectory.swift — the directory `--stream-experts` loads a Hub model from.
//
// Streaming targets one directory, and a directory load doesn't fill in missing
// files, so that copy must be loadable. Local copies are used as they are when they
// have what the loader reads; the Hub is consulted only when none does.

import Foundation
import Hub
import MLXInferenceCore

/// Files SwiftLM downloads for a model: weights, configs, tokenizer and templates.
let modelDownloadPatterns = ["*.safetensors", "*.json", "*.jinja"]

/// A `--stream-experts` download finished without the files the loader needs.
struct ModelDownloadIncomplete: Error, CustomStringConvertible {
    let modelId: String
    let directory: URL
    var description: String {
        "Download of \(modelId) is incomplete (\(directory.path)). Check the network, or delete the directory and retry."
    }
}

/// The repository has no `tokenizer.json`, which the tokenizer loader requires.
struct ModelMissingTokenizer: Error, CustomStringConvertible {
    let modelId: String
    var description: String {
        "\(modelId) has no tokenizer.json, which SwiftLM needs to load it."
    }
}

/// The Hub answered 401/404 and there is no loadable local copy.
struct ModelNotOnHub: Error, CustomStringConvertible {
    let modelId: String
    let underlying: Error
    var description: String {
        "The Hub has no accessible repository \(modelId) (\(underlying)), and no loadable local copy was found. Check the id, or set HF_TOKEN for a private repository."
    }
}

/// The Hub couldn't be used and there is no loadable local copy.
struct ModelUnavailableOffline: Error, CustomStringConvertible {
    let modelId: String
    let underlying: Error
    var description: String {
        "Could not get \(modelId) from the Hub (\(underlying)), and no loadable local copy was found."
    }
}

/// Whether `directory` has `tokenizer.json`. swift-transformers requires it;
/// `tokenizer_config.json` is optional, and `vocab.json` is no substitute.
func hasTokenizerJSON(in directory: URL) -> Bool {
    FileManager.default.fileExists(atPath: directory.appendingPathComponent("tokenizer.json").path)
}

/// Whether the loader can read `directory` as a model: `config.json`, `tokenizer.json`,
/// and weights. With an index, every shard it names; without one, any top-level
/// `*.safetensors` (`model.safetensors`, `weights.00.safetensors`, ...).
func hasLoadableModelFiles(in directory: URL) -> Bool {
    let fm = FileManager.default
    func nonEmpty(_ name: String) -> Bool {
        let url = directory.appendingPathComponent(name).resolvingSymlinksInPath()
        let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return size > 0
    }
    guard nonEmpty("config.json"), nonEmpty("tokenizer.json") else { return false }
    let index = directory.appendingPathComponent("model.safetensors.index.json")
    if let data = try? Data(contentsOf: index),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let weightMap = json["weight_map"] as? [String: String]
    {
        return Set(weightMap.values).allSatisfy(nonEmpty)
    }
    let names = (try? fm.contentsOfDirectory(atPath: directory.path)) ?? []
    return names.contains { $0.hasSuffix(".safetensors") && nonEmpty($0) }
}

/// Whether a Hub error means the repository isn't available to this user.
private func isNotOnHub(_ error: Error) -> Bool {
    guard let hubError = error as? Hub.HubClientError else { return false }
    switch hubError {
    case .authorizationRequired, .resourceNotFound: return true
    case .httpStatusCode(let code): return code == 401 || code == 404
    default: return false
    }
}

/// The directory `--stream-experts` loads and streams `modelId` from.
///
/// A loadable local copy (`candidate`, then the loader's Application Support copy)
/// is used without contacting the Hub. Otherwise the model is downloaded into the
/// Application Support copy, which must then have every top-level listed file.
func resolveStreamingDirectory(modelId: String, candidate: URL?, hub: HubApi) async throws -> URL {
    let fm = FileManager.default
    let localRepo = hub.localRepoLocation(Hub.Repo(id: modelId))
    // Present while a download into localRepo is unfinished; that copy isn't trusted.
    let inProgress = localRepo.appendingPathComponent(".swiftlm-download-in-progress")
    let copies = [candidate, localRepo].compactMap { $0 }.filter { fm.fileExists(atPath: $0.path) }
    let loadable = copies.filter {
        hasLoadableModelFiles(in: $0) && !($0 == localRepo && fm.fileExists(atPath: inProgress.path))
    }
    if let dir = loadable.first { return dir }

    let files: [String]
    do {
        files = try await hub.getFilenames(from: modelId, matching: modelDownloadPatterns)
    } catch where isNotOnHub(error) {
        throw ModelNotOnHub(modelId: modelId, underlying: error)
    } catch {
        throw ModelUnavailableOffline(modelId: modelId, underlying: error)
    }
    guard files.contains("tokenizer.json") else { throw ModelMissingTokenizer(modelId: modelId) }

    // A dense model won't stream: leave completing it to the loader instead of
    // downloading everything here first.
    if let dir = copies.first(where: {
        fm.fileExists(atPath: $0.appendingPathComponent("config.json").path)
    }), let profile = ModelProfiler.profile(modelDirectory: dir, modelId: modelId), !profile.isMoE {
        return dir
    }
    for dir in copies {
        let reason = dir == localRepo && fm.fileExists(atPath: inProgress.path)
            ? "its download didn't finish" : "missing weights or tokenizer.json"
        print("[SwiftLM] \(dir.path) can't be loaded as is (\(reason)).")
    }

    print("[SwiftLM] --stream-experts: downloading \(modelId) before loading...")
    try fm.createDirectory(at: localRepo, withIntermediateDirectories: true)
    fm.createFile(atPath: inProgress.path, contents: nil)
    let tracker = ProgressTracker(modelId: modelId)
    defer { tracker.finish() }
    let snapshot = try await hub.snapshot(from: modelId, matching: modelDownloadPatterns) {
        tracker.printProgress($0)
    }
    tracker.finish()
    let topLevel = files.filter { !$0.contains("/") }
    let missing = topLevel.filter { !fm.fileExists(atPath: snapshot.appendingPathComponent($0).path) }
    guard missing.isEmpty, hasLoadableModelFiles(in: snapshot) else {
        throw ModelDownloadIncomplete(modelId: modelId, directory: snapshot)
    }
    try? fm.removeItem(at: inProgress)
    return snapshot
}
