import Foundation

enum ApiError: LocalizedError {
    case serverError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .serverError(let message): return message
        case .networkError(let error): return error.localizedDescription
        }
    }
}

actor ApiService {
    private let baseURL: String
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init(port: UInt16) {
        self.baseURL = "http://127.0.0.1:\(port)"
    }

    func selectFile(_ filePath: String) async throws -> FileInfo {
        let body = ["file_path": filePath]
        let data = try await post("/api/select-file", body: body)
        return try decoder.decode(FileInfo.self, from: data)
    }

    func discover() async throws -> DiscoverResult {
        let data = try await get("/api/discover")
        return try decoder.decode(DiscoverResult.self, from: data)
    }

    func discoverRefresh() async throws -> DiscoverResult {
        let data = try await post("/api/discover/refresh")
        return try decoder.decode(DiscoverResult.self, from: data)
    }

    func selectDevice(_ deviceIndex: Int) async throws {
        let body = ["device_index": deviceIndex]
        _ = try await post("/api/select-device", body: body)
    }

    func cast() async throws {
        _ = try await post("/api/cast")
    }

    func play() async throws {
        _ = try await post("/api/play")
    }

    func pause() async throws {
        _ = try await post("/api/pause")
    }

    func stop() async throws {
        _ = try await post("/api/stop")
    }

    func seek(_ positionSecs: Int) async throws {
        let body = ["position_secs": positionSecs]
        _ = try await post("/api/seek", body: body)
    }

    func getStatus() async throws -> PlaybackStatus {
        let data = try await get("/api/status")
        return try decoder.decode(PlaybackStatus.self, from: data)
    }

    // MARK: - Private

    private func get(_ path: String) async throws -> Data {
        let url = URL(string: "\(baseURL)\(path)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkResponse(data: data, response: response)
        return data
    }

    private func post(_ path: String, body: Any? = nil) async throws -> Data {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(data: data, response: response)
        return data
    }

    private func checkResponse(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode >= 400 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["error"] as? String {
                throw ApiError.serverError(message)
            }
            throw ApiError.serverError("HTTP \(http.statusCode)")
        }
    }
}
