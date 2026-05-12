import SwiftUI
import VoiceTypeCore

struct DictionarySettingsView: View {
    @EnvironmentObject var dictionary: UserDictionary
    @State private var newTerm: String = ""
    @State private var newNote: String = ""
    @State private var selection = Set<UUID>()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
            Text("Dictionary").font(.title2.bold())
            Text("Add names, acronyms, and jargon you say often. VoiceType passes these to the transcription model and the LLM editor so spelling stays consistent.")
                .foregroundStyle(.secondary)

            HStack {
                TextField("Term (e.g. Will, Anthropic, MLX)", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submit)
                TextField("Note (optional)", text: $newNote)
                    .textFieldStyle(.roundedBorder)
                Button("Add", action: submit).disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Table(dictionary.entries, selection: $selection) {
                TableColumn("Term") { e in
                    TextField("", text: Binding(
                        get: { e.term },
                        set: { newValue in
                            var updated = e; updated.term = newValue; dictionary.update(updated)
                        }
                    ))
                }
                TableColumn("Note") { e in
                    TextField("", text: Binding(
                        get: { e.note },
                        set: { newValue in
                            var updated = e; updated.note = newValue; dictionary.update(updated)
                        }
                    ))
                }
            }
            .frame(minHeight: 220)

            HStack {
                Button(role: .destructive) {
                    dictionary.remove(ids: selection)
                    selection.removeAll()
                } label: {
                    Label("Remove selected", systemImage: "trash")
                }
                .disabled(selection.isEmpty)
                Spacer()
                Text("\(dictionary.entries.count) entries")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(.secondary)
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
