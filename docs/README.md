# Ghost App Website

A clean, dark, minimal, premium marketing site for the Ghost macOS app. It showcases Ghost's capabilities, providers, how-it-works flow, and local-first privacy in a fast, legible static page — no heavy 3D dependencies.

## Overview

The site is a static showcase surface for the Ghost macOS app:

- A sticky nav with smooth-scroll anchors.
- A hero with the product positioning and at-a-glance stats.
- A filterable capabilities grid (24 built-in capabilities) with a detail modal.
- A "How it works" step flow.
- A providers section (local + hosted).
- A local-first privacy section and a closing call-to-action.
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

- **Filter chips:** filter capabilities by module (Routing, Local, Cloud, Retrieval, Actions, Native, Developer).
- **Click a card:** open the capability detail modal.
- **Esc / backdrop / ✕:** close the modal.
- **Nav links:** smooth-scroll to each section.

## Customization

- Edit capability content in `docs/script.js` (`const cards = [...]`).
- Tune the dark/glass visual system in `docs/styles.css` (CSS custom properties at the top).
- Replace `docs/assets/ghost-hero.png` with a real Open Graph preview when available.

## Project Structure

```text
docs/
  index.html        Static shell and content sections
  styles.css        Dark/minimal/premium visual system
  script.js         Capability data, filtering, modal, scroll reveal
  assets/
    ghost-hero.png  Open Graph preview image
  screenshots/
    app/            App visual previews (SVG)
```

## Notes

This is a secondary gallery surface for the Ghost macOS app, not the app itself. The native app lives in `Sources/Ghost/`.
