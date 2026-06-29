/* ============================================
   GHOST — Award-winning website interactions
   GSAP · Three.js · Custom cursor · 3D tilt
   ============================================ */

gsap.registerPlugin(ScrollTrigger);

/* ---------------- CAPABILITY DATA ---------------- */
const cards = [
  {
    kicker: "Agent Router",
    title: "Route each request to the right engine.",
    module: "Routing",
    copy: "Ghost decides when a prompt needs a fast direct model call or a deeper connected agent run.",
    chips: ["Auto route", "Direct or agent", "Approvals"],
    help: "You can ask naturally without deciding the whole execution path up front.",
    works:
      "The router scores the prompt, selected provider, model, and task type before choosing an engine.",
    status: "Built into Ghost",
    size: "large",
  },
  {
    kicker: "Direct API Mode",
    title: "Fast answers from the selected model.",
    module: "Routing",
    copy: "Use provider APIs for quick writing, answers, summaries, and lightweight tool-supported work.",
    chips: ["Fast path", "Provider APIs", "Low friction"],
    help: "Short tasks stay quick and do not need a full agent loop.",
    works:
      "Ghost calls the selected provider directly and can attach safe app-owned tools when needed.",
    status: "Direct engine",
  },
  {
    kicker: "Local Models",
    title: "Run local inference from your Mac.",
    module: "Local",
    copy: "LM Studio and Ollama keep model traffic close to your machine for private everyday work.",
    chips: ["LM Studio", "Ollama", "Local-first"],
    help: "Keep sensitive prompts away from hosted providers when local models are enough.",
    works:
      "Ghost discovers local models from the configured localhost runtimes and routes prompts directly.",
    status: "Local providers",
    size: "wide",
  },
  {
    kicker: "LM Studio",
    title: "Connect to LM Studio on localhost.",
    module: "Local",
    copy: "Ghost reads available LM Studio models and uses the local OpenAI-compatible server.",
    chips: ["localhost:1234", "Model list", "Private"],
    help: "Your local model experiments become usable from a polished macOS workspace.",
    works:
      "Ghost queries LM Studio's local /v1/models endpoint and sends chat through the local API.",
    status: "Supported",
  },
  {
    kicker: "Ollama",
    title: "Use Ollama models in Ghost.",
    module: "Local",
    copy: "Ghost can discover Ollama tags and route local prompts to the Ollama server.",
    chips: ["localhost:11434", "Tags", "Local"],
    help: "Switch between downloaded local models without leaving Ghost.",
    works:
      "Ghost checks Ollama's model list and sends compatible local requests through its endpoint.",
    status: "Supported",
  },
  {
    kicker: "Claude",
    title: "Bring Claude into the same command center.",
    module: "Cloud",
    copy: "Use Anthropic models when you want a hosted reasoning model from the Ghost interface.",
    chips: ["API key", "Hosted", "Selectable"],
    help: "Cloud models sit beside local models instead of living in separate tools.",
    works:
      "Ghost loads the provider key from its secrets layer and sends requests through the Claude path.",
    status: "API key required",
  },
  {
    kicker: "Gemini",
    title: "Use Gemini where it fits the task.",
    module: "Cloud",
    copy: "Ghost supports Gemini provider configuration from the same model picker.",
    chips: ["Google key", "Hosted", "Model picker"],
    help: "Choose the model family that fits the work without changing apps.",
    works:
      "Ghost uses the configured Gemini or Google API key for provider-specific requests.",
    status: "API key required",
  },
  {
    kicker: "DeepSeek",
    title: "Route DeepSeek from the provider layer.",
    module: "Cloud",
    copy: "Ghost includes DeepSeek options for hosted model runs when that provider is selected.",
    chips: ["DeepSeek key", "Hosted", "Direct"],
    help: "Test DeepSeek beside your local and other hosted models.",
    works:
      "Ghost maps the selected DeepSeek model through the Direct API client and scoped key handling.",
    status: "API key required",
  },
  {
    kicker: "RAG Memory",
    title: "Ask questions across local documents.",
    module: "Retrieval",
    copy: "Ghost indexes approved files and retrieves cited chunks so answers stay grounded.",
    chips: ["Local index", "Cited sources", "Reindexable"],
    help: "Your PDFs, markdown, logs, code, and notes become searchable working memory.",
    works:
      "Ghost stores document chunks in a local SQLite index and returns source-backed matches.",
    status: "Local database",
    size: "wide",
  },
  {
    kicker: "Document Indexing",
    title: "Sync folders into Ghost memory.",
    module: "Retrieval",
    copy: "Add files or folders and Ghost keeps an index of supported document and source formats.",
    chips: ["Folder sync", "File types", "Status"],
    help: "Project folders can become context without copy-pasting documents into chat.",
    works:
      "Ghost fingerprints files, skips unchanged content, and stores searchable chunks locally.",
    status: "Supported",
  },
  {
    kicker: "Source-backed Answers",
    title: "Open the source behind an answer.",
    module: "Retrieval",
    copy: "Grounded answers can include inspectable source references rather than vague confidence.",
    chips: ["Citations", "Open source", "Traceable"],
    help: "Check where an answer came from before trusting or using it.",
    works:
      "RAG search returns chunk metadata and source paths that Ghost can open or reveal.",
    status: "Source-aware",
  },
  {
    kicker: "Capability Harness",
    title: "Let models request actions safely.",
    module: "Actions",
    copy: "Ghost-owned tools validate paths, run actions, and report what actually happened.",
    chips: ["Validated", "Verified", "Guarded"],
    help: "The app confirms real results instead of relying on model claims.",
    works:
      "The harness normalizes inputs, gates risky actions, executes app code, and returns receipts.",
    status: "Implemented",
  },
  {
    kicker: "Verified File Actions",
    title: "Create and manage files with receipts.",
    module: "Actions",
    copy: "Ghost can create, read, move, copy, convert, open, and reveal approved files.",
    chips: ["Create", "Convert", "Reveal"],
    help: "Ask for real artifacts and see where they landed.",
    works:
      "File actions run through allowed roots and return actual paths, errors, and summaries.",
    status: "Harness tool",
  },
  {
    kicker: "Calendar Actions",
    title: "Create and query calendar events.",
    module: "Native",
    copy: "Ghost can route scheduling requests into native calendar workflows when permitted.",
    chips: ["Events", "Queries", "macOS"],
    help: "Scheduling can happen from the same assistant surface as your work.",
    works:
      "Calendar requests are parsed, permissioned, and dispatched through Ghost's native integrations.",
    status: "Permissioned",
  },
  {
    kicker: "Reminders",
    title: "Capture follow-ups before they drift.",
    module: "Native",
    copy: "Turn natural language requests into reminders from the Ghost command surface.",
    chips: ["Follow-up", "Due dates", "Native"],
    help: "Convert intent into a reminder without context switching.",
    works:
      "Ghost routes reminder prompts to its automation layer and uses macOS permissions.",
    status: "Permissioned",
  },
  {
    kicker: "Voice Input",
    title: "Speak prompts into the workspace.",
    module: "Native",
    copy: "Ghost includes microphone and speech-recognition permission hooks for voice-driven prompts.",
    chips: ["Mic", "Speech", "Hands-free"],
    help: "Quick thoughts can become prompts before they lose shape.",
    works:
      "The app requests the required macOS permissions and uses the native input path.",
    status: "Permissioned",
  },
  {
    kicker: "Ghost Code",
    title: "Use a wider coding workspace.",
    module: "Developer",
    copy: "Ghost Code gives deeper tasks a terminal-style surface for output, traces, and files.",
    chips: ["Code view", "Traces", "Workspace"],
    help: "Developer work has room to breathe when a compact panel is not enough.",
    works:
      "Ghost switches interface modes and sizes so agent work can show richer context.",
    status: "Interface mode",
  },
  {
    kicker: "Shell Checks",
    title: "Run bounded checks when useful.",
    module: "Developer",
    copy: "Ghost supports restricted command checks with output caps and safer boundaries.",
    chips: ["Read-only", "Output caps", "Review"],
    help: "Verify local state without turning every prompt into broad shell access.",
    works:
      "Read-only checks route through bounded command services and higher-risk commands require approval.",
    status: "Guarded",
  },
  {
    kicker: "Menu Bar Workspace",
    title: "Stay close to the task.",
    module: "Native",
    copy: "Ghost lives in the menu bar and can return with a global keyboard shortcut.",
    chips: ["Menu bar", "Option-Space", "Native"],
    help: "The assistant stays available without taking over the desktop.",
    works:
      "Ghost runs as an accessory macOS app with a menu-bar extra and floating panel.",
    status: "Native app",
  },
  {
    kicker: "Local-first Privacy",
    title: "Choose what stays on your Mac.",
    module: "Local",
    copy: "Use local models and local retrieval when the work should remain close to your machine.",
    chips: ["Local models", "Local RAG", "Control"],
    help: "Make privacy a routing choice instead of an afterthought.",
    works:
      "Ghost separates local providers, local indexes, and hosted provider key paths.",
    status: "Design principle",
  },
  {
    kicker: "Finder/File Tools",
    title: "Open, reveal, and inspect local sources.",
    module: "Actions",
    copy: "Ghost can open cited files, reveal generated artifacts, and inspect workspace paths.",
    chips: ["Finder", "Open", "Reveal"],
    help: "Answers and artifacts stay connected to real files on disk.",
    works:
      "Finder actions run through the capability layer and return the resolved file path.",
    status: "Harness tool",
  },
  {
    kicker: "Agent Configuration",
    title: "Connect the local agent you trust.",
    module: "Developer",
    copy: "Ghost can launch Ghost Agent or Hermes Agent from expected local binary paths.",
    chips: ["ghost", "hermes", "Toolsets"],
    help: "Longer work can move into an agent while Ghost remains the control surface.",
    works:
      "Ghost starts the selected CLI with model, provider, approval mode, and turn-limit options.",
    status: "Local binary",
  },
];

const faqs = [
  {
    q: "What is Ghost?",
    a: "Ghost is a premium local-first macOS AI workspace that lives in your menu bar. It routes prompts to local and hosted models, searches your private knowledge base with RAG, and runs verified Mac actions — all from one native interface.",
  },
  {
    q: "Which model providers does Ghost support?",
    a: "Ghost supports LM Studio and Ollama for local inference, plus Claude (Anthropic), Gemini (Google), and DeepSeek for hosted models. You can switch providers from the model picker without changing apps.",
  },
  {
    q: "How does Ghost protect my privacy?",
    a: "Ghost separates local providers, local indexes, and hosted key paths. Your RAG index lives in a local SQLite database, and provider secrets stay scoped to the routes you choose. You can keep sensitive work entirely on your Mac with local models.",
  },
  {
    q: "What is the capability harness?",
    a: "The capability harness is Ghost's action layer. It validates paths, gates risky actions, executes app-owned tools, and returns real results — not model claims. This means file actions, conversions, and Mac integrations are verified and safe.",
  },
  {
    q: "How do I open Ghost?",
    a: "Ghost runs as a menu-bar app. Click the ghost icon in your menu bar, or press Option-Space from anywhere on your Mac. The panel opens instantly and closes when you click away.",
  },
  {
    q: "Is Ghost open source?",
    a: "Yes. Ghost is open source and available on GitHub. You can build it from source using Swift Package Manager with the Xcode toolchain.",
  },
];

/* ---------------- RENDER BENTO ---------------- */
const bento = document.getElementById("bento");

function renderCards(filter = "all") {
  bento.innerHTML = "";
  cards.forEach((card, i) => {
    const matches = filter === "all" || card.module === filter;
    if (!matches) return;
    const el = document.createElement("article");
    el.className =
      "bento-card reveal" +
      (card.size === "large"
        ? " is-large"
        : card.size === "wide"
          ? " is-wide"
          : "");
    el.dataset.module = card.module;
    el.innerHTML = `
      <span class="card-module">${card.module}</span>
      <span class="card-kicker">${card.kicker}</span>
      <h3 class="card-title">${card.title}</h3>
      <p class="card-copy">${card.copy}</p>
      <div class="card-chips">${card.chips.map((c) => `<span class="chip">${c}</span>`).join("")}</div>
    `;
    el.addEventListener("click", () => openModal(card));
    el.addEventListener("mousemove", (e) => {
      const rect = el.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      el.style.setProperty("--mx", `${x}px`);
      el.style.setProperty("--my", `${y}px`);
      const rotX = (y / rect.height - 0.5) * -6;
      const rotY = (x / rect.width - 0.5) * 6;
      gsap.to(el, {
        rotationX: rotX,
        rotationY: rotY,
        duration: 0.4,
        ease: "power2.out",
        transformPerspective: 800,
      });
    });
    el.addEventListener("mouseleave", () => {
      gsap.to(el, {
        rotationX: 0,
        rotationY: 0,
        duration: 0.5,
        ease: "power3.out",
      });
    });
    bento.appendChild(el);
  });
  initReveals();
}

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

/* ---------------- MODAL ---------------- */
const modal = document.getElementById("modal");
function openModal(card) {
  document.getElementById("modal-kicker").textContent = card.kicker;
  document.getElementById("modal-title").textContent = card.title;
  document.getElementById("modal-copy").textContent = card.copy;
  document.getElementById("modal-module").textContent = card.module;
  document.getElementById("modal-help").textContent = card.help;
  document.getElementById("modal-works").textContent = card.works;
  document.getElementById("modal-status").textContent = card.status;
  document.getElementById("modal-chips").innerHTML = card.chips
    .map((c) => `<li class="chip">${c}</li>`)
    .join("");
  modal.classList.add("is-open");
  modal.setAttribute("aria-hidden", "false");
  document.body.style.overflow = "hidden";
}
function closeModal() {
  modal.classList.remove("is-open");
  modal.setAttribute("aria-hidden", "true");
  document.body.style.overflow = "";
}
modal
  .querySelectorAll("[data-close]")
  .forEach((el) => el.addEventListener("click", closeModal));
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") closeModal();
});

/* ---------------- FILTERS ---------------- */
document.querySelectorAll(".filter").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".filter").forEach((b) => {
      b.classList.remove("is-active");
      b.setAttribute("aria-selected", "false");
    });
    btn.classList.add("is-active");
    btn.setAttribute("aria-selected", "true");
    renderCards(btn.dataset.filter);
  });
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
  if (e.target.closest("[data-cursor='pointer']")) {
    cursor.classList.add("is-hover");
  }
});
document.addEventListener("mouseout", (e) => {
  if (e.target.closest("[data-cursor='pointer']")) {
    cursor.classList.remove("is-hover");
  }
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
      delay: el.dataset.step ? 0.1 : 0,
    });
  });
}

/* ---------------- HERO ENTRANCE ---------------- */
gsap.from(".hero-badge", {
  opacity: 0,
  y: 20,
  duration: 0.6,
  ease: "power3.out",
  delay: 0.1,
});
gsap.from(".hero-title", {
  opacity: 0,
  y: 30,
  duration: 0.8,
  ease: "power3.out",
  delay: 0.2,
});
gsap.from(".hero-lede", {
  opacity: 0,
  y: 20,
  duration: 0.7,
  ease: "power3.out",
  delay: 0.4,
});
gsap.from(".hero-actions", {
  opacity: 0,
  y: 20,
  duration: 0.6,
  ease: "power3.out",
  delay: 0.6,
});
gsap.from(".hero-stats .stat", {
  opacity: 0,
  y: 20,
  duration: 0.5,
  ease: "power3.out",
  delay: 0.8,
  stagger: 0.08,
});

/* ---------------- COUNTER ANIMATION ---------------- */
document.querySelectorAll("[data-count]").forEach((el) => {
  const target = parseInt(el.dataset.count);
  const suffix = el.dataset.suffix || "";
  ScrollTrigger.create({
    trigger: el,
    start: "top 90%",
    once: true,
    onEnter: () => {
      gsap.to(el, {
        textContent: target,
        duration: 1.5,
        ease: "power2.out",
        snap: { textContent: 1 },
        onUpdate: function () {
          el.textContent = Math.round(this.targets()[0].textContent) + suffix;
        },
      });
    },
  });
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

  const count = 400;
  const positions = new Float32Array(count * 3);
  const colors = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    positions[i * 3] = (Math.random() - 0.5) * 120;
    positions[i * 3 + 1] = (Math.random() - 0.5) * 80;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 60;
    const c = Math.random() > 0.5 ? [0.55, 0.36, 1] : [0.46, 0.89, 0.83];
    colors[i * 3] = c[0];
    colors[i * 3 + 1] = c[1];
    colors[i * 3 + 2] = c[2];
  }
  particleGeo = new THREE.BufferGeometry();
  particleGeo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
  particleGeo.setAttribute("color", new THREE.BufferAttribute(colors, 3));
  const material = new THREE.PointsMaterial({
    size: 0.6,
    vertexColors: true,
    transparent: true,
    opacity: 0.7,
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
renderCards();
initReveals();
initThree();
document.getElementById("year").textContent = new Date().getFullYear();
