import Foundation

/// System prompt and function declarations for the Gemini Live session.
@MainActor
enum LivePrompt {
    static func setup(model: String, settings: SettingsStore, tasks: [TaskItem]) -> [String: Any] {
        [
            "model": "models/\(model)",
            "generationConfig": [
                // Live models only emit AUDIO; the app ignores it — the only output used is function calls.
                "responseModalities": ["AUDIO"],
                "temperature": 0.2,
            ],
            "systemInstruction": ["parts": [["text": systemPrompt(settings: settings, tasks: tasks)]]],
            "tools": [["functionDeclarations": functionDeclarations]],
            "inputAudioTranscription": [String: Any](),
        ]
    }

    static func systemPrompt(settings: SettingsStore, tasks: [TaskItem]) -> String {
        let now = Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, yyyy-MM-dd, HH:mm"
        let tz = TimeZone.current
        let listData = (try? JSONSerialization.data(withJSONObject: modelList(tasks), options: [.sortedKeys])) ?? Data()
        let list = String(data: listData, encoding: .utf8) ?? "[]"

        return """
        You are a silent task-capture engine inside a macOS app. The user dictates a brain dump of to-dos, in any \
        language, possibly switching languages mid-sentence. You never speak, never answer, never ask questions and \
        never try to carry out the tasks. Your ONLY output is function calls. If there is nothing to call, stay silent.

        Now: \(f.string(from: now)), time zone \(tz.identifier). Interface language: \(settings.language.englishName).

        Rules:
        - When the user finishes a thought (a pause), call add_task once for each distinct task. Write the title \
        literally in the language the user spoke, short and actionable, keeping the user's wording. Do not invent details. \
        Extra details go to notes.
        - due: an ENGLISH phrase relative to now, e.g. "today 18:00", "tomorrow", "next Friday 3pm", "September 30 10:00", \
        "in 2 hours". Empty string if no date was said. all_day = true when no time of day was said.
        - priority: 1 = highest (urgent / important / high priority), 2 = medium, 3 = low, 4 = none (default).
        - If you are unsure what was said for a field, still fill in your best guess and list that field in uncertain_fields \
        (you cannot ask back).
        - Corrections change existing cards instead of adding new ones: "no, not Friday — Wednesday", "rename the second one", \
        "make it urgent" → edit_task; "remove that", "delete the last one" → delete_task; "undo", "cancel that" → undo_last. \
        "that" / "the last one" means the most recently added or edited task. Always use task ids from the latest list.
        - Every function response contains the full current task list with ids.
        - When the user says a closing phrase such as "that's all", "это всё", "це все", "eso es todo", "to wszystko", \
        "das ist alles", "è tutto", call finish_session.
        - Ignore filler words, thinking out loud and anything that is not a task.

        Current task list: \(list)
        """
    }

    static func modelList(_ tasks: [TaskItem]) -> [[String: Any]] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return tasks.map { t in
            var due = ""
            if let d = t.due {
                f.dateFormat = t.allDay ? "EEE yyyy-MM-dd" : "EEE yyyy-MM-dd HH:mm"
                due = f.string(from: d)
            }
            return [
                "id": t.id,
                "title": t.title,
                "notes": t.notes,
                "due": due,
                "priority": t.priority.rawValue,
            ]
        }
    }

    private static let taskFields: [String: Any] = [
        "title": ["type": "STRING", "description": "Short task title in the user's language, literal wording."],
        "notes": ["type": "STRING", "description": "Optional details. Empty string if none."],
        "due": ["type": "STRING", "description": "English date phrase relative to now (\"tomorrow 3pm\", \"next Friday\"). Empty if none."],
        "all_day": ["type": "BOOLEAN", "description": "True when a date but no time of day was said."],
        "priority": ["type": "INTEGER", "description": "1 highest, 2 medium, 3 low, 4 none."],
        "uncertain_fields": [
            "type": "ARRAY",
            "items": ["type": "STRING", "enum": ["title", "notes", "due", "priority"]],
            "description": "Fields you are not sure you heard correctly.",
        ],
    ]

    static var functionDeclarations: [[String: Any]] {
        var editFields = taskFields
        editFields["task_id"] = ["type": "STRING", "description": "Id of an existing task, e.g. t2."]
        return [
            [
                "name": "add_task",
                "description": "Add a new task card.",
                "parameters": ["type": "OBJECT", "properties": taskFields, "required": ["title"]],
            ],
            [
                "name": "edit_task",
                "description": "Change fields of an existing task. Only pass the fields that change.",
                "parameters": ["type": "OBJECT", "properties": editFields, "required": ["task_id"]],
            ],
            [
                "name": "delete_task",
                "description": "Remove a task card.",
                "parameters": [
                    "type": "OBJECT",
                    "properties": ["task_id": ["type": "STRING", "description": "Id of the task to remove."]],
                    "required": ["task_id"],
                ],
            ],
            ["name": "undo_last", "description": "Revert the last change to the task list."],
            ["name": "finish_session", "description": "The user finished dictating; close the session."],
        ]
    }
}
