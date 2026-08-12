<div align="center">

<a href="https://integratedagentics.com/ghost"><img src="docs/Screenshot 2026-08-11 at 6.42.27 PM.png" alt="Ghost answering a question about the Mohs hardness scale in the notch surface, with provider, model and timing chips above the answer" width="820" /></a>

<samp>v2.1.0 · notarized · one-time purchase · macOS 14+</samp>

<video src="docs/demo-empire-state.mp4" controls muted loop width="800"></video>

[▶ Watch: asking Ghost what the Empire State Building looks like, from the floating bar (MP4)](docs/demo-empire-state.mp4)

</div>

<br/>

Every AI tool today has the same problem: you're the one doing all the context switching. ChatGPT tab, local model UI, terminal agent, document viewer, timer app, Calendar, Reminders — seven surfaces just to get through a focused hour of work. Ghost replaces all of them with one surface that lives in your menu bar and opens with ⌥Space.

So you type a question, attach a file, dictate a note, or start a focus timer — and Ghost routes it to the right model (local or cloud, or your own Claude/ChatGPT plan), searches your indexed documents, remembers what matters about you, creates real files, runs verified Mac actions, and drops back out of sight. No Dock icon, no tab management, no full-screen takeover. Just the work, done.

By default, everything is off: web access, file tools, automation, messaging, screen capture, shell. You opt in one switch at a time. API keys live in your Keychain; if Ghost finds one in `~/.ghost/.env` or the environment it moves it there and strips the file. Local models run entirely on your machine with the same tool harness the cloud models get. And your most personal data — Messages, Notes, Mail, Contacts — is processed **on device only**: Ghost never sends it to a cloud model on its own initiative, and when you deliberately act on a selection from one of those apps, it tells you where the text is going first.

<br/>

## New in 2.1.0

- **Ghost introduces itself.** A new install used to open an empty text field and leave you to guess. There is a real first run now: where answers come from, one honest page about permissions, and a first question you can click to run.
- **It also stops taking your keyboard.** Ghost brought its window forward and grabbed focus on *every* launch, including at login, because it treated every launch as a first one. Fixed.
- **Type a slash to see everything it can do.** Around thirty commands were reachable only if you already knew to type `/help`. They are listed and filtered as you type now. A blank chat also suggests a few questions, picked from what your permission switches actually allow, and they retire once you have used Ghost a few times.
- **Search and name your conversations.** The saved list is searchable across titles *and* message text, renameable, and threads delete one at a time instead of all at once.
- **A web fetch could leak your conversation. It cannot now.** When you named a page for Ghost to read, it skipped the approval prompt because you had chosen the destination. That check compared only host and path, so a page could talk Ghost into re-fetching the same address with your conversation attached as a query string. The check now covers the whole destination: query, fragment, port and credentials.
- **Undo reaches everything it can reverse.** Reminders and calendar events recorded an undo the interface never offered. Quitting an app is undoable too. Where Ghost genuinely cannot reverse something, the card tells you the change is in the Trash instead of showing a dead button.
- **Shortcuts and Spotlight.** Ask Ghost, Start Focus Timer and Toggle Ghost are available as system actions.
- **A selection bar that suits the app you are in.** Explain leads in a code editor, Fix grammar leads in Mail. Nothing is removed, only reordered.
- **A calmer window.** Long answers are set to a comfortable reading width rather than the full 880pt. Three badges above an answer and a duplicate line below became one quiet line. Settings lost a layer of decoration and gained a window size preference. Every icon-only control now has a name for VoiceOver.

<br/>

## Also new since 2.0.4

- **Ghost comes to your text.** Select anything in any app and a small bar appears beside it — Copy, Search, Summarize, Fix, plus rewrites, Explain and Translate. Replace writes the result straight back into the field you selected in, so that app's own undo still works.
- **Sections across the top.** One bar switches the Ghost window between Chat, Timer, Terminal, and Settings.
- **A terminal inside Ghost.** Run shell commands without leaving the window — or say what you want changed and Ghost's coding agent does it, in the same folder. Behind the same permission switch as its shell tool.
- **A cleaner surface.** The typing pill now sits flush just below the camera notch — nothing clipped, no matter how much you type. In floating-bar mode it's a genuine floating text field with a frosted, high-contrast background and no dark slab around it.
- **Ghost remembers you.** An on-device knowledge base quietly grounds every chat, so Ghost knows your people, your preferences, and "the usual." It's plain Markdown you own.
- **Your private data stays on device.** Messages, Notes, Mail, and Contacts never leave your Mac for a cloud model — not for answers, memory, or tools. Use a local model to let AI touch them.
- **Your day, handled.** A ranked daily brief, Reminders, Calendar, and Apple Notes — read and write, in plain language.
- **Messages & FaceTime.** Read and send iMessages and start calls (on-device, opt-in, and confirmed before anything sends).
- **Computer-use.** For a Mac task no built-in tool covers, Ghost writes an AppleScript and runs it _only_ after you approve the exact script.
- **Bring your own subscription.** Run chat through your existing Claude Code or Codex CLI — your account, your plan, at no extra cost.
- **A coding agent in the Terminal, and a pomodoro in the Timer.** <sub><samp>2.0.8</samp></sub> Type a command and it runs; say what you want changed and Ghost's agent does it, in the same folder, on the model you already set up. The Timer became a full pomodoro with a persistent study log: subjects, streaks, and a focus history.
- **Nearly eighty built-in tools**, including a full suite of on-device Mac controls — system report, brightness, audio, dark mode, window snapping, Homebrew, app uninstall, junk cleanup, media conversion, and more.

<br/>

## One surface, eight providers, zero context switching.

<sub><samp>⌥SPACE · ANYWHERE ON MACOS</samp></sub>

![The Ghost composer at rest, hanging from the camera notch as a single input pill with the section bar above it](docs/screenshots/app/quick-ask.jpg)

Press ⌥Space anywhere on your Mac and a frosted-glass surface appears — dropping from the camera notch, or floating up as a text bar near the bottom of the screen, your choice. Chat, file creation, document search, memory, timers, Calendar, Reminders, Notes, screen OCR, and agent coding sessions all live in one place. The aurora background shifts hue with the tone of your conversation. On a notch Mac you can also reveal it by gliding your pointer to the top-center of the screen. Escape dismisses it, and typing a single `/` lists every command Ghost understands.

![Ghost answering "Show me what the planet Saturn looks like" in the notch, with an embedded Cassini photograph and its source](docs/answer-saturn.jpg)

Ghost routes every prompt through an intent classifier that detects what you're actually trying to do — Answer, Research, Files, Summarize, Screenshot, Clipboard, Create, Organize, Automation, Messages, Code, Debug, Review, Shell — then picks the right provider and model. Choose from eight providers — **LM Studio** and **Ollama** (fully local), **Claude**, **Gemini**, **DeepSeek**, **OpenCode Go**, **OpenCode Zen**, and any **OpenAI-compatible** server — or run chat on your own **Claude Code**, **Codex**, or **Antigravity** subscription. Local models get probed on first launch for tool-calling capability and assigned the safest calling convention they can handle, so even models that can't do native function calls still get the harness.

![Ghost answering a question about the James Webb Space Telescope with inline citation markers and a four-entry linked reference list](docs/answer-sourced-cost.jpg)

![The Ghost provider picker open beneath the notch composer, listing Claude, Gemini, DeepSeek v4, OpenCode Go, OpenCode Zen and OpenAI Compatible, above a subscription section offering Claude Code, Codex and Antigravity](docs/providers-picker.jpg)

<video src="docs/media/ghost-showcase-main.mp4" controls muted loop width="100%"></video>

<br/>
<br/>

## Ghost remembers you.

<sub><samp>ON-DEVICE KNOWLEDGE BASE · PLAIN MARKDOWN YOU OWN</samp></sub>

Tell Ghost "remember that I take my coffee black" or "my sister's name is Mara," and it saves a durable fact to a personal knowledge base. From then on it quietly grounds your chats with what it knows — no re-explaining yourself every session. Ask "what do you know about me?" to see it all.

It isn't a black box: your knowledge base is plain Markdown at `~/Ghost Outputs/Knowledge`. Read it, edit it, or delete a note anytime. Nothing about you is stored on a server.

<br/>

## Your files, searched locally. No cloud. No embeddings API. No vector DB SaaS.

<sub><samp>SQLITE + FTS5 · 30+ FORMATS · FSEVENTS SYNC</samp></sub>

Ghost indexes folders you approve into a local SQLite database with FTS5 full-text search — 3,500-character chunks with 500-character overlap, sentence-aware splitting, page numbers from PDFs, section titles from Markdown. A desktop watcher keeps everything in sync with an 8-second debounce. Queries return source-backed chunks with file paths; Ghost opens the exact file at the right line.

30+ formats: txt, md, html, pdf, docx, epub, csv, json, rtf, and every major programming language. Everything stays on your machine.

![Ghost listing a repository's markdown files as rendered tables of file names and sizes, with the folders it read shown as references](docs/files-folder-listing.jpg)

<br/>

## Real files, not chat bubbles.

<sub><samp>DOCX · PDF · PPTX · XLSX · MARKDOWN · HTML · CSV · JSON</samp></sub>

Ask Ghost to create a file and it writes one — not a code block you copy-paste out of a chat window. Native macOS frameworks generate DOCX, PDF, PPTX, XLSX, Markdown, HTML, CSV, and JSON. Files land in your workspace, Ghost Outputs, Desktop, Downloads, or Documents, and every produced document is listed in Document Studio so you can find it again. Every write is verified; if a model claims a file was saved without a confirmed write, Ghost treats that as an error instead of silently trusting it.

<video src="docs/demo-html-game.mp4" controls muted loop width="800"></video>

[▶ Watch: an HTML game Ghost wrote, running as a real file from the Desktop (MP4)](docs/demo-html-game.mp4)

[View the generated solar system demo](docs/media/solar-system-demo.html)

<br/>

## Nearly eighty tools, four risk tiers, one undo journal.

<sub><samp>THE MODEL NEVER TOUCHES YOUR FILESYSTEM</samp></sub>

The capability harness is Ghost's action layer. The model requests an action; Ghost normalizes the path, checks permissions, runs app-owned Swift code, and returns a machine-readable receipt. Around **78 tools** span file operations, document generation and conversion, web search and fetch, Calendar events, Reminders, Apple Notes, iMessage and FaceTime, screen capture with Vision OCR, on-device voice input, memory, and a full suite of Mac controls.

Every tool is classified into four risk tiers — Low (read-only), Medium (writes/creates), High (patches/deletes/shell), and Blocked (unknown tools fail closed). An action journal records before-and-after state so you can roll back what Ghost changed. A created or edited file, a folder, any generated document, an Apple Note, a reminder, a calendar event, and an app Ghost opened or quit are each one tap of **Undo** away, right on the action card in the transcript. Two actions are outside the journal on purpose: uninstalling an app and clearing junk both move things to the Trash rather than deleting them, so recovery is Finder's **Put Back**, and the card says so instead of offering an Undo it cannot honour. Six independent permission switches (web, files, automation, messaging, screen, terminal) are all off by default and toggle independently, with three approval modes — Ask, Safe, and Auto-run.

![The Privacy and Access page with an independent switch for web, files, Mac automation, Messages, screen capture, and Terminal](docs/screenshots/app/privacy-access.jpg)

<video src="docs/demo-moving-screenshots.mp4" controls muted loop width="800"></video>

[▶ Watch: Ghost moving screenshots into a folder as a verified, undoable file action (MP4)](docs/demo-moving-screenshots.mp4)

<br/>

## Runs your Mac, not just your prompts.

<sub><samp>ON-DEVICE · DETERMINISTIC · APPROVAL-GATED WHEN IT MATTERS</samp></sub>

Ask Ghost to actually _do_ things on your Mac. A live **system report** covers CPU, memory, disk, battery health and cycles, chip temperatures, and top processes. Quick actions toggle Dark Mode, set brightness, switch audio devices, mute the mic, empty the Trash, keep the Mac awake, lock the screen, and reveal hidden files. It snaps and tiles windows, manages Homebrew, uninstalls apps completely (with their caches and preferences), scans and clears junk (dry-run first), converts and compresses media, picks a screen color, and runs any macOS Shortcut.

And for anything no built-in tool covers, **computer-use** kicks in: Ghost writes an AppleScript for the task and runs it _only_ after you review and approve the exact script — nothing executes until you say yes.

![Ghost answering "What is my battery health?" with a live battery reading from the on-device system report](docs/Battery Health Ghost.png)

<br/>

## Your day, handled.

<sub><samp>DAILY BRIEF · REMINDERS · CALENDAR · NOTES</samp></sub>

Ask "what's on my plate?" and Ghost returns a ranked daily brief — overdue and upcoming Reminders plus imminent Calendar events, in one glance. Create reminders and events in plain language ("remind me to call the dentist Thursday at 10"), make and append to Apple Notes, and search your notes on-device. Ghost can also quietly prepare proactive suggestions from what's due — but it never fires them on its own.

![Ghost answering "What's on my plate for today?" with a dated agenda of the day's to-dos and their due times](docs/calendar-agenda.png)

<br/>

## Messages, Notes, and calls — on device, by design.

<sub><samp>YOUR PERSONAL DATA NEVER TOUCHES A CLOUD MODEL</samp></sub>

Ghost reads recent iMessages, sends texts, and starts FaceTime calls — after you confirm the recipient and message. It searches your Apple Notes and can read your Contacts to match "Mom" to the right number. This is the most personal data on your Mac, so Ghost draws a hard line: **Messages, Notes, Mail, and Contacts are processed on-device only and are never sent to any cloud model** — not for answers, not for memory, not for tools. To use them with AI at all, pick a local model (LM Studio or Ollama). Messaging is off by default and reading iMessages requires Full Disk Access.

![Ghost reading a recent iMessage thread on-device, showing the conversation inline with a reply field](docs/Imessage Ghost.png)

<br/>

## A pomodoro that keeps the receipts.

<sub><samp>FOCUS · BREAK · LONG BREAK · AND THE RECORD OF ALL OF IT</samp></sub>

Ask for "a 25 minute focus timer" or "remind me to check the oven in 10 minutes" and Ghost starts a countdown right there — deterministic, local, no model inference. Anything that counts as focus time runs as a pomodoro phase: name the subject, and Ghost runs the cycle for you, starting the break itself and reaching for the long break every fourth session. Controls are pause, +5m, skip and stop; active timers take over the compact surface and finished ones reopen with a trackpad haptic.

![A focus phase counting down on the subject "Algorithms", with cycle dots and pause, +5m, skip and stop controls](docs/timer-bar.jpg)

Every completed phase is written to a study log on disk, and the right half of the section is the record built from it — time studied today and this week, sessions completed, current streak, progress against a daily goal, a fifteen-week heatmap, and where the hours actually went by subject. The log never leaves the machine, and it is deliberately never handed to a model as context.

![The Timer section showing the pomodoro card beside a study record with stat tiles, a daily goal bar, a fifteen-week heatmap, and per-subject totals](docs/pomodoro-study-record.jpg)

<br/>

## Rewrite anything, anywhere.

<sub><samp>SELECT TEXT · THE BAR COMES TO YOU</samp></sub>

Select text in any app and a small bar appears beside it: Copy, Search, Summarize, Fix, with Professional, Casual, Humanize, Explain and Translate one click away — and Ask Ghost or Write email to carry the selection into the main window.

The result opens in the bar itself. **Replace** writes it back into the field you selected in through the Accessibility API rather than the clipboard, so that app's own ⌘Z still undoes it. Replace only appears when the field is editable and the action actually produces replacement text — a summary is never pasteable over the paragraph it summarized. Press ⌃⌥Space to bring the bar back, Escape to dismiss it.

Right-click → Services → Ghost still works everywhere too.

![Text selected in TextEdit with Ghost's action bar beside it, expanded to show Rewrite Professionally, Rewrite Casually, Humanize, Explain This and Translate](docs/rewrite-actions.jpg)

![Ghost's Professional rewrite card over the selected draft, showing the rewritten text, a What changed note, and Copy and Replace buttons](docs/rewrite-anywhere.jpg)

<br/>

## Sections, and a terminal.

<sub><samp>CHAT · TIMER · TERMINAL · SETTINGS</samp></sub>

A bar across the top of the Ghost window switches between sections in one click, and stays put as you move between them. Approval prompts deliberately get no tab — they're decisions to make, not places to go.

![The Terminal section answering "What is the last file I added to desktop?" in plain English, with the working directory, a Build chip and the Claude Code · Sonnet 5 route shown above the answer](docs/screenshots/app/terminal.jpg)

**Terminal** takes both halves of the job. Type a command and it runs: arrow keys walk history, `clear` empties the scrollback, and `cd` carries to the next command. Type what you want changed instead — in plain English — and it goes to Ghost's coding agent, rooted at whatever directory you last `cd`'d to and running on the provider or subscription you already configured. Progress streams as it works, and the agent's own commands (`/plan`, `/build`, `/init`, `/files`) work at the same prompt.

Which of the two you get is decided deterministically, without asking a model, so it can't quietly guess wrong — and you can force either one: prefix a line with `!` to run it as a command, or `>` (or `?`) to send it to the agent. It still runs one command at a time rather than emulating a terminal, so interactive programs like vim or an ssh password prompt aren't supported. It sits behind the same Terminal switch as Ghost's shell tool, off until you turn it on.

![The General settings page inside the Ghost surface](docs/screenshots/app/settings.jpg)

**Timer** is a full pomodoro: start a focus phase, name the subject, and Ghost runs the cycle and keeps the study record beside it. Plain countdowns live there too.

<br/>

## The privacy flex.

<sub><samp>SEVEN GUARANTEES · BUILT SO WE DON'T GET A CHOICE</samp></sub>

Ghost is local-first by design. Here's the machinery:

1. **Your personal data stays on your Mac.** Messages, Notes, Mail, and Contacts are on-device only. Ghost's own tools and memory refuse to send them to a cloud model — for answers, memory, or tools. The one exception is text _you_ select and act on: Summarize can't work unless the model may read it, so the bar names the source app and the provider before you press anything. Use a local model to keep it on the machine.
2. **API keys live in the macOS Keychain.** Ghost will read one from `~/.ghost/.env` or the process environment if that is where you left it, but only to migrate it into the Keychain, chmod the file to `0600` and strip the value from it. It only reads a key when calling that provider.
3. **Local providers can't launch agent mode.** Ollama and LM Studio stay inside Ghost's managed Direct API tool loop. No escape hatch.
4. **Web egress is guarded.** Localhost, private IPv4/IPv6, link-local, multicast, and reserved addresses are blocked. DNS resolution checks every address; redirects to private destinations are rejected.
5. **Sensitive paths require explicit consent.** Before touching `.ssh`, `.gnupg`, `.aws`, `login.keychain`, `.kube/config`, or `.env`, Ghost prompts: Allow Once, Always This Session, or Deny.
6. **Actions ask first, and can be undone.** High-risk and irreversible actions always confirm, and file changes are journaled and reversible.
7. **Everything starts off.** Web, files, automation, messaging, screen, and shell are all disabled on first launch. You opt in one switch at a time.

![The AI settings page showing the selected model, the provider picker, and Auto / Always Agent / Always Direct routing with the route Ghost chose](docs/screenshots/app/model-routing.jpg)

<br/>

## Questions, answered.

<details>
<summary><b>How is Ghost priced? What's the catch?</b></summary>
<br/>

Free 24-hour trial, then a one-time $14.99 lifetime license. No subscriptions, no recurring charges, no hidden costs. Bring your own API keys for hosted models, run your existing Claude/ChatGPT plan through the CLI, or use Ollama and LM Studio for free forever.

</details>

<details>
<summary><b>Do I need to pay for AI models too?</b></summary>
<br/>

Local models (Ollama, LM Studio) run entirely on your machine and cost nothing. Hosted models (Claude, Gemini, DeepSeek, OpenCode Go, OpenCode Zen, any OpenAI-compatible server) need your own API keys — you pay those providers directly at their usage rates, not through Ghost. You can also point Ghost at your existing Claude Code or Codex subscription and run chat through it at no extra cost. Ghost itself is just the workspace.

<video src="docs/demo-api-key.mp4" controls muted loop width="800"></video>

[▶ Watch: adding a provider API key in Ghost Settings (MP4)](docs/demo-api-key.mp4)

</details>

<details>
<summary><b>What actually leaves my Mac?</b></summary>
<br/>

Your most personal data — Messages, Notes, Mail, Contacts — never leaves your Mac for a cloud model, ever. When using local models: nothing leaves at all. When using hosted models: your prompt and any attached files go to that provider's API, governed by their privacy policy — the same one your account already lives under. Your knowledge base, RAG index, and API keys never leave your Mac. Web search fetches public pages through Ghost's egress guard; screenshots sent for OCR go to Apple's on-device Vision framework, not a cloud service.

</details>

<details>
<summary><b>Notch or floating bar?</b></summary>
<br/>

Both. On a notch Mac, Ghost drops from the camera notch and the typing pill sits flush just below it. Prefer it elsewhere? Switch to the floating bar and Ghost becomes a clean, high-contrast text field near the bottom of the screen. Pick whichever fits your setup in Settings; the shortcut summons either one.

</details>

<details>
<summary><b>What Macs does it run on?</b></summary>
<br/>

macOS 14 or later, Apple Silicon or Intel. Ghost is a native SwiftUI app notarized by Apple. Local model inference performance depends on your hardware; LM Studio and Ollama manage their own resource usage independently of Ghost.

</details>

<details>
<summary><b>Can I use Ghost for coding?</b></summary>
<br/>

Yes — Ghost Code offers four agent modes: Plan (inspect and propose), Build (edit files and run commands), Explore (read and map a codebase), and Review (inspect diffs and catch bugs). The in-app Agent Console shows an activity timeline with live streaming output, and you can drive it with your own Claude Code or Codex plan.

</details>

<br/>

## Fixed: builds 2.0.1 – 2.0.5 stopped telling you about updates.

<sub><samp>AFFECTS 2.0.1 – 2.0.5 · FIXED IN 2.0.6 · CURRENT RELEASE 2.1.0</samp></sub>

**2.0.6 restored both surfaces: updates are presented again when one is found, and Settings carries a Check for Updates button beside the version number.** The current release, 2.1.0, includes that fix. Nothing about this was ever a risk to your Mac; Ghost simply went quiet about its own updates.

If you are running Ghost 2.0.1 through 2.0.5, **your copy will not tell you that 2.1.0 exists, and it has no button to ask with.** The fix cannot reach you through the thing it fixes — you have to install it once by hand, and it works normally from then on.

What happened: the "Check for Updates" button and the "update available" notice both lived in an older window that was removed in July when it stopped being part of the app. The updater underneath kept working the whole time — it checks on schedule and it does find new versions — but it had been told that Ghost would display what it found, and after the removal Ghost had nowhere to display it. So an affected build checks, finds an update, and says nothing.

What to do, if you are on 2.0.1 – 2.0.5:

- **If you turned on automatic downloading and installing**, you are already fine — Sparkle installs new versions without needing anything from Ghost's interface, so 2.1.0 will arrive on its own.
- **Otherwise you will never be prompted, including if you only enabled automatic _checking_.** Checking is what most people turned on, and a check is exactly what these builds swallow. Download 2.1.0 by hand from **[integratedagentics.com/ghost](https://integratedagentics.com/ghost)** or the [releases page](https://github.com/ryuhemingway/Ghost-App/releases/latest), both of which serve the newest release.

<br/>

<br/>

## Under the hood.

<sub><samp>SWIFTUI · APPKIT · SPARKLE · SQLITE</samp></sub>

Ghost is a native macOS app, not Electron, not a web wrapper.

- **The interface.** <samp>NSVisualEffectView glass · notch or floating bar · reactive aurora background · HK Grotesk + Source Serif Pro · spring animations</samp>
- **The routing engine.** <samp>14 intent kinds · eight providers plus BYO Claude/ChatGPT plan · 4 effort levels · 3 approval modes · auto agent-vs-direct routing</samp>
- **The model probe.** <samp>tests every local model for chat, JSON mode, native tool calls, and argument accuracy · assigns the safest calling convention</samp>
- **Memory.** <samp>on-device Markdown knowledge base · remember / recall · ambient grounding · semantic recall · lives in ~/Ghost Outputs/Knowledge</samp>
- **The RAG system.** <samp>SQLite + FTS5 · 3,500-char chunks · 500-char overlap · sentence-aware · page numbers from PDFs · FSEvents watcher · 30+ formats</samp>
- **The harness.** <samp>~78 tools · 4 risk tiers · undo journal · path normalization · permission gating · verified writes · approval-gated computer-use</samp>
- **Privacy engine.** <samp>on-device-only gate for Messages / Notes / Mail / Contacts · web egress guard · Keychain-stored keys · sensitive-path consent</samp>
- **The experience details.** <samp>trackpad haptics on summon and answer · daily brief · proactive suggestions · latency sparkline · token & cost meter · ⌘K command palette · Prompt Library · right-click rewrite services</samp>

<br/>

## Who's building this.

I'm Ryu, a solo dev building Ghost because I wanted a Mac AI workspace that didn't force me to juggle six different surfaces just to get through a focused hour. Ghost is the app I wanted to use myself — local-first, notch-native, and one tap away from anywhere.

Say hi: [GitHub](https://github.com/ryuhemingway)

<br/>

---

<div align="center">

**[Download Ghost](https://github.com/ryuhemingway/Ghost-App/releases/latest)** · **[Website](https://integratedagentics.com/ghost)**

<sub><samp>DOCS MIT · APP PROPRIETARY · APPLE-NOTARIZED · <a href="https://integratedagentics.com/ghost">INTEGRATEDAGENTICS.COM/GHOST</a></samp></sub>

</div>
