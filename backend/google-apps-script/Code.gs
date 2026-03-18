function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);
    const sheet = getTargetSheet_();
    const row = flattenPayload_(payload);

    ensureHeaderRow_(sheet, Object.keys(row));
    appendRow_(sheet, row);

    return jsonResponse_({
      ok: true,
      receivedAtUtc: new Date().toISOString(),
    });
  } catch (error) {
    return jsonResponse_(
      {
        ok: false,
        error: String(error),
      },
      500
    );
  }
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
  const checksById = {};
  (payload.checks || []).forEach((check) => {
    checksById[check.id] = check;
  });

  return {
    submittedAtUtc: payload.submittedAtUtc || '',
    organization: payload.organization || '',
    ownerName: payload.owner?.name || '',
    ownerEmail: payload.owner?.email || '',
    endpointName: payload.endpoint?.submittedName || '',
    detectedEndpointName: payload.endpoint?.detectedName || '',
    platform: payload.endpoint?.platform || '',
    osVersion: payload.endpoint?.osVersion || '',
    deviceModel: payload.endpoint?.deviceModel || '',
    notes: payload.notes || '',
    diskEncryptionDetected: checksById.disk_encryption?.detectedStatus || '',
    diskEncryptionReviewed: checksById.disk_encryption?.reviewedStatus || '',
    diskEncryptionAutomatic:
      checksById.disk_encryption?.detectedAutomatically || false,
    screenLockDetected: checksById.screen_lock?.detectedStatus || '',
    screenLockReviewed: checksById.screen_lock?.reviewedStatus || '',
    screenLockAutomatic:
      checksById.screen_lock?.detectedAutomatically || false,
    firewallDetected: checksById.firewall?.detectedStatus || '',
    firewallReviewed: checksById.firewall?.reviewedStatus || '',
    firewallAutomatic: checksById.firewall?.detectedAutomatically || false,
    onePasswordDetected: checksById.one_password?.detectedStatus || '',
    onePasswordReviewed: checksById.one_password?.reviewedStatus || '',
    onePasswordAutomatic:
      checksById.one_password?.detectedAutomatically || false,
    rawJson: JSON.stringify(payload),
  };
}

function ensureHeaderRow_(sheet, headers) {
  if (sheet.getLastRow() > 0) {
    return;
  }

  sheet.appendRow(headers);
}

function appendRow_(sheet, row) {
  const headers = sheet
    .getRange(1, 1, 1, sheet.getLastColumn())
    .getValues()[0]
    .map(String);
  const values = headers.map((header) => row[header] ?? '');
  sheet.appendRow(values);
}

function jsonResponse_(payload, statusCode) {
  const output = ContentService.createTextOutput(JSON.stringify(payload));
  output.setMimeType(ContentService.MimeType.JSON);
  return output;
}

