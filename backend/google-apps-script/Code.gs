function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      throw new Error('Missing request body.');
    }

    const envelope = JSON.parse(e.postData.contents);
    const verified = verifyEnvelope_(envelope);

    const payload = verified.payload;
    const lock = LockService.getScriptLock();
    lock.waitLock(30 * 1000);
    try {
      // Replay rejection runs under the lock so concurrent duplicates cannot
      // both pass the cache check before either one records its signature.
      rejectReplays_(verified.signature);

      const summarySheet = getTargetSheet_();
      const summaryRow = buildSummaryRow_(payload);
      const summaryHeaders = upsertHeaders_(
        summarySheet,
        Object.keys(summaryRow)
      );
      appendRow_(summarySheet, summaryHeaders, summaryRow);

      const rawSheet = getRawSheet_();
      const rawRow = flattenPayload_(payload);
      const rawHeaders = upsertHeaders_(rawSheet, Object.keys(rawRow).sort());

      appendRow_(rawSheet, rawHeaders, rawRow);
    } finally {
      lock.releaseLock();
    }

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

  if (envelope.schemaVersion !== 2 && envelope.schemaVersion !== 3) {
    throw new Error('Unsupported envelope schema version.');
  }

  const auth = envelope.auth;
  if (!auth || typeof auth !== 'object' || Array.isArray(auth)) {
    throw new Error('Missing envelope auth block.');
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

  // Schema version 3 signs the exact payload JSON string that travels in the
  // envelope, so verification does not depend on re-serializing the payload.
  // Schema version 2 is kept for apps in the field that still sign a
  // re-serialized payload object.
  let canonicalPayload;
  let payload;
  if (envelope.schemaVersion === 3) {
    if (typeof envelope.payloadJson !== 'string' || !envelope.payloadJson) {
      throw new Error('Missing envelope payload.');
    }
    canonicalPayload = envelope.payloadJson;
  } else {
    payload = envelope.payload;
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new Error('Missing envelope payload.');
    }
    canonicalPayload = JSON.stringify(payload);
  }

  const secret = getSubmissionSecret_();
  const expectedSignature = hmacHex_(secret, `${signedAtUtc}\n${canonicalPayload}`);
  if (!constantTimeEquals_(signature, expectedSignature)) {
    throw new Error('Invalid envelope signature.');
  }

  if (envelope.schemaVersion === 3) {
    payload = JSON.parse(canonicalPayload);
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new Error('Invalid envelope payload.');
    }
  }

  return { payload, signature };
}

function rejectReplays_(signature) {
  // Signatures are unique per submission because each envelope is signed at
  // submit time, so a repeated signature inside the timestamp window means a
  // replayed request.
  const cache = CacheService.getScriptCache();
  const cacheKey = `sig:${signature}`;
  if (cache.get(cacheKey)) {
    throw new Error('Duplicate envelope: this submission was already received.');
  }
  const replayWindowSeconds = 30 * 60;
  cache.put(cacheKey, '1', replayWindowSeconds);
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
  return getSheet_('Endpoint Check-Ins');
}

function getRawSheet_() {
  return getSheet_('Endpoint Check-Ins Raw');
}

function getSheet_(sheetName) {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = spreadsheet.getSheetByName(sheetName);

  if (!sheet) {
    sheet = spreadsheet.insertSheet(sheetName);
  }

  return sheet;
}

function buildSummaryRow_(payload) {
  const checks = Array.isArray(payload.checks) ? payload.checks : [];
  const checkSummary = summarizeChecks_(checks);
  const row = {
    'Submitted at (UTC)': valueOrBlank_(payload.submittedAtUtc),
    Organization: valueOrBlank_(payload.organization),
    'Owner name': valueOrBlank_(payload.owner && payload.owner.name),
    'Owner email': valueOrBlank_(payload.owner && payload.owner.email),
    'Endpoint name': valueOrBlank_(
      payload.endpoint && payload.endpoint.submittedName
    ),
    'Detected endpoint name': valueOrBlank_(
      payload.endpoint && payload.endpoint.detectedName
    ),
    Platform: valueOrBlank_(payload.endpoint && payload.endpoint.platform),
    'OS version': valueOrBlank_(payload.endpoint && payload.endpoint.osVersion),
    'Device model': valueOrBlank_(
      payload.endpoint && payload.endpoint.deviceModel
    ),
    'Device identifier': valueOrBlank_(
      payload.endpoint && payload.endpoint.deviceIdentifier
    ),
    'Overall status': checkSummary.overallStatus,
    'Secure checks': checkSummary.secureCount,
    'Needs attention': checkSummary.attentionCount,
    'Needs review': checkSummary.reviewCount,
    'Not applicable': checkSummary.notApplicableCount,
    Findings: checkSummary.findings,
    Notes: valueOrBlank_(payload.notes),
  };

  checks.forEach((check) => {
    const label = valueOrBlank_(check.label || check.id || 'Unnamed check');
    row[`Check: ${label}`] = describeCheck_(check);
  });

  return row;
}

function summarizeChecks_(checks) {
  let secureCount = 0;
  let attentionCount = 0;
  let reviewCount = 0;
  let notApplicableCount = 0;
  const findings = [];

  checks.forEach((check) => {
    const status = getEffectiveStatus_(check);
    if (status === 'enabled') {
      secureCount += 1;
      return;
    }
    if (status === 'not_applicable') {
      notApplicableCount += 1;
      return;
    }
    if (status === 'manual_review' || status === 'unknown') {
      reviewCount += 1;
    } else {
      attentionCount += 1;
    }
    findings.push(describeCheck_(check));
  });

  return {
    secureCount,
    attentionCount,
    reviewCount,
    notApplicableCount,
    overallStatus:
      attentionCount > 0
        ? 'Needs attention'
        : reviewCount > 0
          ? 'Needs review'
          : 'Compliant',
    findings: findings.join('\n'),
  };
}

function describeCheck_(check) {
  const label = valueOrBlank_(check.label || check.id || 'Unnamed check');
  const status = statusLabel_(getEffectiveStatus_(check));
  const summary = valueOrBlank_(check.summary);
  const details = valueOrBlank_(check.details);
  const parts = [`${label}: ${status}`];

  if (summary) {
    parts.push(summary);
  }
  if (details) {
    parts.push(details);
  }

  return parts.join(' | ');
}

function getEffectiveStatus_(check) {
  return String(
    check.effectiveStatus ||
      check.reviewedStatus ||
      check.detectedStatus ||
      'unknown'
  );
}

function statusLabel_(status) {
  switch (status) {
    case 'enabled':
      return 'Enabled';
    case 'disabled':
      return 'Disabled';
    case 'not_applicable':
      return 'Not applicable';
    case 'manual_review':
      return 'Manual review';
    default:
      return 'Unknown';
  }
}

function valueOrBlank_(value) {
  if (value === null || typeof value === 'undefined') {
    return '';
  }
  return value;
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
