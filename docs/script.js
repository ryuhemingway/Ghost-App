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
  },
  {
    kicker: "Direct API Mode",
    title: "Get fast answers from the selected model.",
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
    help: "You can keep sensitive prompts away from hosted providers when local models are enough.",
    works:
      "Ghost discovers local models from the configured localhost runtimes and routes prompts directly.",
    status: "Local providers",
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
    help: "You can switch between downloaded local models without leaving Ghost.",
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
    help: "You can choose the model family that fits the work without changing apps.",
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
    help: "You can test DeepSeek beside your local and other hosted models.",
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
    help: "You can check where an answer came from before trusting or using it.",
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
    help: "You can ask for real artifacts and see where they landed.",
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
    help: "You can convert intent into a reminder without context switching.",
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
    kicker: "Web Context",
    title: "Add current web context to answers.",
    module: "Actions",
    copy: "Ghost can bring web context into answers while keeping source awareness visible.",
    chips: ["Search", "Context", "Sources"],
    help: "Questions that need outside context can still live inside Ghost.",
    works:
      "The direct client prepares prompts with optional web context before provider execution.",
    status: "Available path",
  },
  {
    kicker: "Shell Checks",
    title: "Run bounded checks when useful.",
    module: "Developer",
    copy: "Ghost supports restricted command checks with output caps and safer boundaries.",
    chips: ["Read-only", "Output caps", "Review"],
    help: "You can verify local state without turning every prompt into broad shell access.",
    works:
      "Read-only checks route through bounded command services and higher-risk commands require approval.",
    status: "Guarded",
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
    kicker: "Provider Settings",
    title: "Keep model keys scoped.",
    module: "Actions",
    copy: "Ghost stores provider secrets and applies them only to the selected model route.",
    chips: ["Keys", "Scoped", "Secrets"],
    help: "You can configure providers without spraying every key into every execution path.",
    works:
      "Secrets are loaded from Ghost's local env store and filtered by provider.",
    status: "Local config",
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
  {
    kicker: "Local-first Privacy",
    title: "Choose what stays on your Mac.",
    module: "Local",
    copy: "Use local models and local retrieval when the work should remain close to your machine.",
    chips: ["Local models", "Local RAG", "Control"],
    help: "You can make privacy a routing choice instead of an afterthought.",
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
];

const grid = document.getElementById("grid");
const modal = document.getElementById("modal");
const modalTitle = document.getElementById("modal-title");
const modalKicker = document.getElementById("modal-kicker");
const modalCopy = document.getElementById("modal-copy");
const modalModule = document.getElementById("modal-module");
const modalHelp = document.getElementById("modal-help");
const modalWorks = document.getElementById("modal-works");
const modalStatus = document.getElementById("modal-status");
const modalChips = document.getElementById("modal-chips");

function renderCards(filter = "all") {
  grid.innerHTML = "";
  cards.forEach((card, index) => {
    const matches = filter === "all" || card.module === filter;
    const el = document.createElement("article");
    el.className = "card reveal" + (matches ? "" : " is-hidden");
    el.style.transitionDelay = `${(index % 12) * 30}ms`;
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
      el.style.setProperty("--mx", `${e.clientX - rect.left}px`);
      el.style.setProperty("--my", `${e.clientY - rect.top}px`);
    });
    grid.appendChild(el);
  });
  requestAnimationFrame(reveal);
}

function openModal(card) {
  modalKicker.textContent = card.kicker;
  modalTitle.textContent = card.title;
  modalCopy.textContent = card.copy;
  modalModule.textContent = card.module;
  modalHelp.textContent = card.help;
  modalWorks.textContent = card.works;
  modalStatus.textContent = card.status;
  modalChips.innerHTML = card.chips
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

// Filters
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

// Nav scroll state
const nav = document.getElementById("nav");
window.addEventListener(
  "scroll",
  () => {
    nav.classList.toggle("is-scrolled", window.scrollY > 8);
  },
  { passive: true },
);

// Reveal on scroll
const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("in");
        revealObserver.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.12, rootMargin: "0px 0px -40px 0px" },
);

function reveal() {
  document
    .querySelectorAll(".reveal:not(.in)")
    .forEach((el) => revealObserver.observe(el));
}

// Year
document.getElementById("year").textContent = new Date().getFullYear();

// Init
renderCards();
reveal();
