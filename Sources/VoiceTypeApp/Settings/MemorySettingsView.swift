import SwiftUI
import VoiceTypeCore

struct MemorySettingsView: View {
    @EnvironmentObject var memory: PersonalMemory
    @State private var draftFacts: String = ""
    @State private var didLoadDraft = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
            Text("Personal memory").font(.title2.bold())
            Text("Anything you write here is appended to the LLM editor's context as background facts. The more specific the better — name, role, projects, recurring people.")
                .foregroundStyle(.secondary)

            TextEditor(text: $draftFacts)
                .font(DesignTokens.Font.body)
                .frame(minHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                        .stroke(DesignTokens.Color.border)
                )
                .onChange(of: draftFacts) { _, newValue in
                    if didLoadDraft { memory.setPersonalFacts(newValue) }
                }
                .onAppear {
                    draftFacts = memory.snapshot.personalFacts
                    didLoadDraft = true
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("Auto-learned phrases").font(.headline)
                Text("These are phrases you've spoken more than once. VoiceType uses them as transcription hints.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(.secondary)
                let phrases = memory.topPhrases(limit: 40)
                if phrases.isEmpty {
                    Text("No learned phrases yet — they appear after a few dictations.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ScrollView {
                        WrapHStack(items: phrases, spacing: 6) { phrase in
                            Text(phrase)
                                .font(DesignTokens.Font.body)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(
                                    Capsule().fill(DesignTokens.Color.surfaceElevated)
                                )
                                .overlay(Capsule().stroke(DesignTokens.Color.border))
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }

            HStack {
                Text("Total dictations: \(memory.snapshot.totalDictations)")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    memory.reset()
                    draftFacts = ""
                } label: {
                    Label("Reset memory", systemImage: "trash")
                }
            }
        }
    }
}

/// Lightweight wrapping HStack for tag-cloud layout.
struct WrapHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        FlowLayout(spacing: spacing) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width.isFinite ? width : currentX, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
