import Foundation

/// Minimal Gemini Live API client over a raw WebSocket (BidiGenerateContent).
/// All events are delivered on the main queue.
final class GeminiLiveClient: NSObject, URLSessionWebSocketDelegate {
    struct FunctionCall {
        let id: String
        let name: String
        let args: [String: Any]
    }

    enum Event {
        case setupComplete
        case toolCall([FunctionCall])
        case inputTranscript(String)
        /// nil error = server closed the session normally (e.g. session time limit).
        case closed(ServiceError?)
    }

    var onEvent: ((Event) -> Void)?

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var finished = false

    private static let endpoint = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"

    func connect(apiKey: String, setup: [String: Any]) {
        var comps = URLComponents(string: Self.endpoint)!
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))]
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        let task = session.webSocketTask(with: comps.url!)
        task.maximumMessageSize = 16 * 1024 * 1024
        self.session = session
        self.task = task
        task.resume()
        send(["setup": setup])
        receiveNext()
    }

    /// 16 kHz mono little-endian PCM16. Safe to call from the audio thread.
    func sendAudio(_ pcm: Data) {
        send(["realtimeInput": ["audio": ["data": pcm.base64EncodedString(), "mimeType": "audio/pcm;rate=16000"]]])
    }

    func sendAudioStreamEnd() {
        send(["realtimeInput": ["audioStreamEnd": true]])
    }

    func sendToolResponses(_ responses: [[String: Any]]) {
        send(["toolResponse": ["functionResponses": responses]])
    }

    func close() {
        finished = true
        task?.cancel(with: .normalClosure, reason: nil)
        session?.invalidateAndCancel()
        task = nil
        session = nil
    }

    // MARK: - Private

    private func send(_ object: [String: Any]) {
        guard let task, let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { _ in }
    }

    private func receiveNext() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                let data: Data?
                switch message {
                case .string(let s): data = s.data(using: .utf8)
                case .data(let d): data = d
                @unknown default: data = nil
                }
                if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.handle(json)
                }
                self.receiveNext()
            case .failure(let error):
                // The close frame (with a readable reason) usually arrives via the delegate right after; give it a moment.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.finish(ServiceError.from(error))
                }
            }
        }
    }

    private func handle(_ json: [String: Any]) {
        if json["setupComplete"] != nil {
            onEvent?(.setupComplete)
        }
        if let toolCall = json["toolCall"] as? [String: Any],
           let calls = toolCall["functionCalls"] as? [[String: Any]] {
            let parsed = calls.compactMap { c -> FunctionCall? in
                guard let name = c["name"] as? String else { return nil }
                return FunctionCall(id: c["id"] as? String ?? UUID().uuidString, name: name, args: c["args"] as? [String: Any] ?? [:])
            }
            if !parsed.isEmpty { onEvent?(.toolCall(parsed)) }
        }
        if let content = json["serverContent"] as? [String: Any],
           let transcription = content["inputTranscription"] as? [String: Any],
           let text = transcription["text"] as? String, !text.isEmpty {
            onEvent?(.inputTranscript(text))
        }
        if let error = json["error"] as? [String: Any] {
            finish(Self.classify(code: error["code"] as? Int ?? 0, reason: error["message"] as? String ?? "\(error)"))
        }
    }

    private func finish(_ error: ServiceError?) {
        guard !finished else { return }
        finished = true
        task?.cancel()
        session?.invalidateAndCancel()
        onEvent?(.closed(error))
    }

    static func classify(code: Int, reason: String) -> ServiceError {
        let r = reason.lowercased()
        if r.contains("api key") || r.contains("api_key") || r.contains("permission_denied") || r.contains("unauthenticated")
            || r.contains("permission denied") || code == 401 || code == 403 {
            return .invalidToken
        }
        if r.contains("quota") || r.contains("resource_exhausted") || r.contains("resource has been exhausted")
            || r.contains("rate limit") || code == 429 {
            return .quota
        }
        return .other(reason.isEmpty ? "WebSocket \(code)" : reason)
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let text = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        if closeCode == .normalClosure && text.isEmpty {
            finish(nil)
        } else {
            finish(Self.classify(code: closeCode.rawValue, reason: text))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.finish(ServiceError.from(error)) }
        }
    }
}

extension GeminiLiveClient {
    /// Opens a short session and waits for setupComplete — used by the "Test" button in Settings.
    static func test(apiKey: String, model: String) async -> Result<Void, ServiceError> {
        await withCheckedContinuation { (cont: CheckedContinuation<Result<Void, ServiceError>, Never>) in
            DispatchQueue.main.async {
                let client = GeminiLiveClient()
                var done = false
                func complete(_ r: Result<Void, ServiceError>) {
                    guard !done else { return }
                    done = true
                    client.onEvent = nil
                    client.close()
                    cont.resume(returning: r)
                }
                client.onEvent = { event in
                    switch event {
                    case .setupComplete: complete(.success(()))
                    case .closed(let e): complete(.failure(e ?? .other("closed")))
                    default: break
                    }
                }
                client.connect(apiKey: apiKey, setup: [
                    "model": "models/\(model)",
                    "generationConfig": ["responseModalities": ["AUDIO"]],
                ])
                DispatchQueue.main.asyncAfter(deadline: .now() + 12) { complete(.failure(.network)) }
            }
        }
    }
}
