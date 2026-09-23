import Foundation

/// TickTick Open API (https://developer.ticktick.com/docs).
struct TickTickClient {
    let token: String
    private let base = URL(string: "https://api.ticktick.com/open/v1/")!

    func projectCount() async throws -> Int {
        var request = URLRequest(url: base.appendingPathComponent("project"))
        authorize(&request)
        let (data, _) = try await perform(request)
        return (try? JSONSerialization.jsonObject(with: data) as? [Any])?.count ?? 0
    }

    /// Creates the task in Inbox and returns TickTick's task id.
    func createTask(_ task: TaskItem, timeZone: TimeZone = .current) async throws -> String {
        var request = URLRequest(url: base.appendingPathComponent("task"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.body(for: task, timeZone: timeZone))
        let (data, _) = try await perform(request)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? String ?? UUID().uuidString
    }

    static func body(for task: TaskItem, timeZone: TimeZone) -> [String: Any] {
        var body: [String: Any] = [
            "title": task.title.trimmingCharacters(in: .whitespacesAndNewlines),
            "priority": task.priority.tickTickValue,
        ]
        let notes = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { body["content"] = notes }
        if let due = task.due {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = timeZone
            let date = task.allDay ? cal.startOfDay(for: due) : due
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = timeZone
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            let s = f.string(from: date)
            body["startDate"] = s
            body["dueDate"] = s
            body["timeZone"] = timeZone.identifier
            body["isAllDay"] = task.allDay
            if !task.allDay {
                // A regular reminder at the due time.
                body["reminders"] = ["TRIGGER:PT0S"]
            }
        }
        return body
    }

    private func authorize(_ request: inout URLRequest) {
        request.setValue("Bearer \(token.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ServiceError.from(error)
        }
        guard let http = response as? HTTPURLResponse else { throw ServiceError.other("No HTTP response") }
        switch http.statusCode {
        case 200..<300: return (data, http)
        case 401, 403: throw ServiceError.invalidToken
        case 429: throw ServiceError.quota
        default:
            let text = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw ServiceError.other("HTTP \(http.statusCode) \(text)")
        }
    }
}
