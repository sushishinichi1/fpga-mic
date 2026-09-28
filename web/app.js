"use strict";

const BAUD_RATE = 115200;
const HISTORY_LENGTH = 240;
const UART_ACTIVE_MS = 1500;
const SAMPLE_RATE = 35156.25;
const FFT_SIZE = 256;
const SPECTRUM_BANDS = 32;
const BEAT_FLASH_MS = 130;
const SPECTRUM_SMOOTHING = Object.freeze({
  attackOld: 0.3,
  attackInput: 0.7,
  releaseOld: 0.8,
  releaseInput: 0.2,
});
const DISPLAY_GAIN = Object.freeze({
  peak: 4,
  rms: 8,
  low: 8,
  mid: 10,
  high: 12,
});

const connectButton = document.querySelector("#connectButton");
const disconnectButton = document.querySelector("#disconnectButton");
const rawValue = document.querySelector("#rawValue");
const peakValue = document.querySelector("#peakValue");
const rmsValue = document.querySelector("#rmsValue");
const volumeValue = document.querySelector("#volumeValue");
const volumeBar = document.querySelector("#volumeBar");
const lowValue = document.querySelector("#lowValue");
const midValue = document.querySelector("#midValue");
const highValue = document.querySelector("#highValue");
const lowBar = document.querySelector("#lowBar");
const midBar = document.querySelector("#midBar");
const highBar = document.querySelector("#highBar");
const uartStatus = document.querySelector("#uartStatus");
const linesPerSecond = document.querySelector("#linesPerSecond");
const lastLine = document.querySelector("#lastLine");
const fftBinValue = document.querySelector("#fftBinValue");
const dominantFrequency = document.querySelector("#dominantFrequency");
const fftPowerValue = document.querySelector("#fftPowerValue");
const spectrumBarsElement = document.querySelector("#spectrumBars");
const beatIndicator = document.querySelector("#beatIndicator");
const beatCountValue = document.querySelector("#beatCountValue");
const bpmValue = document.querySelector("#bpmValue");
const canvas = document.querySelector("#historyCanvas");
const ctx = canvas.getContext("2d");

let port = null;
let reader = null;
let keepReading = false;
let history = Array(HISTORY_LENGTH).fill(0);
let lineTimestamps = [];
let lastReceiveAt = 0;
let spectrumDisplay = Array(SPECTRUM_BANDS).fill(0);
let lastBeatCount = null;
let beatFlashTimer = null;
const spectrumBars = Array.from({ length: SPECTRUM_BANDS }, () => {
  const track = document.createElement("div");
  const fill = document.createElement("div");
  track.className = "spectrum-track";
  fill.className = "spectrum-fill";
  track.append(fill);
  spectrumBarsElement.append(track);
  return fill;
});

function setConnectedUi(connected) {
  connectButton.disabled = connected;
  disconnectButton.disabled = !connected;
}

function clampByte(value) {
  return Math.max(0, Math.min(255, Number.isFinite(value) ? value : 0));
}

function applyDisplayGain(value, gain) {
  return clampByte(clampByte(value) * gain);
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

function setBar(bar, value) {
  const clamped = clampByte(value);
  bar.style.width = `${(clamped / 255) * 100}%`;
  return clamped;
}

function updateVolume(value) {
  const rawValue = clampByte(value);
  const displayValue = setBar(
    volumeBar,
    applyDisplayGain(rawValue, DISPLAY_GAIN.rms),
  );
  volumeValue.value = String(rawValue);
  history.push(displayValue);
  history = history.slice(-HISTORY_LENGTH);
  drawHistory();
}

function updateBand(output, bar, value, gain) {
  const rawValue = clampByte(value);
  setBar(bar, applyDisplayGain(rawValue, gain));
  output.value = String(rawValue);
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

function parseFields(line) {
  const fields = {};
  for (const match of line.matchAll(/([A-Z_]+):(-?\d+)/g)) {
    fields[match[1]] = Number(match[2]);
  }
  return fields;
}

function updateSpectrum(line) {
  const values = line
    .slice("SPEC:".length)
    .split(",")
    .map((value) => Number(value));

  if (values.length !== SPECTRUM_BANDS || values.some((value) => !Number.isFinite(value))) {
    return;
  }

  spectrumDisplay = spectrumDisplay.map((oldValue, index) => {
    const inputValue = clampByte(values[index]);
    const rising = inputValue > oldValue;
    const nextValue = rising
      ? oldValue * SPECTRUM_SMOOTHING.attackOld
        + inputValue * SPECTRUM_SMOOTHING.attackInput
      : oldValue * SPECTRUM_SMOOTHING.releaseOld
        + inputValue * SPECTRUM_SMOOTHING.releaseInput;
    spectrumBars[index].style.height = `${(nextValue / 255) * 100}%`;
    return nextValue;
  });
}

function flashBeatIndicator() {
  beatIndicator.classList.add("active");
  if (beatFlashTimer !== null) {
    clearTimeout(beatFlashTimer);
  }
  beatFlashTimer = setTimeout(() => {
    beatIndicator.classList.remove("active");
    beatFlashTimer = null;
  }, BEAT_FLASH_MS);
}

function handleLine(line) {
  const trimmed = line.trim();
  if (!trimmed) {
    return;
  }

  noteLineReceived();
  lastLine.value = trimmed;

  if (trimmed.startsWith("SPEC:")) {
    updateSpectrum(trimmed);
    return;
  }

  const fields = parseFields(trimmed);
  if (!("PEAK" in fields)) {
    return;
  }

  if ("RAW" in fields) {
    rawValue.value = String(fields.RAW);
  }

  const peak = clampByte(fields.PEAK);
  const rms = clampByte(fields.RMS ?? peak);
  peakValue.value = String(peak);
  rmsValue.value = String(rms);
  updateVolume(rms);

  updateBand(lowValue, lowBar, fields.LOW ?? 0, DISPLAY_GAIN.low);
  updateBand(midValue, midBar, fields.MID ?? 0, DISPLAY_GAIN.mid);
  updateBand(highValue, highBar, fields.HIGH ?? 0, DISPLAY_GAIN.high);

  if ("FFT_BIN" in fields) {
    const fftBin = Math.max(0, Math.trunc(fields.FFT_BIN));
    const frequency = (fftBin * SAMPLE_RATE) / FFT_SIZE;
    fftBinValue.value = String(fftBin);
    dominantFrequency.value = `${Math.round(frequency)} Hz`;
  }

  if ("FFT_PWR" in fields) {
    fftPowerValue.value = String(Math.max(0, Math.trunc(fields.FFT_PWR)));
  }

  if ("BEAT_COUNT" in fields) {
    const beatCount = Math.max(0, Math.trunc(fields.BEAT_COUNT));
    if ((lastBeatCount !== null && beatCount > lastBeatCount) || fields.BEAT === 1) {
      flashBeatIndicator();
    }
    lastBeatCount = beatCount;
    beatCountValue.value = String(beatCount);
  }

  if ("BPM_VALID" in fields) {
    bpmValue.value = fields.BPM_VALID === 1 && "BPM" in fields
      ? String(Math.max(0, Math.trunc(fields.BPM)))
      : "--";
  }
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
