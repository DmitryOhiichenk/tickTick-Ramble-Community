import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Screen { case start, recording, review }

    enum RecState: Equatable {
        case idle, connecting, listening, finishing
        case failed(ServiceError?)
    }

    struct SendResult: Equatable {
        let sent: Int
        let total: Int
        var complete: Bool { sent == total }
    }

    @Published var screen: Screen = .start
    @Published var recState: RecState = .idle
    @Published var tasks: [TaskItem] = [] { didSet { saveDraft() } }
    @Published var expandedId: String?
    @Published var flashId: String?
    @Published var levels: [Float] = Array(repeating: 0, count: 28)
    @Published var showSettings = false
    @Published var sendResult: SendResult?
    @Published var isSending = false
    @Published var confirmClose = false
    @Published var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @Published var micError = false

    let settings: SettingsStore
    /// Hides the window (and quits when background mode is off). Set by AppDelegate.
    var hideWindow: () -> Void = {}

    private var client: GeminiLiveClient?
    private var audio: AudioCapture?
    private var generation = 0
    private var undoStack: [[TaskItem]] = []
    private var nextNumber = 1
    private var lastVoiceAt = Date()
    private var silenceTimer: Timer?
    private var transcript = ""
    private var hideAfterSend = false

    private static let voiceThreshold: Float = 0.32
    private static let stopPhrases = [
        "that's all", "that is all", "это всё", "это все", "на этом всё", "на этом все", "це все", "це всё",
        "eso es todo", "es todo", "to wszystko", "das ist alles", "das war's", "das wars", "è tutto", "e tutto",
    ]

    private let persistsDraft: Bool

    init(settings: SettingsStore, persistsDraft: Bool = true) {
        self.settings = settings
        self.persistsDraft = persistsDraft
        if persistsDraft { loadDraft() }
    }

    // MARK: - Derived

    var blockedTasks: [TaskItem] {
        tasks.filter { $0.title.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var canSend: Bool { !tasks.isEmpty && blockedTasks.isEmpty && !isSending }

    func binding(for id: String) -> Binding<TaskItem> {
        Binding(
            get: { [weak self] in
                self?.tasks.first { $0.id == id } ?? TaskItem(id: id, title: "")
            },
            set: { [weak self] newValue in
                guard let self, let i = self.tasks.firstIndex(where: { $0.id == id }) else { return }
                self.tasks[i] = newValue
            }
        )
    }

    // MARK: - Window-level actions

    func closeTapped() {
        switch screen {
        case .start:
            hideWindow()
        case .recording:
            finishRecording(immediate: true)
            if tasks.isEmpty { hideWindow() } else { confirmClose = true }
        case .review:
            if tasks.isEmpty { screen = .start; hideWindow() } else { confirmClose = true }
        }
    }

    func escapePressed() {
        if sendResult != nil { dismissSendResult(); return }
        if showSettings { withAnimation(.easeOut(duration: 0.2)) { showSettings = false }; return }
        if expandedId != nil { endEditing(); return }
    }

    /// Close dialog on the review screen: send, then hide.
    func sendAndClose() {
        hideAfterSend = true
        Task { await sendAll() }
    }

    func discardAndClose() {
        tasks.removeAll()
        undoStack.removeAll()
        screen = .start
        hideWindow()
    }

    /// Called before the window hides for any reason (menu, hotkey, background).
    func windowWillHide() {
        if screen == .recording { finishRecording(immediate: true) }
    }

    func refreshMicStatus() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard screen != .recording else { return }
        guard settings.tokensConfigured else { screen = tasks.isEmpty ? .start : .review; return }
        refreshMicStatus()
        switch micStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    self.refreshMicStatus()
                    if granted { self.startRecording() }
                }
            }
            return
        case .denied, .restricted:
            screen = tasks.isEmpty ? .start : .review
            return
        default:
            break
        }
        micError = false
        showSettings = false
        expandedId = nil
        withAnimation(.easeInOut(duration: 0.25)) { screen = .recording }
        openSession()
    }

    /// Reconnect after a failure, keeping the cards.
    func continueSession() {
        guard screen == .recording else { return }
        openSession()
    }

    func recordMore() { startRecording() }

    func checkTapped() { finishRecording(immediate: false) }

    /// Ends the session. When not immediate, the mic stops but the socket stays open ~2.5 s to receive
    /// function calls for the last phrase.
    func finishRecording(immediate: Bool) {
        guard screen == .recording else { return }
        stopAudio()
        if immediate || client == nil || recState != .listening {
            stopSession()
            goToReviewOrStart()
            return
        }
        recState = .finishing
        client?.sendAudioStreamEnd()
        let gen = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, self.generation == gen, self.recState == .finishing else { return }
            self.stopSession()
            self.goToReviewOrStart()
        }
    }

    private func goToReviewOrStart() {
        recState = .idle
        levels = Array(repeating: 0, count: levels.count)
        withAnimation(.easeInOut(duration: 0.25)) {
            screen = tasks.isEmpty ? .start : .review
        }
    }

    private func openSession() {
        stopSession()
        generation += 1
        let gen = generation
        recState = .connecting
        transcript = ""
        let client = GeminiLiveClient()
        client.onEvent = { [weak self] event in
            guard let self, self.generation == gen else { return }
            self.handle(event)
        }
        self.client = client
        let setup = LivePrompt.setup(model: settings.effectiveModel, settings: settings, tasks: tasks)
        client.connect(apiKey: settings.geminiKey, setup: setup)
    }

    private func handle(_ event: GeminiLiveClient.Event) {
        switch event {
        case .setupComplete:
            startAudio()
        case .toolCall(let calls):
            handleToolCalls(calls)
        case .inputTranscript(let text):
            transcript += text
            checkStopPhrase()
        case .closed(let error):
            client = nil
            if recState == .finishing {
                stopSession()
                goToReviewOrStart()
            } else if screen == .recording {
                stopAudio()
                recState = .failed(error)
            }
        }
    }

    private func startAudio() {
        let capture = AudioCapture()
        let client = self.client
        capture.onChunk = { data in client?.sendAudio(data) }
        capture.onLevel = { [weak self] level in
            DispatchQueue.main.async { self?.push(level: level) }
        }
        do {
            try capture.start()
        } catch {
            micError = true
            stopSession()
            recState = .failed(.other(settings.t(.micUnavailable)))
            return
        }
        audio = capture
        recState = .listening
        lastVoiceAt = Date()
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkSilence() }
        }
    }

    private func push(level: Float) {
        guard audio != nil else { return }
        levels.removeFirst()
        levels.append(level)
        if level > Self.voiceThreshold { lastVoiceAt = Date() }
    }

    private func checkSilence() {
        guard recState == .listening else { return }
        if Date().timeIntervalSince(lastVoiceAt) > TimeInterval(settings.silenceTimeout) {
            finishRecording(immediate: false)
        }
    }

    private func checkStopPhrase() {
        let normalized = transcript.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).subtracting(CharacterSet(charactersIn: "'")))
        if Self.stopPhrases.contains(where: { normalized.hasSuffix($0) }) {
            finishRecording(immediate: false)
        }
    }

    private func stopAudio() {
        audio?.stop()
        audio = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    private func stopSession() {
        stopAudio()
        generation += 1
        client?.onEvent = nil
        client?.close()
        client = nil
        if case .failed = recState {} else { recState = .idle }
    }

    // MARK: - Function calls from the model

    private func handleToolCalls(_ calls: [GeminiLiveClient.FunctionCall]) {
        var responses: [[String: Any]] = []
        var finish = false
        for call in calls {
            let result: String
            switch call.name {
            case "add_task": result = addTask(call.args)
            case "edit_task": result = editTask(call.args)
            case "delete_task": result = deleteTask(call.args)
            case "undo_last": result = undoLast()
            case "finish_session":
                result = "ok"
                finish = true
            default: result = "error: unknown function"
            }
            responses.append([
                "id": call.id,
                "name": call.name,
                "response": ["result": result, "tasks": LivePrompt.modelList(tasks)],
            ])
        }
        client?.sendToolResponses(responses)
        if finish { finishRecording(immediate: true) }
    }

    private func addTask(_ args: [String: Any]) -> String {
        let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return "error: title is required" }
        pushUndo()
        var task = TaskItem(id: newTaskId(), title: title)
        apply(args, to: &task)
        withAnimation(.easeOut(duration: 0.25)) { tasks.append(task) }
        return "ok: added \(task.id)"
    }

    private func editTask(_ args: [String: Any]) -> String {
        guard let id = args["task_id"] as? String, let i = tasks.firstIndex(where: { $0.id == id }) else {
            return "error: unknown task_id"
        }
        pushUndo()
        var task = tasks[i]
        apply(args, to: &task)
        tasks[i] = task
        flash(id)
        return "ok: edited \(id)"
    }

    private func deleteTask(_ args: [String: Any]) -> String {
        guard let id = args["task_id"] as? String, tasks.contains(where: { $0.id == id }) else {
            return "error: unknown task_id"
        }
        pushUndo()
        withAnimation(.easeOut(duration: 0.25)) { tasks.removeAll { $0.id == id } }
        return "ok: deleted \(id)"
    }

    private func undoLast() -> String {
        guard let previous = undoStack.popLast() else { return "nothing to undo" }
        withAnimation(.easeOut(duration: 0.25)) { tasks = previous }
        return "ok: undone"
    }

    private func pushUndo() {
        undoStack.append(tasks)
        if undoStack.count > 50 { undoStack.removeFirst() }
    }

    private func apply(_ args: [String: Any], to task: inout TaskItem) {
        if let title = args["title"] as? String, !title.trimmingCharacters(in: .whitespaces).isEmpty {
            task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let notes = args["notes"] as? String { task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let due = args["due"] as? String {
            let trimmed = due.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.lowercased() == "none" {
                task.due = nil
                task.allDay = false
            } else if let parsed = DateParser.parse(trimmed) {
                task.due = parsed.date
                task.allDay = !parsed.hasTime
            } else {
                task.uncertain.insert(.due)
            }
        }
        if let allDay = args["all_day"] as? Bool, allDay, let due = task.due {
            task.allDay = true
            task.due = Calendar.current.startOfDay(for: due)
        }
        if let p = (args["priority"] as? NSNumber)?.intValue {
            task.priority = Priority(rawValue: min(4, max(1, p))) ?? .p4
        }
        if let uncertain = args["uncertain_fields"] as? [String] {
            task.uncertain = Set(uncertain.compactMap { TaskField(rawValue: $0) })
        }
    }

    private func flash(_ id: String) {
        flashId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            if self?.flashId == id { withAnimation(.easeOut(duration: 0.2)) { self?.flashId = nil } }
        }
    }

    // MARK: - Manual editing (review screen)

    func toggleExpanded(_ id: String) {
        let opening = expandedId != id
        dropEmptyTasks(except: opening ? id : nil)
        withAnimation(.easeInOut(duration: 0.2)) { expandedId = opening ? id : nil }
    }

    /// Click on empty space, Return in the title or Esc: edits are already saved as you type,
    /// so this just closes the editor (and drops a manually added task left without a title).
    func endEditing() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        guard expandedId != nil else { return }
        dropEmptyTasks(except: nil)
        withAnimation(.easeInOut(duration: 0.2)) { expandedId = nil }
    }

    /// Review screen: add a task by hand and open it for editing.
    func addManualTask() {
        dropEmptyTasks(except: nil)
        let task = TaskItem(id: newTaskId(), title: "")
        withAnimation(.easeOut(duration: 0.2)) {
            tasks.append(task)
            expandedId = task.id
        }
    }

    /// t1, t2… — never reuses an id that is on screen, so the model can't confuse two cards.
    private func newTaskId() -> String {
        let maxOnScreen = tasks.compactMap { Int($0.id.dropFirst()) }.max() ?? 0
        nextNumber = max(nextNumber, maxOnScreen + 1)
        defer { nextNumber += 1 }
        return "t\(nextNumber)"
    }

    private func dropEmptyTasks(except keep: String?) {
        let empty = tasks.filter { $0.id != keep && $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !empty.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            tasks.removeAll { t in empty.contains { $0.id == t.id } }
        }
    }

    func delete(_ id: String) {
        withAnimation(.easeOut(duration: 0.25)) {
            tasks.removeAll { $0.id == id }
            if expandedId == id { expandedId = nil }
        }
        if tasks.isEmpty && screen == .review { withAnimation { screen = .start } }
    }

    // MARK: - Sending to TickTick

    func sendAll() async {
        guard !isSending else { return }
        guard blockedTasks.isEmpty, !tasks.isEmpty else {
            if let first = blockedTasks.first { expandedId = first.id }
            hideAfterSend = false
            return
        }
        isSending = true
        expandedId = nil
        let client = TickTickClient(token: settings.tickTickToken)
        let total = tasks.count
        var sent = 0
        for task in tasks {
            if task.remoteId != nil { sent += 1; continue }
            let ok = await send(task, client: client)
            if ok { sent += 1 }
        }
        isSending = false
        withAnimation(.spring(duration: 0.3)) { sendResult = SendResult(sent: sent, total: total) }
        if sent == total {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                if self?.sendResult != nil { self?.dismissSendResult() }
            }
        } else {
            hideAfterSend = false
        }
    }

    func retry(_ id: String) async {
        guard let task = tasks.first(where: { $0.id == id }), !isSending else { return }
        isSending = true
        let ok = await send(task, client: TickTickClient(token: settings.tickTickToken))
        isSending = false
        if ok {
            withAnimation { tasks.removeAll { $0.id == id } }
            if tasks.isEmpty {
                withAnimation(.spring(duration: 0.3)) { sendResult = SendResult(sent: 1, total: 1) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    if self?.sendResult != nil { self?.dismissSendResult() }
                }
            }
        }
    }

    private func send(_ task: TaskItem, client: TickTickClient) async -> Bool {
        do {
            let remoteId = try await client.createTask(task)
            if let i = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[i].remoteId = remoteId
                tasks[i].sendError = nil
            }
            return true
        } catch {
            let e = ServiceError.from(error)
            if let i = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[i].sendError = settings.message(for: e)
            }
            return false
        }
    }

    func dismissSendResult() {
        guard let result = sendResult else { return }
        withAnimation(.easeOut(duration: 0.2)) { sendResult = nil }
        withAnimation { tasks.removeAll { $0.remoteId != nil } }
        if result.complete || tasks.isEmpty {
            tasks.removeAll()
            undoStack.removeAll()
            nextNumber = 1
            withAnimation { screen = .start }
            if hideAfterSend { hideAfterSend = false; hideWindow() }
        }
    }

    // MARK: - Draft persistence (a crash or quit never loses recognized tasks)

    static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dictate for TickTick", isDirectory: true)
    }

    private static var draftURL: URL { supportDirectory.appendingPathComponent("draft.json") }

    private func saveDraft() {
        guard persistsDraft else { return }
        let url = Self.draftURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if tasks.isEmpty {
            try? FileManager.default.removeItem(at: url)
        } else if let data = try? JSONEncoder().encode(tasks) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadDraft() {
        guard let data = try? Data(contentsOf: Self.draftURL),
              let saved = try? JSONDecoder().decode([TaskItem].self, from: data), !saved.isEmpty else { return }
        tasks = saved.filter { $0.remoteId == nil }
        nextNumber = (tasks.compactMap { Int($0.id.dropFirst()) }.max() ?? 0) + 1
        if !tasks.isEmpty { screen = .review }
    }
}
