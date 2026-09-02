# README captures

Everything the repository's front page (`README.md`) loads. Native macOS
screenshots off the current build, shot against a bare desktop so nothing but
Ghost's own glass is in frame, plus the answer examples.

All of it is JPEG at quality 82, longest side 2400px. That is not a style
preference: raw Retina PNGs are 8–10 MB each, and three of them used to sit at
the top of the README, so opening the front page pulled 25 MB of images. The
same three encode to 1.1 MB and look identical at display size.

```text
hero-notch-answer.jpg   the banner: an answer in the notch, provider/model chips
notch-hero.jpg          an answer in the notch, with timing chips
quick-ask.jpg           the resting composer hanging from the notch
model-routing.jpg       the AI settings page: model, provider, routing
privacy-access.jpg      the Privacy & Access page, one switch per capability
settings.jpg            the General settings page
terminal.jpg            the Terminal section
providers-picker.jpg    the provider picker beneath the composer
answer-saturn.jpg       an answer with an inline image and its source
answer-sourced-cost.jpg a cited answer with a linked reference list
files-folder-listing.jpg  a folder listing read from disk
calendar-agenda.png     today's agenda read from Calendar
timer-bar.jpg           the countdown plate in the notch
pomodoro-study-record.jpg  the study log and heatmap
rewrite-actions.jpg     the selection action bar
rewrite-anywhere.jpg    a rewrite applied in another app
imessage-thread.jpg     an iMessage thread read on-device
battery-health.jpg      a battery reading from the on-device system report
```

## The masters are not in this repository

Raw screen recordings and full-resolution captures live in
`~/Desktop/Projects/Ghost Media Masters` (690 MB, 5 video masters plus stills).
They were moved out because they are inputs, not deliverables: the five
`demo-*.mp4` clips in `../media/` are 11 MB encoded, and keeping 690 MB of
sources beside them made the repository twenty times its useful size.

Re-encode from a master rather than re-shooting. The shipped video settings are
1080p, CRF 26; a poster frame must never be frame 1, which is usually black.
