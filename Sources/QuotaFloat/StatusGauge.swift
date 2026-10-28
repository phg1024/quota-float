import Cocoa
import QuotaKit

/// Compact menu-bar gauge. Per service: its symbol, two stacked bars for the first two windows (usually 5-hour on top,
/// weekly below) and the lower of those two remaining percentages. Drawn at display time so it follows the menu bar's
/// light or dark appearance.
func statusGaugeImage(for sections: [(service: QuotaService, section: QuotaSection)]) -> NSImage {
    let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    let labels = sections.map { item -> String in
        if let lowest = item.section.windows.prefix(2).compactMap(\.remaining).min() { return String(format: "%.0f", lowest) }
        return item.section.loading && item.section.updated == nil ? "…" : "–"
    }
    let symbolWidth: CGFloat = 12, barWidth: CGFloat = 14, gap: CGFloat = 3, separator: CGFloat = 8
    let textWidths = labels.map { ceil(($0 as NSString).size(withAttributes: [.font: font]).width) }
    let width = textWidths.reduce(0) { $0 + symbolWidth + gap + barWidth + gap + $1 } + separator * CGFloat(max(0, sections.count - 1))

    let image = NSImage(size: NSSize(width: width, height: 18), flipped: false) { rect in
        var x: CGFloat = 0
        for (index, item) in sections.enumerated() {
            let ink = NSColor.labelColor.withAlphaComponent(item.section.isStale ? 0.45 : 1)
            if let symbol = NSImage(systemSymbolName: item.service.symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 10, weight: .bold)) {
                let size = symbol.size
                let tinted = NSImage(size: size, flipped: false) { bounds in
                    symbol.draw(in: bounds)
                    ink.set()
                    bounds.fill(using: .sourceAtop)
                    return true
                }
                tinted.draw(in: NSRect(x: x + (symbolWidth - size.width) / 2, y: (rect.height - size.height) / 2,
                                       width: size.width, height: size.height))
            }
            x += symbolWidth + gap

            let windows = Array(item.section.windows.prefix(2))
            for (row, y) in [CGFloat(12), 5].enumerated() {
                NSColor.labelColor.withAlphaComponent(0.22).setFill()
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barWidth, height: 3), xRadius: 1.5, yRadius: 1.5).fill()
                guard row < windows.count, let remaining = windows[row].remaining else { continue }
                let fill = item.section.isStale ? ink : remaining <= 10 ? .systemRed : remaining <= 25 ? .systemOrange : ink
                fill.setFill()
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: max(1.5, barWidth * remaining / 100), height: 3),
                             xRadius: 1.5, yRadius: 1.5).fill()
            }
            x += barWidth + gap

            let text = labels[index] as NSString
            let textHeight = text.size(withAttributes: [.font: font]).height
            text.draw(at: NSPoint(x: x, y: (rect.height - textHeight) / 2), withAttributes: [.font: font, .foregroundColor: ink])
            x += textWidths[index] + separator
        }
        return true
    }
    image.isTemplate = false
    return image
}

/// One line of text per service for the tooltip, accessibility label and menu.
func statusSummary(_ service: QuotaService, _ section: QuotaSection) -> String {
    let title = service.name + (section.plan.map { " (\($0.capitalized))" } ?? "")
    if section.windows.isEmpty { return "\(title): " + (section.error ?? (section.loading ? "reading…" : "unavailable")) }
    let rows = section.windows.map { "\($0.title) \($0.remaining.map { String(format: "%.0f%% left", $0) } ?? "unavailable")" }
    return "\(title): " + rows.joined(separator: " · ") + (section.isStale ? " (stale)" : "")
}
