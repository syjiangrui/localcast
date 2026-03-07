import Foundation
import os

final class SseService: @unchecked Sendable {
    private let baseURL: String
    private let logger = Logger(subsystem: "com.reikly.localcast", category: "SSE")

    init(port: UInt16) {
        self.baseURL = "http://127.0.0.1:\(port)"
    }

    func statusStream() -> AsyncStream<PlaybackStatus> {
        eventStream(path: "/api/status/stream")
    }

    func devicesStream() -> AsyncStream<DiscoverResult> {
        eventStream(path: "/api/devices/stream")
    }

    /// Creates an AsyncStream that connects to the given SSE endpoint using a
    /// delegate-based URLSession (URLSession.bytes is not suitable for chunked
    /// streaming because it buffers data before yielding).
    private func eventStream<T: Decodable & Sendable>(path: String) -> AsyncStream<T> {
        let urlString = "\(baseURL)\(path)"
        let logger = self.logger

        return AsyncStream { continuation in
            guard let url = URL(string: urlString) else {
                continuation.finish()
                return
            }

            var request = URLRequest(url: url)
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let handler = SseDataHandler<T>(decoder: decoder, logger: logger, continuation: continuation)

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 3600
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: config, delegate: handler, delegateQueue: nil)

            let task = session.dataTask(with: request)
            task.resume()

            continuation.onTermination = { _ in
                task.cancel()
                session.invalidateAndCancel()
            }
        }
    }
}

// MARK: - Delegate-based SSE parser

/// Receives chunked SSE data via URLSessionDataDelegate and parses events
/// into decoded values, yielding them through an AsyncStream continuation.
private final class SseDataHandler<T: Decodable & Sendable>: NSObject, URLSessionDataDelegate {
    private let decoder: JSONDecoder
    private let logger: Logger
    private let continuation: AsyncStream<T>.Continuation
    private var buffer = ""

    init(decoder: JSONDecoder, logger: Logger, continuation: AsyncStream<T>.Continuation) {
        self.decoder = decoder
        self.logger = logger
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        // SSE data arrives in chunks; split by newlines and process each line.
        let lines = chunk.components(separatedBy: "\n")
        for line in lines {
            processLine(line)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        continuation.finish()
    }

    private func processLine(_ line: String) {
        if line.hasPrefix("data:") {
            // Append data (SSE spec allows multiple data: lines per event)
            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if buffer.isEmpty {
                buffer = payload
            } else {
                buffer += "\n" + payload
            }
        } else if line.isEmpty && !buffer.isEmpty {
            // Empty line = end of event → decode and yield
            if let data = buffer.data(using: .utf8),
               let value = try? decoder.decode(T.self, from: data) {
                continuation.yield(value)
            }
            buffer = ""
        }
        // Lines starting with ":" are comments (keep-alive), ignore them.
    }
}
