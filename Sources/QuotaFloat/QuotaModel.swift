import Foundation
import QuotaKit

enum QuotaService: CaseIterable, Identifiable {
    case codex, claude

    var id: Self { self }
    var name: String { self == .codex ? "Codex" : "Claude" }
    var symbol: String { self == .codex ? "sparkle" : "asterisk" }
    var scope: String { self == .codex ? "Account-wide" : "Plan" }
    /// Claude is read less often because each check starts a full Claude Code process.
    var refreshInterval: TimeInterval { self == .codex ? 60 : 300 }

    func fetch() throws -> QuotaResult {
        switch self {
        case .codex: return try CodexQuota.fetch()
        case .claude: return try ClaudeQuota.fetch()
        }
    }
}

struct QuotaSection {
    var windows: [QuotaWindow] = []
    var plan: String?
    var updated: Date?
    var error: String?
    var loading = false

    var isStale: Bool { error != nil }
}

/// Keeps the last successful result per service. A failed refresh records the error but keeps the old values.
final class QuotaModel: ObservableObject {
    @Published private var sections: [QuotaService: QuotaSection] = [:]
    var onUpdate: (() -> Void)?
    private var timer: Timer?
    private var lastAttempt: [QuotaService: Date] = [:]

    subscript(service: QuotaService) -> QuotaSection { sections[service] ?? QuotaSection() }
    var isRefreshingAll: Bool { QuotaService.allCases.allSatisfy { self[$0].loading } }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh(onlyIfDue: true) }
    }

    func refresh(onlyIfDue: Bool = false) {
        for service in QuotaService.allCases {
            if onlyIfDue, let last = lastAttempt[service], Date().timeIntervalSince(last) < service.refreshInterval - 10 { continue }
            load(service)
        }
    }

    private func load(_ service: QuotaService) {
        guard !self[service].loading else { return }
        lastAttempt[service] = Date()
        sections[service, default: QuotaSection()].loading = true
        DispatchQueue.global(qos: .utility).async {
            let result = Result { try service.fetch() }
            DispatchQueue.main.async {
                var section = self[service]
                section.loading = false
                switch result {
                case .success(let value):
                    section.windows = value.windows
                    section.plan = value.plan
                    section.updated = Date()
                    section.error = nil
                case .failure(let error):
                    section.error = error.localizedDescription
                }
                self.sections[service] = section
                self.onUpdate?()
            }
        }
    }
}
