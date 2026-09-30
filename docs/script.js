/* ============================================
   GHOST · Website interactions
   GSAP reveals · FAQ · theme · copy-to-clipboard
   ============================================ */

/* GSAP comes off a CDN, and a blocked or slow cdnjs used to take the whole
   file down with it: the FAQ is rendered by this script, so one failed
   request left an empty section on the page. Everything animated is now
   behind this flag, and everything structural runs either way. */
const hasGSAP = typeof gsap !== "undefined" && typeof ScrollTrigger !== "undefined";
if (hasGSAP) gsap.registerPlugin(ScrollTrigger);

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
const animate = hasGSAP && !reduceMotion;

/* ---------------- FAQ DATA ---------------- */
const faqs = [
  {
    q: "What do I need to run Ghost?",
    a: "A Mac with Apple silicon (M1 or later) running macOS 14 Sonoma or newer. There is no Intel version. You also need a model: a Claude Code, Codex or Antigravity plan, an API key from a provider, or LM Studio or Ollama running on your Mac.",
  },
  {
    q: "Which models does it work with?",
    a: "With an API key: Claude, Gemini, DeepSeek, OpenCode Go, OpenCode Zen and any OpenAI-compatible server. On your own Mac: anything you run in LM Studio or Ollama. Ghost can also run on the Claude Code, Codex and Antigravity command line tools, which use the plan you already pay for.",
  },
  {
    q: "Does my data leave my Mac?",
    a: "Only on the route you pick. With a local model, no cloud AI sees your prompts. Messages, Notes, Mail and Contacts are only ever read by a local model, whichever route you use, and every capability starts switched off.",
  },
  {
    q: "Can I undo what Ghost does?",
    a: "Yes, for anything that can be reversed. Files, documents, notes, reminders and calendar events come with an Undo button, and by default Ghost asks before it changes anything. A sent message cannot be unsent, so Ghost asks before sending one.",
  },
  {
    q: "Is Ghost open source?",
    a: "No. Ghost is a one-time purchase and its source code is private. The GitHub repository has the documentation, the release notes and the security policy.",
  },
];

/* ---------------- RENDER FAQ ---------------- */
const faqList = document.getElementById("faq-list");
faqs.forEach((faq) => {
  const item = document.createElement("div");
  item.className = "faq-item reveal";
  item.innerHTML = `
    <button class="faq-question" data-cursor="pointer" aria-expanded="false">
      <span>${faq.q}</span>
      <span class="faq-icon" aria-hidden="true">+</span>
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
      f.querySelector(".faq-question").setAttribute("aria-expanded", "false");
    });
    if (!isOpen) {
      item.classList.add("is-open");
      answer.style.maxHeight = answer.scrollHeight + "px";
      question.setAttribute("aria-expanded", "true");
    }
  });
  faqList.appendChild(item);
});

/* max-height is a pixel measurement taken at one width, so an answer left
   open through a rotate or a window resize reflows taller than the number we
   stored and the last lines get clipped. Same bug the release rail already
   guards against. */
window.addEventListener("resize", () => {
  const open = faqList.querySelector(".faq-item.is-open .faq-answer");
  if (open) open.style.maxHeight = open.scrollHeight + "px";
});

/* ---------------- THEME TOGGLE ---------------- */
/* The initial theme is resolved by the inline boot script in <head>, before
   first paint. This only has to handle the click, and remember it: the
   toggle used to be forgotten on reload, so choosing light was a decision
   you had to make again on every page load. */
const themeToggle = document.getElementById("theme-toggle");
const syncThemeToggle = () => {
  const isLight = document.documentElement.dataset.theme === "light";
  themeToggle.setAttribute("aria-pressed", String(isLight));
  themeToggle.setAttribute(
    "aria-label",
    isLight ? "Switch to dark theme" : "Switch to light theme",
  );
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute("content", isLight ? "#faf8f5" : "#000000");
};
syncThemeToggle();
themeToggle.addEventListener("click", () => {
  const next =
    document.documentElement.dataset.theme === "light" ? "dark" : "light";
  document.documentElement.dataset.theme = next;
  try {
    localStorage.setItem("ghost-theme", next);
  } catch (e) {}
  syncThemeToggle();
  if (animate) {
    gsap.fromTo(
      "body",
      { opacity: 0.8 },
      { opacity: 1, duration: 0.3, ease: "power2.out" },
    );
  }
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

/* ---------------- RELEASE RAIL ---------------- */
/* Older releases are one line each until you open them. The rail draws
   itself as you scroll and each version lights its dot on arrival. */
function initReleaseRail() {
  const rail = document.getElementById("release-rail");
  if (!rail) return;

  const rows = Array.from(rail.querySelectorAll(".release-row"));

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
      if (hasGSAP) ScrollTrigger.refresh();
    });
  });

  // max-height is a pixel measurement taken at one width. Rotate the phone
  // with a release open and the text reflows taller than the number we
  // stored, so the last lines get clipped by the row below.
  window.addEventListener("resize", () => {
    const openBody = rail.querySelector(".release-row.is-open .release-body");
    if (openBody) openBody.style.maxHeight = openBody.scrollHeight + "px";
  });

  if (!animate) {
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
/* These are fromTo, so they set opacity: 0 inline before they run. That
   beats the CSS reduced-motion rescue, which is a stylesheet and cannot
   undo an inline style, so the hero used to fade and slide for someone who
   had asked for no motion at all. Guarded now, like everything else. */
function initHero() {
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
}

/* .reveal rests at opacity 0 and is raised by a tween. With no GSAP there is
   nothing to raise it, and the page would render as a blank column. */
function showEverything() {
  document.querySelectorAll(".reveal").forEach((el) => {
    el.style.opacity = "1";
    el.style.transform = "none";
  });
}

/* ---------------- INIT ---------------- */
if (animate) {
  initStaggeredReveals();
  initReveals();
  initHero();
} else {
  showEverything();
}
initReleaseRail();
initScrollProgress();
document.getElementById("year").textContent = new Date().getFullYear();
