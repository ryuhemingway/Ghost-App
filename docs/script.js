import * as THREE from "three";
import { gsap } from "gsap";

const canvas = document.querySelector("#gallery-canvas");
const detail = document.querySelector("#detail");
const detailClose = document.querySelector(".detail-close");
const statusText = document.querySelector("#status-text");
const detailKicker = document.querySelector("#detail-kicker");
const detailTitle = document.querySelector("#detail-title");
const detailCopy = document.querySelector("#detail-copy");
const detailLayer = document.querySelector("#detail-layer");

const cards = [
  {
    kicker: "Agent Router",
    title: "Direct API or agent depth",
    layer: "Routing",
    copy: "Ghost decides whether the prompt needs a fast model answer or a deeper local agent loop with tools, approvals, and project context.",
    palette: ["#8b5cff", "#73e0d3", "#f4ce7a"]
  },
  {
    kicker: "RAG Memory",
    title: "Private cited context",
    layer: "Retrieval",
    copy: "Index documents locally, retrieve cited chunks, and keep source files inspectable from the answer.",
    palette: ["#73e0d3", "#1f6d66", "#f7f0ff"]
  },
  {
    kicker: "Harness",
    title: "Verified local action",
    layer: "Trust",
    copy: "The model can ask, but Ghost normalizes, gates, executes, and verifies what actually happened on your Mac.",
    palette: ["#f4ce7a", "#8b5cff", "#211232"]
  },
  {
    kicker: "Local Models",
    title: "LM Studio and Ollama",
    layer: "Local-first",
    copy: "Run local models through a managed tool loop with provider isolation, keeping local work away from accidental cloud-agent drift.",
    palette: ["#dd8bb7", "#8b5cff", "#06030a"]
  },
  {
    kicker: "Mac Native",
    title: "Calendar, reminders, files",
    layer: "Native",
    copy: "Schedule, inspect, create, reveal, dictate, and run safe read-only checks without leaving the menu-bar command layer.",
    palette: ["#f4ce7a", "#dd8bb7", "#4b245c"]
  },
  {
    kicker: "Ghost Code",
    title: "Project-aware work",
    layer: "Developer",
    copy: "A wider terminal-grade surface for traces, command output, file context, and agent workflows.",
    palette: ["#73e0d3", "#8b5cff", "#0d1324"]
  },
  {
    kicker: "Provider Layer",
    title: "Claude, Gemini, DeepSeek",
    layer: "Cloud",
    copy: "Switch providers intentionally while Ghost scopes credentials to the selected model route.",
    palette: ["#8b5cff", "#dd8bb7", "#f7f0ff"]
  },
  {
    kicker: "Finder Bridge",
    title: "Files become actions",
    layer: "Workspace",
    copy: "Read, write, convert, open, and reveal files through a harness that understands safe roots.",
    palette: ["#f7f0ff", "#73e0d3", "#1a0d2a"]
  },
  {
    kicker: "Research",
    title: "Ask across private notes",
    layer: "Knowledge",
    copy: "Turn PDFs, markdown, transcripts, and logs into searchable memory without flattening your workflow.",
    palette: ["#f4ce7a", "#73e0d3", "#020106"]
  },
  {
    kicker: "Command Surface",
    title: "Always near the work",
    layer: "macOS",
    copy: "A calm, spectral layer that appears from the menu bar and disappears when the work is done.",
    palette: ["#8b5cff", "#f4ce7a", "#06030a"]
  },
  {
    kicker: "Receipts",
    title: "Proof over promises",
    layer: "Verification",
    copy: "Ghost's transcript is built from structured results, not unverified model confidence.",
    palette: ["#73e0d3", "#f7f0ff", "#8b5cff"]
  },
  {
    kicker: "Private Layer",
    title: "Your Mac stays central",
    layer: "Control",
    copy: "Choose the model, own the context, and keep local work local when the task demands it.",
    palette: ["#dd8bb7", "#f4ce7a", "#120a1c"]
  }
];

const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: true,
  alpha: true,
  powerPreference: "high-performance"
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.8));

const scene = new THREE.Scene();
scene.fog = new THREE.FogExp2(0x05030a, 0.035);

const camera = new THREE.PerspectiveCamera(68, window.innerWidth / window.innerHeight, 0.1, 100);
camera.position.set(0, 0, 0.1);

const gallery = new THREE.Group();
scene.add(gallery);

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2(10, 10);
const cardMeshes = [];
let hovered = null;
let activeCard = null;
let isDragging = false;
let pointerMoved = false;
let lastX = 0;
let lastY = 0;
let velocityX = 0;
let velocityY = 0;
const targetRotation = { x: 0.05, y: -0.2 };
const currentRotation = { x: 0.05, y: -0.2 };

function makeCardTexture(card, index) {
  const textureCanvas = document.createElement("canvas");
  textureCanvas.width = 1024;
  textureCanvas.height = 1360;
  const ctx = textureCanvas.getContext("2d");
  const [a, b, c] = card.palette;

  const gradient = ctx.createLinearGradient(0, 0, textureCanvas.width, textureCanvas.height);
  gradient.addColorStop(0, a);
  gradient.addColorStop(0.46, "#13091f");
  gradient.addColorStop(1, b);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, textureCanvas.width, textureCanvas.height);

  ctx.globalAlpha = 0.24;
  for (let i = 0; i < 42; i += 1) {
    ctx.strokeStyle = i % 2 ? c : "#ffffff";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(520, 610, 70 + i * 16, 0.1 * i, Math.PI * 1.2 + i * 0.02);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;

  ctx.fillStyle = "rgba(255,255,255,0.08)";
  roundRect(ctx, 72, 76, 880, 1208, 46);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,0.22)";
  ctx.lineWidth = 2;
  ctx.stroke();

  ctx.fillStyle = c;
  ctx.font = "700 34px Inter, system-ui, sans-serif";
  ctx.letterSpacing = "4px";
  ctx.fillText(card.kicker.toUpperCase(), 116, 180);

  ctx.fillStyle = "#f7f0ff";
  ctx.font = "600 86px Georgia, serif";
  wrapText(ctx, card.title, 116, 330, 760, 94);

  ctx.fillStyle = "rgba(247,240,255,0.72)";
  ctx.font = "400 34px Inter, system-ui, sans-serif";
  wrapText(ctx, card.copy, 116, 720, 760, 48);

  ctx.strokeStyle = "rgba(255,255,255,0.22)";
  ctx.beginPath();
  ctx.moveTo(116, 1044);
  ctx.lineTo(850, 1044);
  ctx.stroke();

  ctx.fillStyle = "rgba(0,0,0,0.32)";
  roundRect(ctx, 116, 1098, 328, 76, 38);
  ctx.fill();
  ctx.fillStyle = "#f7f0ff";
  ctx.font = "600 30px Inter, system-ui, sans-serif";
  ctx.fillText(`0${(index % 9) + 1} / ${card.layer}`, 148, 1147);

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

function wrapText(ctx, text, x, y, maxWidth, lineHeight) {
  const words = text.split(" ");
  let line = "";
  let cursorY = y;

  words.forEach((word) => {
    const test = line ? `${line} ${word}` : word;
    if (ctx.measureText(test).width > maxWidth && line) {
      ctx.fillText(line, x, cursorY);
      line = word;
      cursorY += lineHeight;
    } else {
      line = test;
    }
  });

  if (line) ctx.fillText(line, x, cursorY);
}

function createGallery() {
  const radius = 10.6;

  cards.forEach((card, index) => {
    const row = Math.floor(index / 4);
    const col = index % 4;
    const theta = (col / 4) * Math.PI * 2 + row * 0.34;
    const phi = Math.PI * (0.31 + row * 0.18);
    const x = radius * Math.sin(phi) * Math.cos(theta);
    const y = radius * Math.cos(phi);
    const z = radius * Math.sin(phi) * Math.sin(theta);

    const material = new THREE.SpriteMaterial({
      map: makeCardTexture(card, index),
      transparent: true,
      opacity: 0.84,
      depthWrite: false
    });

    const mesh = new THREE.Sprite(material);
    mesh.position.set(x, y, z);
    mesh.scale.set(2.65, 3.52, 1);
    mesh.userData = {
      card,
      index,
      baseScale: new THREE.Vector3(2.65, 3.52, 1)
    };
    gallery.add(mesh);
    cardMeshes.push(mesh);
  });
}

function createAtmosphere() {
  const stars = new THREE.BufferGeometry();
  const points = [];
  for (let i = 0; i < 700; i += 1) {
    const radius = 18 + Math.random() * 26;
    const theta = Math.random() * Math.PI * 2;
    const phi = Math.acos(2 * Math.random() - 1);
    points.push(
      radius * Math.sin(phi) * Math.cos(theta),
      radius * Math.cos(phi),
      radius * Math.sin(phi) * Math.sin(theta)
    );
  }
  stars.setAttribute("position", new THREE.Float32BufferAttribute(points, 3));
  const material = new THREE.PointsMaterial({
    color: 0xd8c8ff,
    size: 0.035,
    transparent: true,
    opacity: 0.58,
    depthWrite: false
  });
  scene.add(new THREE.Points(stars, material));

  const ring = new THREE.Mesh(
    new THREE.SphereGeometry(13, 48, 24),
    new THREE.MeshBasicMaterial({
      color: 0x8b5cff,
      wireframe: true,
      transparent: true,
      opacity: 0.035,
      side: THREE.BackSide
    })
  );
  scene.add(ring);
}

function resize() {
  const width = window.innerWidth;
  const height = window.innerHeight;
  camera.aspect = width / height;
  camera.fov = width < 760 ? 78 : 68;
  camera.updateProjectionMatrix();
  renderer.setSize(width, height, false);
}

function setPointer(event) {
  const rect = canvas.getBoundingClientRect();
  pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
  pointer.y = -(((event.clientY - rect.top) / rect.height) * 2 - 1);
}

function onPointerDown(event) {
  if (activeCard) return;
  isDragging = true;
  pointerMoved = false;
  lastX = event.clientX;
  lastY = event.clientY;
  velocityX = 0;
  velocityY = 0;
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
  targetRotation.y += dx * 0.0042;
  targetRotation.x += dy * 0.0028;
  targetRotation.x = THREE.MathUtils.clamp(targetRotation.x, -0.78, 0.78);
  velocityX = dx * 0.0042;
  velocityY = dy * 0.0028;
  statusText.textContent = "Rotating spherical gallery";
}

function onPointerUp(event) {
  if (activeCard) return;
  isDragging = false;
  canvas.releasePointerCapture?.(event.pointerId);
  if (!pointerMoved && hovered) openDetail(hovered);
  window.setTimeout(() => {
    if (!activeCard) statusText.textContent = "Spherical gallery ready";
  }, 420);
}

function focusCard(mesh) {
  if (hovered === mesh) return;
  if (hovered) {
    const base = hovered.userData.baseScale;
    gsap.to(hovered.scale, { x: base.x, y: base.y, z: base.z, duration: 0.45, ease: "power3.out" });
    gsap.to(hovered.material, { opacity: 0.84, duration: 0.35, ease: "power2.out" });
  }
  hovered = mesh;
  if (hovered) {
    const base = hovered.userData.baseScale;
    gsap.to(hovered.scale, { x: base.x * 1.12, y: base.y * 1.12, z: base.z, duration: 0.45, ease: "power3.out" });
    gsap.to(hovered.material, { opacity: 1, duration: 0.35, ease: "power2.out" });
    statusText.textContent = hovered.userData.card.title;
  }
}

function openDetail(mesh) {
  const { card } = mesh.userData;
  activeCard = mesh;
  detailKicker.textContent = card.kicker;
  detailTitle.textContent = card.title;
  detailCopy.textContent = card.copy;
  detailLayer.textContent = card.layer;
  detail.classList.add("is-open");
  detail.setAttribute("aria-hidden", "false");
  statusText.textContent = `Opened ${card.title}`;

  gsap.to(gallery.scale, { x: 0.86, y: 0.86, z: 0.86, duration: 0.85, ease: "power4.out" });
  gsap.to(gallery.rotation, {
    x: gallery.rotation.x + 0.08,
    y: gallery.rotation.y - 0.22,
    duration: 0.85,
    ease: "power4.out"
  });
  const base = mesh.userData.baseScale;
  gsap.to(mesh.scale, { x: base.x * 1.34, y: base.y * 1.34, z: base.z, duration: 0.8, ease: "power4.out" });
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
  gsap.to(closing.scale, { x: base.x * 1.12, y: base.y * 1.12, z: base.z, duration: 0.55, ease: "power3.out" });
}

function tick() {
  requestAnimationFrame(tick);

  if (!isDragging && !activeCard) {
    targetRotation.y += velocityX;
    targetRotation.x += velocityY;
    targetRotation.x = THREE.MathUtils.clamp(targetRotation.x, -0.78, 0.78);
    velocityX *= 0.92;
    velocityY *= 0.9;
  }

  currentRotation.x += (targetRotation.x - currentRotation.x) * 0.085;
  currentRotation.y += (targetRotation.y - currentRotation.y) * 0.085;
  gallery.rotation.x = currentRotation.x;
  gallery.rotation.y = currentRotation.y;

  if (!isDragging && !activeCard) {
    raycaster.setFromCamera(pointer, camera);
    const hit = raycaster.intersectObjects(cardMeshes, false)[0]?.object || null;
    focusCard(hit);
  }

  renderer.render(scene, camera);
}

createGallery();
createAtmosphere();
resize();
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
  rotateTo(y = 0.8, x = 0.05) {
    targetRotation.y = y;
    targetRotation.x = x;
  }
};
