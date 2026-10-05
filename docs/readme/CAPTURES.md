# README captures

Everything the repository's front page (`README.md`) loads. Native macOS
screenshots off the current build, shot against a bare desktop so nothing but
Ghost's own glass is in frame, plus the answer examples.

All of it is JPEG at quality 82, longest side 2400px. That is not a style
preference: raw Retina PNGs are 8–10 MB each, and three of them used to sit at
the top of the README, so opening the front page pulled 25 MB of images. The
same three encode to 1.1 MB and look identical at display size.

```text
hero-notch-answer.jpg   the banner: a snow leopard answer in the Noir notch (2026-10-04)
quick-ask.jpg           the composer under the seven-section bar, RAG hover hint (2026-10-04)
instant-answer.jpg      "what time is it in Tokyo", answered on the Mac, Minimal theme (2026-10-04)
answer-cited.jpg        a cited web answer with a five-entry reference list (2026-10-04)
providers-picker.jpg    the model menu: providers, subscriptions, Claude models (2026-10-04)
agents-overview.jpg     the Agents tab: usage, chats, a live session (2026-10-04)
approval-card.jpg       a live agent asking permission from the notch (2026-10-04)
agents-chat.jpg         a Claude chat in the Agents tab (2026-10-04)
terminal-claude-code.jpg  Claude Code running inside the Terminal section (2026-10-04)
settings-themes.jpg     General settings with the five themes (2026-10-04)
theme-classic.jpg       an answer in the Classic theme (2026-10-04)
theme-tron.jpg          an answer in the Tron theme (2026-10-04)
privacy-access.jpg      the Privacy & Access switches, cropped above the phone link (2026-10-04)
model-routing.jpg       the AI settings page: model, provider, routing
files-folder-listing.jpg  a folder listing read from disk
calendar-agenda.png     today's agenda read from Calendar
timer-bar.jpg           the countdown plate in the notch
pomodoro-study-record.jpg  the study log and heatmap
rewrite-actions.jpg     the selection action bar
rewrite-anywhere.jpg    a rewrite applied in another app
imessage-thread.jpg     an iMessage thread read on-device
battery-health.jpg      a battery reading from the on-device system report
```

The 2026-10-04 set was shot with demo prompts only. Masters are in
`Ghost Media Masters/2026-10-04`. Never capture Countdowns, Catch up, the
Timer or the Privacy page's phone link as they stand: they show real calendar,
mail, messages and an access key.

## The masters are not in this repository

Raw screen recordings and full-resolution captures live in
`~/Desktop/Projects/Ghost Media Masters` (690 MB, 5 video masters plus stills).
They were moved out because they are inputs, not deliverables: the five
`demo-*.mp4` clips in `../media/` are 11 MB encoded, and keeping 690 MB of
sources beside them made the repository twenty times its useful size.

Re-encode from a master rather than re-shooting. The shipped video settings are
1080p, CRF 26; a poster frame must never be frame 1, which is usually black.
