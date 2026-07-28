import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";

const PORT = 3000;
const CSV_PATH = "pc_app/data/count_log.csv";
const RESET_REQUEST_DIR = "pc_app/data/reset_requests";
const HEX_PATTERN = /^[0-9A-Fa-f]{8}$/;
let resetRequestSequence = 0;

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

function createResetRequest() {
  mkdirSync(RESET_REQUEST_DIR, { recursive: true });
  resetRequestSequence += 1;
  const requestPath =
    `${RESET_REQUEST_DIR}/${Date.now()}-${process.pid}-${resetRequestSequence}.reset`;
  writeFileSync(requestPath, "r\n", { encoding: "utf8", flag: "wx" });
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
    </style>
  </head>
  <body>
    <h2>Latest Count</h2>
    <div id="latest-count">-</div>
    <div>HEX: <span id="latest-hex">-</span></div>
    <div>Time: <span id="latest-time">-</span></div>
    <button id="reset-counter" type="button">Reset Counter</button>
    <span id="reset-status"></span>
    <p>Total Records: <span id="total-count">0</span></p>
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
      const resetStatusElement = document.getElementById("reset-status");

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
        setText(resetStatusElement, "");

        const response = await fetch("/api/reset", {
          method: "POST",
          cache: "no-store",
        });
        const data = await response.json();

        if (!response.ok) {
          throw new Error(data.error || "failed to send reset command");
        }

        setText(resetStatusElement, "Reset command sent");
      }

      resetCounterElement.addEventListener("click", () => {
        resetCounter().catch((error) => {
          setText(resetStatusElement, error.message);
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

const server = createServer((request, response) => {
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
      createResetRequest();
      sendJson(response, { ok: true, message: "Reset command sent" });
    } catch (error) {
      sendErrorJson(response, 500, error.message);
    }
    return;
  }

  sendHtml(response);
});

server.listen(PORT);
