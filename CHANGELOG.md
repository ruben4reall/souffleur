# Changelog

Each release's section is what Souffleur's update window and the GitHub release show. Dates are in ISO format.

## Unreleased

- **Below the notch**: the prompter hangs from the notch's lower edge and never covers the menu bar, whose items and
  whatever other apps show beside the camera stay free. The time and the voice move to a band at its top.
- **Other notch apps**: the prompter stays in front of their expanded views while it is open, and Souffleur tells
  them when it opens and closes (two distributed notifications) so they can step aside.
- **Fit in**: one click in the speed card sets the speed so the script lasts exactly 30 seconds, a minute, two, or
  another usual length.
- **Use my pace**: after a take read at another pace than the speed set, the summary offers to roll at the reader's
  own pace from then on.
- The welcome window says what Souffleur does now: it hangs from the notch, stops when you stop, and stays out of
  screen recordings.

Fixed, after a full review of every feature:

- **Souffleur no longer quits when the microphone starts.** In 1.1.0, pressing play in Voice Pace (the default) or
  Voice Follow closed the app: the block the audio thread calls belonged to the main actor, and Swift's isolation
  check stopped the app on the first buffer.
- The buttons shown when the pointer rests on the prompter (restart, slower, pause, faster, close) work again: a click
  on them used to pause the script instead.
- Moving a line back or on while the script rolls (Page Up, Page Down, ⌃⌥⌘← and →, the phone remote) no longer
  freezes it.
- Auto Scroll and Voice Pace roll at the speed set: they ran 13 to 24% slow, so Fit in and the time left were off.
- The phone remote no longer drops a request now and then.
- A take started right after another could end at once.
- The coach counts the last line: a full read shows 100%.
- Voice Follow finds the language's model in another region when yours has none (English on a Mac set to
  Switzerland).
- Two-finger scrolling on the prompter follows the direction set in System Settings.
- A document dropped on the script is imported instead of its path being typed in, and a web link dropped on the
  window is no longer fetched.
- Choosing another mode during a take applies at once.
- With the Paper colours the notch prompter stays black and readable; Show the timer applies to every placement.

## 1.1.0 (2026-09-27)

Souffleur now looks and behaves like the notch prompters people already know, and keeps everything it adds.

- **Stops when you stop**: Voice Pace is the new default. Press play and speak: the script rolls at your speed and
  waits as soon as you go quiet. The switch in the speed card turns it off.
- **A new prompter**: compact, lit from below with a soft light and a faint halo beneath it, the line being read in
  the middle with long fades above and below. On a screen without a notch it hangs from the menu bar.
- **Stage light colours**: violet, ocean, ember, mint or gold, or none, in Settings, Prompter.
- **A new window**: a big play button on the script, and a speed card from tortoise to hare.
- **Invisible in screen recordings**: checked on macOS 26.5 with the Mac's own screenshots and recordings and with
  ScreenCaptureKit, which screen recorders and meeting apps use. Settings and the README now say what was measured.
- **Shortcuts**: Settings says when another app already holds one of Souffleur's shortcuts.
- **Phone remote**: requests time out, and the number of connections is capped.

## 1.0.0 (2026-09-27)

The first release of Souffleur: a teleprompter that lives in the MacBook notch, free and open source under the MIT
License.

- **Voice follow**: speech recognised on the Mac and lined up with the script, word by word. The words said dim, the
  next one lights up, and the line being read stays under the camera. It waits when you pause, finds you again when
  you skip, and understands numbers, contractions and accents.
- **Four ways to scroll**: Voice Follow, Voice Pace, Auto Scroll and Manual.
- **Three places**: the notch, compact and ringed with a violet light that follows your voice; a floating glass card;
  full screen on any display, mirrored for a teleprompter rig.
- **Control**: global shortcuts, presentation clickers and foot pedals, a phone remote over the local network,
  `souffleur://` links and Shortcuts actions.
- **Scripts**: a library of Markdown files with light markup, and import from text, RTF, Word, PDF and PowerPoint
  speaker notes.
- **Coach**: live pace beside the camera and a summary after every take.
- **Privacy**: no account, no analytics, the voice never leaves the Mac.
- **Updates**: Sparkle, EdDSA-signed and notarized by Apple.
