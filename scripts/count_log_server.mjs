import { readFileSync } from "node:fs";
import { createServer } from "node:http";

const PORT = 3000;
const CSV_PATH = "pc_app/data/count_log.csv";
const HEX_PATTERN = /^[0-9A-Fa-f]{8}$/;

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

const server = createServer((request, response) => {
  console.log("request received:", new Date().toISOString());

  const { count, rows } = readCountLog();
  console.log("valid rows:", count);
  const latestRow = rows[rows.length - 1];
  const displayRows = rows.slice(-100).reverse();
  const tableRows = displayRows
    .map(
      (row) => `<tr>
          <td>${row.timestamp}</td>
          <td>${row.countHex}</td>
          <td>${row.countDecimal}</td>
        </tr>`,
    )
    .join("");

  response.writeHead(200, {
  "Content-Type": "text/html; charset=utf-8",
  "Cache-Control": "no-store",
});
  response.end(`<!doctype html>
<html lang="ja">
  <head>
    <meta http-equiv="refresh" content="5">
    <title>Tang Nano 9K Count Log</title>
  </head>
  <body>
    <h2>Latest Count</h2>
    <div>${latestRow.countDecimal}</div>
    <div>HEX: ${latestRow.countHex}</div>
    <div>Time: ${latestRow.timestamp}</div>
    <p>Count: ${count}</p>
    <table>
      <thead>
        <tr>
          <th>timestamp</th>
          <th>count_hex</th>
          <th>count_decimal</th>
        </tr>
      </thead>
      <tbody>
        ${tableRows}
      </tbody>
    </table>
  </body>
</html>`);
});

server.listen(PORT);
