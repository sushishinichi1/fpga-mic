"use strict";

const BAUD_RATE = 115200;
const HISTORY_LENGTH = 240;
const UART_ACTIVE_MS = 1500;

const connectButton = document.querySelector("#connectButton");
const disconnectButton = document.querySelector("#disconnectButton");
const rawValue = document.querySelector("#rawValue");
const peakValue = document.querySelector("#peakValue");
const volumeValue = document.querySelector("#volumeValue");
const debugVolumeValue = document.querySelector("#debugVolumeValue");
const volumeBar = document.querySelector("#volumeBar");
const uartStatus = document.querySelector("#uartStatus");
const linesPerSecond = document.querySelector("#linesPerSecond");
const lastLine = document.querySelector("#lastLine");
const canvas = document.querySelector("#historyCanvas");
const ctx = canvas.getContext("2d");

let port = null;
let reader = null;
let keepReading = false;
let history = Array(HISTORY_LENGTH).fill(0);
let lineTimestamps = [];
let lastReceiveAt = 0;

function setConnectedUi(connected) {
  connectButton.disabled = connected;
  disconnectButton.disabled = !connected;
}

function resizeCanvas() {
  const rect = canvas.getBoundingClientRect();
  const ratio = window.devicePixelRatio || 1;
  const width = Math.max(1, Math.floor(rect.width * ratio));
  const height = Math.max(1, Math.floor(rect.height * ratio));

  if (canvas.width !== width || canvas.height !== height) {
    canvas.width = width;
    canvas.height = height;
    drawHistory();
  }
}

function updateVolume(value) {
  const clamped = Math.max(0, Math.min(255, value));
  volumeValue.value = String(clamped);
  debugVolumeValue.value = String(clamped);
  volumeBar.style.width = `${(clamped / 255) * 100}%`;
  history.push(clamped);
  history = history.slice(-HISTORY_LENGTH);
  drawHistory();
}

function drawHistory() {
  const width = canvas.width;
  const height = canvas.height;

  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = "#fbfcfe";
  ctx.fillRect(0, 0, width, height);

  ctx.strokeStyle = "#e1e5ec";
  ctx.lineWidth = 1;
  for (let i = 1; i < 4; i += 1) {
    const y = (height * i) / 4;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(width, y);
    ctx.stroke();
  }

  ctx.strokeStyle = "#1f6feb";
  ctx.lineWidth = Math.max(2, Math.round(width / 500));
  ctx.beginPath();
  history.forEach((value, index) => {
    const x = (index / (HISTORY_LENGTH - 1)) * width;
    const y = height - (value / 255) * height;

    if (index === 0) {
      ctx.moveTo(x, y);
    } else {
      ctx.lineTo(x, y);
    }
  });
  ctx.stroke();
}

function noteLineReceived() {
  const now = performance.now();
  lastReceiveAt = now;
  lineTimestamps.push(now);
  lineTimestamps = lineTimestamps.filter((time) => now - time <= 1000);
  linesPerSecond.value = String(lineTimestamps.length);
}

function updateUartStatus() {
  const active = keepReading && performance.now() - lastReceiveAt < UART_ACTIVE_MS;
  uartStatus.value = active ? "receiving" : keepReading ? "waiting" : "stopped";
  lineTimestamps = lineTimestamps.filter((time) => performance.now() - time <= 1000);
  linesPerSecond.value = String(lineTimestamps.length);
}

function handleLine(line) {
  const trimmed = line.trim();
  if (!trimmed) {
    return;
  }

  noteLineReceived();
  lastLine.value = trimmed;

  const match = trimmed.match(/^(?:RAW|AW):(-?\d+)\s+PEAK:(\d+)\s+VOL:(\d+)$/);
  if (!match) {
    return;
  }

  rawValue.value = match[1];
  peakValue.value = match[2];
  updateVolume(Number(match[3]));
}

async function readLoop() {
  const decoder = new TextDecoder();
  let buffer = "";

  while (port && keepReading) {
    reader = port.readable.getReader();

    try {
      while (keepReading) {
        const { value, done } = await reader.read();
        if (done) {
          break;
        }

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split(/\r?\n/);
        buffer = lines.pop() ?? "";
        lines.forEach(handleLine);
      }
    } finally {
      reader.releaseLock();
      reader = null;
    }
  }
}

async function connect() {
  if (!("serial" in navigator)) {
    uartStatus.value = "unsupported";
    lastLine.value = "Open this page in Chrome or Edge with Web Serial support.";
    return;
  }

  try {
    port = await navigator.serial.requestPort();
    await port.open({ baudRate: BAUD_RATE });
    keepReading = true;
    lastReceiveAt = 0;
    lineTimestamps = [];
    setConnectedUi(true);
    await readLoop();
  } catch (error) {
    uartStatus.value = "error";
    lastLine.value = error.message;
    setConnectedUi(false);
  }
}

async function disconnect() {
  keepReading = false;

  if (reader) {
    await reader.cancel();
  }

  if (port) {
    await port.close();
    port = null;
  }

  setConnectedUi(false);
  updateUartStatus();
}

connectButton.addEventListener("click", connect);
disconnectButton.addEventListener("click", disconnect);
window.addEventListener("resize", resizeCanvas);

setInterval(updateUartStatus, 250);
requestAnimationFrame(resizeCanvas);
