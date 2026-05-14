import SwiftUI
import VOCACore

struct MemorySettingsView: View {
    @EnvironmentObject var memory: PersonalMemory
    @State private var draftFacts: String = ""
    @State private var didLoadDraft = false

    var body: some View {
        SettingsPage(
            title: "Personal memory",
            subtitle: "Background context VOCA appends to the LLM editor. The more specific the better — name, role, projects, recurring people."
        ) {
            factsCard
            learnedPhrasesCard
            footerCard
        }
    }

    // MARK: - Cards

    private var factsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("Personal facts")

                TextEditor(text: $draftFacts)
                    .font(DesignTokens.Typography.body)
                    .scrollContentBackground(.hidden)
                    .padding(DesignTokens.Space.sm)
                    .frame(minHeight: 160)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                            .fill(DesignTokens.Color.surfaceSunken)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                            .stroke(DesignTokens.Color.borderSubtle, lineWidth: 0.5)
                    )
                    .onChange(of: draftFacts) { _, newValue in
                        if didLoadDraft { memory.setPersonalFacts(newValue) }
                    }
                    .onAppear {
                        draftFacts = memory.snapshot.personalFacts
                        didLoadDraft = true
                    }

                Text("Free-form. Saved as you type.")
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
        }
    }

    private var learnedPhrasesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("Auto-learned phrases")
                Text("Phrases you've spoken more than once. VOCA uses them as transcription hints.")
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()

                let phrases = memory.topPhrases(limit: 40)
                if phrases.isEmpty {
                    Text("No learned phrases yet — they appear after a few dictations.")
                        .font(DesignTokens.Typography.caption)
                        .vtTertiaryText()
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                                .fill(DesignTokens.Color.surfaceSunken)
                        )
                } else {
                    ScrollView {
                        WrapHStack(items: phrases, spacing: DesignTokens.Space.xs) { phrase in
                            Text(phrase)
                                .font(DesignTokens.Typography.captionEmphasis)
                                .foregroundStyle(DesignTokens.Color.accent)
                                .padding(.horizontal, DesignTokens.Space.sm)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(DesignTokens.Color.accentTint)
                                )
                        }
                        .padding(.vertical, DesignTokens.Space.xs)
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
    }

    private var footerCard: some View {
        Card {
            HStack(alignment: .center, spacing: DesignTokens.Space.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
                    Text("Total dictations")
                        .font(DesignTokens.Typography.bodyEmphasis)
                        .vtPrimaryText()
                    Text("\(memory.snapshot.totalDictations)")
                        .font(DesignTokens.Typography.title2)
                        .vtSecondaryText()
                }
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    memory.reset()
                    draftFacts = ""
                } label: {
                    Label("Reset memory", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Layout

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
    var spacing: CGFloat = DesignTokens.Space.sm

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
