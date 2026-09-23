import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // Content runs under the transparent title bar; the header row lines up with the window buttons.
            Group {
                switch app.screen {
                case .start:
                    StartView().transition(.opacity)
                case .recording, .review:
                    SessionView().transition(.opacity)
                }
            }
            .ignoresSafeArea(edges: .top)

            if app.showSettings {
                SettingsView()
                    .ignoresSafeArea(edges: .top)
                    .transition(.move(edge: .trailing))
                    .zIndex(2)
            }

            if let result = app.sendResult {
                SentPopup(result: result)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(3)
            }
        }
        .frame(minWidth: 420, maxWidth: 420, minHeight: 680, maxHeight: 780)
        .environment(\.locale, settings.language.locale)
        .alert(settings.t(.unsentTitle), isPresented: $app.confirmClose) {
            Button(settings.t(.send)) { app.sendAndClose() }
            Button(settings.t(.discard), role: .destructive) { app.discardAndClose() }
            Button(settings.t(.cancel), role: .cancel) {}
        } message: {
            Text(settings.t(.unsentMessage))
        }
    }
}

struct SentPopup: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    let result: AppState.SendResult

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
                .onTapGesture { app.dismissSendResult() }
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((result.complete ? Theme.accent : Theme.priority(.p2)).opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: result.complete ? "checkmark" : "exclamationmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(result.complete ? Theme.accent : Theme.priority(.p2))
                }
                if result.complete {
                    Text(settings.t(.sentTitle))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(settings.t(.tasksAdded, result.sent))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                } else {
                    Text(settings.t(.sentPartial, result.sent, result.total))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                Button(settings.t(.done)) { app.dismissSendResult() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 6)
            }
            .padding(24)
            .frame(width: 280)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card).shadow(color: .black.opacity(0.18), radius: 20, y: 8))
        }
    }
}
