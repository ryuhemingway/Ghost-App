# Ghost App Website

A clean, dark, minimal, premium marketing site for the Ghost macOS app. It showcases Ghost's notch-first command surface, timers, model routing, providers, verified Mac actions, and local-first privacy in a fast, legible static page — no heavy 3D dependencies.

## Overview

The site is a static showcase surface for the Ghost macOS app:

- A sticky nav with smooth-scroll anchors.
- A hero with the product positioning and at-a-glance stats.
- A tour of the notch-first summon flow, Direct API and agent routing, RAG memory, verified actions, native Mac integrations, and deeper-work modes.
- A providers section (local + hosted).
- A local-first privacy section; current screenshots and the sped-up demo video live alongside the site assets.
- Subtle scroll-reveal animations and a pointer-follow glow on cards.
- Fully responsive and respects `prefers-reduced-motion`.

## Run locally

No build step or dependencies are required — the site is plain HTML/CSS/JS and loads only Google Fonts.

```bash
python3 -m http.server 4173 --directory docs
```

Then open:

```text
http://127.0.0.1:4173
```

## Controls

- **Nav links:** smooth-scroll to each section.
- **Theme toggle:** switch between dark and light presentation.
- **FAQ rows:** expand one answer at a time.

## Customization

- Edit FAQ content and page interactions in `docs/script.js`.
- Tune the dark/glass visual system in `docs/styles.css` (CSS custom properties at the top).
- Replace `docs/assets/ghost-hero.png` with a real Open Graph preview when available.
- Replace `docs/media/ghost-demo.mp4` and `docs/media/ghost-demo-poster.png` when the product demo is re-recorded.

## Project Structure

```text
docs/
  index.html        Static shell and content sections
  styles.css        Dark/minimal/premium visual system
  script.js         FAQ data, theme toggle, navigation, scroll reveal
  assets/
    ghost-hero.png  Open Graph preview image
  media/
    ghost-demo.mp4
    ghost-demo-poster.png
  screenshots/
    app/            Current native app screenshots
```

## Notes

This is a secondary gallery surface for the Ghost macOS app, not the app itself. The native app lives in `Sources/Ghost/`.

## Where the assets live

**Everything under `docs/` is published. Nothing internal lives here.** That is
the whole rule, and it is structural rather than a list of `--exclude` flags to
remember: `ARCHITECTURE.md` and the internal security audit sit at the
repository root, not in this directory, so a wholesale sync of `docs/` cannot
leak them. If you add something here, assume the world can read it.

Two asset directories, split by which document loads them:

| Directory | Loaded by | Contents |
| --- | --- | --- |
| `media/` | `index.html` — this site | Site imagery and the `demo-*.mp4` clips, kebab-case, already encoded for the web |
| `readme/` | `../README.md` — the GitHub front page | App screenshots and answer examples. See `readme/CAPTURES.md` |

Nothing is shared between them, which is deliberate: a file in `media/` can be
renamed or recropped for the site without silently changing what the README
shows, and vice versa. It also means "is this used?" is answerable by grepping
one file rather than guessing.

**Encode before committing.** Raw captures off a Retina display run 8–10 MB
each, and the README's were doing exactly that — the front page cost 25 MB in
three images. `sips -s format jpeg -s formatOptions 82 -Z 2400 in.png --out
out.jpg` cut the same three to 1.1 MB with no visible loss. The raw masters are
not in this repository at all; see `readme/CAPTURES.md`.
