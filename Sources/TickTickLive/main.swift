import AppKit

if CommandLine.arguments.contains("--selftest") {
    exit(SelfTest.run() ? 0 : 1)
}

if let i = CommandLine.arguments.firstIndex(of: "--snapshots"), i + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated { Snapshots.run(to: CommandLine.arguments[i + 1]) }
    exit(0)
}

let application = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
application.run()
