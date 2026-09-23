import SwiftUI

/// Screens 2 and 3 share the card feed: while recording the record panel is pinned at the bottom,
/// on review it collapses into the send buttons and cards become editable.
struct SessionView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore

    private var recording: Bool { app.screen == .recording }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(title: settings.t(.inbox))
            if recording, case .failed(let error) = app.recState {
                ErrorBanner(error: error)
            }
            GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(app.tasks) { task in
                            TaskCardView(task: app.binding(for: task.id), editable: !recording)
                                .id(task.id)
                                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 8)),
                                                        removal: .opacity.combined(with: .move(edge: .leading))))
                        }
                        if !recording {
                            AddTaskButton()
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, recording ? 200 : 130)
                    // Fill the viewport so a click on empty space (between or below cards) closes the editor.
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .top)
                    .contentShape(Rectangle())
                    .onTapGesture { app.endEditing() }
                }
                .scrollIndicators(.never)
                .onChange(of: app.tasks.count) { old, new in
                    if new > old { withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) } }
                }
            }
            }
        }
        .overlay(alignment: .bottom) {
            Group {
                if recording { RecordingPanel() } else { ReviewBar() }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Review screen: dictation is over, but a task can still be typed in by hand.
struct AddTaskButton: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @State private var hovering = false

    var body: some View {
        Button { app.addManualTask() } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text(settings.t(.addTask))
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(hovering ? 0.1 : 0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct ErrorBanner: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    let error: ServiceError?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.error)
            Text(error.map { $0 == .network ? settings.t(.connectionLost) : settings.message(for: $0) } ?? settings.t(.connectionLost))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(3)
            Spacer(minLength: 4)
            Button(settings.t(.continueAction)) { app.continueSession() }
                .buttonStyle(SmallButtonStyle())
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.error.opacity(0.1)))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

struct RecordingPanel: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore

    private var title: String {
        switch app.recState {
        case .connecting: return settings.t(.connecting)
        case .finishing: return settings.t(.finishing)
        case .failed: return settings.t(.connectionLost)
        default: return settings.t(.listening)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(settings.t(.speakAll))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                Button { app.checkTapped() } label: {
                    ZStack {
                        Circle().fill(Theme.accent)
                            .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 3)
                        if app.recState == .finishing {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            Waveform(levels: app.levels, active: app.recState == .listening)
            Text(settings.t(.beta))
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 36)
        .padding(.bottom, 16)
        .background(
            LinearGradient(stops: [
                .init(color: Theme.background.opacity(0), location: 0),
                .init(color: Theme.background, location: 0.22),
                .init(color: Theme.background, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
    }
}

/// 28 bars of live mic amplitude: blue bars are active, pale ones are background.
struct Waveform: View {
    let levels: [Float]
    let active: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(levels.indices, id: \.self) { i in
                let level = CGFloat(levels[i])
                Capsule()
                    .fill(active && level > 0.12 ? Theme.accent : Theme.accent.opacity(0.18))
                    .frame(width: 5, height: max(5, level * 44))
            }
        }
        .frame(height: 44)
        .animation(.linear(duration: 0.08), value: levels)
    }
}

struct ReviewBar: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 8) {
            Button {
                Task { await app.sendAll() }
            } label: {
                HStack(spacing: 8) {
                    if app.isSending { ProgressView().controlSize(.small).tint(.white) }
                    Text("\(settings.t(.addToTickTick)) (\(app.tasks.count))")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!app.canSend)

            Button(settings.t(.recordMore)) { app.recordMore() }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(app.isSending)
        }
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .background(
            LinearGradient(stops: [
                .init(color: Theme.background.opacity(0), location: 0),
                .init(color: Theme.background, location: 0.25),
                .init(color: Theme.background, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
    }
}
