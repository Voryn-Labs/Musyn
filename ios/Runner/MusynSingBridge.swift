import Foundation
import Flutter

@MainActor final class MusynSingBridge {
  private let channel: FlutterMethodChannel
  private var work: Task<URL, Error>?
  private var modelWork: Task<URL, Error>?
  private var modelRequest: Int?
  private var previousFile: URL?
  private var requestID: Int?
  private var cacheRoot: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("musyn-vocal-stems", isDirectory: true)
  }
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.vorynlabs.musyn/sing", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
  }
  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "supported" { if #available(iOS 18.0, *) { result(true) } else { result(false) }; return }
    if call.method == "cancel" { work?.cancel(); modelWork?.cancel(); modelRequest = nil; requestID = nil; result(nil); return }
    guard #available(iOS 18.0, *) else { result(FlutterError(code: "unsupported", message: "Vocal reduction requires iOS 18", details: nil)); return }
    if call.method == "installModel", let args = call.arguments as? [String: Any], let request = args["request"] as? Int {
      modelWork?.cancel()
      modelRequest = request
      let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("musyn-vocal-model", isDirectory: true)
      let task = Task.detached(priority: .userInitiated) {
        try await MusynVocalModel.install(in: support, progress: { _, _ in })
      }
      modelWork = task
      Task {
        do { _ = try await task.value; result(nil) }
        catch { result(FlutterError(code: "model", message: error.localizedDescription, details: nil)) }
      }
      return
    }
    if call.method == "cached", let args = call.arguments as? [String: Any],
      let alias = args["alias"] as? String, alias.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil {
      let root = cacheRoot
      Task.detached(priority: .userInitiated) {
        let index = root.appendingPathComponent("alias-" + alias)
        guard let key = try? String(contentsOf: index, encoding: .utf8),
          key.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else {
          await MainActor.run { result(nil) }; return
        }
        let file = root.appendingPathComponent(key + ".musyn-stems.mov")
        let valid = await MusynSingEngine.validCache(file)
        if valid { try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path) }
        else { try? FileManager.default.removeItem(at: index) }
        await MainActor.run { result(valid ? file.path : nil) }
      }
      return
    }
    guard call.method == "prepare", let args = call.arguments as? [String: Any], let path = args["path"] as? String,
      let key = args["key"] as? String, key.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
      let request = args["request"] as? Int, path.hasPrefix(NSHomeDirectory() + "/"), FileManager.default.fileExists(atPath: path) else {
      result(FlutterError(code: "input", message: "No local audio is ready for separation", details: nil)); return
    }
    let previous = work; previous?.cancel(); requestID = request
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("musyn-vocal-model", isDirectory: true)
    let root = cacheRoot
    let alias = args["alias"] as? String
    let installedModel = modelRequest == request ? modelWork : nil
    let output = root.appendingPathComponent(key + ".musyn-stems.mov")
    let progress: @Sendable (String, Double) -> Void = { [weak self] stage, value in
      Task { @MainActor [weak self] in
        guard let self = self, self.requestID == request else { return }
        self.channel.invokeMethod("progress", arguments: ["request": request, "stage": stage, "progress": value])
      }
    }
    let task = Task.detached(priority: .userInitiated) {
      if let previous = previous { _ = await previous.result }
      try Task.checkCancellation()
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      if await MusynSingEngine.validCache(output) { return output }
      let model: URL
      if let installedModel = installedModel { model = try await installedModel.value }
      else { model = try await MusynVocalModel.install(in: support, progress: progress) }
      return try await MusynSingEngine.prepare(input: URL(fileURLWithPath: path), output: output, model: model, progress: progress)
    }
    work = task
    Task { [weak self] in
      do {
        let file = try await task.value
        guard self?.requestID == request else { result(FlutterError(code: "cancelled", message: "Selection changed", details: nil)); return }
        if let alias = alias, alias.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil {
          try? key.write(to: root.appendingPathComponent("alias-" + alias), atomically: true, encoding: .utf8)
        }
        self?.trim(root, keeping: file)
        self?.previousFile = file
        result(file.path)
      } catch is CancellationError { result(FlutterError(code: "cancelled", message: "Vocal preparation cancelled", details: nil)) }
      catch { result(FlutterError(code: "separation", message: error.localizedDescription, details: nil)) }
    }
  }
  private func trim(_ directory: URL, keeping file: URL) {
    let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? [])
      .filter { $0.lastPathComponent.hasSuffix(".musyn-stems.mov") }
      .sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
    var bytes = files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    var count = files.count
    for old in files.reversed() where old != file && old != previousFile && (count > 5 || bytes > 200 * 1024 * 1024) {
      let size = (try? old.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
      try? FileManager.default.removeItem(at: old); bytes -= size; count -= 1
    }
    let indices = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
      .filter { $0.lastPathComponent.hasPrefix("alias-") }
      .sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
    for index in indices.dropFirst(40) { try? FileManager.default.removeItem(at: index) }
    for index in indices.prefix(40) {
      guard let key = try? String(contentsOf: index, encoding: .utf8), key.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(key + ".musyn-stems.mov").path) else {
        try? FileManager.default.removeItem(at: index); continue
      }
    }
  }
}
