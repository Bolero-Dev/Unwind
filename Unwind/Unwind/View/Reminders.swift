//
//  Reminders.swift
//  Unwind
//
//  Lists the user's recurring weekly reminders and lets them add, edit,
//  toggle, and delete them. Each reminder is backed by local notifications
//  (see ReminderScheduler).
//
//  Created by Leah Cluff on 4/10/23.
//

import SwiftUI
import SwiftData

struct Reminders: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Reminder.createdAt) private var reminders: [Reminder]

    @State private var editing: Reminder?     // reminder being edited in the sheet
    @State private var showingNew = false

    var body: some View {
        ZStack {
            Gradient.blueGradient.ignoresSafeArea()

            VStack(spacing: 16) {
                NavHeader("Reminders") {
                    Button {
                        showingNew = true
                    } label: {
                        Image(systemName: "plus").headerIcon()
                    }
                }

                if reminders.isEmpty {
                    Spacer()
                    Text("No reminders yet.\nTap + to add one.")
                        .font(.custom("Montserrat-Regular", size: 18))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .opacity(0.7)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List {
                        ForEach(reminders) { reminder in
                            ReminderRow(reminder: reminder, onEdit: { editing = reminder })
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
        .task { await ReminderScheduler.requestAuthorization() }
        .sheet(isPresented: $showingNew) {
            NavigationStack { ReminderEditor(reminder: nil) }
        }
        .sheet(item: $editing) { reminder in
            NavigationStack { ReminderEditor(reminder: reminder) }
        }
        .preferredColorScheme(.dark)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let reminder = reminders[index]
            ReminderScheduler.cancel(reminder)
            context.delete(reminder)
        }
    }
}

// MARK: - Row

private struct ReminderRow: View {
    @Bindable var reminder: Reminder
    let onEdit: () -> Void

    var body: some View {
        HStack {
            // Tapping the time/days opens the editor; the toggle stays independent.
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.timeString)
                        .font(.custom("Montserrat-SemiBold", size: 24))
                    Text(reminder.label.isEmpty ? reminder.weekdaysString
                                                : "\(reminder.label) · \(reminder.weekdaysString)")
                        .font(.custom("Montserrat-Regular", size: 13))
                        .opacity(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: $reminder.isEnabled)
                .labelsHidden()
                .tint(.vividTangerine)
                .onChange(of: reminder.isEnabled) { _, _ in
                    ReminderScheduler.sync(reminder)
                }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
}

// MARK: - Editor

struct ReminderEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let reminder: Reminder?

    @State private var label: String
    @State private var time: Date
    @State private var selectedWeekdays: Set<Int>
    @State private var showDeleteConfirm = false

    private var isNew: Bool { reminder == nil }

    init(reminder: Reminder?) {
        self.reminder = reminder
        _label = State(initialValue: reminder?.label ?? "")
        _time = State(initialValue: reminder?.time ?? Self.defaultTime)
        _selectedWeekdays = State(initialValue: Set(reminder?.weekdays ?? []))
    }

    /// 8:00 PM today, used as the starting time for a brand-new reminder.
    private static var defaultTime: Date {
        Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: .now) ?? .now
    }

    var body: some View {
        ZStack {
            Gradient.blueGradient.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                // Same header pattern as every other screen: back arrow, title,
                // and a trash action (existing reminders only).
                NavHeader(isNew ? "New Reminder" : "Edit Reminder") {
                    if !isNew {
                        Button { showDeleteConfirm = true } label: {
                            Image(systemName: "trash").headerIcon()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 24) {
                    TextField("Label (optional)", text: $label)
                        .font(.custom("Montserrat-Regular", size: 18))
                        .padding(18)
                        .warmCard()

                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .font(.custom("Montserrat-Regular", size: 18))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Repeat")
                            .font(.custom("Montserrat-Regular", size: 18))
                        WeekdaySelector(selected: $selectedWeekdays)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Plain "Save" beneath the form — matches the Journal editor.
                Button(action: save) {
                    Text("Save")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedWeekdays.isEmpty)
                .opacity(selectedWeekdays.isEmpty ? 0.4 : 1)
                .padding(.bottom, 12)
            }
            .foregroundStyle(.white)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .tint(.white)
        .preferredColorScheme(.dark)
        .confirmationDialog("Delete this reminder?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete Reminder", role: .destructive, action: deleteReminder)
            Button("Cancel", role: .cancel) { }
        }
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let hour = components.hour ?? 20
        let minute = components.minute ?? 0
        let weekdays = selectedWeekdays.sorted()

        let target: Reminder
        if let reminder {
            reminder.label = label
            reminder.hour = hour
            reminder.minute = minute
            reminder.weekdays = weekdays
            target = reminder
        } else {
            let new = Reminder(label: label, hour: hour, minute: minute,
                               weekdays: weekdays, isEnabled: true)
            context.insert(new)
            target = new
        }

        // Make sure we have permission, then (re)schedule the notifications.
        Task {
            await ReminderScheduler.requestAuthorization()
            ReminderScheduler.sync(target)
        }
        dismiss()
    }

    private func deleteReminder() {
        guard let reminder else { return }
        ReminderScheduler.cancel(reminder)   // tear down its scheduled notifications
        context.delete(reminder)
        dismiss()
    }
}

// MARK: - Weekday selector

/// A row of seven circular toggles (S M T W T F S). Tapping one adds/removes
/// that weekday (1 = Sunday ... 7 = Saturday) from the selection.
private struct WeekdaySelector: View {
    @Binding var selected: Set<Int>

    private let symbols = Calendar.current.veryShortWeekdaySymbols  // ["S","M",...]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { weekday in
                let isOn = selected.contains(weekday)
                Button {
                    if isOn { selected.remove(weekday) } else { selected.insert(weekday) }
                } label: {
                    Text(symbols[weekday - 1])
                        .font(.custom("Montserrat-SemiBold", size: 15))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(isOn ? Color.vividTangerine : Color.white.opacity(0.12))
                        )
                        .foregroundStyle(isOn ? Color.midnight : .white)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NavigationStack { Reminders() }
        .modelContainer(for: Reminder.self, inMemory: true)
}
