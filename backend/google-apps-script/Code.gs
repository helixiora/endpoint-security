function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      throw new Error('Missing request body.');
    }

    const payload = JSON.parse(e.postData.contents);
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
