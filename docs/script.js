/* ============================================
   GHOST · Website interactions
   GSAP reveals · FAQ · theme · copy-to-clipboard
   ============================================ */

gsap.registerPlugin(ScrollTrigger);

/* ---------------- FAQ DATA ---------------- */
const faqs = [
  {
    q: "What is Ghost?",
    a: "Ghost is a local-first macOS AI workspace you summon with a keystroke. It routes prompts to local and hosted models, searches your private knowledge base with RAG, starts timers, and runs verified Mac actions, all from one native SwiftUI surface that appears as a top-center notch or a floating bar and vanishes when you dismiss it.",
  },
  {
    q: "How do I open Ghost?",
    a: "Press Option+Space from anywhere on your Mac. In Settings you choose where Ghost appears: dropping down from the top-center notch, where gliding your pointer to the top of the screen also reveals it, or floating as a Siri-style bar about an inch up from the bottom, growing upward as it fills. A second shortcut (Option+Shift+Space by default) opens the very same surface, and the ghost://toggle deep link works from any app or script. It keeps your draft and collapses when you dismiss it.",
  },
  {
    q: "Which model providers does Ghost support?",
    a: "Eight providers: LM Studio and Ollama for local inference; Claude (Anthropic), Gemini (Google), DeepSeek v4, OpenCode Go, and OpenCode Zen for hosted models; plus any OpenAI-compatible endpoint: OpenAI, vLLM, or any server speaking the /v1 chat-completions schema. Just set a base URL and model name; the API key is optional for local or keyless servers. You switch providers from the model picker without changing apps.",
  },
  {
    q: "How does routing work?",
    a: "Ghost scores your prompt and picks the provider, model, and engine. Deterministic timers are handled locally first. The Direct API path calls the provider's HTTP API with Ghost's native tool harness for fast answers and verified actions. The Ghost Agent path shells out to a local CLI for deeper multi-step work.",
  },
  {
    q: "What is RAG memory?",
    a: "Ghost indexes the folders you approve into a local SQLite database with FTS5 full-text search. It supports 30 file formats, including PDF, DOCX, EPUB, Markdown, and source code. When a prompt needs context, Ghost retrieves cited, source-backed chunks you can open at the right spot.",
  },
  {
    q: "What is the capability harness?",
    a: "The capability harness is Ghost's action layer. The model never touches the filesystem directly. It asks, Ghost normalizes paths, checks permissions, runs app-owned code, and returns a machine-readable receipt. File-generation prompts can save to safe destinations such as Desktop, Downloads, Documents, Ghost Outputs, or the workspace.",
  },
  {
    q: "How does Ghost protect my privacy?",
    a: "Every capability starts off. You opt into each one in a three-step first run. API keys live in macOS Keychain and are only read when their provider is actually called. A web egress guard blocks private networks. Sensitive paths like .ssh, .gnupg, and login.keychain require explicit consent even with Full Disk Access.",
  },
  {
    q: "Is Ghost open source?",
    a: "No. Ghost is a one-time purchase and its source is not public. The GitHub repository holds the documentation, the changelog, and the security policy. What you can check for yourself: Ghost is notarized by Apple, every capability ships switched off, and Messages, Notes, Mail, and Contacts are processed on device and refused to cloud models.",
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

/* ---------------- MOTION PREFERENCE ---------------- */
/* Everything scroll-linked below is opt-in on this flag. The CSS block at
   the bottom of styles.css already rescues .reveal and kills transitions,
   but GSAP never consults a stylesheet, and a scrubbed tween would happily
   hold an element at scaleY(0) for someone who asked for no motion. So the
   resting state in CSS is always the finished one, and JS only ever
   animates *towards* it. */
const reduceMotion = window.matchMedia(
  "(prefers-reduced-motion: reduce)",
).matches;

/* ---------------- RELEASE RAIL ---------------- */
/* Older releases are one line each until you open them. The rail draws
   itself as you scroll and each version lights its dot on arrival. */
function initReleaseRail() {
  const rail = document.getElementById("release-rail");
  if (!rail) return;

  const rows = gsap.utils.toArray(rail.querySelectorAll(".release-row"));

  rows.forEach((row) => {
    const head = row.querySelector(".release-head");
    const body = row.querySelector(".release-body");
    if (!head || !body) return;

    head.addEventListener("click", () => {
      const isOpen = row.classList.contains("is-open");
      rows.forEach((r) => {
        r.classList.remove("is-open");
        r.querySelector(".release-body").style.maxHeight = "0";
        r.querySelector(".release-head").setAttribute("aria-expanded", "false");
      });
      if (!isOpen) {
        row.classList.add("is-open");
        body.style.maxHeight = body.scrollHeight + "px";
        head.setAttribute("aria-expanded", "true");
      }
      // The rail just changed height, so the scrubbed line has to remeasure
      // or it ends up drawn against the old geometry.
      ScrollTrigger.refresh();
    });
  });

  // max-height is a pixel measurement taken at one width. Rotate the phone
  // with a release open and the text reflows taller than the number we
  // stored, so the last lines get clipped by the row below.
  window.addEventListener("resize", () => {
    const openBody = rail.querySelector(".release-row.is-open .release-body");
    if (openBody) openBody.style.maxHeight = openBody.scrollHeight + "px";
  });

  if (reduceMotion) {
    rows.forEach((row) => row.classList.add("is-lit"));
    return;
  }

  const progress = document.querySelector(".release-progress");
  if (progress) {
    gsap.fromTo(
      progress,
      { scaleY: 0 },
      {
        scaleY: 1,
        ease: "none",
        scrollTrigger: {
          trigger: rail,
          start: "top 72%",
          end: "bottom 65%",
          scrub: 0.6,
        },
      },
    );
  }

  rows.forEach((row) => {
    ScrollTrigger.create({
      trigger: row,
      start: "top 80%",
      onEnter: () => row.classList.add("is-lit"),
    });
  });
}

/* ---------------- SCROLL PROGRESS ---------------- */
function initScrollProgress() {
  const bar = document.createElement("div");
  bar.className = "scroll-progress";
  document.body.appendChild(bar);

  const update = () => {
    const max = document.documentElement.scrollHeight - window.innerHeight;
    const ratio = max > 0 ? Math.min(window.scrollY / max, 1) : 0;
    bar.style.transform = `scaleX(${ratio})`;
  };

  window.addEventListener("scroll", update, { passive: true });
  window.addEventListener("resize", update);
  update();
}

/* ---------------- GSAP REVEALS ---------------- */
/* Groups marked data-reveal-stagger come in as a set rather than each
   element tripping its own trigger. Runs before initReveals, and flags what
   it claims, because initReveals skips anything already marked. */
function initStaggeredReveals() {
  gsap.utils.toArray("[data-reveal-stagger]").forEach((group) => {
    const items = gsap.utils.toArray(group.querySelectorAll(".reveal"));
    if (!items.length) return;
    items.forEach((el) => (el.dataset.revealed = "1"));
    gsap.to(items, {
      scrollTrigger: {
        trigger: group,
        start: "top 85%",
        toggleActions: "play none none none",
      },
      opacity: 1,
      y: 0,
      duration: 0.7,
      ease: "power3.out",
      stagger: 0.07,
    });
  });
}

function initReveals() {
  gsap.utils.toArray(".reveal").forEach((el) => {
    if (el.dataset.revealed) return;
    el.dataset.revealed = "1";
    if (el.closest("#hero")) return; // the hero is raised by its own timeline
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
  "#hero .hero-actions",
  { opacity: 0, y: 20 },
  { opacity: 1, y: 0, duration: 0.6, ease: "power3.out", delay: 0.6 },
);
/* The product shot carries .reveal, and initReveals deliberately skips
   anything inside #hero, so it has to be raised here or it never shows. */
gsap.fromTo(
  ".device",
  { opacity: 0, y: 40 },
  { opacity: 1, y: 0, duration: 1, ease: "power3.out", delay: 0.75 },
);

/* ---------------- INIT ---------------- */
initStaggeredReveals();
initReveals();
initReleaseRail();
initScrollProgress();
document.getElementById("year").textContent = new Date().getFullYear();
