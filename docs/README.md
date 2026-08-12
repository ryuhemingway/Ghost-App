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
