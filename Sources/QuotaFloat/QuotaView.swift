import SwiftUI
import QuotaKit

extension QuotaService {
    var tint: Color { self == .codex ? .mint : Color(red: 0.85, green: 0.47, blue: 0.34) }
}

func barColor(remaining: Double) -> Color {
    remaining <= 10 ? .red : remaining <= 25 ? .orange : .mint
}

struct QuotaView: View {
    @ObservedObject var model: QuotaModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                HStack(spacing: 9) {
                    Image(systemName: "gauge.with.dots.needle.67percent").foregroundStyle(.secondary)
                    Text("Quota").font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .overlay(WindowDragHandle())
                .help("Drag to move the quota window")
                Button { model.refresh() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12))
                }
                .buttonStyle(.plain).disabled(model.isRefreshingAll).help("Refresh quota")
                Button { NSApp.hide(nil) } label: {
                    Image(systemName: "minus").font(.system(size: 12))
                }
                .buttonStyle(.plain).help("Hide window; reopen from the menu bar")
            }
            ForEach(QuotaService.allCases) { service in
                if service != QuotaService.allCases.first {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                }
                QuotaSectionView(service: service, section: model[service])
            }
        }
        .padding(18).frame(width: 294)
        .background(Color(red: 0.075, green: 0.09, blue: 0.11))
        .preferredColorScheme(.dark)
    }
}

struct QuotaSectionView: View {
    let service: QuotaService
    let section: QuotaSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: service.symbol).foregroundStyle(service.tint).font(.system(size: 11, weight: .semibold))
                Text(service.name).font(.system(size: 12, weight: .semibold))
                Spacer()
                Group {
                    if section.loading { Text("Refreshing…") }
                    else if let date = section.updated { Text(date, style: .time) }
                }
                .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            if section.windows.isEmpty {
                Text(section.loading ? "Reading your quota…" : "Quota unavailable")
                    .foregroundStyle(.secondary).font(.system(size: 13))
            }
            ForEach(section.windows) { QuotaRow(window: $0) }
            if let error = section.error {
                Text((section.updated == nil ? "" : "Stale data · ") + error)
                    .font(.system(size: 10)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            Text(section.plan.map { $0.capitalized + " · " + service.scope } ?? service.scope)
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
}

struct QuotaRow: View {
    let window: QuotaWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(window.remaining.map { String(format: "%.0f%%", $0) } ?? "—")
                    .font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("left").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.09))
                    if let remaining = window.remaining {
                        Capsule().fill(barColor(remaining: remaining)).frame(width: geo.size.width * remaining / 100)
                    }
                }
            }
            .frame(height: 5)
            if let reset = window.reset {
                Text("Resets \(reset.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
