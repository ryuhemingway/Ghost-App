import * as THREE from "three";
import { gsap } from "gsap";

const canvas = document.querySelector("#gallery-canvas");
const detail = document.querySelector("#detail");
const detailClose = document.querySelector(".detail-close");
const statusText = document.querySelector("#status-text");
const detailPreview = document.querySelector("#detail-preview");
const detailKicker = document.querySelector("#detail-kicker");
const detailTitle = document.querySelector("#detail-title");
const detailCopy = document.querySelector("#detail-copy");
const detailLayer = document.querySelector("#detail-layer");
const detailHelp = document.querySelector("#detail-help");
const detailWork = document.querySelector("#detail-work");
const detailStatus = document.querySelector("#detail-status");

const cards = [
  {
    kicker: "Agent Router",
    title: "Route each request to the right engine.",
    module: "Routing",
    copy: "Ghost decides when a prompt needs a fast direct model call or a deeper connected agent run.",
    chips: ["Auto route", "Direct or agent", "Approvals"],
    help: "You can ask naturally without deciding the whole execution path up front.",
    works: "The router scores the prompt, selected provider, model, and task type before choosing an engine.",
    status: "Built into Ghost",
    visual: "router",
    palette: ["#8b5cff", "#76e4d3", "#f4ce7a"]
  },
  {
    kicker: "Direct API Mode",
    title: "Get fast answers from the selected model.",
    module: "Inference",
    copy: "Use provider APIs for quick writing, answers, summaries, and lightweight tool-supported work.",
    chips: ["Fast path", "Provider APIs", "Low friction"],
    help: "Short tasks stay quick and do not need a full agent loop.",
    works: "Ghost calls the selected provider directly and can attach safe app-owned tools when needed.",
    status: "Direct engine",
    visual: "direct",
    palette: ["#f4ce7a", "#8b5cff", "#f7f0ff"]
  },
  {
    kicker: "Local Models",
    title: "Run local inference from your Mac.",
    module: "Local",
    copy: "LM Studio and Ollama keep model traffic close to your machine for private everyday work.",
    chips: ["LM Studio", "Ollama", "Local-first"],
    help: "You can keep sensitive prompts away from hosted providers when local models are enough.",
    works: "Ghost discovers local models from the configured localhost runtimes and routes prompts directly.",
    status: "Local providers",
    visual: "local",
    palette: ["#76e4d3", "#1f6d66", "#f7f0ff"]
  },
  {
    kicker: "LM Studio",
    title: "Connect to LM Studio on localhost.",
    module: "Provider",
    copy: "Ghost reads available LM Studio models and uses the local OpenAI-compatible server.",
    chips: ["localhost:1234", "Model list", "Private"],
    help: "Your local model experiments become usable from a polished macOS workspace.",
    works: "Ghost queries LM Studio's local `/v1/models` endpoint and sends chat through the local API.",
    status: "Supported",
    visual: "provider",
    palette: ["#dd8bb7", "#8b5cff", "#07030c"]
  },
  {
    kicker: "Ollama",
    title: "Use Ollama models in Ghost.",
    module: "Provider",
    copy: "Ghost can discover Ollama tags and route local prompts to the Ollama server.",
    chips: ["localhost:11434", "Tags", "Local"],
    help: "You can switch between downloaded local models without leaving Ghost.",
    works: "Ghost checks Ollama's model list and sends compatible local requests through its endpoint.",
    status: "Supported",
    visual: "provider",
    palette: ["#76e4d3", "#f4ce7a", "#061012"]
  },
  {
    kicker: "Claude",
    title: "Bring Claude into the same command center.",
    module: "Cloud",
    copy: "Use Anthropic models when you want a hosted reasoning model from the Ghost interface.",
    chips: ["API key", "Hosted", "Selectable"],
    help: "Cloud models sit beside local models instead of living in separate tools.",
    works: "Ghost loads the provider key from its secrets layer and sends requests through the Claude path.",
    status: "API key required",
    visual: "provider",
    palette: ["#f4ce7a", "#dd8bb7", "#2a173a"]
  },
  {
    kicker: "Gemini",
    title: "Use Gemini where it fits the task.",
    module: "Cloud",
    copy: "Ghost supports Gemini provider configuration from the same model picker.",
    chips: ["Google key", "Hosted", "Model picker"],
    help: "You can choose the model family that fits the work without changing apps.",
    works: "Ghost uses the configured Gemini or Google API key for provider-specific requests.",
    status: "API key required",
    visual: "provider",
    palette: ["#8b5cff", "#76e4d3", "#f7f0ff"]
  },
  {
    kicker: "DeepSeek",
    title: "Route DeepSeek from the provider layer.",
    module: "Cloud",
    copy: "Ghost includes DeepSeek options for hosted model runs when that provider is selected.",
    chips: ["DeepSeek key", "Hosted", "Direct"],
    help: "You can test DeepSeek beside your local and other hosted models.",
    works: "Ghost maps the selected DeepSeek model through the Direct API client and scoped key handling.",
    status: "API key required",
    visual: "provider",
    palette: ["#73e0d3", "#8b5cff", "#11192c"]
  },
  {
    kicker: "RAG Memory",
    title: "Ask questions across local documents.",
    module: "Retrieval",
    copy: "Ghost indexes approved files and retrieves cited chunks so answers stay grounded.",
    chips: ["Local index", "Cited sources", "Reindexable"],
    help: "Your PDFs, markdown, logs, code, and notes become searchable working memory.",
    works: "Ghost stores document chunks in a local SQLite index and returns source-backed matches.",
    status: "Local database",
    visual: "rag",
    palette: ["#f4ce7a", "#76e4d3", "#020106"]
  },
  {
    kicker: "Document Indexing",
    title: "Sync folders into Ghost memory.",
    module: "Retrieval",
    copy: "Add files or folders and Ghost keeps an index of supported document and source formats.",
    chips: ["Folder sync", "File types", "Status"],
    help: "Project folders can become context without copy-pasting documents into chat.",
    works: "Ghost fingerprints files, skips unchanged content, and stores searchable chunks locally.",
    status: "Supported",
    visual: "indexing",
    palette: ["#f4ce7a", "#73e0d3", "#15100a"]
  },
  {
    kicker: "Source-backed Answers",
    title: "Open the source behind an answer.",
    module: "Retrieval",
    copy: "Grounded answers can include inspectable source references rather than vague confidence.",
    chips: ["Citations", "Open source", "Traceable"],
    help: "You can check where an answer came from before trusting or using it.",
    works: "RAG search returns chunk metadata and source paths that Ghost can open or reveal.",
    status: "Source-aware",
    visual: "sources",
    palette: ["#76e4d3", "#f7f0ff", "#8b5cff"]
  },
  {
    kicker: "Capability Harness",
    title: "Let models request actions safely.",
    module: "Actions",
    copy: "Ghost-owned tools validate paths, run actions, and report what actually happened.",
    chips: ["Validated", "Verified", "Guarded"],
    help: "The app confirms real results instead of relying on model claims.",
    works: "The harness normalizes inputs, gates risky actions, executes app code, and returns receipts.",
    status: "Implemented",
    visual: "harness",
    palette: ["#f4ce7a", "#8b5cff", "#211232"]
  },
  {
    kicker: "Verified File Actions",
    title: "Create and manage files with receipts.",
    module: "Files",
    copy: "Ghost can create, read, move, copy, convert, open, and reveal approved files.",
    chips: ["Create", "Convert", "Reveal"],
    help: "You can ask for real artifacts and see where they landed.",
    works: "File actions run through allowed roots and return actual paths, errors, and summaries.",
    status: "Harness tool",
    visual: "files",
    palette: ["#f7f0ff", "#73e0d3", "#1a0d2a"]
  },
  {
    kicker: "Calendar Actions",
    title: "Create and query calendar events.",
    module: "Native",
    copy: "Ghost can route scheduling requests into native calendar workflows when permitted.",
    chips: ["Events", "Queries", "macOS"],
    help: "Scheduling can happen from the same assistant surface as your work.",
    works: "Calendar requests are parsed, permissioned, and dispatched through Ghost's native integrations.",
    status: "Permissioned",
    visual: "calendar",
    palette: ["#f4ce7a", "#dd8bb7", "#4b245c"]
  },
  {
    kicker: "Reminders",
    title: "Capture follow-ups before they drift.",
    module: "Native",
    copy: "Turn natural language requests into reminders from the Ghost command surface.",
    chips: ["Follow-up", "Due dates", "Native"],
    help: "You can convert intent into a reminder without context switching.",
    works: "Ghost routes reminder prompts to its automation layer and uses macOS permissions.",
    status: "Permissioned",
    visual: "reminders",
    palette: ["#dd8bb7", "#f4ce7a", "#120a1c"]
  },
  {
    kicker: "Voice Input",
    title: "Speak prompts into the workspace.",
    module: "Input",
    copy: "Ghost includes microphone and speech-recognition permission hooks for voice-driven prompts.",
    chips: ["Mic", "Speech", "Hands-free"],
    help: "Quick thoughts can become prompts before they lose shape.",
    works: "The app requests the required macOS permissions and uses the native input path.",
    status: "Permissioned",
    visual: "voice",
    palette: ["#8b5cff", "#f7f0ff", "#06030a"]
  },
  {
    kicker: "Web Context",
    title: "Add current web context to answers.",
    module: "Research",
    copy: "Ghost can bring web context into answers while keeping source awareness visible.",
    chips: ["Search", "Context", "Sources"],
    help: "Questions that need outside context can still live inside Ghost.",
    works: "The direct client prepares prompts with optional web context before provider execution.",
    status: "Available path",
    visual: "web",
    palette: ["#73e0d3", "#8b5cff", "#0d1324"]
  },
  {
    kicker: "Shell Checks",
    title: "Run bounded checks when useful.",
    module: "Terminal",
    copy: "Ghost supports restricted command checks with output caps and safer boundaries.",
    chips: ["Read-only", "Output caps", "Review"],
    help: "You can verify local state without turning every prompt into broad shell access.",
    works: "Read-only checks route through bounded command services and higher-risk commands require approval.",
    status: "Guarded",
    visual: "shell",
    palette: ["#8b5cff", "#f4ce7a", "#06030a"]
  },
  {
    kicker: "Ghost Code",
    title: "Use a wider coding workspace.",
    module: "Developer",
    copy: "Ghost Code gives deeper tasks a terminal-style surface for output, traces, and files.",
    chips: ["Code view", "Traces", "Workspace"],
    help: "Developer work has room to breathe when a compact panel is not enough.",
    works: "Ghost switches interface modes and sizes so agent work can show richer context.",
    status: "Interface mode",
    visual: "code",
    palette: ["#73e0d3", "#8b5cff", "#11192c"]
  },
  {
    kicker: "Menu Bar Workspace",
    title: "Stay close to the task.",
    module: "macOS",
    copy: "Ghost lives in the menu bar and can return with a global keyboard shortcut.",
    chips: ["Menu bar", "Option-Space", "Native"],
    help: "The assistant stays available without taking over the desktop.",
    works: "Ghost runs as an accessory macOS app with a menu-bar extra and floating panel.",
    status: "Native app",
    visual: "panel",
    palette: ["#8b5cff", "#dd8bb7", "#08040f"]
  },
  {
    kicker: "Provider Settings",
    title: "Keep model keys scoped.",
    module: "Settings",
    copy: "Ghost stores provider secrets and applies them only to the selected model route.",
    chips: ["Keys", "Scoped", "Secrets"],
    help: "You can configure providers without spraying every key into every execution path.",
    works: "Secrets are loaded from Ghost's local env store and filtered by provider.",
    status: "Local config",
    visual: "settings",
    palette: ["#f4ce7a", "#f7f0ff", "#2a173a"]
  },
  {
    kicker: "Agent Configuration",
    title: "Connect the local agent you trust.",
    module: "Agent",
    copy: "Ghost can launch Ghost Agent or Hermes Agent from expected local binary paths.",
    chips: ["ghost", "hermes", "Toolsets"],
    help: "Longer work can move into an agent while Ghost remains the control surface.",
    works: "Ghost starts the selected CLI with model, provider, approval mode, and turn-limit options.",
    status: "Local binary",
    visual: "agent",
    palette: ["#8b5cff", "#73e0d3", "#1b1130"]
  },
  {
    kicker: "Local-first Privacy",
    title: "Choose what stays on your Mac.",
    module: "Privacy",
    copy: "Use local models and local retrieval when the work should remain close to your machine.",
    chips: ["Local models", "Local RAG", "Control"],
    help: "You can make privacy a routing choice instead of an afterthought.",
    works: "Ghost separates local providers, local indexes, and hosted provider key paths.",
    status: "Design principle",
    visual: "privacy",
    palette: ["#dd8bb7", "#f4ce7a", "#120a1c"]
  },
  {
    kicker: "Finder/File Tools",
    title: "Open, reveal, and inspect local sources.",
    module: "Workspace",
    copy: "Ghost can open cited files, reveal generated artifacts, and inspect workspace paths.",
    chips: ["Finder", "Open", "Reveal"],
    help: "Answers and artifacts stay connected to real files on disk.",
    works: "Finder actions run through the capability layer and return the resolved file path.",
    status: "Harness tool",
    visual: "finder",
    palette: ["#f7f0ff", "#76e4d3", "#171026"]
  }
];

const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: true,
  alpha: true,
  powerPreference: "high-performance"
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.55));

const scene = new THREE.Scene();
scene.fog = new THREE.FogExp2(0x040207, 0.047);

const camera = new THREE.PerspectiveCamera(58, window.innerWidth / window.innerHeight, 0.1, 80);
camera.position.set(0, 0, 0.1);

const gallery = new THREE.Group();
const gridGroup = new THREE.Group();
gallery.add(gridGroup);
scene.add(gallery);

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2(10, 10);
const centerPointer = new THREE.Vector2(0.1, 0.01);
const cardMeshes = [];
const tempWorldPosition = new THREE.Vector3();
let hovered = null;
let activeCard = null;
let isDragging = false;
let pointerMoved = false;
let lastX = 0;
let lastY = 0;
let velocityX = 0;
let velocityY = 0;
let settleTimer = 0;
const rotationBounds = { x: 0.5, y: 1.04 };
const targetRotation = { x: 0.02, y: 0 };
const currentRotation = { x: 0.02, y: 0 };

function makeCardTexture(card, index) {
  const textureCanvas = document.createElement("canvas");
  textureCanvas.width = 1100;
  textureCanvas.height = 1380;
  const ctx = textureCanvas.getContext("2d");
  drawFeatureTile(ctx, textureCanvas, card, index);
  const texture = new THREE.CanvasTexture(textureCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = 8;
  return texture;
}

function makeDetailPreview(card) {
  const previewCanvas = document.createElement("canvas");
  previewCanvas.width = 1400;
  previewCanvas.height = 760;
  const ctx = previewCanvas.getContext("2d");
  drawPreviewSurface(ctx, previewCanvas, card, true);
  return previewCanvas.toDataURL("image/png");
}

function drawFeatureTile(ctx, canvasEl, card, index) {
  const [a, b, c] = card.palette;
  const width = canvasEl.width;
  const height = canvasEl.height;
  const gradient = ctx.createLinearGradient(0, 0, width, height);
  gradient.addColorStop(0, "#160d23");
  gradient.addColorStop(0.46, "#07030b");
  gradient.addColorStop(1, "#11071b");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);

  ctx.globalAlpha = 0.3;
  ctx.fillStyle = a;
  ctx.beginPath();
  ctx.arc(120, 110, 210, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = b;
  ctx.beginPath();
  ctx.arc(950, 270, 240, 0, Math.PI * 2);
  ctx.fill();
  ctx.globalAlpha = 1;

  roundRect(ctx, 44, 44, width - 88, height - 88, 38);
  ctx.fillStyle = "rgba(255,255,255,0.065)";
  ctx.fill();
  ctx.strokeStyle = "rgba(247,240,255,0.2)";
  ctx.lineWidth = 2;
  ctx.stroke();

  drawPreviewSurface(ctx, { width: width - 160, height: 590 }, card, false, 80, 86);

  ctx.fillStyle = c;
  ctx.font = "900 26px Inter, system-ui, sans-serif";
  ctx.fillText(card.kicker.toUpperCase(), 80, 760);

  ctx.fillStyle = "#f7f0ff";
  ctx.font = "760 58px Inter, system-ui, sans-serif";
  wrapText(ctx, card.title, 80, 850, 900, 66, 2);

  ctx.fillStyle = "rgba(247,240,255,0.7)";
  ctx.font = "430 28px Inter, system-ui, sans-serif";
  wrapText(ctx, card.copy, 80, 1015, 900, 40, 3);

  drawChips(ctx, card.chips, 80, 1190, c);

  ctx.fillStyle = "rgba(247,240,255,0.5)";
  ctx.font = "700 24px Inter, system-ui, sans-serif";
  ctx.fillText(`${String(index + 1).padStart(2, "0")} · ${card.module}`, 80, 1300);
}

function drawPreviewSurface(ctx, canvasEl, card, wide = false, offsetX = 0, offsetY = 0) {
  const width = canvasEl.width;
  const height = canvasEl.height;
  const x = offsetX;
  const y = offsetY;
  const [a, b, c] = card.palette;

  ctx.save();
  ctx.translate(x, y);
  roundRect(ctx, 0, 0, width, height, wide ? 42 : 34);
  const panel = ctx.createLinearGradient(0, 0, width, height);
  panel.addColorStop(0, "rgba(247,240,255,0.18)");
  panel.addColorStop(0.5, "rgba(247,240,255,0.075)");
  panel.addColorStop(1, "rgba(247,240,255,0.12)");
  ctx.fillStyle = panel;
  ctx.fill();
  ctx.strokeStyle = "rgba(247,240,255,0.22)";
  ctx.lineWidth = 2;
  ctx.stroke();

  ctx.fillStyle = "rgba(2,1,6,0.72)";
  roundRect(ctx, 26, 26, width - 52, height - 52, wide ? 30 : 26);
  ctx.fill();

  ctx.fillStyle = "rgba(255,255,255,0.16)";
  ctx.beginPath(); ctx.arc(62, 60, 10, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(94, 60, 10, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(126, 60, 10, 0, Math.PI * 2); ctx.fill();

  ctx.fillStyle = c;
  ctx.font = `800 ${wide ? 30 : 25}px Inter, system-ui, sans-serif`;
  ctx.fillText("Ghost", 160, 70);
  ctx.fillStyle = "rgba(247,240,255,0.58)";
  ctx.font = `600 ${wide ? 20 : 18}px Inter, system-ui, sans-serif`;
  ctx.fillText("Visual preview", width - (wide ? 245 : 215), 68);

  const contentTop = 105;
  if (["router", "direct", "agent"].includes(card.visual)) {
    drawRoutingPreview(ctx, width, height, contentTop, a, b, c, card.visual);
  } else if (["rag", "indexing", "sources"].includes(card.visual)) {
    drawRagPreview(ctx, width, height, contentTop, a, b, c, card.visual);
  } else if (["harness", "files", "finder"].includes(card.visual)) {
    drawHarnessPreview(ctx, width, height, contentTop, a, b, c, card.visual);
  } else if (["calendar", "reminders", "voice", "web"].includes(card.visual)) {
    drawNativePreview(ctx, width, height, contentTop, a, b, c, card.visual);
  } else if (card.visual === "code" || card.visual === "shell") {
    drawCodePreview(ctx, width, height, contentTop, a, b, c);
  } else if (card.visual === "settings" || card.visual === "provider" || card.visual === "local" || card.visual === "privacy") {
    drawSettingsPreview(ctx, width, height, contentTop, a, b, c, card.visual);
  } else {
    drawPanelPreview(ctx, width, height, contentTop, a, b, c);
  }

  ctx.restore();
}

function drawRoutingPreview(ctx, width, height, top, a, b, c, variant) {
  const labels = variant === "agent" ? ["Prompt", "Ghost", "Agent CLI", "Verified result"] : ["Prompt", "Router", "Direct API", "Answer"];
  labels.forEach((label, i) => {
    const x = 62 + i * ((width - 180) / 3);
    const y = top + (i % 2) * 88;
    ctx.strokeStyle = i === 1 ? c : "rgba(247,240,255,0.2)";
    ctx.fillStyle = i === 1 ? `${a}44` : "rgba(255,255,255,0.07)";
    roundRect(ctx, x, y, 150, 72, 18);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = "#f7f0ff";
    ctx.font = "750 20px Inter, system-ui, sans-serif";
    ctx.fillText(label, x + 18, y + 44);
    if (i < labels.length - 1) {
      ctx.strokeStyle = "rgba(247,240,255,0.26)";
      ctx.beginPath();
      ctx.moveTo(x + 155, y + 36);
      ctx.lineTo(x + 205, y + 36);
      ctx.stroke();
    }
  });
  drawMiniTranscript(ctx, 64, top + 230, width - 128, height - top - 280, ["Selected engine", "Scoped provider", "Action receipt"], c);
}

function drawRagPreview(ctx, width, height, top, a, b, c, variant) {
  const leftWidth = Math.min(260, width * 0.31);
  ctx.fillStyle = "rgba(255,255,255,0.06)";
  roundRect(ctx, 58, top, leftWidth, height - top - 56, 22);
  ctx.fill();
  ["Desktop", "Notes", "Project", "PDFs"].forEach((name, i) => {
    ctx.fillStyle = i === 1 ? `${c}33` : "rgba(255,255,255,0.06)";
    roundRect(ctx, 80, top + 34 + i * 58, leftWidth - 44, 38, 12);
    ctx.fill();
    ctx.fillStyle = i === 1 ? "#f7f0ff" : "rgba(247,240,255,0.7)";
    ctx.font = "650 18px Inter, system-ui, sans-serif";
    ctx.fillText(name, 100, top + 59 + i * 58);
  });
  const x = 90 + leftWidth;
  drawMiniTranscript(ctx, x, top, width - x - 58, height - top - 56, variant === "sources" ? ["Answer cites 4 chunks", "Open source", "Reveal in Finder"] : ["Sync complete", "35,890 chunks", "Query local memory"], c);
}

function drawHarnessPreview(ctx, width, height, top, a, b, c, variant) {
  const rows = variant === "files" ? ["create_docx", "convert_pdf", "reveal_file"] : ["normalize path", "execute tool", "verify result"];
  drawMiniTranscript(ctx, 62, top, width - 124, height - top - 58, rows, c);
  ctx.strokeStyle = c;
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.arc(width - 145, top + 80, 38, 0, Math.PI * 2);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(width - 164, top + 80);
  ctx.lineTo(width - 149, top + 96);
  ctx.lineTo(width - 121, top + 62);
  ctx.stroke();
}

function drawNativePreview(ctx, width, height, top, a, b, c, variant) {
  const labels = {
    calendar: ["Today", "Project review", "3:00 PM"],
    reminders: ["Inbox", "Follow up", "Tomorrow"],
    voice: ["Listening", "Speak a prompt", "Ready"],
    web: ["Web context", "Sources found", "Cited answer"]
  }[variant];
  drawMiniTranscript(ctx, 62, top, width - 124, height - top - 58, labels, c);
  for (let i = 0; i < 5; i += 1) {
    ctx.fillStyle = i === 2 ? `${a}55` : "rgba(255,255,255,0.08)";
    roundRect(ctx, width - 270 + i * 38, top + 190 - i * 20, 24, 100 + i * 17, 12);
    ctx.fill();
  }
}

function drawCodePreview(ctx, width, height, top, a, b, c) {
  ctx.fillStyle = "rgba(0,0,0,0.42)";
  roundRect(ctx, 58, top, width - 116, height - top - 56, 22);
  ctx.fill();
  const lines = ["$ ghost chat --provider lmstudio", "✓ loaded workspace instructions", "✓ inspected files", "→ patch ready", "verified result shown"];
  lines.forEach((line, i) => {
    ctx.fillStyle = i === 3 ? c : "rgba(247,240,255,0.76)";
    ctx.font = "650 22px SFMono-Regular, monospace";
    ctx.fillText(line, 92, top + 60 + i * 48);
  });
}

function drawSettingsPreview(ctx, width, height, top, a, b, c, variant) {
  const providers = variant === "local" ? ["LM Studio", "Ollama", "Local RAG"] : ["Claude", "Gemini", "DeepSeek"];
  ctx.fillStyle = "rgba(255,255,255,0.055)";
  roundRect(ctx, 58, top, width - 116, height - top - 56, 22);
  ctx.fill();
  providers.forEach((provider, i) => {
    ctx.fillStyle = i === 0 ? `${a}44` : "rgba(255,255,255,0.07)";
    roundRect(ctx, 90, top + 42 + i * 68, width - 180, 46, 16);
    ctx.fill();
    ctx.fillStyle = "#f7f0ff";
    ctx.font = "720 21px Inter, system-ui, sans-serif";
    ctx.fillText(provider, 116, top + 72 + i * 68);
    ctx.fillStyle = i === 0 ? c : "rgba(247,240,255,0.45)";
    ctx.beginPath();
    ctx.arc(width - 126, top + 65 + i * 68, 8, 0, Math.PI * 2);
    ctx.fill();
  });
}

function drawPanelPreview(ctx, width, height, top, a, b, c) {
  drawMiniTranscript(ctx, 62, top, width - 124, height - top - 58, ["Ask Ghost", "Choose model", "Verified answer"], c);
}

function drawMiniTranscript(ctx, x, y, width, height, rows, accent) {
  ctx.fillStyle = "rgba(255,255,255,0.055)";
  roundRect(ctx, x, y, width, height, 22);
  ctx.fill();
  rows.forEach((row, i) => {
    const rowY = y + 34 + i * 64;
    ctx.fillStyle = i === rows.length - 1 ? `${accent}30` : "rgba(255,255,255,0.065)";
    roundRect(ctx, x + 24, rowY, width - 48, 42, 14);
    ctx.fill();
    ctx.fillStyle = i === rows.length - 1 ? "#f7f0ff" : "rgba(247,240,255,0.72)";
    ctx.font = "700 19px Inter, system-ui, sans-serif";
    ctx.fillText(row, x + 46, rowY + 27);
  });
}

function drawChips(ctx, chips, x, y, accent) {
  let cursor = x;
  chips.slice(0, 3).forEach((chip) => {
    const width = Math.max(120, ctx.measureText(chip).width + 44);
    ctx.fillStyle = "rgba(0,0,0,0.34)";
    roundRect(ctx, cursor, y, width, 56, 28);
    ctx.fill();
    ctx.strokeStyle = `${accent}88`;
    ctx.stroke();
    ctx.fillStyle = "#f7f0ff";
    ctx.font = "750 21px Inter, system-ui, sans-serif";
    ctx.fillText(chip, cursor + 22, y + 36);
    cursor += width + 16;
  });
}

function roundRect(ctx, x, y, width, height, radius) {
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + width, y, x + width, y + height, radius);
  ctx.arcTo(x + width, y + height, x, y + height, radius);
  ctx.arcTo(x, y + height, x, y, radius);
  ctx.arcTo(x, y, x + width, y, radius);
  ctx.closePath();
}

function wrapText(ctx, text, x, y, maxWidth, lineHeight, maxLines = 99) {
  const words = text.split(" ");
  let line = "";
  let cursorY = y;
  let lines = 0;

  words.forEach((word) => {
    if (lines >= maxLines) return;
    const test = line ? `${line} ${word}` : word;
    if (ctx.measureText(test).width > maxWidth && line) {
      ctx.fillText(line, x, cursorY);
      line = word;
      cursorY += lineHeight;
      lines += 1;
    } else {
      line = test;
    }
  });

  if (line && lines < maxLines) ctx.fillText(line, x, cursorY);
}

function createGallery() {
  const isMobile = window.innerWidth < 760;
  const rows = isMobile ? 5 : 4;
  const cols = isMobile ? 6 : 8;
  const yawMin = isMobile ? -48 : -60;
  const yawMax = isMobile ? 48 : 60;
  const pitchMin = isMobile ? -34 : -31;
  const pitchMax = isMobile ? 34 : 31;
  const radius = isMobile ? 5.9 : 6.55;
  const baseWidth = isMobile ? 1.36 : 1.68;
  const baseHeight = isMobile ? 1.68 : 2.06;

  createGridLines(rows, cols, yawMin, yawMax, pitchMin, pitchMax, radius + 0.04);

  let index = 0;
  for (let row = 0; row < rows; row += 1) {
    for (let col = 0; col < cols; col += 1) {
      const card = cards[index % cards.length];
      const u = cols === 1 ? 0.5 : col / (cols - 1);
      const v = rows === 1 ? 0.5 : row / (rows - 1);
      const yawDeg = THREE.MathUtils.lerp(yawMin, yawMax, u);
      const pitchDeg = THREE.MathUtils.lerp(pitchMax, pitchMin, v);
      const yaw = THREE.MathUtils.degToRad(yawDeg);
      const pitch = THREE.MathUtils.degToRad(pitchDeg);
      const edge = Math.min(1, Math.abs(yawDeg) / 74 + Math.abs(pitchDeg) / 92);
      const depth = radius + edge * 0.22;
      const x = depth * Math.cos(pitch) * Math.sin(yaw);
      const y = depth * Math.sin(pitch);
      const z = -depth * Math.cos(pitch) * Math.cos(yaw);
      const centerBoost = 1 - edge * 0.05;
      const baseOpacity = 0.98 - edge * 0.18;

      const material = new THREE.SpriteMaterial({
        map: makeCardTexture(card, index),
        transparent: true,
        opacity: baseOpacity,
        depthWrite: false
      });

      const mesh = new THREE.Sprite(material);
      mesh.position.set(x, y, z);
      mesh.scale.set(baseWidth * centerBoost, baseHeight * centerBoost, 1);
      mesh.userData = {
        card,
        index,
        baseOpacity,
        edge,
        baseScale: new THREE.Vector3(baseWidth * centerBoost, baseHeight * centerBoost, 1)
      };
      gallery.add(mesh);
      cardMeshes.push(mesh);
      index += 1;
    }
  }
}

function createGridLines(rows, cols, yawMin, yawMax, pitchMin, pitchMax, radius) {
  const lineMaterial = new THREE.LineBasicMaterial({
    color: 0xf7f0ff,
    transparent: true,
    opacity: 0.13,
    depthWrite: false
  });
  const yawStep = (yawMax - yawMin) / cols;
  const pitchStep = (pitchMax - pitchMin) / rows;

  for (let i = 0; i <= cols; i += 1) {
    const yaw = THREE.MathUtils.degToRad(yawMin + yawStep * i - yawStep / 2);
    const points = [];
    for (let s = 0; s <= 72; s += 1) {
      const pitch = THREE.MathUtils.degToRad(THREE.MathUtils.lerp(pitchMin - pitchStep / 2, pitchMax + pitchStep / 2, s / 72));
      points.push(curvePoint(radius, yaw, pitch));
    }
    gridGroup.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(points), lineMaterial));
  }

  for (let i = 0; i <= rows; i += 1) {
    const pitch = THREE.MathUtils.degToRad(pitchMin + pitchStep * i - pitchStep / 2);
    const points = [];
    for (let s = 0; s <= 96; s += 1) {
      const yaw = THREE.MathUtils.degToRad(THREE.MathUtils.lerp(yawMin - yawStep / 2, yawMax + yawStep / 2, s / 96));
      points.push(curvePoint(radius, yaw, pitch));
    }
    gridGroup.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(points), lineMaterial));
  }
}

function curvePoint(radius, yaw, pitch) {
  return new THREE.Vector3(
    radius * Math.cos(pitch) * Math.sin(yaw),
    radius * Math.sin(pitch),
    -radius * Math.cos(pitch) * Math.cos(yaw)
  );
}

function createAtmosphere() {
  const stars = new THREE.BufferGeometry();
  const points = [];
  for (let i = 0; i < 650; i += 1) {
    const radius = 9 + Math.random() * 18;
    const theta = Math.random() * Math.PI * 2;
    const phi = Math.acos(2 * Math.random() - 1);
    points.push(
      radius * Math.sin(phi) * Math.cos(theta),
      radius * Math.cos(phi),
      radius * Math.sin(phi) * Math.sin(theta)
    );
  }
  stars.setAttribute("position", new THREE.Float32BufferAttribute(points, 3));
  scene.add(new THREE.Points(stars, new THREE.PointsMaterial({
    color: 0xd8c8ff,
    size: 0.026,
    transparent: true,
    opacity: 0.34,
    depthWrite: false
  })));
}

function resize() {
  const width = window.innerWidth;
  const height = window.innerHeight;
  camera.aspect = width / height;
  camera.fov = width < 760 ? 70 : 56;
  camera.updateProjectionMatrix();
  renderer.setSize(width, height, false);
}

function setPointer(event) {
  const rect = canvas.getBoundingClientRect();
  pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
  pointer.y = -(((event.clientY - rect.top) / rect.height) * 2 - 1);
}

function clampTargetRotation() {
  targetRotation.x = THREE.MathUtils.clamp(targetRotation.x, -rotationBounds.x, rotationBounds.x);
  targetRotation.y = THREE.MathUtils.clamp(targetRotation.y, -rotationBounds.y, rotationBounds.y);
}

function onPointerDown(event) {
  if (activeCard) return;
  isDragging = true;
  pointerMoved = false;
  lastX = event.clientX;
  lastY = event.clientY;
  velocityX = 0;
  velocityY = 0;
  window.clearTimeout(settleTimer);
  canvas.setPointerCapture?.(event.pointerId);
}

function onPointerMove(event) {
  setPointer(event);

  if (!isDragging || activeCard) return;
  const dx = event.clientX - lastX;
  const dy = event.clientY - lastY;
  lastX = event.clientX;
  lastY = event.clientY;

  if (Math.abs(dx) + Math.abs(dy) > 3) pointerMoved = true;
  targetRotation.y += dx * 0.003;
  targetRotation.x += dy * 0.002;
  clampTargetRotation();
  velocityX = dx * 0.003;
  velocityY = dy * 0.002;
  statusText.textContent = "Rotating Ghost feature wall";
}

function onPointerUp(event) {
  if (activeCard) return;
  isDragging = false;
  canvas.releasePointerCapture?.(event.pointerId);
  if (!pointerMoved && hovered) {
    openDetail(hovered);
    return;
  }
  settleTimer = window.setTimeout(() => {
    if (!activeCard) focusCard(nearestCenterCard());
  }, 320);
}

function nearestCenterCard() {
  gallery.updateMatrixWorld();
  let best = null;
  let bestScore = Infinity;

  cardMeshes.forEach((mesh) => {
    mesh.getWorldPosition(tempWorldPosition);
    const projected = tempWorldPosition.clone().project(camera);
    if (projected.z > 1) return;
    const dx = projected.x - centerPointer.x;
    const dy = projected.y - centerPointer.y;
    const score = dx * dx + dy * dy + mesh.userData.edge * 0.012;
    if (score < bestScore) {
      bestScore = score;
      best = mesh;
    }
  });

  return best;
}

function focusCard(mesh) {
  if (hovered === mesh) return;
  hovered = mesh;

  cardMeshes.forEach((item) => {
    const base = item.userData.baseScale;
    const isFocused = item === hovered;
    const dimmed = hovered && !isFocused;
    const scale = isFocused ? 1.11 : 1;
    const opacity = isFocused ? 1 : dimmed ? item.userData.baseOpacity * 0.84 : item.userData.baseOpacity;
    gsap.to(item.scale, {
      x: base.x * scale,
      y: base.y * scale,
      z: 1,
      duration: isFocused ? 0.42 : 0.34,
      ease: "power3.out"
    });
    gsap.to(item.material, {
      opacity,
      duration: 0.28,
      ease: "power2.out"
    });
    item.renderOrder = isFocused ? 10 : 0;
  });

  if (hovered) statusText.textContent = hovered.userData.card.kicker;
}

function openDetail(mesh) {
  const { card } = mesh.userData;
  activeCard = mesh;
  detailKicker.textContent = card.kicker;
  detailTitle.textContent = card.title;
  detailCopy.textContent = card.copy;
  detailLayer.textContent = card.module;
  detailHelp.textContent = card.help;
  detailWork.textContent = card.works;
  detailStatus.textContent = card.status;
  detailPreview.style.backgroundImage = `url(${makeDetailPreview(card)})`;
  detail.classList.add("is-open");
  detail.setAttribute("aria-hidden", "false");
  statusText.textContent = `Opened ${card.kicker}`;

  gsap.to(gallery.scale, { x: 0.92, y: 0.92, z: 0.92, duration: 0.85, ease: "power4.out" });
  gsap.to(gallery.rotation, {
    x: gallery.rotation.x + 0.035,
    y: gallery.rotation.y - 0.1,
    duration: 0.85,
    ease: "power4.out"
  });
  const base = mesh.userData.baseScale;
  gsap.to(mesh.scale, { x: base.x * 1.24, y: base.y * 1.24, z: 1, duration: 0.72, ease: "power4.out" });
  gsap.to(".detail-shell", { y: 0, scale: 1, opacity: 1, duration: 0.68, ease: "power4.out" });
}

function closeDetail() {
  if (!activeCard) return;
  const closing = activeCard;
  activeCard = null;
  detail.setAttribute("aria-hidden", "true");
  statusText.textContent = "Returned to Ghost feature wall";

  gsap.to(".detail-shell", {
    y: 24,
    scale: 0.96,
    opacity: 0,
    duration: 0.35,
    ease: "power2.in",
    onComplete: () => detail.classList.remove("is-open")
  });
  gsap.to(gallery.scale, { x: 1, y: 1, z: 1, duration: 0.75, ease: "power4.out" });
  const base = closing.userData.baseScale;
  gsap.to(closing.scale, { x: base.x * 1.11, y: base.y * 1.11, z: 1, duration: 0.55, ease: "power3.out" });
}

function tick() {
  requestAnimationFrame(tick);

  if (!isDragging && !activeCard) {
    targetRotation.y += velocityX;
    targetRotation.x += velocityY;
    clampTargetRotation();
    velocityX *= 0.9;
    velocityY *= 0.88;
    if (Math.abs(velocityX) < 0.0008) velocityX = 0;
    if (Math.abs(velocityY) < 0.0008) velocityY = 0;
  }

  currentRotation.x += (targetRotation.x - currentRotation.x) * 0.09;
  currentRotation.y += (targetRotation.y - currentRotation.y) * 0.09;
  gallery.rotation.x = currentRotation.x;
  gallery.rotation.y = currentRotation.y;

  if (!isDragging && !activeCard) {
    raycaster.setFromCamera(pointer, camera);
    const hit = raycaster.intersectObjects(cardMeshes, false)[0]?.object || null;
    focusCard(hit || nearestCenterCard());
  }

  renderer.render(scene, camera);
}

createGallery();
createAtmosphere();
resize();
focusCard(nearestCenterCard());
tick();

window.addEventListener("resize", resize);
canvas.addEventListener("pointerdown", onPointerDown);
canvas.addEventListener("pointermove", onPointerMove);
canvas.addEventListener("pointerup", onPointerUp);
canvas.addEventListener("pointercancel", onPointerUp);
detailClose.addEventListener("click", closeDetail);
window.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeDetail();
});

window.ghostGalleryDebug = {
  focusCard(index = 0) {
    const mesh = cardMeshes[index % cardMeshes.length];
    focusCard(mesh);
    return mesh.userData.card.title;
  },
  openCard(index = 0) {
    const mesh = cardMeshes[index % cardMeshes.length];
    focusCard(mesh);
    openDetail(mesh);
    return mesh.userData.card.title;
  },
  closeDetail,
  rotateTo(y = 0.5, x = 0.04) {
    targetRotation.y = THREE.MathUtils.clamp(y, -rotationBounds.y, rotationBounds.y);
    targetRotation.x = THREE.MathUtils.clamp(x, -rotationBounds.x, rotationBounds.x);
  },
  cardCount: () => cardMeshes.length,
  cardTitles: () => cardMeshes.map((mesh) => mesh.userData.card.kicker)
};
