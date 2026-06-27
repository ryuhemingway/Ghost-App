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

const cards = [
  ["Agent Router", "Route by task", "Routing", "Fast answers go direct. Deeper work moves through a connected agent with tools and approvals.", ["#8b5cff", "#73e0d3", "#f4ce7a"]],
  ["Local Models", "LM Studio", "Local", "Run local models through Ghost's managed tool loop without accidental cloud-agent drift.", ["#dd8bb7", "#8b5cff", "#07030c"]],
  ["Local Models", "Ollama", "Local", "Keep local inference close to the Mac while still giving models real Ghost capabilities.", ["#73e0d3", "#1f6d66", "#f7f0ff"]],
  ["RAG Memory", "Cited context", "Retrieval", "Index private files, retrieve source chunks, and keep citations inspectable.", ["#f4ce7a", "#73e0d3", "#020106"]],
  ["Harness", "Verified action", "Trust", "Models can ask. Ghost normalizes, gates, executes, and verifies what happened.", ["#f4ce7a", "#8b5cff", "#211232"]],
  ["File Tools", "Create files", "Workspace", "Create, read, convert, open, reveal, and organize files through safe roots.", ["#f7f0ff", "#73e0d3", "#1a0d2a"]],
  ["Calendar", "Schedule work", "Native", "Create and query calendar events from the same command surface.", ["#f4ce7a", "#dd8bb7", "#4b245c"]],
  ["Reminders", "Capture intent", "Native", "Turn natural language into reminders without leaving the gallery layer.", ["#dd8bb7", "#f4ce7a", "#120a1c"]],
  ["Voice Input", "Speak prompts", "Input", "Dictate prompts into a Mac-native assistant that stays near the work.", ["#8b5cff", "#f7f0ff", "#06030a"]],
  ["Web Context", "Search with cites", "Research", "Bring web context into answers while keeping source references visible.", ["#73e0d3", "#8b5cff", "#0d1324"]],
  ["Shell Checks", "Read-only runs", "Terminal", "Run restricted command checks with output caps and safe command boundaries.", ["#8b5cff", "#f4ce7a", "#06030a"]],
  ["Provider Layer", "Switch models", "Cloud", "Move between Claude, Gemini, DeepSeek, LM Studio, and Ollama intentionally.", ["#8b5cff", "#dd8bb7", "#f7f0ff"]],
  ["Verified Results", "Proof over claims", "Receipts", "Ghost's transcript reflects structured action results, not model confidence.", ["#73e0d3", "#f7f0ff", "#8b5cff"]],
  ["Ghost Code", "Trace the work", "Developer", "Use a wider surface for command output, file context, and agent traces.", ["#73e0d3", "#8b5cff", "#11192c"]],
  ["Private Layer", "Own context", "Control", "Choose the model, own the context, and decide what stays local.", ["#dd8bb7", "#f4ce7a", "#120a1c"]],
  ["Finder Bridge", "Reveal sources", "Workspace", "Open cited documents and reveal generated files without losing context.", ["#f7f0ff", "#76e4d3", "#171026"]],
  ["Document QA", "Ask PDFs", "Knowledge", "Ask across PDFs, markdown, logs, code, and transcripts with local citations.", ["#f4ce7a", "#73e0d3", "#020106"]],
  ["Deep Work", "Agent turns", "Autonomy", "Give complex work to an agent while Ghost preserves the boundary of truth.", ["#8b5cff", "#73e0d3", "#1b1130"]],
  ["API Keys", "Scoped secrets", "Security", "Provider keys are scoped to the selected route instead of sprayed into every run.", ["#f4ce7a", "#f7f0ff", "#2a173a"]],
  ["Ghost Glass", "Calm control", "Interface", "A compact command surface that feels native, spectral, and close to macOS.", ["#8b5cff", "#dd8bb7", "#08040f"]],
  ["Ghost Outputs", "Real artifacts", "Files", "Generate documents and artifacts into known local destinations.", ["#73e0d3", "#f4ce7a", "#071216"]],
  ["Sync Folders", "Fresh memory", "RAG", "Sync changed documents into local memory without damaging originals.", ["#f4ce7a", "#73e0d3", "#15100a"]],
  ["Mac Actions", "Native bridge", "Automation", "Calendar, reminders, files, Finder, voice, and shell checks share one layer.", ["#dd8bb7", "#8b5cff", "#16091f"]],
  ["Command Center", "Menu-bar close", "macOS", "Ghost appears near the task, then gets out of the way.", ["#8b5cff", "#f4ce7a", "#05030a"]]
].map(([kicker, title, layer, copy, palette]) => ({ kicker, title, layer, copy, palette }));

const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: true,
  alpha: true,
  powerPreference: "high-performance"
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));

const scene = new THREE.Scene();
scene.fog = new THREE.FogExp2(0x05030a, 0.052);

const camera = new THREE.PerspectiveCamera(62, window.innerWidth / window.innerHeight, 0.1, 80);
camera.position.set(0, 0, 0.1);

const gallery = new THREE.Group();
scene.add(gallery);

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2(10, 10);
const centerPointer = new THREE.Vector2(0.16, 0.02);
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
const rotationBounds = { x: 0.42, y: 0.92 };
const targetRotation = { x: 0.02, y: 0 };
const currentRotation = { x: 0.02, y: 0 };

function makeCardTexture(card, index) {
  const textureCanvas = document.createElement("canvas");
  textureCanvas.width = 1024;
  textureCanvas.height = 1280;
  const ctx = textureCanvas.getContext("2d");
  const [a, b, c] = card.palette;

  const gradient = ctx.createLinearGradient(0, 0, textureCanvas.width, textureCanvas.height);
  gradient.addColorStop(0, a);
  gradient.addColorStop(0.38, "#13091f");
  gradient.addColorStop(1, b);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, textureCanvas.width, textureCanvas.height);

  ctx.globalAlpha = 0.22;
  for (let i = 0; i < 32; i += 1) {
    ctx.strokeStyle = i % 2 ? c : "#ffffff";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(530, 560, 70 + i * 18, 0.06 * i, Math.PI * 1.2 + i * 0.018);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;

  const glass = ctx.createLinearGradient(76, 74, 948, 1160);
  glass.addColorStop(0, "rgba(255,255,255,0.16)");
  glass.addColorStop(0.54, "rgba(255,255,255,0.07)");
  glass.addColorStop(1, "rgba(255,255,255,0.11)");
  ctx.fillStyle = glass;
  roundRect(ctx, 70, 72, 884, 1136, 46);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,0.28)";
  ctx.lineWidth = 2;
  ctx.stroke();

  ctx.fillStyle = c;
  ctx.font = "800 32px Inter, system-ui, sans-serif";
  ctx.fillText(card.kicker.toUpperCase(), 112, 164);

  ctx.fillStyle = "#f7f0ff";
  ctx.font = "650 92px Georgia, serif";
  wrapText(ctx, card.title, 112, 330, 760, 98, 3);

  ctx.fillStyle = "rgba(247,240,255,0.72)";
  ctx.font = "400 34px Inter, system-ui, sans-serif";
  wrapText(ctx, card.copy, 112, 690, 760, 48, 4);

  ctx.strokeStyle = "rgba(255,255,255,0.22)";
  ctx.beginPath();
  ctx.moveTo(112, 1000);
  ctx.lineTo(852, 1000);
  ctx.stroke();

  ctx.fillStyle = "rgba(0,0,0,0.34)";
  roundRect(ctx, 112, 1058, 360, 76, 38);
  ctx.fill();
  ctx.fillStyle = "#f7f0ff";
  ctx.font = "650 30px Inter, system-ui, sans-serif";
  ctx.fillText(`${String(index + 1).padStart(2, "0")} / ${card.layer}`, 146, 1108);

  const texture = new THREE.CanvasTexture(textureCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = 8;
  return texture;
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
  const radius = isMobile ? 6.1 : 6.7;
  const baseWidth = isMobile ? 1.38 : 1.5;
  const baseHeight = isMobile ? 1.72 : 1.86;
  const bands = [
    { count: 5, pitch: 29, yaw: 48, offset: -0.2 },
    { count: 7, pitch: 12, yaw: 62, offset: 0.12 },
    { count: 7, pitch: -7, yaw: 62, offset: -0.06 },
    { count: 5, pitch: -25, yaw: 48, offset: 0.2 }
  ];

  let index = 0;
  bands.forEach((band) => {
    for (let col = 0; col < band.count; col += 1) {
      const card = cards[index % cards.length];
      const t = band.count === 1 ? 0.5 : col / (band.count - 1);
      const yawDeg = THREE.MathUtils.lerp(-band.yaw, band.yaw, t) + band.offset * 10;
      const pitchDeg = band.pitch + Math.sin((t + band.offset) * Math.PI) * 3;
      const yaw = THREE.MathUtils.degToRad(yawDeg);
      const pitch = THREE.MathUtils.degToRad(pitchDeg);
      const edge = Math.min(1, Math.abs(yawDeg) / 68 + Math.abs(pitchDeg) / 72);
      const depth = radius + edge * 0.82;
      const x = depth * Math.cos(pitch) * Math.sin(yaw);
      const y = depth * Math.sin(pitch);
      const z = -depth * Math.cos(pitch) * Math.cos(yaw);
      const centerBoost = 1 - edge * 0.14;
      const baseOpacity = 0.94 - edge * 0.26;

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
  });
}

function createAtmosphere() {
  const stars = new THREE.BufferGeometry();
  const points = [];
  for (let i = 0; i < 900; i += 1) {
    const radius = 9 + Math.random() * 22;
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
    size: 0.032,
    transparent: true,
    opacity: 0.5,
    depthWrite: false
  })));

  const dome = new THREE.Mesh(
    new THREE.SphereGeometry(8.4, 56, 28),
    new THREE.MeshBasicMaterial({
      color: 0x8b5cff,
      wireframe: true,
      transparent: true,
      opacity: 0.045,
      side: THREE.BackSide
    })
  );
  scene.add(dome);
}

function resize() {
  const width = window.innerWidth;
  const height = window.innerHeight;
  camera.aspect = width / height;
  camera.fov = width < 760 ? 74 : 62;
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
  targetRotation.y += dx * 0.0032;
  targetRotation.x += dy * 0.0022;
  clampTargetRotation();
  velocityX = dx * 0.0032;
  velocityY = dy * 0.0022;
  statusText.textContent = "Rotating dense gallery";
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
  }, 360);
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
    const score = dx * dx + dy * dy + mesh.userData.edge * 0.018;
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
    const scale = isFocused ? 1.18 : 1;
    const opacity = isFocused ? 1 : dimmed ? item.userData.baseOpacity * 0.58 : item.userData.baseOpacity;
    gsap.to(item.scale, {
      x: base.x * scale,
      y: base.y * scale,
      z: 1,
      duration: isFocused ? 0.48 : 0.42,
      ease: "power3.out"
    });
    gsap.to(item.material, {
      opacity,
      duration: 0.35,
      ease: "power2.out"
    });
    item.renderOrder = isFocused ? 10 : 0;
  });

  if (hovered) statusText.textContent = hovered.userData.card.title;
}

function openDetail(mesh) {
  const { card } = mesh.userData;
  activeCard = mesh;
  detailKicker.textContent = card.kicker;
  detailTitle.textContent = card.title;
  detailCopy.textContent = card.copy;
  detailLayer.textContent = card.layer;
  detailPreview.style.background = `
    radial-gradient(circle at 28% 18%, ${card.palette[2]}66, transparent 38%),
    linear-gradient(135deg, ${card.palette[0]}, #12081e 48%, ${card.palette[1]})
  `;
  detail.classList.add("is-open");
  detail.setAttribute("aria-hidden", "false");
  statusText.textContent = `Opened ${card.title}`;

  gsap.to(gallery.scale, { x: 0.9, y: 0.9, z: 0.9, duration: 0.85, ease: "power4.out" });
  gsap.to(gallery.rotation, {
    x: gallery.rotation.x + 0.045,
    y: gallery.rotation.y - 0.12,
    duration: 0.85,
    ease: "power4.out"
  });
  const base = mesh.userData.baseScale;
  gsap.to(mesh.scale, { x: base.x * 1.35, y: base.y * 1.35, z: 1, duration: 0.8, ease: "power4.out" });
  gsap.to(".detail-shell", { y: 0, scale: 1, opacity: 1, duration: 0.7, ease: "power4.out" });
}

function closeDetail() {
  if (!activeCard) return;
  const closing = activeCard;
  activeCard = null;
  detail.setAttribute("aria-hidden", "true");
  statusText.textContent = "Returned to spherical gallery";

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
  gsap.to(closing.scale, { x: base.x * 1.18, y: base.y * 1.18, z: 1, duration: 0.55, ease: "power3.out" });
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
  cardCount: () => cardMeshes.length
};
