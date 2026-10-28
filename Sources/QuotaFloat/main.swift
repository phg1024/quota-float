import Cocoa
import QuotaKit

// A CLI that exits early must not take the app down when its stdin pipe is written to.
signal(SIGPIPE, SIG_IGN)

let arguments = CommandLine.arguments
if arguments.contains("--version") {
    print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development build")
} else if arguments.contains("--check") {
    // Prints live quota for every service without opening a window; exits nonzero if any service fails.
    var failed = false
    for service in QuotaService.allCases {
        do {
            for row in try service.fetch().windows {
                print("\(service.name) · \(row.title): \(row.remaining.map { String(format: "%.0f%% remaining", $0) } ?? "unavailable")")
            }
        } catch {
            fputs("\(service.name): \(error.localizedDescription)\n", stderr)
            failed = true
        }
    }
    exit(failed ? 1 : 0)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
