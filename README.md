# TickTick Live — Voice Task Manager

A voice brain dump for TickTick on macOS. You talk, tasks appear as cards while you speak (Gemini Live API, function calls), you check them, and one button sends them to your TickTick Inbox.

## Features

- **Talk, don't type.** Press a hotkey and say everything on your mind. Each task shows up as a card as soon as you finish the thought.
- **Any language.** Dictate in English, Ukrainian, Russian, Spanish, Polish, German, Italian or any other language Gemini understands, even switching mid-sentence. Task titles stay in the language you spoke.
- **Dates, times and priorities from speech.** "Call Anna tomorrow at 3, it's urgent" becomes a P1 task due tomorrow at 15:00. Relative dates like "next Friday" or "in two hours" are worked out for you.
- **Correct by voice.** Say "no, not Friday, Wednesday", "rename the second one", "remove that" or "undo", and the card on screen changes. No need to start over.
- **Doubtful parts are highlighted.** If a word or date may have been misheard, the field is marked yellow so you know what to check.
- **Hands-free stop.** Recording ends when you press the check button, say "that's all", or stay silent for a set time (15 seconds by default).
- **Review before sending.** Nothing reaches TickTick until you say so. Click a card to edit its title, description, date and priority. Delete a card with a swipe or the trash icon. Click empty space to close the editor.
- **Add tasks by hand.** After dictation, use **Add task** to type in anything the recording missed.
- **One click to TickTick.** **Add to TickTick** sends every task to your Inbox. If some fail, they stay on screen with a Retry button, and a retry never creates duplicates.
- **Nothing gets lost.** Unsent tasks are saved on disk and come back after a crash or restart.
- **A global hotkey.** ⌥⇧R by default, changeable in Settings, with checks for conflicts with macOS and other apps. Press it again to finish recording.
- **Menu bar and background mode.** Optionally keep the app in the menu bar and running after its window is closed. The microphone is only on while you record.
- **Looks like TickTick.** The same priority flags, colors and date chips, plus light, dark and system themes.
- **Private by design.** Your API keys stay in the macOS Keychain. Audio is streamed to Gemini only while you are recording, and the app keeps no transcripts or logs.

## Install

Download an installer from the [Releases](https://github.com/DmitryOhiichenk/tickTick-Ramble-Community/releases) page, or build it yourself (see [Build from source](#build-from-source)):

- `TickTick-Live-<version>.pkg` — a standard installer wizard; installs the app into Applications and launches it.
- `TickTick-Live-<version>.dmg` — open it and drag the app into Applications.

Requires macOS 14 or later, Apple Silicon or Intel.

The build is ad-hoc signed (no Apple Developer ID). It runs as-is on the Mac it was built on. On another Mac, the first launch needs a right-click on the app → Open, or System Settings → Privacy & Security → Open Anyway.

## First run

1. Gear icon → Connections:
   - **Gemini Live API key** — from [Google AI Studio](https://aistudio.google.com/apikey);
   - **TickTick token** — an Open API access token ([developer.ticktick.com](https://developer.ticktick.com/)).

   Each field has a Test button. Tokens are stored in the Keychain.
2. Click the microphone or press **⌥⇧R**. On the first recording macOS asks for microphone access.
3. Say your tasks. The session ends with the check button, a phrase like "that's all", or after 15 seconds of silence (adjustable).
4. Review the cards: click one to edit it, click empty space to close the editor, or add a task by hand with **Add task**. Then press **Add to TickTick**.

## Window

A regular macOS window: close / minimize / zoom buttons, Dock icon, ⌘Tab, ⌘M, ⌘W, ⌘Q, ⌘, for Settings. Recording keeps going while the window is minimized or covered. With background mode on, closing the window removes the Dock icon and the app stays in the menu bar.

## Settings

| Setting | Default | What it does |
| --- | --- | --- |
| App language | English | EN, UK, RU, ES, PL, DE, IT; switches instantly. You can dictate in any language |
| Theme | System | System, Light or Dark |
| Stop listening after silence | 15 s | 5–60 s in 5 s steps |
| Gemini and TickTick tokens | — | Keychain, Test button |
| Gemini model | `gemini-3.8-live` | Change it if Google renames the model |
| Global hotkey | ⌥⇧R | Change → press a new shortcut. Checks for conflicts with macOS and other apps |
| Show in menu bar | On | Menu bar icon: open, new recording, settings, quit |
| Run in background | On | After the window is closed the app keeps running and responds to the hotkey. The microphone stays off until you start recording |
| Launch at login | Off | Uses `SMAppService` |

## Build from source

Only the Xcode Command Line Tools are needed (not full Xcode).

```bash
./scripts/make_installer.sh
```

The script builds a universal binary (Apple Silicon + Intel), the `.app`, the `.dmg` and the `.pkg`. App only: `./scripts/build.sh`.

Checks without UI or network (date parsing in 7 languages, TickTick request body, priority mapping):

```bash
swift build && .build/debug/TickTickLive --selftest
```

Screenshots of every screen in light and dark mode: `.build/debug/TickTickLive --snapshots <folder>` (set `SNAP_LANG=en` for English).

## Where things are

- `Sources/TickTickLive/AppState.swift` — recording session, function-call handling, manual editing, sending.
- `LivePrompt.swift` — system prompt and the 5 Gemini functions.
- `GeminiLiveClient.swift` — Live API WebSocket client.
- `TickTickClient.swift` — TickTick Open API.
- `DateParser.swift` — local date parsing ("next Friday 3pm", "завтра в 15:00").
- `Hotkey.swift` — global hotkey (Carbon) and conflict checks.
- `Views/` — SwiftUI screens.
- Unsent tasks are kept in `~/Library/Application Support/TickTick Live/draft.json`, so a crash or quit never loses them. No session logs are written.
