import Flutter
import Foundation

final class DocumentOpenQueue {
  private var entries: [[String: String]] = []
  private let lock = NSLock()

  var onEnqueue: (() -> Void)?

  func enqueue(path: String) {
    enqueue(["path": path])
  }

  func enqueue(error: String) {
    enqueue(["error": error])
  }

  func takeAll() -> [[String: String]] {
    lock.lock()
    defer { lock.unlock() }
    let result = entries
    entries.removeAll()
    return result
  }

  func pendingPaths() -> Set<String> {
    lock.lock()
    defer { lock.unlock() }
    return Set(entries.compactMap { $0["path"] })
  }

  private func enqueue(_ entry: [String: String]) {
    lock.lock()
    entries.append(entry)
    lock.unlock()
    onEnqueue?()
  }
}

final class DocumentOpenBroker {
  static let shared = DocumentOpenBroker()
  static let channelName = "net.nativemind.comics_editor/document_open"

  let queue: DocumentOpenQueue
  private var channel: FlutterMethodChannel?
  private let copyQueue = DispatchQueue(label: "net.nativemind.comics-editor.document-copy")

  init(queue: DocumentOpenQueue = DocumentOpenQueue()) {
    self.queue = queue
  }

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "takePendingDocuments" {
        result(self?.queue.takeAll() ?? [])
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
    queue.onEnqueue = { [weak self] in
      DispatchQueue.main.async {
        self?.channel?.invokeMethod("documentsAvailable", arguments: nil)
      }
    }
    pruneStaleCopies()
  }

  func accept(urls: [URL]) {
    for url in urls {
      copyQueue.async { [weak self] in
        self?.copyAndEnqueue(url)
      }
    }
  }

  static func isComicsURL(_ url: URL) -> Bool {
    url.isFileURL && url.pathExtension.caseInsensitiveCompare("comics") == .orderedSame
  }

  private func copyAndEnqueue(_ url: URL) {
    guard Self.isComicsURL(url) else {
      queue.enqueue(error: "Unsupported external document: \(url.lastPathComponent)")
      return
    }

    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed { url.stopAccessingSecurityScopedResource() }
    }

    var coordinationError: NSError?
    var copiedPath: String?
    var copyError: Error?
    NSFileCoordinator().coordinate(
      readingItemAt: url,
      options: [],
      error: &coordinationError
    ) { coordinatedURL in
      do {
        copiedPath = try makePrivateCopy(of: coordinatedURL)
      } catch {
        copyError = error
      }
    }

    if let copiedPath {
      queue.enqueue(path: copiedPath)
    } else {
      let message = copyError?.localizedDescription
        ?? coordinationError?.localizedDescription
        ?? "Unknown copy failure"
      queue.enqueue(error: "Unable to copy external Comics document: \(message)")
    }
  }

  private func makePrivateCopy(of source: URL) throws -> String {
    let directory = try incomingDirectory()
    let identifier = UUID().uuidString
    let staging = directory.appendingPathComponent("\(identifier).part")
    let target = directory.appendingPathComponent("\(identifier).comics")
    let manager = FileManager.default
    try? manager.removeItem(at: staging)
    do {
      try manager.copyItem(at: source, to: staging)
      try manager.moveItem(at: staging, to: target)
      return target.path
    } catch {
      try? manager.removeItem(at: staging)
      try? manager.removeItem(at: target)
      throw error
    }
  }

  private func incomingDirectory() throws -> URL {
    let caches = try FileManager.default.url(
      for: .cachesDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let directory = caches.appendingPathComponent("incoming-comics", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory
  }

  private func pruneStaleCopies() {
    copyQueue.async { [weak self] in
      guard let self, let directory = try? incomingDirectory() else { return }
      let pending = queue.pendingPaths()
      let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
      let keys: Set<URLResourceKey> = [.contentModificationDateKey]
      let files = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: Array(keys)
      )
      for file in files ?? [] where !pending.contains(file.path) {
        let values = try? file.resourceValues(forKeys: keys)
        if let modified = values?.contentModificationDate, modified < cutoff {
          try? FileManager.default.removeItem(at: file)
        }
      }
    }
  }
}
