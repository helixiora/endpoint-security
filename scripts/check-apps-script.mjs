import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const codePath = path.resolve(
  process.cwd(),
  'backend/google-apps-script/Code.gs'
);
const source = fs.readFileSync(codePath, 'utf8');

class FakeRange {
  constructor(sheet, row, column, numRows, numCols) {
    this.sheet = sheet;
    this.row = row;
    this.column = column;
    this.numRows = numRows;
    this.numCols = numCols;
  }

  getValues() {
    return this.sheet.getValues(
      this.row,
      this.column,
      this.numRows,
      this.numCols
    );
  }

  setValues(values) {
    this.sheet.setValues(this.row, this.column, values);
    return this;
  }
}

class FakeSheet {
  constructor() {
    this.rows = [];
  }

  getLastRow() {
    return this.rows.length;
  }

  getLastColumn() {
    return this.rows.reduce((max, row) => Math.max(max, row.length), 0);
  }

  getRange(row, column, numRows, numCols) {
    return new FakeRange(this, row, column, numRows, numCols);
  }

  appendRow(values) {
    this.rows.push([...values]);
  }

  getValues(row, column, numRows, numCols) {
    const values = [];

    for (let rowOffset = 0; rowOffset < numRows; rowOffset += 1) {
      const currentRow = [];
      for (let colOffset = 0; colOffset < numCols; colOffset += 1) {
        currentRow.push(
          this.rows[row + rowOffset - 1]?.[column + colOffset - 1] ?? ''
        );
      }
      values.push(currentRow);
    }

    return values;
  }

  setValues(row, column, values) {
    const numRows = values.length;
    const numCols = values[0]?.length ?? 0;

    while (this.rows.length < row + numRows - 1) {
      this.rows.push([]);
    }

    for (let rowOffset = 0; rowOffset < numRows; rowOffset += 1) {
      const targetRow = this.rows[row + rowOffset - 1];
      while (targetRow.length < column + numCols - 1) {
        targetRow.push('');
      }

      for (let colOffset = 0; colOffset < numCols; colOffset += 1) {
        targetRow[column + colOffset - 1] = values[rowOffset][colOffset];
      }
    }
  }
}

const sandbox = {
  console,
  JSON,
  Date,
  ContentService: {
    MimeType: {
      JSON: 'application/json',
    },
    createTextOutput(text) {
      return {
        mimeType: null,
        text,
        setMimeType(mimeType) {
          this.mimeType = mimeType;
          return this;
        },
      };
    },
  },
  SpreadsheetApp: {
    getActiveSpreadsheet() {
      throw new Error('SpreadsheetApp is not used by this check script.');
    },
  },
};

vm.createContext(sandbox);
vm.runInContext(source, sandbox, { filename: codePath });

assert.equal(typeof sandbox.flattenPayload_, 'function');
assert.equal(typeof sandbox.upsertHeaders_, 'function');
assert.equal(typeof sandbox.appendRow_, 'function');
assert.equal(typeof sandbox.jsonResponse_, 'function');

const payload = {
  submittedAtUtc: '2026-03-18T08:30:00.000Z',
  owner: {
    email: 'alice@example.com',
    name: 'Alice / Ops',
  },
  endpoint: {
    extra: {
      gpu: 'M3',
    },
    platform: 'macos',
  },
  checks: [
    {
      detectedAutomatically: true,
      detectedStatus: 'enabled',
      id: 'disk_encryption',
      reviewedStatus: 'enabled',
    },
  ],
  notes: null,
  emptyList: [],
  emptyObject: {},
  weirdKey: {
    'slash/key': 'value',
    'tilde~key': 'ok',
  },
};

const flattened = sandbox.flattenPayload_(payload);

assert.equal(flattened['/owner/name'], 'Alice / Ops');
assert.equal(flattened['/owner/email'], 'alice@example.com');
assert.equal(flattened['/endpoint/platform'], 'macos');
assert.equal(flattened['/endpoint/extra/gpu'], 'M3');
assert.equal(flattened['/checks/0/id'], 'disk_encryption');
assert.equal(flattened['/checks/0/detectedAutomatically'], true);
assert.equal(flattened['/notes'], 'null');
assert.equal(flattened['/emptyList'], '[]');
assert.equal(flattened['/emptyObject'], '{}');
assert.equal(flattened['/weirdKey/slash~1key'], 'value');
assert.equal(flattened['/weirdKey/tilde~0key'], 'ok');
assert.ok(!Object.prototype.hasOwnProperty.call(flattened, 'rawJson'));

const sheet = new FakeSheet();
const initialHeaders = Object.keys(flattened).sort();
const resolvedHeaders = sandbox.upsertHeaders_(sheet, initialHeaders);
assert.deepEqual(resolvedHeaders, initialHeaders);
sandbox.appendRow_(sheet, resolvedHeaders, flattened);

const nextFlattened = sandbox.flattenPayload_({
  endpoint: {
    architecture: 'x64',
    platform: 'windows',
  },
});
const expandedHeaders = sandbox.upsertHeaders_(
  sheet,
  Object.keys(nextFlattened).sort()
);

assert.ok(expandedHeaders.includes('/endpoint/architecture'));
sandbox.appendRow_(sheet, expandedHeaders, nextFlattened);
assert.equal(
  sheet.rows[0][expandedHeaders.indexOf('/endpoint/architecture')],
  '/endpoint/architecture'
);
assert.equal(
  sheet.rows[2][expandedHeaders.indexOf('/endpoint/architecture')],
  'x64'
);
assert.equal(
  sheet.rows[2][expandedHeaders.indexOf('/endpoint/platform')],
  'windows'
);

const response = sandbox.jsonResponse_({ ok: true });
assert.equal(response.text, JSON.stringify({ ok: true }));
assert.equal(response.mimeType, 'application/json');

console.log('Apps Script checks passed.');
