/* ============================================
   GHOST — Flowing website interactions
   GSAP · Three.js · Custom cursor · Side nav
   ============================================ */

gsap.registerPlugin(ScrollTrigger);

/* ---------------- FAQ DATA ---------------- */
const faqs = [
  {
    q: "What is Ghost?",
    a: "Ghost is a local-first macOS AI workspace you summon with a keystroke. It routes prompts to local and hosted models, searches your private knowledge base with RAG, starts timers, and runs verified Mac actions — all from one native SwiftUI surface that appears as a top-center notch or a floating bar and vanishes when you dismiss it.",
  },
  {
    q: "How do I open Ghost?",
    a: "Press Option+Space from anywhere on your Mac. In Settings you choose where Ghost appears: dropping down from the top-center notch — where gliding your pointer to the top of the screen also reveals it — or floating as a Siri-style bar about an inch up from the bottom, growing upward as it fills. A second shortcut (Option+Shift+Space by default) opens the very same surface, and the ghost://toggle deep link works from any app or script. It keeps your draft and collapses when you dismiss it.",
  },
  {
    q: "Which model providers does Ghost support?",
    a: "Eight providers: LM Studio and Ollama for local inference; Claude (Anthropic), Gemini (Google), DeepSeek v4, OpenCode Go, and OpenCode Zen for hosted models; plus any OpenAI-compatible endpoint — OpenAI, vLLM, or any server speaking the /v1 chat-completions schema. Just set a base URL and model name; the API key is optional for local or keyless servers. You switch providers from the model picker without changing apps.",
  },
  {
    q: "How does routing work?",
    a: "Ghost scores your prompt and picks the provider, model, and engine. Deterministic timers are handled locally first. The Direct API path calls the provider's HTTP API with Ghost's native tool harness for fast answers and verified actions. The Ghost Agent path shells out to a local CLI for deeper multi-step work.",
  },
  {
    q: "What is RAG memory?",
    a: "Ghost indexes the folders you approve into a local SQLite database with FTS5 full-text search. It supports 30 file formats — including PDF, DOCX, EPUB, Markdown, and source code. When a prompt needs context, Ghost retrieves cited, source-backed chunks you can open at the right spot.",
  },
  {
    q: "What is the capability harness?",
    a: "The capability harness is Ghost's action layer. The model never touches the filesystem directly — it asks, Ghost normalizes paths, checks permissions, runs app-owned code, and returns a machine-readable receipt. File-generation prompts can save to safe destinations such as Desktop, Downloads, Documents, Ghost Outputs, or the workspace.",
  },
  {
    q: "How does Ghost protect my privacy?",
    a: "Every capability starts off — you opt into each one in a six-step onboarding. API keys live in macOS Keychain and are only read when their provider is actually called. A web egress guard blocks private networks. Sensitive paths like .ssh, .gnupg, and login.keychain require explicit consent even with Full Disk Access.",
  },
  {
    q: "Is Ghost open source?",
    a: "Yes. Ghost is open source and available on GitHub. It requires macOS 14 or later and builds with Swift 6.1. The only dependency is Sparkle for auto-updates.",
  },
];

/* ---------------- RENDER FAQ ---------------- */
const faqList = document.getElementById("faq-list");
faqs.forEach((faq) => {
  const item = document.createElement("div");
  item.className = "faq-item reveal";
  item.innerHTML = `
    <button class="faq-question" data-cursor="pointer">
      <span>${faq.q}</span>
      <span class="faq-icon">+</span>
    </button>
    <div class="faq-answer"><div class="faq-answer-inner">${faq.a}</div></div>
  `;
  const question = item.querySelector(".faq-question");
  const answer = item.querySelector(".faq-answer");
  question.addEventListener("click", () => {
    const isOpen = item.classList.contains("is-open");
    document.querySelectorAll(".faq-item").forEach((f) => {
      f.classList.remove("is-open");
      f.querySelector(".faq-answer").style.maxHeight = "0";
    });
    if (!isOpen) {
      item.classList.add("is-open");
      answer.style.maxHeight = answer.scrollHeight + "px";
    }
  });
  faqList.appendChild(item);
});

/* ---------------- THEME TOGGLE ---------------- */
const themeToggle = document.getElementById("theme-toggle");
themeToggle.addEventListener("click", () => {
  const current = document.documentElement.dataset.theme;
  const next = current === "dark" ? "light" : "dark";
  document.documentElement.dataset.theme = next;
  gsap.fromTo(
    "body",
    { opacity: 0.8 },
    { opacity: 1, duration: 0.3, ease: "power2.out" },
  );
});

/* ---------------- NAV SCROLL ---------------- */
const nav = document.getElementById("nav");
window.addEventListener(
  "scroll",
  () => {
    nav.classList.toggle("is-scrolled", window.scrollY > 8);
  },
  { passive: true },
);

/* ---------------- SIDE NAV ---------------- */
const sideBtns = document.querySelectorAll(".side-nav-btn");
sideBtns.forEach((btn) => {
  btn.addEventListener("click", () => {
    const target = document.getElementById(btn.dataset.target);
    if (target) target.scrollIntoView({ behavior: "smooth" });
  });
});
const sections = Array.from(sideBtns).map((b) =>
  document.getElementById(b.dataset.target),
);
function syncSideNav() {
  const mid = window.innerHeight / 2;
  let activeIdx = 0;
  sections.forEach((s, i) => {
    if (!s) return;
    const r = s.getBoundingClientRect();
    if (r.top <= mid) activeIdx = i;
  });
  sideBtns.forEach((b, i) => b.classList.toggle("is-active", i === activeIdx));
}
window.addEventListener("scroll", syncSideNav, { passive: true });
syncSideNav();

/* ---------------- CUSTOM CURSOR ---------------- */
const cursor = document.getElementById("cursor");
const cursorDot = document.getElementById("cursor-dot");
let mouseX = 0,
  mouseY = 0,
  cursorX = 0,
  cursorY = 0;

window.addEventListener("mousemove", (e) => {
  mouseX = e.clientX;
  mouseY = e.clientY;
  cursorDot.style.left = mouseX + "px";
  cursorDot.style.top = mouseY + "px";
});

function animateCursor() {
  cursorX += (mouseX - cursorX) * 0.15;
  cursorY += (mouseY - cursorY) * 0.15;
  cursor.style.left = cursorX + "px";
  cursor.style.top = cursorY + "px";
  requestAnimationFrame(animateCursor);
}
animateCursor();

document.addEventListener("mouseover", (e) => {
  if (e.target.closest("[data-cursor='pointer']"))
    cursor.classList.add("is-hover");
});
document.addEventListener("mouseout", (e) => {
  if (e.target.closest("[data-cursor='pointer']"))
    cursor.classList.remove("is-hover");
});

/* ---------------- MAGNETIC BUTTONS ---------------- */
document.querySelectorAll(".magnetic").forEach((btn) => {
  btn.addEventListener("mousemove", (e) => {
    const rect = btn.getBoundingClientRect();
    const x = e.clientX - rect.left - rect.width / 2;
    const y = e.clientY - rect.top - rect.height / 2;
    gsap.to(btn, { x: x * 0.3, y: y * 0.3, duration: 0.4, ease: "power3.out" });
  });
  btn.addEventListener("mouseleave", () => {
    gsap.to(btn, { x: 0, y: 0, duration: 0.5, ease: "elastic.out(1, 0.4)" });
  });
});

/* ---------------- GSAP REVEALS ---------------- */
function initReveals() {
  gsap.utils.toArray(".reveal").forEach((el) => {
    if (el.dataset.revealed) return;
    el.dataset.revealed = "1";
    if (el.closest("#hero") && !el.classList.contains("scroll-cue")) return;
    gsap.to(el, {
      scrollTrigger: {
        trigger: el,
        start: "top 88%",
        toggleActions: "play none none none",
      },
      opacity: 1,
      y: 0,
      duration: 0.8,
      ease: "power3.out",
    });
  });
}

/* ---------------- HERO ENTRANCE ---------------- */
gsap.fromTo(
  ".hero-badge",
  { opacity: 0, y: 20 },
  { opacity: 1, y: 0, duration: 0.6, ease: "power3.out", delay: 0.1 },
);
gsap.fromTo(
  ".hero-title",
  { opacity: 0, y: 30 },
  { opacity: 1, y: 0, duration: 0.8, ease: "power3.out", delay: 0.2 },
);
gsap.fromTo(
  ".hero-lede",
  { opacity: 0, y: 20 },
  { opacity: 1, y: 0, duration: 0.7, ease: "power3.out", delay: 0.4 },
);
gsap.fromTo(
  ".hero-actions",
  { opacity: 0, y: 20 },
  { opacity: 1, y: 0, duration: 0.6, ease: "power3.out", delay: 0.6 },
);
gsap.from(".hero-ghost-watermark", {
  opacity: 0,
  scale: 0.9,
  duration: 1.2,
  ease: "power3.out",
  delay: 0.3,
});

/* ---------------- THREE.JS HERO — FLOATING GHOSTS ---------------- */
/* A drifting 3D field of little Ghost logos. We use THREE.Sprite (screen-
   facing quads) rather than GL points so the ghosts render crisp at any
   size — points hit the hardware size cap and cull at the viewport edge. */
let scene, camera, renderer, ghostGroup;
const ghostSprites = [];
let heroCanvas = document.getElementById("hero-canvas");
const prefersReducedMotion = window.matchMedia(
  "(prefers-reduced-motion: reduce)",
).matches;

/* Draw the brand ghost silhouette (0..64 viewBox path) into a canvas so we
   can hand it to Three.js as a texture. White fill, eyes punched out — the
   sprite's color multiplies the white, tinting each ghost to the palette. */
function makeGhostTexture() {
  const S = 128;
  const cvs = document.createElement("canvas");
  cvs.width = S;
  cvs.height = S;
  const ctx = cvs.getContext("2d");
  ctx.scale(S / 64, S / 64);
  const body = new Path2D(
    "M16 49V28c0-11 7-18 16-18s16 7 16 18v21l-5-4-5 4-6-4-6 4-5-4-5 4Z",
  );
  ctx.fillStyle = "#ffffff";
  ctx.fill(body);
  ctx.globalCompositeOperation = "destination-out";
  ctx.beginPath();
  ctx.arc(26, 29, 3, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(38, 29, 3, 0, Math.PI * 2);
  ctx.fill();
  const tex = new THREE.CanvasTexture(cvs);
  tex.magFilter = THREE.LinearFilter;
  tex.minFilter = THREE.LinearMipmapLinearFilter;
  tex.needsUpdate = true;
  return tex;
}

function initThree() {
  if (!heroCanvas || typeof THREE === "undefined") return;
  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(
    75,
    window.innerWidth / window.innerHeight,
    0.1,
    1000,
  );
  camera.position.z = 50;
  renderer = new THREE.WebGLRenderer({
    canvas: heroCanvas,
    alpha: true,
    antialias: true,
  });
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

  const ghostTex = makeGhostTexture();
  // Brand palette — one shared material per hue keeps this cheap.
  const palette = [0x00ff9d, 0xa855f7, 0xd97757, 0x4b8bf5];
  const materials = palette.map(
    (color) =>
      new THREE.SpriteMaterial({
        map: ghostTex,
        color,
        transparent: true,
        opacity: 0.92,
        depthWrite: false,
        blending: THREE.NormalBlending, // reads on both dark + light themes
      }),
  );

  ghostGroup = new THREE.Group();
  const count = 64;
  for (let i = 0; i < count; i++) {
    const sprite = new THREE.Sprite(materials[i % materials.length]);
    const baseX = (Math.random() - 0.5) * 120;
    const baseY = (Math.random() - 0.5) * 80;
    const baseZ = (Math.random() - 0.5) * 60;
    sprite.position.set(baseX, baseY, baseZ);
    const size = 2.4 + Math.random() * 2.8; // world units
    sprite.scale.set(size, size, 1);
    sprite.userData = {
      baseY,
      phase: Math.random() * Math.PI * 2,
      speed: 0.35 + Math.random() * 0.55,
      bob: 1.4 + Math.random() * 2.2,
    };
    ghostGroup.add(sprite);
    ghostSprites.push(sprite);
  }
  scene.add(ghostGroup);

  if (prefersReducedMotion) {
    renderer.render(scene, camera); // one static frame, no rAF loop
  } else {
    animateThree();
  }
}

let scrollY = 0;
window.addEventListener(
  "scroll",
  () => {
    scrollY = window.scrollY;
  },
  { passive: true },
);

function animateThree() {
  requestAnimationFrame(animateThree);
  if (!renderer || !ghostGroup) return;
  const t = Date.now() * 0.001;
  ghostGroup.rotation.y += 0.0008;
  ghostGroup.rotation.x += 0.0003;
  ghostGroup.position.y = scrollY * 0.005;
  for (const sprite of ghostSprites) {
    const u = sprite.userData;
    sprite.position.y = u.baseY + Math.sin(t * u.speed + u.phase) * u.bob;
  }
  renderer.render(scene, camera);
}

window.addEventListener("resize", () => {
  if (!renderer) return;
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  // With reduced motion there is no rAF loop, so repaint the resized frame.
  if (prefersReducedMotion) renderer.render(scene, camera);
});

/* ---------------- INIT ---------------- */
initReveals();
initThree();
document.getElementById("year").textContent = new Date().getFullYear();
