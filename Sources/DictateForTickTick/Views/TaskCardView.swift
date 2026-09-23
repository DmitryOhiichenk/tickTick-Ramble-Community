import SwiftUI

struct TaskCardView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @Binding var task: TaskItem
    let editable: Bool

    @State private var hovering = false
    @State private var dragX: CGFloat = 0

    private var expanded: Bool { editable && app.expandedId == task.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if expanded {
                TaskEditor(task: $task)
            } else {
                summary
            }
            if let error = task.sendError, !expanded {
                HStack {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.error)
                        .lineLimit(2)
                    Spacer()
                    Button(settings.t(.retry)) { Task { await app.retry(task.id) } }
                        .buttonStyle(SmallButtonStyle(tint: Theme.error))
                        .disabled(app.isSending)
                }
                .padding(.top, 10)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.08), radius: 1.5, x: 0, y: 1)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: borderWidth))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if editable && !expanded { app.toggleExpanded(task.id) }
        }
        .onHover { hovering = $0 }
        .offset(x: dragX)
        .gesture(swipeToDelete, including: editable && !expanded ? .all : .subviews)
        .contextMenu {
            if editable {
                Button(settings.t(.deleteTask), role: .destructive) { app.delete(task.id) }
            }
        }
        .animation(.easeOut(duration: 0.2), value: app.flashId)
    }

    private var borderColor: Color {
        if task.sendError != nil { return Theme.error }
        if app.flashId == task.id { return Theme.accent }
        return .clear
    }

    private var borderWidth: CGFloat { task.sendError != nil ? 1.5 : 2 }

    private var swipeToDelete: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    dragX = min(0, value.translation.width)
                }
            }
            .onEnded { value in
                if value.translation.width < -120 {
                    app.delete(task.id)
                } else {
                    withAnimation(.spring(duration: 0.25)) { dragX = 0 }
                }
            }
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .stroke(Theme.priority(task.priority).opacity(task.priority == .p4 ? 0.6 : 1), lineWidth: 1.5)
                .frame(width: 18, height: 18)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .uncertainHighlight(task.uncertain.contains(.title))
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(3)
                        .uncertainHighlight(task.uncertain.contains(.notes))
                }
                ChipsRow(task: task)
            }
            Spacer(minLength: 0)
            if editable && hovering {
                Button { app.delete(task.id) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
                .help(settings.t(.deleteTask))
            }
        }
    }
}

struct ChipsRow: View {
    @EnvironmentObject var settings: SettingsStore
    let task: TaskItem

    var body: some View {
        HStack(spacing: 6) {
            Chip(uncertain: task.uncertain.contains(.priority)) {
                Image(systemName: "flag.fill").foregroundStyle(Theme.priority(task.priority))
                Text(task.priority.label)
            }
            if let due = task.due {
                Chip(uncertain: task.uncertain.contains(.due)) {
                    Image(systemName: "calendar")
                    Text(DueFormatter.string(due, allDay: task.allDay, settings: settings))
                }
            } else if task.uncertain.contains(.due) {
                Chip(uncertain: true) {
                    Image(systemName: "calendar")
                    Text(settings.t(.noDate))
                }
            }
        }
    }
}

struct Chip<Content: View>: View {
    var uncertain = false
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 4) { content }
            .font(.system(size: 12))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(uncertain ? Theme.uncertainFill : Theme.chip))
    }
}

extension View {
    /// Fields the model wasn't sure about are highlighted yellow.
    func uncertainHighlight(_ on: Bool) -> some View {
        padding(.horizontal, on ? 3 : 0)
            .background(RoundedRectangle(cornerRadius: 4).fill(on ? Theme.uncertainFill : .clear))
    }
}
