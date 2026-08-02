import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { createServer } from "node:http";

const PORT = 3000;
const CSV_PATH = "pc_app/data/count_log.csv";
const RESET_REQUEST_DIR = "pc_app/data/reset_requests";
const HEX_PATTERN = /^[0-9A-Fa-f]{8}$/;
let resetRequestSequence = 0;
let latestBrightness = 255;
const SPI_RESPONSE_TIMEOUT_MS = 1500;
const ACCEL_RESPONSE_TIMEOUT_MS = 3000;

function readCountLog() {
  const text = readFileSync(CSV_PATH, "utf8");
  const lines = text
    .split(/\r?\n/)
    .filter((line) => line.trim().length > 0);

  const rows = [];

  for (const line of lines) {
    const columns = line.split(",");
    if (
      columns.length === 3 &&
      columns[0] === "timestamp" &&
      columns[1] === "count_hex" &&
      columns[2] === "count_decimal"
    ) {
      continue;
    }

    if (columns.length !== 3) {
      continue;
    }

    const [timestamp, countHex, countDecimal] = columns;
    if (
      timestamp.length === 0 ||
      !HEX_PATTERN.test(countHex) ||
      !Number.isInteger(Number(countDecimal))
    ) {
      continue;
    }

    rows.push({
      timestamp: columns[0],
      countHex: columns[1],
      countDecimal: columns[2],
    });
  }

  return {
    count: rows.length,
    rows,
  };
}

function getCountPayload() {
  const { count, rows } = readCountLog();
  const latestRow = rows[rows.length - 1];

  return {
    count,
    latest: latestRow ?? null,
    latest100: rows.slice(-100).reverse(),
  };
}

function sendJson(response, data) {
  response.writeHead(200, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  });
  response.end(JSON.stringify(data));
}

function sendErrorJson(response, statusCode, message) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  });
  response.end(JSON.stringify({ error: message }));
}

function createUartRequest(command) {
  mkdirSync(RESET_REQUEST_DIR, { recursive: true });
  resetRequestSequence += 1;
  const requestBase = `${Date.now()}-${process.pid}-${resetRequestSequence}`;
  const temporaryPath = `${RESET_REQUEST_DIR}/${requestBase}.tmp`;
  const requestPath = `${RESET_REQUEST_DIR}/${requestBase}.reset`;
  writeFileSync(temporaryPath, `${command}\n`, { encoding: "utf8", flag: "wx" });
  renameSync(temporaryPath, requestPath);
  return requestPath;
}

function parseRequestBody(request) {
  return new Promise((resolve, reject) => {
    let body = "";

    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1024) {
        reject(new Error("request body too large"));
        request.destroy();
      }
    });
    request.on("end", () => resolve(body));
    request.on("error", reject);
  });
}

function parseBrightnessValue(body) {
  let parsedBody;
  try {
    parsedBody = JSON.parse(body);
  } catch {
    throw new Error("invalid JSON body");
  }

  const value = Number(parsedBody.value);
  if (!Number.isInteger(value) || value < 0 || value > 255) {
    throw new Error("value must be an integer from 0 to 255");
  }

  return value;
}

function parseSpiTransferValue(body) {
  let parsedBody;
  try {
    parsedBody = JSON.parse(body);
  } catch {
    throw new Error("invalid JSON body");
  }

  const value = Number(parsedBody.value);
  if (!Number.isInteger(value) || value < 0 || value > 255) {
    throw new Error("value must be an integer from 0 to 255");
  }

  return value;
}

function parseInt8List(value, name) {
  if (!Array.isArray(value)) {
    throw new Error(`${name} must be an array`);
  }
  if (value.length < 1 || value.length > 16) {
    throw new Error(`${name} length must be from 1 to 16`);
  }

  return value.map((item) => {
    const parsedValue = Number(item);
    if (!Number.isInteger(parsedValue) || parsedValue < -128 || parsedValue > 127) {
      throw new Error(`${name} values must be int8 integers`);
    }
    return parsedValue;
  });
}

function parseDotProductRequest(body) {
  let parsedBody;
  try {
    parsedBody = JSON.parse(body);
  } catch {
    throw new Error("invalid JSON body");
  }

  const inputs = parseInt8List(parsedBody.inputs, "inputs");
  const weights = parseInt8List(parsedBody.weights, "weights");
  if (inputs.length !== weights.length) {
    throw new Error("inputs and weights must have the same length");
  }

  return { inputs, weights };
}

function delay(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function waitForResponseFile(requestPath, timeoutMs) {
  const responsePath = requestPath.replace(/\.reset$/, ".response.json");
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    if (existsSync(responsePath)) {
      const text = readFileSync(responsePath, "utf8");
      unlinkSync(responsePath);
      return JSON.parse(text);
    }
    await delay(50);
  }

  throw new Error("UART request timed out");
}

function sendHtml(response) {
  response.writeHead(200, {
    "Content-Type": "text/html; charset=utf-8",
    "Cache-Control": "no-store",
  });
  response.end(`<!doctype html>
<html lang="ja">
  <head>
    <title>Tang Nano 9K Count Log</title>
    <style>
      table {
        border-collapse: collapse;
      }

      th,
      td {
        border: 1px solid #c8c8c8;
        padding: 8px 12px;
        text-align: left;
      }

      .status-value {
        display: inline-block;
        min-width: 4em;
        white-space: nowrap;
      }

      #spi-results {
        margin-top: 8px;
      }

      #spi-results div {
        white-space: nowrap;
      }
    </style>
  </head>
  <body>
    <h2>Latest Count</h2>
    <div id="latest-count">-</div>
    <div>HEX: <span id="latest-hex">-</span></div>
    <div>Time: <span id="latest-time">-</span></div>
    <button id="reset-counter" type="button">Reset Counter</button>
    <button id="led-on" type="button">LED ON</button>
    <button id="led-off" type="button">LED OFF</button>
    <span id="reset-status"></span>
    <p>
      LED Brightness:
      <span id="brightness-value">${latestBrightness}</span>
    </p>
    <input
      id="brightness"
      type="range"
      min="0"
      max="255"
      value="${latestBrightness}"
    >
    <p>Total Records: <span id="total-count">0</span></p>
    <h2>SPI Loopback Test</h2>
    <label for="spi-tx">TX:</label>
    <input id="spi-tx" value="A5" size="4">
    <button id="spi-transfer" type="button">Transfer</button>
    <button id="spi-loopback-test" type="button">Run Loopback Test</button>
    <div>RX: <span id="spi-rx" class="status-value">-</span></div>
    <div>Communication: <span id="spi-communication" class="status-value">Idle</span></div>
    <div>Loopback: <span id="spi-loopback" class="status-value">-</span></div>
    <div id="spi-results"></div>
    <h2>AI Dot Product Accelerator</h2>
    <label for="dot-inputs">Inputs:</label>
    <input id="dot-inputs" value="1, 2, 3, 4" size="24">
    <br>
    <label for="dot-weights">Weights:</label>
    <input id="dot-weights" value="5, 6, 7, 8" size="24">
    <button id="dot-run" type="button">Run Accelerator</button>
    <div>Python result: <span id="dot-python">-</span></div>
    <div>FPGA result: <span id="dot-fpga">-</span></div>
    <div>Verification: <span id="dot-verification" class="status-value">-</span></div>
    <div>FPGA cycles: <span id="dot-cycles">-</span></div>
    <div>Vector length: <span id="dot-length">-</span></div>
    <div>Status: <span id="dot-status">Idle</span></div>
    <table>
      <thead>
        <tr>
          <th>timestamp</th>
          <th>count_hex</th>
          <th>count_decimal</th>
        </tr>
      </thead>
      <tbody id="count-rows"></tbody>
    </table>
    <script>
      const latestCountElement = document.getElementById("latest-count");
      const latestHexElement = document.getElementById("latest-hex");
      const latestTimeElement = document.getElementById("latest-time");
      const totalCountElement = document.getElementById("total-count");
      const countRowsElement = document.getElementById("count-rows");
      const resetCounterElement = document.getElementById("reset-counter");
      const ledOnElement = document.getElementById("led-on");
      const ledOffElement = document.getElementById("led-off");
      const resetStatusElement = document.getElementById("reset-status");
      const brightnessElement = document.getElementById("brightness");
      const brightnessValueElement = document.getElementById("brightness-value");
      const spiTxElement = document.getElementById("spi-tx");
      const spiTransferElement = document.getElementById("spi-transfer");
      const spiLoopbackTestElement = document.getElementById("spi-loopback-test");
      const spiRxElement = document.getElementById("spi-rx");
      const spiCommunicationElement = document.getElementById("spi-communication");
      const spiLoopbackElement = document.getElementById("spi-loopback");
      const spiResultsElement = document.getElementById("spi-results");
      const dotInputsElement = document.getElementById("dot-inputs");
      const dotWeightsElement = document.getElementById("dot-weights");
      const dotRunElement = document.getElementById("dot-run");
      const dotPythonElement = document.getElementById("dot-python");
      const dotFpgaElement = document.getElementById("dot-fpga");
      const dotVerificationElement = document.getElementById("dot-verification");
      const dotCyclesElement = document.getElementById("dot-cycles");
      const dotLengthElement = document.getElementById("dot-length");
      const dotStatusElement = document.getElementById("dot-status");
      let brightnessTimer = null;

      function setText(element, value) {
        element.textContent = value;
      }

      function renderTable(rows) {
        countRowsElement.replaceChildren(
          ...rows.map((row) => {
            const tableRow = document.createElement("tr");
            const timestampCell = document.createElement("td");
            const hexCell = document.createElement("td");
            const decimalCell = document.createElement("td");

            timestampCell.textContent = row.timestamp;
            hexCell.textContent = row.countHex;
            decimalCell.textContent = row.countDecimal;

            tableRow.append(timestampCell, hexCell, decimalCell);
            return tableRow;
          }),
        );
      }

      async function refreshCounts() {
        const response = await fetch("/api/counts", { cache: "no-store" });
        if (!response.ok) {
          throw new Error("failed to fetch counts");
        }

        const data = await response.json();
        const latest = data.latest;

        setText(latestCountElement, latest ? latest.countDecimal : "-");
        setText(latestHexElement, latest ? latest.countHex : "-");
        setText(latestTimeElement, latest ? latest.timestamp : "-");
        setText(totalCountElement, data.count);
        renderTable(data.latest100);
      }

      async function resetCounter() {
        await sendCommandRequest("/api/reset");
      }

      async function sendCommandRequest(url) {
        setText(resetStatusElement, "");

        const response = await fetch(url, {
          method: "POST",
          cache: "no-store",
        });
        const data = await response.json();

        if (!response.ok) {
          throw new Error(data.error || "failed to send reset command");
        }

        setText(resetStatusElement, "Reset command sent");
      }

      async function sendBrightness(value) {
        setText(resetStatusElement, "");

        const response = await fetch("/api/led/brightness", {
          method: "POST",
          cache: "no-store",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ value }),
        });
        const data = await response.json();

        if (!response.ok) {
          throw new Error(data.error || "failed to send brightness command");
        }

        setText(resetStatusElement, "Brightness command sent");
      }

      function scheduleBrightnessSend() {
        const value = Number(brightnessElement.value);
        setText(brightnessValueElement, value);

        if (brightnessTimer !== null) {
          clearTimeout(brightnessTimer);
        }

        brightnessTimer = setTimeout(() => {
          sendBrightness(value).catch((error) => {
            setText(resetStatusElement, error.message);
          });
        }, 150);
      }

      function parseSpiInput() {
        const text = spiTxElement.value.trim();
        if (/^[0-9]+$/.test(text)) {
          return Number(text);
        }
        if (/^[0-9a-fA-F]{2}$/.test(text)) {
          return parseInt(text, 16);
        }
        throw new Error("TX must be 0-255 or two hex digits");
      }

      async function transferSpi() {
        const value = parseSpiInput();
        if (!Number.isInteger(value) || value < 0 || value > 255) {
          throw new Error("TX must be 0-255");
        }

        const data = await transferSpiValue(value);
        renderSpiTransferResult(data);
      }

      async function transferSpiValue(value) {
        const response = await fetch("/api/spi/transfer", {
          method: "POST",
          cache: "no-store",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ value }),
        });
        const data = await response.json();

        if (!response.ok) {
          throw new Error(data.error || "SPI transfer failed");
        }

        return data;
      }

      function renderSpiTransferResult(data) {
        const tx = Number(data.tx);
        const rx = Number(data.rx);
        const loopbackPassed = tx === rx;

        setText(spiRxElement, data.rxHex);
        setText(spiCommunicationElement, "Completed");
        setText(spiLoopbackElement, loopbackPassed ? "PASS" : "FAIL");
      }

      function formatHexByte(value) {
        return value.toString(16).toUpperCase().padStart(2, "0");
      }

      async function runLoopbackTest() {
        const values = [0x00, 0x01, 0x55, 0xAA, 0xA5, 0xFF];
        spiLoopbackTestElement.disabled = true;
        spiTransferElement.disabled = true;
        spiResultsElement.replaceChildren();
        setText(spiCommunicationElement, "Running");
        setText(spiLoopbackElement, "-");

        try {
          for (const value of values) {
            const data = await transferSpiValue(value);
            const tx = Number(data.tx);
            const rx = Number(data.rx);
            const loopbackPassed = tx === rx;
            const resultRow = document.createElement("div");
            resultRow.textContent =
              formatHexByte(tx) + " -> " + formatHexByte(rx) + " " +
              (loopbackPassed ? "PASS" : "FAIL");
            spiResultsElement.append(resultRow);
            renderSpiTransferResult(data);
          }
        } finally {
          spiLoopbackTestElement.disabled = false;
          spiTransferElement.disabled = false;
        }
      }

      function parseInt8Csv(text, name) {
        const values = text.split(",").map((item) => item.trim()).filter(Boolean);
        if (values.length < 1 || values.length > 16) {
          throw new Error(name + " length must be 1-16");
        }
        return values.map((item) => {
          const value = Number(item);
          if (!Number.isInteger(value) || value < -128 || value > 127) {
            throw new Error(name + " values must be int8");
          }
          return value;
        });
      }

      async function runDotProduct() {
        const inputs = parseInt8Csv(dotInputsElement.value, "inputs");
        const weights = parseInt8Csv(dotWeightsElement.value, "weights");
        if (inputs.length !== weights.length) {
          throw new Error("inputs and weights must have the same length");
        }

        dotRunElement.disabled = true;
        setText(dotStatusElement, "Running");
        setText(dotVerificationElement, "-");

        try {
          const response = await fetch("/api/accelerator/dot-product", {
            method: "POST",
            cache: "no-store",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ inputs, weights }),
          });
          const data = await response.json();

          if (!response.ok) {
            throw new Error(data.error || "accelerator failed");
          }

          setText(dotPythonElement, data.pythonResult);
          setText(dotFpgaElement, data.fpgaResult);
          setText(dotVerificationElement, data.passed ? "PASS" : "FAIL");
          setText(dotCyclesElement, data.cycles);
          setText(dotLengthElement, data.vectorLength);
          setText(dotStatusElement, "Completed");
        } finally {
          dotRunElement.disabled = false;
        }
      }

      resetCounterElement.addEventListener("click", () => {
        resetCounter().catch((error) => {
          setText(resetStatusElement, error.message);
        });
      });
      ledOnElement.addEventListener("click", () => {
        sendCommandRequest("/api/led/on").catch((error) => {
          setText(resetStatusElement, error.message);
        });
      });
      ledOffElement.addEventListener("click", () => {
        sendCommandRequest("/api/led/off").catch((error) => {
          setText(resetStatusElement, error.message);
        });
      });
      brightnessElement.addEventListener("input", scheduleBrightnessSend);
      spiTransferElement.addEventListener("click", () => {
        setText(spiCommunicationElement, "Running");
        setText(spiLoopbackElement, "-");
        transferSpi().catch((error) => {
          setText(spiCommunicationElement, error.message);
          setText(spiLoopbackElement, "-");
        });
      });
      spiLoopbackTestElement.addEventListener("click", () => {
        runLoopbackTest().catch((error) => {
          setText(spiCommunicationElement, error.message);
          setText(spiLoopbackElement, "-");
        });
      });
      dotRunElement.addEventListener("click", () => {
        runDotProduct().catch((error) => {
          setText(dotStatusElement, error.message);
          setText(dotVerificationElement, "-");
        });
      });

      refreshCounts().catch((error) => console.error(error));
      setInterval(() => {
        refreshCounts().catch((error) => console.error(error));
      }, 1000);
    </script>
  </body>
</html>`);
}

const server = createServer(async (request, response) => {
  console.log("request received:", new Date().toISOString(), request.url);

  if (request.url === "/api/counts") {
    const payload = getCountPayload();
    console.log("valid rows:", payload.count);
    sendJson(response, payload);
    return;
  }

  if (request.url === "/api/reset") {
    if (request.method !== "POST") {
      sendErrorJson(response, 405, "method not allowed");
      return;
    }

    try {
      createUartRequest("W 04 00000001");
      sendJson(response, { ok: true, message: "Reset command sent" });
    } catch (error) {
      sendErrorJson(response, 500, error.message);
    }
    return;
  }

  if (request.url === "/api/led/on" || request.url === "/api/led/off") {
    if (request.method !== "POST") {
      sendErrorJson(response, 405, "method not allowed");
      return;
    }

    try {
      const value = request.url === "/api/led/on" ? "00000001" : "00000000";
      createUartRequest(`W 08 ${value}`);
      sendJson(response, { ok: true, message: "Reset command sent" });
    } catch (error) {
      sendErrorJson(response, 500, error.message);
    }
    return;
  }

  if (request.url === "/api/led/brightness") {
    if (request.method !== "POST") {
      sendErrorJson(response, 405, "method not allowed");
      return;
    }

    try {
      const body = await parseRequestBody(request);
      const value = parseBrightnessValue(body);
      const hexValue = value.toString(16).toUpperCase().padStart(8, "0");
      createUartRequest(`W 0C ${hexValue}`);
      latestBrightness = value;
      sendJson(response, { ok: true, value });
    } catch (error) {
      sendErrorJson(response, 400, error.message);
    }
    return;
  }

  if (request.url === "/api/spi/transfer") {
    if (request.method !== "POST") {
      sendErrorJson(response, 405, "method not allowed");
      return;
    }

    try {
      const body = await parseRequestBody(request);
      const value = parseSpiTransferValue(body);
      const requestPath = createUartRequest(`SPI_TRANSFER ${value}`);
      const result = await waitForResponseFile(requestPath, SPI_RESPONSE_TIMEOUT_MS);
      if (!result.ok) {
        sendErrorJson(response, 504, result.error || "SPI transfer failed");
        return;
      }
      sendJson(response, result);
    } catch (error) {
      const statusCode = error.message.includes("timed out") ? 504 : 400;
      sendErrorJson(response, statusCode, error.message);
    }
    return;
  }

  if (request.url === "/api/accelerator/dot-product") {
    if (request.method !== "POST") {
      sendErrorJson(response, 405, "method not allowed");
      return;
    }

    try {
      const body = await parseRequestBody(request);
      const payload = parseDotProductRequest(body);
      const requestPath = createUartRequest(`DOT_PRODUCT ${JSON.stringify(payload)}`);
      const result = await waitForResponseFile(requestPath, ACCEL_RESPONSE_TIMEOUT_MS);
      if (!result.ok) {
        const statusCode = result.error?.includes("timed out") ? 504 : 500;
        sendErrorJson(response, statusCode, result.error || "accelerator failed");
        return;
      }
      sendJson(response, result);
    } catch (error) {
      const statusCode = error.message.includes("timed out") ? 504 : 400;
      sendErrorJson(response, statusCode, error.message);
    }
    return;
  }

  sendHtml(response);
});

server.listen(PORT);
