import assert from 'node:assert/strict';
import crypto from 'node:crypto';
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

class FakeSpreadsheet {
  constructor() {
    this.sheets = new Map();
  }

  getSheetByName(name) {
    return this.sheets.get(name) ?? null;
  }

  insertSheet(name) {
    const sheet = new FakeSheet();
    this.sheets.set(name, sheet);
    return sheet;
  }
}

class FakeCache {
  constructor() {
    this.entries = new Map();
  }

  get(key) {
    return this.entries.get(key) ?? null;
  }

  put(key, value) {
    this.entries.set(key, value);
  }
}

const fakeSpreadsheet = new FakeSpreadsheet();
const fakeCache = new FakeCache();

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
  PropertiesService: {
    getScriptProperties() {
      return {
        getProperty(name) {
          return name === 'SUBMISSION_SHARED_SECRET'
            ? 'test-shared-secret'
            : null;
        },
      };
    },
  },
  Utilities: {
    computeHmacSha256Signature(value, secret) {
      const digest = crypto
        .createHmac('sha256', secret)
        .update(value)
        .digest();
      return [...digest].map((byte) => (byte > 127 ? byte - 256 : byte));
    },
  },
  SpreadsheetApp: {
    getActiveSpreadsheet() {
      return fakeSpreadsheet;
    },
  },
  LockService: {
    getScriptLock() {
      return {
        waitLock() {},
        releaseLock() {},
      };
    },
  },
  CacheService: {
    getScriptCache() {
      return fakeCache;
    },
  },
};

vm.createContext(sandbox);
vm.runInContext(source, sandbox, { filename: codePath });

assert.equal(typeof sandbox.flattenPayload_, 'function');
assert.equal(typeof sandbox.buildSummaryRow_, 'function');
assert.equal(typeof sandbox.verifyEnvelope_, 'function');
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
      effectiveStatus: 'enabled',
      id: 'disk_encryption',
      label: 'Hard disk encryption',
      reviewedStatus: 'enabled',
      summary: 'FileVault is enabled.',
    },
    {
      detectedAutomatically: true,
      detectedStatus: 'disabled',
      effectiveStatus: 'disabled',
      id: 'firewall',
      label: 'Firewall',
      reviewedStatus: 'disabled',
      summary: 'The macOS application firewall is disabled.',
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

function signEnvelope(signedAtUtc, canonicalPayload) {
  return crypto
    .createHmac('sha256', 'test-shared-secret')
    .update(`${signedAtUtc}\n${canonicalPayload}`)
    .digest('hex');
}

const signedAtUtc = new Date().toISOString();
const payloadJson = JSON.stringify(payload);
const envelope = {
  schemaVersion: 3,
  auth: {
    algorithm: 'HMAC-SHA256',
    signedAtUtc,
    signature: signEnvelope(signedAtUtc, payloadJson),
  },
  payloadJson,
};

assert.deepEqual(sandbox.verifyEnvelope_(envelope).payload, payload);
assert.equal(
  sandbox.verifyEnvelope_(envelope).signature,
  envelope.auth.signature
);

// Schema version 3 signs the exact payload string, so verification survives
// formatting the server would not reproduce (extra whitespace here).
const oddlyFormattedPayloadJson = `{ "notes":  "spaced out" }`;
const oddlyFormattedEnvelope = {
  schemaVersion: 3,
  auth: {
    algorithm: 'HMAC-SHA256',
    signedAtUtc,
    signature: signEnvelope(signedAtUtc, oddlyFormattedPayloadJson),
  },
  payloadJson: oddlyFormattedPayloadJson,
};
assert.deepEqual(sandbox.verifyEnvelope_(oddlyFormattedEnvelope).payload, {
  notes: 'spaced out',
});

// Schema version 2 envelopes from apps in the field keep verifying.
const legacyEnvelope = {
  schemaVersion: 2,
  auth: {
    algorithm: 'HMAC-SHA256',
    signedAtUtc,
    signature: signEnvelope(signedAtUtc, payloadJson),
  },
  payload,
};
assert.deepEqual(sandbox.verifyEnvelope_(legacyEnvelope).payload, payload);

assert.throws(
  () =>
    sandbox.verifyEnvelope_({
      ...envelope,
      auth: {
        ...envelope.auth,
        signature: 'bad-signature',
      },
    }),
  /Invalid envelope signature/
);
assert.throws(
  () =>
    sandbox.verifyEnvelope_({
      ...envelope,
      auth: {
        algorithm: 'HMAC-SHA256',
        signedAtUtc: '2020-01-01T00:00:00.000Z',
        signature: signEnvelope('2020-01-01T00:00:00.000Z', payloadJson),
      },
    }),
  /outside the allowed window/
);

const flattened = sandbox.flattenPayload_(
  sandbox.verifyEnvelope_(envelope).payload
);

assert.equal(flattened['/owner/name'], 'Alice / Ops');
assert.equal(flattened['/owner/email'], 'alice@example.com');
assert.equal(flattened['/endpoint/platform'], 'macos');
assert.equal(flattened['/endpoint/extra/gpu'], 'M3');
assert.equal(flattened['/checks/0/id'], 'disk_encryption');
assert.equal(flattened['/checks/0/detectedAutomatically'], true);
assert.equal(flattened['/checks/1/id'], 'firewall');
assert.equal(flattened['/checks/1/effectiveStatus'], 'disabled');
assert.equal(flattened['/notes'], 'null');
assert.equal(flattened['/emptyList'], '[]');
assert.equal(flattened['/emptyObject'], '{}');
assert.equal(flattened['/weirdKey/slash~1key'], 'value');
assert.equal(flattened['/weirdKey/tilde~0key'], 'ok');
assert.ok(!Object.prototype.hasOwnProperty.call(flattened, 'rawJson'));

const summaryRow = sandbox.buildSummaryRow_(payload);
assert.equal(summaryRow['Submitted at (UTC)'], '2026-03-18T08:30:00.000Z');
assert.equal(summaryRow['Owner name'], 'Alice / Ops');
assert.equal(summaryRow['Owner email'], 'alice@example.com');
assert.equal(summaryRow.Platform, 'macos');
assert.equal(summaryRow['Overall status'], 'Needs attention');
assert.equal(summaryRow['Secure checks'], 1);
assert.equal(summaryRow['Needs attention'], 1);
assert.equal(summaryRow['Needs review'], 0);
assert.match(summaryRow.Findings, /Firewall: Disabled/);
assert.equal(
  summaryRow['Check: Hard disk encryption'],
  'Hard disk encryption: Enabled | FileVault is enabled.'
);
assert.equal(
  summaryRow['Check: Firewall'],
  'Firewall: Disabled | The macOS application firewall is disabled.'
);

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

const doPostResponse = sandbox.doPost({
  postData: {
    contents: JSON.stringify(envelope),
  },
});
assert.equal(doPostResponse.mimeType, 'application/json');
assert.equal(JSON.parse(doPostResponse.text).ok, true);

// Replaying the exact same envelope must be rejected.
const replayResponse = sandbox.doPost({
  postData: {
    contents: JSON.stringify(envelope),
  },
});
assert.equal(JSON.parse(replayResponse.text).ok, false);
assert.match(JSON.parse(replayResponse.text).error, /already received/);

const overviewSheet = fakeSpreadsheet.getSheetByName('Endpoint Check-Ins');
const rawSheet = fakeSpreadsheet.getSheetByName('Endpoint Check-Ins Raw');
assert.ok(overviewSheet);
assert.ok(rawSheet);
assert.equal(overviewSheet.rows.length, 2);
assert.equal(rawSheet.rows.length, 2);
assert.equal(
  overviewSheet.rows[1][overviewSheet.rows[0].indexOf('Overall status')],
  'Needs attention'
);
assert.equal(
  rawSheet.rows[1][rawSheet.rows[0].indexOf('/owner/email')],
  'alice@example.com'
);

const response = sandbox.jsonResponse_({ ok: true });
assert.equal(response.text, JSON.stringify({ ok: true }));
assert.equal(response.mimeType, 'application/json');

console.log('Apps Script checks passed.');
