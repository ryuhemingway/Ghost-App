# Ghost Sphere Gallery

An immersive 3D gallery experience for Ghost, built with **Three.js** and **GSAP**. The viewer sits inside a dark spherical gallery dimension while image cards orbit on the inner surface of the space. Drag to rotate, hover to focus, click to open a polished detail page, and return cleanly to the gallery.

The interaction is inspired by the premium spatial feel of [Phantom](https://www.phantom.land/) without copying its exact design.

## Overview

Ghost Sphere Gallery turns the existing Ghost landing page into a cinematic, full-screen portfolio surface:

- The camera feels placed inside a spherical card environment.
- Cards are distributed around the viewer in a dome/sphere formation.
- Pointer and touch dragging use smooth inertial easing.
- Hovered cards scale and brighten for a premium focus state.
- Clicking a card opens a GSAP-animated detail template.
- Returning from detail restores the 3D scene without a reload.

## Features

- Full-screen Three.js scene
- Spherical/dome-like card placement
- Smooth drag rotation with inertial decay
- Responsive desktop and mobile layout
- Raycast hover and click interactions
- GSAP detail-page transitions
- Generated placeholder card imagery using canvas textures
- Debug hooks for testing and screenshot capture
- Clean static hosting through `docs/` for GitHub Pages

## Tech Stack

- **Three.js** for the 3D scene, camera, cards, raycasting, and rendering
- **GSAP** for card focus and detail-page animation
- **Vanilla HTML/CSS/JS** for the shell, HUD, controls, and overlay
- **Static GitHub Pages-ready docs folder**

Dependencies are loaded in `docs/index.html` through an import map:

```html
"three": "https://unpkg.com/three@0.165.0/build/three.module.js"
"gsap": "https://esm.sh/gsap@3.12.5"
```

## Screenshots

### Main Spherical Gallery

![Main spherical gallery](docs/screenshots/main-spherical-gallery.png)

### Hover / Focused Card State

![Focused card state](docs/screenshots/focused-card-state.png)

### Click / Page Transition State

![Click transition state](docs/screenshots/click-transition-state.png)

### Detail Page Template

![Detail page template](docs/screenshots/detail-page-template.png)

### Mobile Responsive Layout

![Mobile responsive gallery](docs/screenshots/mobile-responsive-gallery.png)

Screenshots are stored in:

```text
docs/screenshots/
```

## Installation

No package installation is required for the gallery. The app is a static site and loads Three.js and GSAP from CDN.

Clone the repository:

```bash
git clone https://github.com/ryuhemingway/Ghost-App.git
cd Ghost-App
```

Optional: if you want to run your own local tooling, install any server you prefer. Python's built-in server is enough.

## Usage

Run the gallery locally:

```bash
python3 -m http.server 4173 --directory docs
```

Open it in the browser:

```text
http://127.0.0.1:4173
```

Interact with the spherical gallery:

- **Drag with mouse or touch:** rotate the gallery around the viewer.
- **Release after dragging:** inertia continues the motion with eased decay.
- **Hover a card:** the card scales and brightens.
- **Click a card:** animate into the detail template.
- **Return to sphere:** click **Return to sphere**.
- **Keyboard:** press `Esc` to close the detail page.

## Project Structure

```text
docs/
  index.html              Static app shell and import map
  styles.css              Premium dark/glass responsive styling
  script.js               Three.js scene, GSAP motion, interactions
  assets/
    ghost-hero.png        Existing Open Graph preview image
  screenshots/
    main-spherical-gallery.png
    focused-card-state.png
    click-transition-state.png
    detail-page-template.png
    mobile-responsive-gallery.png
Sources/Ghost/            Original macOS Ghost app source
Tests/GhostTests/         Original Swift tests
script/build_and_run.sh   Original macOS app build helper
```

## Customization

Edit gallery content in `docs/script.js`:

```js
const cards = [
  {
    kicker: "Agent Router",
    title: "Direct API or agent depth",
    layer: "Routing",
    copy: "Ghost decides whether the prompt needs a fast model answer...",
    palette: ["#8b5cff", "#73e0d3", "#f4ce7a"]
  }
];
```

Useful tuning points:

- Change `radius` inside `createGallery()` to tighten or widen the sphere.
- Adjust card dimensions in `mesh.scale.set(2.65, 3.52, 1)`.
- Tune drag feel with `velocityX`, `velocityY`, and decay values in `tick()`.
- Modify the dark/glass visual system in `docs/styles.css`.
- Replace generated canvas textures with real image assets if desired.

## Troubleshooting

If the page is blank:

- Make sure you are serving through HTTP, not opening `docs/index.html` directly from the filesystem.
- Confirm the browser can reach the Three.js and GSAP CDN URLs.
- Open Chrome DevTools and check the Console tab for network or module-loading errors.

If dragging feels wrong:

- Confirm pointer events are reaching the canvas.
- Test in Chrome with hardware acceleration enabled.
- Lower the renderer pixel ratio in `docs/script.js` if the machine is struggling.

If screenshots need refreshing:

1. Run the local server.
2. Open the gallery in Chrome.
3. Capture current states into `docs/screenshots/`.
4. Update this README if filenames change.

## Original macOS Ghost App

This repository still contains the original Swift macOS Ghost app. To build that app:

```bash
swift build
./script/build_and_run.sh
```

The interactive gallery lives separately in `docs/` and can be hosted independently through GitHub Pages.
