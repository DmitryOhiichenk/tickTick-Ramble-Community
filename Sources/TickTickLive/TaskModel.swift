import Foundation

enum Priority: Int, Codable, CaseIterable, Identifiable {
    case p1 = 1, p2, p3, p4

    var id: Int { rawValue }
    var label: String { "P\(rawValue)" }

    /// TickTick stores priority as 0 / 1 / 3 / 5.
    var tickTickValue: Int {
        switch self {
        case .p1: return 5
        case .p2: return 3
        case .p3: return 1
        case .p4: return 0
        }
    }

    init(tickTick value: Int) {
        switch value {
        case 5: self = .p1
        case 3: self = .p2
        case 1: self = .p3
        default: self = .p4
        }
    }
}

enum TaskField: String, Codable, CaseIterable {
    case title, notes, due, priority
}

struct TaskItem: Identifiable, Codable, Equatable {
    /// Local id (t1, t2…). Assigned by the app, never sent to TickTick.
    var id: String
    var title: String
    var notes: String = ""
    var due: Date?
    var allDay: Bool = false
    var priority: Priority = .p4
    var uncertain: Set<TaskField> = []
    /// TickTick task id once the task has been created (prevents duplicates on retry).
    var remoteId: String?
    var sendError: String?
}

enum ServiceError: Error, Equatable {
    case invalidToken
    case network
    case quota
    case other(String)

    static func from(_ error: Error) -> ServiceError {
        if let e = error as? ServiceError { return e }
        if let u = error as? URLError {
            switch u.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
                return .network
            default:
                return .other(u.localizedDescription)
            }
        }
        return .other(error.localizedDescription)
    }
}
