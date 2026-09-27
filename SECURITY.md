# Security

## Reporting a vulnerability

Please open a [private security advisory](https://github.com/ruben4reall/souffleur/security/advisories/new) rather
than a public issue. You will get an answer within a few days.

## What Souffleur touches on your Mac

Everything Souffleur reads, writes or runs, and why.

### Files

| Path | What | When |
|---|---|---|
| `~/Library/Application Support/Souffleur/Scripts/` | Your scripts, one Markdown file each. Deleting a script moves its file to the Trash | Always |
| `~/Library/Preferences/ch.rubencatalao.souffleur.plist` | Settings, the selected script, the summary of the last take, the phone remote's pairing code | Always |

Documents you import are read once and copied into a new script; the original is never changed.

### Microphone and speech

The microphone is open only while a take runs in Voice Follow or Voice Pace, and closes with the prompter. Speech is
recognised on the Mac (`SFSpeechRecognizer` with `requiresOnDeviceRecognition`, or `SpeechAnalyzer` on macOS 26 when
its model is installed); nothing is recorded or kept. The words of the script are given to the recogniser as
vocabulary, on the Mac.

### Processes

- `/usr/bin/zipinfo` and `/usr/bin/unzip`, to read the speaker notes of a PowerPoint file you import, without
  extracting anything to disk.

### Network

- The update check: Sparkle reads `https://getsouffleur.vercel.app/appcast.xml` once a day and downloads new versions
  from GitHub. Updates are signed with Souffleur's EdDSA key and verified before they are opened. Sparkle's system
  profile is off. You can turn automatic checks off in Settings, General.
- The phone remote, only while you turn it on: a small HTTP server on port 7575 (or the next free one up to 7579). It
  accepts connections from loopback, link-local and private addresses only, and answers nothing without the 12
  character pairing code in the address, compared in constant time. A request has five seconds to arrive, at most
  sixteen connections are open at once, and four pages at most follow the prompter. Settings can make a new code at
  any time.
- Nothing else. No account, no telemetry, no analytics, no crash reports.

### Permissions

The microphone and speech recognition, asked only when you choose a voice mode. Keyboard shortcuts use the Carbon hot
key API, which needs no permission and never sees other keystrokes.

### Login item

When you choose Open at Login, Souffleur registers itself with `SMAppService`. It shows in System Settings, General,
Login Items.

### Other apps

When the prompter opens and closes, Souffleur posts the distributed notifications
`ch.rubencatalao.souffleur.prompterDidOpen` and `ch.rubencatalao.souffleur.prompterDidClose`, so notch apps can step
aside. They carry the placement (notch, floating or full screen) and nothing else: no script, no title.

### Screen capture

The prompter's windows set `NSWindow.sharingType = .none` (Settings, Prompter, on by default). macOS then leaves them
out of screenshots, screen recordings and screen sharing, ScreenCaptureKit included: checked on macOS 26.5 with the
Mac's own screenshots and recordings and with a ScreenCaptureKit capture of the whole display.
