/* ============================================
   GHOST — Flowing website interactions
   GSAP · Three.js · Custom cursor · Side nav
   ============================================ */

gsap.registerPlugin(ScrollTrigger);

/* ---------------- FAQ DATA ---------------- */
const faqs = [
  {
    q: "What is Ghost?",
    a: "Ghost is a notch-first local macOS AI workspace that lives in your menu bar. It routes prompts to local and hosted models, searches your private knowledge base with RAG, starts timers, and runs verified Mac actions — all from one native SwiftUI surface you summon with a keystroke.",
  },
  {
    q: "How do I open Ghost?",
    a: "Click the ghost icon in your menu bar, press Option+Space from anywhere on your Mac, or open the quick Ghost Bar with Option+Shift+Space. The top-center notch opens instantly, keeps your draft, and collapses when you dismiss it. You can also use the ghost://toggle deep link.",
  },
  {
    q: "Which model providers does Ghost support?",
    a: "Seven providers: LM Studio and Ollama for local inference, plus Claude (Anthropic), Gemini (Google), DeepSeek, OpenCode Go, and OpenCode Zen for hosted models. You can switch providers from the model picker without changing apps.",
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

/* ---------------- THREE.JS HERO PARTICLES ---------------- */
let scene, camera, renderer, particles, particleGeo;
let heroCanvas = document.getElementById("hero-canvas");

function initThree() {
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

  function makeGhostTexture() {
    const c = document.createElement("canvas");
    c.width = 64;
    c.height = 64;
    const ctx = c.getContext("2d");
    const grad = ctx.createLinearGradient(0, 0, 64, 64);
    grad.addColorStop(0, "#00ff9d");
    grad.addColorStop(0.5, "#d97757");
    grad.addColorStop(1, "#a855f7");
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.moveTo(16, 49);
    ctx.lineTo(16, 28);
    ctx.quadraticCurveTo(16, 10, 32, 10);
    ctx.quadraticCurveTo(48, 10, 48, 28);
    ctx.lineTo(48, 49);
    ctx.lineTo(43, 45);
    ctx.lineTo(38, 49);
    ctx.lineTo(32, 45);
    ctx.lineTo(26, 49);
    ctx.lineTo(21, 45);
    ctx.lineTo(16, 49);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#050505";
    ctx.beginPath();
    ctx.arc(26, 29, 3, 0, Math.PI * 2);
    ctx.arc(38, 29, 3, 0, Math.PI * 2);
    ctx.fill();
    const tex = new THREE.CanvasTexture(c);
    tex.needsUpdate = true;
    return tex;
  }

  const ghostTex = makeGhostTexture();
  const count = 250;
  const positions = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    positions[i * 3] = (Math.random() - 0.5) * 120;
    positions[i * 3 + 1] = (Math.random() - 0.5) * 80;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 60;
  }
  particleGeo = new THREE.BufferGeometry();
  particleGeo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
  const material = new THREE.PointsMaterial({
    size: 3.5,
    map: ghostTex,
    transparent: true,
    opacity: 0.6,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
  });
  particles = new THREE.Points(particleGeo, material);
  scene.add(particles);
  animateThree();
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
  if (!particles) return;
  particles.rotation.y += 0.0008;
  particles.rotation.x += 0.0003;
  particles.position.y = scrollY * 0.005;
  const positions = particleGeo.attributes.position.array;
  for (let i = 0; i < positions.length; i += 3) {
    positions[i + 1] += Math.sin(Date.now() * 0.0005 + i) * 0.008;
  }
  particleGeo.attributes.position.needsUpdate = true;
  renderer.render(scene, camera);
}

window.addEventListener("resize", () => {
  if (!renderer) return;
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});

/* ---------------- INIT ---------------- */
initReveals();
initThree();
document.getElementById("year").textContent = new Date().getFullYear();
