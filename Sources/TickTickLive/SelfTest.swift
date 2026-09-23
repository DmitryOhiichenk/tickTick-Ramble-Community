import Foundation

/// `TickTickLive --selftest` — checks date parsing and the TickTick payload without network or UI.
enum SelfTest {
    static func run() -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        // Wednesday, 2026-09-23 10:00 local time.
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 10, minute: 0))!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"

        let cases: [(String, String?, Bool)] = [
            ("tomorrow", "2026-09-24 00:00", false),
            ("tomorrow 3pm", "2026-09-24 15:00", true),
            ("next Friday 3pm", "2026-09-25 15:00", true),
            ("friday", "2026-09-25 00:00", false),
            ("Wednesday", "2026-09-30 00:00", false),
            ("today 18:00", "2026-09-23 18:00", true),
            ("September 30 10:00", "2026-09-30 10:00", true),
            ("in 2 hours", "2026-09-23 12:00", true),
            ("in 3 days", "2026-09-26 00:00", false),
            ("2026-10-01", "2026-10-01 00:00", false),
            ("2026-10-01T09:30:00", "2026-10-01 09:30", true),
            ("завтра в 15:00", "2026-09-24 15:00", true),
            ("послезавтра", "2026-09-25 00:00", false),
            ("в пятницу в 9", "2026-09-25 09:00", true),
            ("30 сентября 14:30", "2026-09-30 14:30", true),
            ("через 2 дня", "2026-09-25 00:00", false),
            ("післязавтра о 10:00", "2026-09-25 10:00", true),
            ("у середу", "2026-09-30 00:00", false),
            ("mañana 15:00", "2026-09-24 15:00", true),
            ("martes 15", "2026-09-29 00:00", false),
            ("jutro o 8", "2026-09-24 08:00", true),
            ("morgen um 15 Uhr", "2026-09-24 15:00", true),
            ("domani alle 9", "2026-09-24 09:00", true),
            ("30.09 18:00", "2026-09-30 18:00", true),
            ("18:00", "2026-09-23 18:00", true),
            ("9:00", "2026-09-24 09:00", true),
            ("tonight", "2026-09-23 20:00", true),
            ("ср, 30 сент., 14:00", "2026-09-30 14:00", true),
            ("Mi., 30. Sept.", "2026-09-30 00:00", false),
            ("mer 30 set", "2026-09-30 00:00", false),
            ("śr., 30 wrz 9:15", "2026-09-30 09:15", true),
            ("5 жовтня о 18:30", "2026-10-05 18:30", true),
            ("в 7 вечера", "2026-09-23 19:00", true),
            ("", nil, false),
            ("none", nil, false),
        ]

        var failures = 0
        for (input, expected, expectTime) in cases {
            let result = DateParser.parse(input, now: now, calendar: cal)
            let got = result.map { f.string(from: $0.date) }
            let ok = got == expected && (result == nil || result!.hasTime == expectTime)
            if !ok { failures += 1 }
            print("\(ok ? "✓" : "✗") \(input.isEmpty ? "<empty>" : input) → \(got ?? "nil")\(result.map { $0.hasTime ? " (time)" : " (all day)" } ?? "")\(ok ? "" : "   expected \(expected ?? "nil")")")
        }

        // Priority mapping and payload.
        let task = TaskItem(id: "t1", title: "Call Anna", notes: "about the contract",
                            due: cal.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 15)), allDay: false,
                            priority: .p1)
        let body = TickTickClient.body(for: task, timeZone: .current)
        let payloadOK = body["priority"] as? Int == 5 && body["content"] as? String == "about the contract"
            && (body["reminders"] as? [String]) == ["TRIGGER:PT0S"]
            && (body["dueDate"] as? String)?.hasPrefix("2026-09-24T15:00:00") == true
        print("\(payloadOK ? "✓" : "✗") TickTick payload: \(body)")
        if !payloadOK { failures += 1 }

        let mappingOK = Priority.allCases.map(\.tickTickValue) == [5, 3, 1, 0]
            && Priority.allCases.allSatisfy { Priority(tickTick: $0.tickTickValue) == $0 }
        print("\(mappingOK ? "✓" : "✗") priority mapping P1→5 P2→3 P3→1 P4→0")
        if !mappingOK { failures += 1 }

        print(failures == 0 ? "All checks passed" : "\(failures) check(s) failed")
        return failures == 0
    }
}
