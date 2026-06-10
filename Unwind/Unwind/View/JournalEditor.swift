//
//  JournalEditor.swift
//  Unwind
//
//  Compose + edit screen. Title and body live in one container, separated by a
//  soft hand-drawn divider. Delete (existing entries) is a trash icon in the
//  header; Save is a plain word beneath the container.
//

import SwiftUI
import SwiftData

struct JournalEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// The entry being edited, or nil when composing a new one.
    let entry: JournalEntry?

    @State private var title: String
    @State private var bodyText: String
    @State private var showDeleteConfirm = false

    private var isNew: Bool { entry == nil }

    init(entry: JournalEntry?) {
        self.entry = entry
        _title = State(initialValue: entry?.title ?? "")
        _bodyText = State(initialValue: entry?.body ?? "")
    }

    private var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Gradient.blueGradient.ignoresSafeArea()

            VStack(spacing: 20) {
                // Trash (existing entries only) sits where every other screen's
                // action icon sits, matching the back button.
                NavHeader("Journal") {
                    if !isNew {
                        Button { showDeleteConfirm = true } label: {
                            Image(systemName: "trash").headerIcon()
                        }
                    }
                }

                // Title + body in a single container, split by a soft divider.
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Title", text: $title)
                        .font(.custom("Montserrat-SemiBold", size: 22))
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 4)   // sit the line close under the title

                    brushLine

                    TextEditor(text: $bodyText)
                        .font(.custom("Montserrat-Regular", size: 17))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)     // writing room below the line
                        .padding(.bottom, 10)
                        .frame(maxHeight: .infinity)
                }
                .warmCard()
                .padding(.horizontal)

                // Plain "Save" beneath the container — no rounded button.
                Button(action: save) {
                    Text("Save")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
                .disabled(isEmpty)
                .opacity(isEmpty ? 0.4 : 1)
                .padding(.bottom, 12)
            }
            .foregroundStyle(.white)
        }
        .tapToDismissKeyboard()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .tint(.white)
        .preferredColorScheme(.dark)
        .confirmationDialog("Delete this entry?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete Entry", role: .destructive, action: deleteEntry)
            Button("Cancel", role: .cancel) { }
        }
    }

    /// Hand-drawn brushstroke divider between the title and the body. A fixed
    /// height makes it a touch bolder than its natural (very thin) proportions.
    private var brushLine: some View {
        Image("TitleDivider")
            .resizable()
            .frame(height: 7)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
    }

    private func save() {
        if let entry {
            entry.title = title
            entry.body = bodyText
        } else {
            let newEntry = JournalEntry(title: title, body: bodyText)
            context.insert(newEntry)
        }
        dismiss()
    }

    private func deleteEntry() {
        guard let entry else { return }
        context.delete(entry)
        dismiss()
    }
}

#Preview("New") {
    NavigationStack { JournalEditor(entry: nil) }
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
