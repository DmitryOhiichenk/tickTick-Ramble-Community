import SwiftUI

/// Inline editor of an expanded card on the review screen. Changes are saved as you type.
struct TaskEditor: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @Binding var task: TaskItem

    @FocusState private var titleFocused: Bool
    @FocusState private var notesFocused: Bool
    @State private var showNotes = false
    @State private var dueText = ""
    @State private var dueError = false
    @State private var showCalendar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                TextField(settings.t(.titlePlaceholder), text: $task.title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .focused($titleFocused)
                    .onSubmit { app.endEditing() }
                    .inputBox(focused: titleFocused, uncertain: task.uncertain.contains(.title))
                    .onChange(of: task.title) { task.uncertain.remove(.title) }
                IconButton(systemName: "chevron.up", size: 16) { app.toggleExpanded(task.id) }
            }

            if showNotes || !task.notes.isEmpty {
                TextField(settings.t(.notesPlaceholder), text: $task.notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1...8)
                    .focused($notesFocused)
                    .inputBox(focused: notesFocused, uncertain: task.uncertain.contains(.notes))
                    .onChange(of: task.notes) { task.uncertain.remove(.notes) }
            } else {
                Button(settings.t(.addDescription)) {
                    showNotes = true
                    DispatchQueue.main.async { notesFocused = true }
                }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.accent)
            }

            Divider().overlay(Theme.separator)

            dueRow

            VStack(alignment: .leading, spacing: 6) {
                Text(settings.t(.priority))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
                PriorityPicker(selection: $task.priority)
                    .uncertainHighlight(task.uncertain.contains(.priority))
                    .onChange(of: task.priority) { task.uncertain.remove(.priority) }
            }

            HStack {
                Button { app.delete(task.id) } label: {
                    Label(settings.t(.deleteTask), systemImage: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .onAppear {
            titleFocused = true
            syncDueText()
        }
        // Closing the editor keeps a date typed without pressing Return.
        .onDisappear { applyDueText() }
        .onChange(of: task.due) { syncDueText() }
        .onChange(of: task.allDay) { syncDueText() }
    }

    private var dueRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(Theme.secondary)
                TextField(settings.t(.duePlaceholder), text: $dueText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit(applyDueText)
                Button { showCalendar.toggle() } label: {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showCalendar, arrowEdge: .bottom) { calendarPopover }
                if task.due != nil {
                    Button { task.due = nil; task.allDay = false } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(settings.t(.clearDate))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(task.uncertain.contains(.due) ? Theme.uncertainFill : Theme.chip))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(dueError ? Theme.error : .clear, lineWidth: 1))

            if dueError {
                Text(settings.t(.unparsedDate)).font(.system(size: 11)).foregroundStyle(Theme.error)
            }
        }
    }

    private var calendarPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker("", selection: dateBinding, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Toggle(settings.t(.allDay), isOn: allDayBinding)
                    .toggleStyle(.checkbox)
                Spacer()
                if !task.allDay && task.due != nil {
                    DatePicker("", selection: dateBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                }
            }
        }
        .padding(12)
        .frame(width: 260)
        .environment(\.locale, settings.language.locale)
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { task.due ?? Calendar.current.startOfDay(for: Date()) },
            set: { newValue in
                if task.due == nil { task.allDay = true }
                task.due = task.allDay ? Calendar.current.startOfDay(for: newValue) : newValue
                task.uncertain.remove(.due)
                dueError = false
            }
        )
    }

    private var allDayBinding: Binding<Bool> {
        Binding(
            get: { task.due == nil || task.allDay },
            set: { allDay in
                let base = task.due ?? Calendar.current.startOfDay(for: Date())
                if allDay {
                    task.allDay = true
                    task.due = Calendar.current.startOfDay(for: base)
                } else {
                    task.allDay = false
                    task.due = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: base)
                }
            }
        )
    }

    private func applyDueText() {
        let text = dueText.trimmingCharacters(in: .whitespaces)
        // Unchanged formatted value ("Tomorrow, 15:00") — nothing to parse.
        if let due = task.due, text == DueFormatter.string(due, allDay: task.allDay, settings: settings) {
            dueError = false
            return
        }
        if text.isEmpty {
            task.due = nil
            task.allDay = false
            dueError = false
            return
        }
        if let parsed = DateParser.parse(text) {
            task.due = parsed.date
            task.allDay = !parsed.hasTime
            task.uncertain.remove(.due)
            dueError = false
        } else {
            dueError = true
        }
    }

    private func syncDueText() {
        dueText = task.due.map { DueFormatter.string($0, allDay: task.allDay, settings: settings) } ?? ""
    }
}

struct PriorityPicker: View {
    @Binding var selection: Priority

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Priority.allCases) { p in
                Button { selection = p } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill").foregroundStyle(Theme.priority(p))
                        Text(p.label).foregroundStyle(Theme.text)
                    }
                    .font(.system(size: 12, weight: selection == p ? .semibold : .regular))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(selection == p ? Theme.card : .clear))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(selection == p ? Theme.accent.opacity(0.6) : .clear, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.chip))
    }
}

extension View {
    /// A clearly outlined input: field background, 1 pt border, accent border while focused.
    func inputBox(focused: Bool, uncertain: Bool) -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(uncertain ? Theme.uncertainFill : Theme.input))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(focused ? Theme.accent : Theme.inputBorder, lineWidth: focused ? 1.5 : 1)
            )
            .animation(.easeOut(duration: 0.12), value: focused)
    }
}
