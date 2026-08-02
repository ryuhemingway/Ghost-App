<div align="center">

<a href="https://integratedagentics.com/ghost"><img src="docs/hero-einstein.png" alt="Ghost answering &quot;What was Albert Einsteins most important equation?&quot; in the notch surface, with inline citations and a numbered reference list" width="820" /></a>

<samp>v2.0.4 · notarized · one-time purchase · macOS 14+</samp>

<video src="docs/demo-empire-state.mp4" controls muted loop width="800"></video>

[▶ Watch: asking Ghost what the Empire State Building looks like, from the floating bar (MP4)](docs/demo-empire-state.mp4)

</div>

<br/>

Every AI tool today has the same problem: you're the one doing all the context switching. ChatGPT tab, local model UI, terminal agent, document viewer, timer app, Calendar, Reminders — seven surfaces just to get through a focused hour of work. Ghost replaces all of them with one surface that lives in your menu bar and opens with ⌥Space.

So you type a question, attach a file, dictate a note, or start a focus timer — and Ghost routes it to the right model (local or cloud, or your own Claude/ChatGPT plan), searches your indexed documents, remembers what matters about you, creates real files, runs verified Mac actions, and drops back out of sight. No Dock icon, no tab management, no full-screen takeover. Just the work, done.

By default, everything is off: web access, file tools, automation, messaging, screen capture, shell. You opt in one switch at a time. API keys live in your Keychain, not in a `.env` file. Local models run entirely on your machine with the same tool harness the cloud models get. And your most personal data — Messages, Notes, Mail, Contacts — is processed **on device only**: Ghost never sends it to a cloud model on its own initiative, and when you deliberately act on a selection from one of those apps, it tells you where the text is going first.

<br/>

## New in 2.0.4

- **Ghost comes to your text.** Select anything in any app and a small bar appears beside it — Copy, Search, Summarize, Fix, plus rewrites, Explain and Translate. Replace writes the result straight back into the field you selected in, so that app's own undo still works.
- **Sections across the top.** One bar switches the Ghost window between Chat, Timer, Terminal, and Settings.
- **A terminal inside Ghost.** Run shell commands without leaving the window, behind the same permission switch as its shell tool.
- **A cleaner surface.** The typing pill now sits flush just below the camera notch — nothing clipped, no matter how much you type. In floating-bar mode it's a genuine floating text field with a frosted, high-contrast background and no dark slab around it.
- **Ghost remembers you.** An on-device knowledge base quietly grounds every chat, so Ghost knows your people, your preferences, and "the usual." It's plain Markdown you own.
- **Your private data stays on device.** Messages, Notes, Mail, and Contacts never leave your Mac for a cloud model — not for answers, memory, or tools. Use a local model to let AI touch them.
- **Your day, handled.** A ranked daily brief, Reminders, Calendar, and Apple Notes — read and write, in plain language.
- **Messages & FaceTime.** Read and send iMessages and start calls (on-device, opt-in, and confirmed before anything sends).
- **Computer-use.** For a Mac task no built-in tool covers, Ghost writes an AppleScript and runs it *only* after you approve the exact script.
- **Bring your own subscription.** Run chat through your existing Claude Code or Codex CLI — your account, your plan, at no extra cost.
- **Nearly eighty built-in tools**, including a full suite of on-device Mac controls — system report, brightness, audio, dark mode, window snapping, Homebrew, app uninstall, junk cleanup, media conversion, and more.

<br/>

## One surface, eight providers, zero context switching.

<sub><samp>⌥SPACE · ANYWHERE ON MACOS</samp></sub>

Press ⌥Space anywhere on your Mac and a frosted-glass surface appears — dropping from the camera notch, or floating up as a text bar near the bottom of the screen, your choice. Chat, file creation, document search, memory, timers, Calendar, Reminders, Notes, screen OCR, and agent coding sessions all live in one place. The aurora background shifts hue with the tone of your conversation. On a notch Mac you can also reveal it by gliding your pointer to the top-center of the screen. Escape dismisses it, and ⌘K opens a command palette for everything else.

![Ghost answering "What does saturn look like?" in the notch surface, with an embedded image of Saturn and a numbered source list](docs/answer-saturn.png)

Ghost routes every prompt through an intent classifier that detects what you're actually trying to do — Answer, Research, Files, Summarize, Screenshot, Clipboard, Create, Organize, Automation, Messages, Code, Debug, Review, Shell — then picks the right provider and model. Choose from eight providers — **LM Studio** and **Ollama** (fully local), **Claude**, **Gemini**, **DeepSeek**, **OpenCode Go**, **OpenCode Zen**, and any **OpenAI-compatible** server — or run chat on your own **Claude Code** or **Codex** subscription. Local models get probed on first launch for tool-calling capability and assigned the safest calling convention they can handle, so even models that can't do native function calls still get the harness.

![Ghost answering "What is the cost of living in San Fran?" with a sourced cost breakdown and a six-entry reference list](docs/answer-sourced-cost.png)

![The Ghost provider picker open above the floating bar, listing LM Studio, Ollama, Claude, Gemini, DeepSeek, OpenCode Go, OpenCode Zen, OpenAI Compatible, and your own Claude Code or Codex subscription](docs/providers-picker.png)

<video src="docs/media/ghost-showcase-main.mp4" controls muted loop width="100%"></video>

<br/>

## Or let it drop from the notch.

<sub><samp>NOTCH-FIRST · TOP-CENTER · SAME SURFACE, SAME TOOLS</samp></sub>

Prefer it up top? Ghost condenses out of the camera notch and expands only as far as the answer needs — inline imagery, citations, and the composer in one frosted panel, anchored where your eyes already are. Glide the pointer to the top-center of the screen to reveal it instead of reaching for the shortcut. Everything the floating bar does, the notch does — it's a single toggle in Settings, not a separate mode.

![Ghost answering "What does the solar system look like?" from the camera notch, with an embedded true-color solar system image and numbered sources](docs/notch-solar-system.png)

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

![Ghost listing the contents of a Desktop folder as a table of items, types, and modified dates, with a routing verification block](docs/files-folder-listing.png)

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

Every tool is classified into four risk tiers — Low (read-only), Medium (writes/creates), High (patches/deletes/shell), and Blocked (unknown tools fail closed). An action journal records before-and-after state so you can roll back any run — a created file, note, reminder, or event is one tap of **Undo** away, right on the action card in the transcript. Six independent permission switches (web, files, automation, messaging, screen, terminal) are all off by default and toggle independently, with three approval modes — Ask, Safe, and Auto-run.

![Reading a Desktop folder, with a verification receipt showing how the request was routed](docs/screenshots/app/local-file-access.png)

<video src="docs/demo-moving-screenshots.mp4" controls muted loop width="800"></video>

[▶ Watch: Ghost moving screenshots into a folder as a verified, undoable file action (MP4)](docs/demo-moving-screenshots.mp4)

<br/>

## Runs your Mac, not just your prompts.

<sub><samp>ON-DEVICE · DETERMINISTIC · APPROVAL-GATED WHEN IT MATTERS</samp></sub>

Ask Ghost to actually *do* things on your Mac. A live **system report** covers CPU, memory, disk, battery health and cycles, chip temperatures, and top processes. Quick actions toggle Dark Mode, set brightness, switch audio devices, mute the mic, empty the Trash, keep the Mac awake, lock the screen, and reveal hidden files. It snaps and tiles windows, manages Homebrew, uninstalls apps completely (with their caches and preferences), scans and clears junk (dry-run first), converts and compresses media, picks a screen color, and runs any macOS Shortcut.

And for anything no built-in tool covers, **computer-use** kicks in: Ghost writes an AppleScript for the task and runs it *only* after you review and approve the exact script — nothing executes until you say yes.

![Ghost answering "How much free space do I have?" and "What is my battery health?" with live storage and battery readings from the on-device system report](docs/mac-free-space.png)

<br/>

## Your day, handled.

<sub><samp>DAILY BRIEF · REMINDERS · CALENDAR · NOTES</samp></sub>

Ask "what's on my plate?" and Ghost returns a ranked daily brief — overdue and upcoming Reminders plus imminent Calendar events, in one glance. Create reminders and events in plain language ("remind me to call the dentist Thursday at 10"), make and append to Apple Notes, and search your notes on-device. Ghost can also quietly prepare proactive suggestions from what's due — but it never fires them on its own.

![Ghost answering "What's on my plate for today?" with a dated agenda of the day's to-dos and their due times](docs/calendar-agenda.png)

<br/>

## Messages, Notes, and calls — on device, by design.

<sub><samp>YOUR PERSONAL DATA NEVER TOUCHES A CLOUD MODEL</samp></sub>

Ghost reads recent iMessages, sends texts, and starts FaceTime calls — after you confirm the recipient and message. It searches your Apple Notes and can read your Contacts to match "Mom" to the right number. This is the most personal data on your Mac, so Ghost draws a hard line: **Messages, Notes, Mail, and Contacts are processed on-device only and are never sent to any cloud model** — not for answers, not for memory, not for tools. To use them with AI at all, pick a local model (LM Studio or Ollama). Messaging is off by default and reading iMessages requires Full Disk Access.

![Ghost reading a recent iMessage thread on-device, showing the conversation inline with a reply field](docs/messages-katie.png)

<br/>

## Timers that mean it.

<sub><samp>DETERMINISTIC · LOCAL · NO MODEL CALLED</samp></sub>

Ask for "a 25 minute focus timer" or "remind me to check the oven in 10 minutes" and Ghost starts a countdown right in the bar — deterministic, local, no model inference. Active timers take over the compact surface. Completed timers reopen with a trackpad haptic. Controls include pause, resume, +5m, restart, cancel, and dismiss.

![Ghost timer bar counting down 4:57 remaining, with Pause, +5m, Cancel, and Ask controls](docs/timer-bar.png)

<br/>

## Rewrite anything, anywhere.

<sub><samp>SELECT TEXT · THE BAR COMES TO YOU</samp></sub>

Select text in any app and a small bar appears beside it: Copy, Search, Summarize, Fix, with Professional, Casual, Humanize, Explain and Translate one click away — and Ask Ghost or Write email to carry the selection into the main window.

The result opens in the bar itself. **Replace** writes it back into the field you selected in through the Accessibility API rather than the clipboard, so that app's own ⌘Z still undoes it. Replace only appears when the field is editable and the action actually produces replacement text — a summary is never pasteable over the paragraph it summarized. Press ⌃⌥Space to bring the bar back, Escape to dismiss it.

Right-click → Services → Ghost still works everywhere too.

![A note selected in Apple Notes with Ghost's Professional rewrite card below it, showing what changed and Reject / Accept buttons](docs/rewrite-anywhere.png)

<br/>

## Sections, and a terminal.

<sub><samp>CHAT · TIMER · TERMINAL · SETTINGS</samp></sub>

A bar across the top of the Ghost window switches between sections in one click, and stays put as you move between them. Approval prompts deliberately get no tab — they're decisions to make, not places to go.

**Terminal** runs shell commands in the window: arrow keys walk history, `clear` empties the scrollback, and `cd` carries to the next command. It runs one command at a time rather than emulating a terminal, so interactive programs like vim or an ssh password prompt aren't supported. It sits behind the same Terminal switch as Ghost's shell tool, off until you turn it on.

**Timer** starts Focus, Break, Deep Work, or a plain ten-minute timer directly, with no model involved.

<br/>

## The privacy flex.

<sub><samp>SEVEN GUARANTEES · BUILT SO WE DON'T GET A CHOICE</samp></sub>

Ghost is local-first by design. Here's the machinery:

1. **Your personal data stays on your Mac.** Messages, Notes, Mail, and Contacts are on-device only. Ghost's own tools and memory refuse to send them to a cloud model — for answers, memory, or tools. The one exception is text *you* select and act on: Summarize can't work unless the model may read it, so the bar names the source app and the provider before you press anything. Use a local model to keep it on the machine.
2. **API keys live in the macOS Keychain.** Not `.env` files, not plaintext configs. Ghost only reads a key when calling that provider.
3. **Local providers can't launch agent mode.** Ollama and LM Studio stay inside Ghost's managed Direct API tool loop. No escape hatch.
4. **Web egress is guarded.** Localhost, private IPv4/IPv6, link-local, multicast, and reserved addresses are blocked. DNS resolution checks every address; redirects to private destinations are rejected.
5. **Sensitive paths require explicit consent.** Before touching `.ssh`, `.gnupg`, `.aws`, `login.keychain`, `.kube/config`, or `.env`, Ghost prompts: Allow Once, Always This Session, or Deny.
6. **Actions ask first, and can be undone.** High-risk and irreversible actions always confirm, and file changes are journaled and reversible.
7. **Everything starts off.** Web, files, automation, messaging, screen, and shell are all disabled on first launch. You opt in one switch at a time.

![Ghost model routing across local and cloud providers](docs/screenshots/app/model-routing.png)

<br/>

## Questions, answered.

<details>
<summary><b>How is Ghost priced? What's the catch?</b></summary>
<br/>

Free 2-day trial, then a one-time $10 lifetime license. No subscriptions, no recurring charges, no hidden costs. Bring your own API keys for hosted models, run your existing Claude/ChatGPT plan through the CLI, or use Ollama and LM Studio for free forever.

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
