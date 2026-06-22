function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      throw new Error('Missing request body.');
    }

    const envelope = JSON.parse(e.postData.contents);
    const payload = verifyEnvelope_(envelope);
    const sheet = getTargetSheet_();
    const row = flattenPayload_(payload);
    const headers = upsertHeaders_(sheet, Object.keys(row).sort());

    appendRow_(sheet, headers, row);

    return jsonResponse_({
      ok: true,
      receivedAtUtc: new Date().toISOString(),
    });
  } catch (error) {
    return jsonResponse_({
      ok: false,
      error: String(error),
    });
  }
}

function verifyEnvelope_(envelope) {
  if (!envelope || typeof envelope !== 'object' || Array.isArray(envelope)) {
    throw new Error('Invalid signed envelope.');
  }

  if (envelope.schemaVersion !== 2) {
    throw new Error('Unsupported envelope schema version.');
  }

  const auth = envelope.auth;
  const payload = envelope.payload;
  if (!auth || typeof auth !== 'object' || Array.isArray(auth)) {
    throw new Error('Missing envelope auth block.');
  }
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new Error('Missing envelope payload.');
  }

  const signedAtUtc = String(auth.signedAtUtc || '');
  const signature = String(auth.signature || '');
  if (auth.algorithm !== 'HMAC-SHA256' || !signedAtUtc || !signature) {
    throw new Error('Invalid envelope auth fields.');
  }

  const signedAt = new Date(signedAtUtc);
  if (Number.isNaN(signedAt.getTime())) {
    throw new Error('Invalid envelope timestamp.');
  }

  const maxSkewMilliseconds = 15 * 60 * 1000;
  if (Math.abs(Date.now() - signedAt.getTime()) > maxSkewMilliseconds) {
    throw new Error('Envelope timestamp is outside the allowed window.');
  }

  const secret = getSubmissionSecret_();
  const canonicalPayload = JSON.stringify(payload);
  const expectedSignature = hmacHex_(secret, `${signedAtUtc}\n${canonicalPayload}`);
  if (!constantTimeEquals_(signature, expectedSignature)) {
    throw new Error('Invalid envelope signature.');
  }

  return payload;
}

function getSubmissionSecret_() {
  const secret = PropertiesService.getScriptProperties().getProperty(
    'SUBMISSION_SHARED_SECRET'
  );
  if (!secret) {
    throw new Error('SUBMISSION_SHARED_SECRET script property is not configured.');
  }
  return secret;
}

function hmacHex_(secret, value) {
  const bytes = Utilities.computeHmacSha256Signature(value, secret);
  return bytes
    .map((byte) => {
      const normalized = byte < 0 ? byte + 256 : byte;
      return normalized.toString(16).padStart(2, '0');
    })
    .join('');
}

function constantTimeEquals_(left, right) {
  const leftText = String(left);
  const rightText = String(right);
  let diff = leftText.length ^ rightText.length;
  const maxLength = Math.max(leftText.length, rightText.length);

  for (let index = 0; index < maxLength; index += 1) {
    const leftCode = index < leftText.length ? leftText.charCodeAt(index) : 0;
    const rightCode = index < rightText.length ? rightText.charCodeAt(index) : 0;
    diff |= leftCode ^ rightCode;
  }

  return diff === 0;
}

function getTargetSheet_() {
  const sheetName = 'Endpoint Check-Ins';
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = spreadsheet.getSheetByName(sheetName);

  if (!sheet) {
    sheet = spreadsheet.insertSheet(sheetName);
  }

  return sheet;
}

function flattenPayload_(payload) {
  const flattened = {};
  flattenValue_('', payload, flattened);
  return flattened;
}

function flattenValue_(path, value, flattened) {
  const columnName = path || '$';

  if (value === null) {
    flattened[columnName] = 'null';
    return;
  }

  if (
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    flattened[columnName] = value;
    return;
  }

  if (Array.isArray(value)) {
    if (value.length === 0) {
      flattened[columnName] = '[]';
      return;
    }

    value.forEach((item, index) => {
      flattenValue_(joinPath_(path, String(index)), item, flattened);
    });
    return;
  }

  if (typeof value === 'object') {
    const keys = Object.keys(value);

    if (keys.length === 0) {
      flattened[columnName] = '{}';
      return;
    }

    keys.sort().forEach((key) => {
      flattenValue_(
        joinPath_(path, escapePathSegment_(key)),
        value[key],
        flattened
      );
    });
    return;
  }

  flattened[columnName] = String(value);
}

function joinPath_(path, segment) {
  return path ? `${path}/${segment}` : `/${segment}`;
}

function escapePathSegment_(segment) {
  return String(segment).replace(/~/g, '~0').replace(/\//g, '~1');
}

function upsertHeaders_(sheet, incomingHeaders) {
  const existingHeaders = getHeaders_(sheet);

  if (existingHeaders.length === 0) {
    sheet.getRange(1, 1, 1, incomingHeaders.length).setValues([incomingHeaders]);
    return incomingHeaders;
  }

  const existingHeaderSet = {};
  existingHeaders.forEach((header) => {
    existingHeaderSet[header] = true;
  });

  const missingHeaders = incomingHeaders.filter(
    (header) => !existingHeaderSet[header]
  );

  if (missingHeaders.length === 0) {
    return existingHeaders;
  }

  sheet
    .getRange(1, existingHeaders.length + 1, 1, missingHeaders.length)
    .setValues([missingHeaders]);

  return existingHeaders.concat(missingHeaders);
}

function getHeaders_(sheet) {
  if (sheet.getLastRow() === 0 || sheet.getLastColumn() === 0) {
    return [];
  }

  return sheet
    .getRange(1, 1, 1, sheet.getLastColumn())
    .getValues()[0]
    .map((header) => String(header));
}

function appendRow_(sheet, headers, row) {
  const values = headers.map((header) =>
    Object.prototype.hasOwnProperty.call(row, header) ? row[header] : ''
  );
  sheet.appendRow(values);
}

function jsonResponse_(payload) {
  const output = ContentService.createTextOutput(JSON.stringify(payload));
  output.setMimeType(ContentService.MimeType.JSON);
  return output;
}
