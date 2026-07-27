import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const CSV_PATH = resolve("pc_app", "data", "count_log.csv");
const HEX_PATTERN = /^[0-9A-Fa-f]{8}$/;

function parseCsv(text) {
  const records = [];

  for (const rawLine of text.replace(/^\uFEFF/, "").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line.length === 0) {
      continue;
    }

    const columns = line.split(",").map((column) => column.trim());
    if (isHeader(columns)) {
      continue;
    }

    if (columns.length !== 3) {
      continue;
    }

    const [timestamp, countHex, countDecimalText] = columns;
    const countDecimal = Number(countDecimalText);

    if (
      timestamp.length === 0 ||
      !HEX_PATTERN.test(countHex) ||
      !Number.isInteger(countDecimal)
    ) {
      continue;
    }

    records.push({
      timestamp,
      count_hex: countHex.toUpperCase(),
      count_decimal: countDecimal,
    });
  }

  return records;
}

function isHeader(columns) {
  return (
    columns.length === 3 &&
    columns[0] === "timestamp" &&
    columns[1] === "count_hex" &&
    columns[2] === "count_decimal"
  );
}

function printRecords(records) {
  if (records.length === 0) {
    console.log("No valid count records found.");
    return;
  }

  console.log(`CSV: ${CSV_PATH}`);
  console.log(`Records: ${records.length}`);
  console.table(records);
}

const text = readFileSync(CSV_PATH, "utf8");
printRecords(parseCsv(text));
