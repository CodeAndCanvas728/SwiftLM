// StreamingDirectory.swift — where a Hub model is loaded from, checked against the
// Hub's own file list.
//
// `--stream-experts` streams from the one directory it was activated for, and a
// directory load doesn't fill in missing files. So the directory must be complete,
// and "complete" is decided by what the Hub lists, not by guessing a shard layout
// (repos ship `weights.NN.safetensors`, no index, or an index naming extra shards).

import Foundation
import Hub
import MLXInferenceCore

/// Files SwiftLM downloads for a model: weights, configs, tokenizer and templates.
let modelDownloadPatterns = ["*.safetensors", "*.json", "*.jinja"]

/// A `--stream-experts` prefetch finished without every listed file on disk.
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

/// The Hub couldn't be reached and there is no local copy known to be complete.
struct ModelUnavailableOffline: Error, CustomStringConvertible {
    let modelId: String
    let underlying: Error
    var description: String {
        "Could not reach the Hub to fetch \(modelId) (\(underlying)), and no complete local copy was found."
    }
}

/// The Hub answered, but has no repository `modelId` this user can read.
struct ModelNotOnHub: Error, CustomStringConvertible {
    let modelId: String
    let underlying: Error
    var description: String {
        "The Hub has no accessible repository \(modelId) (\(underlying)). Check the id, or log in for a gated model."
    }
}

struct HubListingTimeout: Error, CustomStringConvertible {
    var description: String { "the Hub did not answer in time" }
}

/// The Hub's file list for a repository, or why there isn't one.
enum HubListing {
    case files([String])
    /// A network error or timeout; the Hub gave no answer.
    case unreachable(Error)
}

/// Asks the Hub which files `modelId` has. Throws only when the Hub answered with
/// an error (unknown or gated repository); connectivity problems are `.unreachable`.
func fetchHubListing(_ hub: HubApi, modelId: String) async throws -> HubListing {
    do {
        let files = try await withThrowingTaskGroup(of: [String].self) { group in
            group.addTask { try await hub.getFilenames(from: modelId, matching: modelDownloadPatterns) }
            group.addTask {
                try await Task.sleep(nanoseconds: 15_000_000_000)
                throw HubListingTimeout()
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
        return .files(files)
    } catch let error as Hub.HubClientError {
        switch error {
        case .httpStatusCode, .authorizationRequired, .resourceNotFound, .fileNotFound:
            throw ModelNotOnHub(modelId: modelId, underlying: error)
        default:
            return .unreachable(error)
        }
    } catch {
        return .unreachable(error)
    }
}

/// Listed files that are absent from `directory`.
func missingFiles(_ files: [String], in directory: URL) -> [String] {
    files.filter { !FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) }
}

/// Whether `directory` has `tokenizer.json`. swift-transformers requires it;
/// `tokenizer_config.json` is optional, and `vocab.json` is no substitute.
func hasTokenizerJSON(in directory: URL) -> Bool {
    FileManager.default.fileExists(atPath: directory.appendingPathComponent("tokenizer.json").path)
}

/// The directory `--stream-experts` loads and streams `modelId` from.
///
/// Online, a local copy (`candidate`, then the loader's Application Support copy)
/// is used only if it has every listed file; otherwise the model is downloaded and
/// must then have them all. Offline, only a copy known to be complete is used.
func resolveStreamingDirectory(
    modelId: String, candidate: URL?, hub: HubApi, listing: HubListing
) async throws -> URL {
    let fm = FileManager.default
    let localRepo = hub.localRepoLocation(Hub.Repo(id: modelId))
    // Records that this copy once matched the Hub listing, for offline starts.
    let marker = localRepo.appendingPathComponent(".swiftlm-snapshot-complete")
    let copies = [candidate, localRepo].compactMap { $0 }.filter { fm.fileExists(atPath: $0.path) }

    switch listing {
    case .files(let files):
        guard files.contains("tokenizer.json") else { throw ModelMissingTokenizer(modelId: modelId) }
        for dir in copies {
            let missing = missingFiles(files, in: dir)
            if missing.isEmpty {
                if dir == localRepo { fm.createFile(atPath: marker.path, contents: nil) }
                return dir
            }
            print("[SwiftLM] \(dir.path) is missing \(missing.count) of \(files.count) files (e.g. \(missing[0])).")
        }
        // A dense model won't stream: leave completing it to the loader instead of
        // downloading everything here first.
        if let dir = copies.first(where: {
            fm.fileExists(atPath: $0.appendingPathComponent("config.json").path)
        }), let profile = ModelProfiler.profile(modelDirectory: dir, modelId: modelId), !profile.isMoE {
            return dir
        }

        print("[SwiftLM] --stream-experts: downloading \(modelId) before loading...")
        let tracker = ProgressTracker(modelId: modelId)
        defer { tracker.finish() }
        let snapshot = try await hub.snapshot(from: modelId, matching: modelDownloadPatterns) {
            tracker.printProgress($0)
        }
        tracker.finish()
        guard missingFiles(files, in: snapshot).isEmpty else {
            throw ModelDownloadIncomplete(modelId: modelId, directory: snapshot)
        }
        fm.createFile(atPath: marker.path, contents: nil)
        return snapshot

    case .unreachable(let error):
        let verified = fm.fileExists(atPath: marker.path) && hasTokenizerJSON(in: localRepo)
            ? [localRepo] : []
        let plausible = copies.filter {
            hasTokenizerJSON(in: $0) && ModelStorage.validateLocalModelDirectory($0, logFailures: false)
        }
        guard let dir = (verified + plausible).first else {
            throw ModelUnavailableOffline(modelId: modelId, underlying: error)
        }
        print("[SwiftLM] ⚠️  Could not reach the Hub to check \(modelId) (\(error)); using \(dir.path).")
        return dir
    }
}
