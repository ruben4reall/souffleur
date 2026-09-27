# Contributing to Souffleur

Thank you for helping. A few principles keep Souffleur what it is.

## Principles

- **Idle means idle.** With the prompter closed, nothing runs: no microphone, no timer, no animation. While it is
  open, motion belongs to the render server (Core Animation) or to one display link that stops when the text is still.
- **The voice stays on the Mac.** Recognition must run on device. A language the Mac cannot recognise offline falls
  back to Voice Pace; it is never sent to a server.
- **Native.** AppKit and Core Animation for the prompter, TextKit for its text, SwiftUI for the windows. No web views.
- **Private.** No network calls beyond the update check and the phone remote the user turns on, no analytics.
  [SECURITY.md](SECURITY.md) lists everything Souffleur touches: keep it true.
- **Tested rules.** Behaviour that can be expressed without AppKit belongs in `SouffleurCore`, with tests. The voice
  tracker especially: every bug found in the wild becomes a test there first.

## Workflow

1. `scripts/build.sh` and `swift test --package-path Packages/SouffleurKit` must pass without warnings.
2. Visible text is in English, with no em dash; strings in the app go through the String Catalog.
3. One change per pull request, with a screenshot or a short video for anything visible.
4. For the website: `node site/tools/audit.mjs` must be clean, and every picture of the app comes from the app itself,
   through `scripts/capture-site.sh`.

## Where things live

See the table in the [README](README.md#build-from-source).
