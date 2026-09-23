import AppKit
import SwiftUI

/// `DictateForTickTick --snapshots <dir>` renders every screen to PNG (light and dark) for visual review.
@MainActor
enum Snapshots {
    static func run(to dir: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let settings = SettingsStore()
        let lang = ProcessInfo.processInfo.environment["SNAP_LANG"].flatMap(AppLanguage.init(rawValue:)) ?? .ru
        let savedLanguage = settings.language
        settings.language = lang

        let cal = Calendar.current
        let tomorrow15 = cal.date(bySettingHour: 15, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: Date())!)!
        let friday = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: Date()))!
        let english = lang != .ru
        let sample = [
            TaskItem(id: "t1", title: english ? "Call Anna about the contract" : "Позвонить Анне по договору",
                     notes: english ? "Confirm payment dates and the delivery address" : "Уточнить сроки оплаты и адрес доставки",
                     due: tomorrow15, allDay: false, priority: .p1),
            TaskItem(id: "t2", title: english ? "Buy cat food" : "Купить корм коту", due: friday, allDay: true, priority: .p4),
            TaskItem(id: "t3", title: english ? "Send the September report" : "Отправить отчёт за сентябрь", priority: .p2, uncertain: [.due]),
            TaskItem(id: "t4", title: english ? "Book a dentist appointment" : "Записаться к стоматологу", priority: .p3, uncertain: [.title]),
        ]

        let savedAppearance = settings.appearance

        func shot(_ name: String, dark: Bool, configure: (AppState) -> Void) {
            // The theme picker in Settings shows the theme of the shot.
            settings.appearance = dark ? .dark : .light
            let state = AppState(settings: settings, persistsDraft: false)
            state.tasks = []
            configure(state)
            let view = RootView().environmentObject(state).environmentObject(settings)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = NSRect(x: 0, y: 0, width: 420, height: 700)
            let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = hosting
            window.orderFrontRegardless()
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name)-\(dark ? "dark" : "light").png")
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            window.orderOut(nil)
        }

        for dark in [false, true] {
            shot("1-start", dark: dark) { _ in }
            shot("2-recording", dark: dark) { s in
                s.tasks = Array(sample.prefix(3))
                s.screen = .recording
                s.recState = .listening
                s.levels = (0..<28).map { i in Float(0.15 + 0.7 * abs(sin(Double(i) * 0.55))) }
            }
            shot("3-review", dark: dark) { s in
                s.tasks = sample
                s.screen = .review
                s.tasks[2].sendError = nil
            }
            shot("3b-review-expanded", dark: dark) { s in
                s.tasks = sample
                s.screen = .review
                s.expandedId = "t1"
            }
            shot("3c-manual-task", dark: dark) { s in
                s.tasks = Array(sample.prefix(2))
                s.screen = .review
                s.addManualTask()
            }
            shot("4-sent", dark: dark) { s in
                s.tasks = sample
                s.screen = .review
                s.sendResult = .init(sent: 4, total: 4)
            }
            shot("5-settings", dark: dark) { s in
                s.showSettings = true
            }
            shot("2b-error", dark: dark) { s in
                s.tasks = Array(sample.prefix(2))
                s.screen = .recording
                s.recState = .failed(.network)
            }
        }
        settings.language = savedLanguage
        settings.appearance = savedAppearance
        print("snapshots written to \(dir)")
    }
}
