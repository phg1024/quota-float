import Foundation

/// Runs a CLI that speaks newline-delimited JSON on stdin/stdout. Sends `first`, then passes each JSON object the
/// process prints to `handle` until it returns a value or throws. The process is stopped on return, and the whole
/// exchange is bounded by `timeout` even if the process (or a descendant holding its stdout) never exits.
func exchangeJSONLines<T>(executable: String, arguments: [String], environment: [String: String]? = nil,
                          first: [String: Any], timeout: TimeInterval = 25, service: String, unreachable: String,
                          handle: (_ message: [String: Any], _ send: ([String: Any]) throws -> Void) throws -> T?) throws -> T {
    let process = Process()
    let input = Pipe(), output = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    if let environment { process.environment = environment }
    process.currentDirectoryURL = FileManager.default.temporaryDirectory
    process.standardInput = input
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    let reader = LineReader(output.fileHandleForReading)
    try process.run()
    defer {
        reader.stop()
        try? input.fileHandleForWriting.close()
        stop(process)
        try? output.fileHandleForReading.close()
    }

    func send(_ message: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(10)
        try input.fileHandleForWriting.write(contentsOf: data)
    }
    try send(first)
    let deadline = DispatchTime.now() + timeout
    while let line = try reader.nextLine(before: deadline) {
        guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
        if let result = try handle(message, send) { return result }
    }
    if reader.timedOut { throw QuotaError("\(service) didn’t respond within \(Int(timeout)) s. Refresh to try again.") }
    throw QuotaError(unreachable)
}

/// Asks the process to exit, then kills it if it is still running two seconds later.
private func stop(_ process: Process) {
    guard process.isRunning else { return }
    process.terminate()
    let deadline = Date().addingTimeInterval(2)
    while process.isRunning && Date() < deadline { usleep(20_000) }
    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    process.waitUntilExit()
}

/// Collects complete lines from a pipe without blocking the caller past a deadline.
final class LineReader {
    static let maxLineLength = 4 << 20

    private let handle: FileHandle
    private let lock = NSLock()
    private let ready = DispatchSemaphore(value: 0)
    private var buffer = Data()
    private var lines: [Data] = []
    private var finished = false
    private(set) var timedOut = false

    init(_ handle: FileHandle) {
        self.handle = handle
        handle.readabilityHandler = { [weak self] handle in self?.receive(handle.availableData) }
    }

    /// The next complete line, or nil once output ends, overflows, or the deadline passes.
    func nextLine(before deadline: DispatchTime) throws -> Data? {
        while true {
            lock.lock()
            if !lines.isEmpty {
                let line = lines.removeFirst()
                lock.unlock()
                return line
            }
            let done = finished
            lock.unlock()
            if done { return nil }
            if ready.wait(timeout: deadline) == .timedOut {
                timedOut = true
                return nil
            }
        }
    }

    func stop() {
        handle.readabilityHandler = nil
    }

    private func receive(_ chunk: Data) {
        lock.lock()
        if chunk.isEmpty {
            finished = true
        } else {
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 10) {
                lines.append(buffer.subdata(in: buffer.startIndex..<newline))
                buffer.removeSubrange(buffer.startIndex...newline)
            }
            if buffer.count > Self.maxLineLength { finished = true }
        }
        let done = finished
        lock.unlock()
        if done { handle.readabilityHandler = nil }
        ready.signal()
    }
}
