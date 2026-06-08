//
//  JournalEntryList.swift
//  Unwind
//
//  Created by Leah Cluff on 4/10/23.
//

import SwiftUI
import SwiftData

struct JournalEntryList: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @State private var showingNewEntry = false

    var body: some View {
        ZStack {
            Gradient.blueGradient.ignoresSafeArea()

            VStack(spacing: 16) {
                NavHeader("Entries") {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "plus").headerIcon()
                    }
                }

                if entries.isEmpty {
                    Spacer()
                    Text("No entries yet.\nTap + to write your first.")
                        .font(.custom("Montserrat-Regular", size: 18))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .opacity(0.7)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink {
                                JournalEditor(entry: entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title.isEmpty ? "Untitled" : entry.title)
                                        .font(.custom("Montserrat-SemiBold", size: 20))
                                    Text(entry.createdAt, style: .date)
                                        .font(.custom("Montserrat-Regular", size: 13))
                                        .opacity(0.6)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                            }
                            .listRowBackground(
                                Gradient.cardFill
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .padding(.vertical, 6)
                            )
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .foregroundStyle(.white)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .tint(.white)
        .sheet(isPresented: $showingNewEntry) {
            NavigationStack {
                JournalEditor(entry: nil)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(entries[index])
        }
    }
}

#Preview {
    NavigationStack {
        JournalEntryList()
    }
    .modelContainer(for: JournalEntry.self, inMemory: true)
}
