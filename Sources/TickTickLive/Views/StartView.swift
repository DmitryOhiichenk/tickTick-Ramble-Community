import SwiftUI

/// Screen 1: a single microphone button with concentric rings.
struct StartView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore

    private var micBlocked: Bool { app.micStatus == .denied || app.micStatus == .restricted }
    private var enabled: Bool { settings.tokensConfigured && !micBlocked }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar()
            Spacer()
            MicButton(enabled: enabled) { app.startRecording() }
            VStack(spacing: 10) {
                Text(settings.t(.clickOrHotkey, settings.hotkey.display))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)

                if !settings.tokensConfigured {
                    Button(settings.t(.setTokens)) {
                        withAnimation(.easeOut(duration: 0.2)) { app.showSettings = true }
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 13))
                } else if micBlocked {
                    Text(settings.t(.micNeeded))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                    Button(settings.t(.allowAccess)) { app.openMicrophoneSettings() }
                        .buttonStyle(SmallButtonStyle())
                }
            }
            .padding(.top, 36)
            Spacer()
            Spacer().frame(height: 40)
        }
        .onAppear { app.refreshMicStatus() }
    }
}

struct MicButton: View {
    let enabled: Bool
    let action: () -> Void
    @State private var hovering = false

    private let diameter: CGFloat = 96

    var body: some View {
        ZStack {
            TimelineView(.animation(paused: !(hovering && enabled))) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        ring(index: i, time: time)
                    }
                }
            }
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(nsColor: NSColor(hex: 0x6A8CFF)), Theme.accent],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: Theme.accent.opacity(0.35), radius: hovering ? 14 : 8, y: 4)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.4)
            .onHover { hovering = $0 }
        }
        .frame(width: 220, height: 220)
    }

    /// Idle: static rings. Hover: scale 1.0 → 1.15, opacity 0.35 → 0, 1.8 s, 0.6 s phase shift between rings.
    private func ring(index i: Int, time: TimeInterval) -> some View {
        let size = diameter + CGFloat(i + 1) * 30
        let animating = hovering && enabled
        let phase = animating ? ((time + Double(i) * 0.6).truncatingRemainder(dividingBy: 1.8)) / 1.8 : 0
        let scale = animating ? 1 + 0.15 * phase : 1
        let opacity = animating ? 0.35 * (1 - phase) : 0.35 - Double(i) * 0.09
        return Circle()
            .stroke(Theme.accent.opacity(enabled ? opacity : opacity * 0.4), lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(scale)
    }
}
