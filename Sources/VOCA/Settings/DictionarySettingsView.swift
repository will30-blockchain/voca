import SwiftUI
import VOCACore

struct DictionarySettingsView: View {
    @EnvironmentObject var dictionary: UserDictionary
    @State private var newTerm: String = ""
    @State private var newNote: String = ""
    @State private var selection = Set<UUID>()

    var body: some View {
        SettingsPage(
            title: "Dictionary",
            subtitle: "Names, acronyms, and jargon you say often. VOCA passes these to both the transcription model and the LLM editor so spelling stays consistent."
        ) {
            addEntryCard
            entriesCard
        }
    }

    // MARK: - Cards

    private var addEntryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("Add a term")
                HStack(alignment: .top, spacing: DesignTokens.Space.sm) {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                        Text("Term")
                            .font(DesignTokens.Typography.bodyEmphasis)
                            .vtPrimaryText()
                        TextField("e.g. Anthropic, MLX, Will", text: $newTerm)
                            .textFieldStyle(.roundedBorder)
                            .font(DesignTokens.Typography.body)
                            .onSubmit(submit)
                    }
                    VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                        Text("Note")
                            .font(DesignTokens.Typography.bodyEmphasis)
                            .vtPrimaryText()
                        TextField("Optional context", text: $newNote)
                            .textFieldStyle(.roundedBorder)
                            .font(DesignTokens.Typography.body)
                            .onSubmit(submit)
                    }
                    VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                        Text(" ")
                            .font(DesignTokens.Typography.bodyEmphasis)
                        Button("Add", action: submit)
                            .buttonStyle(.borderedProminent)
                            .tint(DesignTokens.Color.accent)
                            .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private var entriesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle(
                    "Entries",
                    trailing: AnyView(
                        Text("\(dictionary.entries.count)")
                            .font(DesignTokens.Typography.captionEmphasis)
                            .vtTertiaryText()
                    )
                )

                Table(dictionary.entries, selection: $selection) {
                    TableColumn("Term") { entry in
                        TextField("", text: Binding(
                            get: { entry.term },
                            set: { newValue in
                                var updated = entry
                                updated.term = newValue
                                dictionary.update(updated)
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.body)
                    }
                    TableColumn("Note") { entry in
                        TextField("", text: Binding(
                            get: { entry.note },
                            set: { newValue in
                                var updated = entry
                                updated.note = newValue
                                dictionary.update(updated)
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.body)
                        .vtSecondaryText()
                    }
                }
                .frame(minHeight: 240)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                        .fill(DesignTokens.Color.surfaceSunken)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                        .stroke(DesignTokens.Color.borderSubtle, lineWidth: 0.5)
                )

                HStack {
                    Button(role: .destructive) {
                        dictionary.remove(ids: selection)
                        selection.removeAll()
                    } label: {
                        Label("Remove selected", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selection.isEmpty)
                    Spacer()
                }
            }
        }
    }

    private func submit() {
        let term = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        dictionary.add(term, note: newNote.trimmingCharacters(in: .whitespacesAndNewlines))
        newTerm = ""
        newNote = ""
    }
}
