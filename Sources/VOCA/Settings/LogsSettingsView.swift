import AppKit
import SwiftUI
import VOCACore

struct LogsSettingsView: View {
    @EnvironmentObject var log: LogStore

    @State private var levelFilter: Filter = .all
    @State private var categoryFilter: LogStore.Category? = nil
    @State private var expanded: Set<UUID> = []

    enum Filter: String, CaseIterable, Identifiable {
        case all, info, warning, error
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    var body: some View {
        SettingsPage(
            title: "Logs",
            subtitle: "Every step the engine takes, persisted to ~/Library/Application Support/VOCA/log.jsonl. Use this to see why a take dropped or which provider failed."
        ) {
            filtersCard
            entriesCard
            footerCard
        }
    }

    private var filtersCard: some View {
        Card {
            HStack(alignment: .center, spacing: DesignTokens.Space.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                    Text("Level")
                        .font(DesignTokens.Typography.bodyEmphasis)
                        .vtPrimaryText()
                    Picker("", selection: $levelFilter) {
                        ForEach(Filter.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(minWidth: 280)
                }
                VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                    Text("Category")
                        .font(DesignTokens.Typography.bodyEmphasis)
                        .vtPrimaryText()
                    Picker("", selection: $categoryFilter) {
                        Text("All").tag(LogStore.Category?.none)
                        ForEach(LogStore.Category.allCases, id: \.self) { c in
                            Text(c.displayName).tag(LogStore.Category?.some(c))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Spacer()
            }
        }
    }

    private var filtered: [LogStore.Entry] {
        log.entries.filter { entry in
            let levelOk: Bool = {
                switch levelFilter {
                case .all: return true
                case .info: return entry.level == .info
                case .warning: return entry.level == .warning
                case .error: return entry.level == .error
                }
            }()
            let categoryOk = categoryFilter == nil || entry.category == categoryFilter
            return levelOk && categoryOk
        }
    }

    private var entriesCard: some View {
        Card(padding: DesignTokens.Space.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                SectionTitle(
                    "Recent activity",
                    trailing: AnyView(
                        Text("\(filtered.count) of \(log.entries.count)")
                            .font(DesignTokens.Typography.caption)
                            .vtTertiaryText()
                    )
                )
                if filtered.isEmpty {
                    Text("Nothing matches the current filter.")
                        .font(DesignTokens.Typography.body)
                        .vtSecondaryText()
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                                .fill(DesignTokens.Color.surfaceSunken)
                        )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filtered) { entry in
                                LogRow(
                                    entry: entry,
                                    isExpanded: expanded.contains(entry.id),
                                    toggle: { toggleExpand(entry.id) }
                                )
                            }
                        }
                    }
                    .frame(minHeight: 280, maxHeight: 480)
                }
            }
        }
    }

    private var footerCard: some View {
        Card {
            HStack(spacing: DesignTokens.Space.sm) {
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(log.plainText(), forType: .string)
                } label: {
                    Label("Copy all", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([log.storagePath])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    log.clear()
                    expanded.removeAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func toggleExpand(_ id: UUID) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }
}

// MARK: - Row

private struct LogRow: View {
    let entry: LogStore.Entry
    let isExpanded: Bool
    let toggle: () -> Void

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(alignment: .top, spacing: DesignTokens.Space.sm) {
                    levelDot
                    Text(Self.timeFormatter.string(from: entry.date))
                        .font(DesignTokens.Typography.mono)
                        .vtTertiaryText()
                        .frame(width: 64, alignment: .leading)
                    Text(entry.category.displayName)
                        .font(DesignTokens.Typography.captionEmphasis)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(DesignTokens.Color.surfaceSunken)
                        )
                        .vtSecondaryText()
                        .frame(width: 80, alignment: .leading)
                    Text(entry.message)
                        .font(DesignTokens.Typography.body)
                        .vtPrimaryText()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !entry.detail.isEmpty {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .vtTertiaryText()
                    }
                }
                .padding(.horizontal, DesignTokens.Space.sm)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isExpanded && !entry.detail.isEmpty {
                detailGrid
                    .padding(.horizontal, DesignTokens.Space.sm)
                    .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(rowBackground)
        )
    }

    private var rowBackground: Color {
        switch entry.level {
        case .error: return DesignTokens.Color.danger.opacity(0.06)
        case .warning: return DesignTokens.Color.warning.opacity(0.06)
        case .info: return Color.clear
        }
    }

    private var levelDot: some View {
        Circle()
            .fill(levelColor)
            .frame(width: 8, height: 8)
            .padding(.top, 7)
    }

    private var levelColor: Color {
        switch entry.level {
        case .info: return DesignTokens.Color.textTertiary
        case .warning: return DesignTokens.Color.warning
        case .error: return DesignTokens.Color.danger
        }
    }

    private var detailGrid: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entry.detail.sorted(by: { $0.key < $1.key }), id: \.key) { kv in
                HStack(alignment: .top, spacing: DesignTokens.Space.sm) {
                    Text(kv.key)
                        .font(DesignTokens.Typography.mono)
                        .vtTertiaryText()
                        .frame(width: 120, alignment: .trailing)
                    Text(kv.value)
                        .font(DesignTokens.Typography.mono)
                        .vtSecondaryText()
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.leading, 80)
    }
}
