# Google Sheets Backend

This Apps Script receives the app's JSON payload and appends one row per submission into a Google Sheet.

## Setup

1. Create a new Google Sheet.
2. Open `Extensions` -> `Apps Script`.
3. Replace the default script with [`Code.gs`](./Code.gs).
4. Deploy it as a web app:
   - Execute as: `Me`
   - Who has access: `Anyone with the link` or your preferred internal audience
5. Copy the deployment URL and use it as the Flutter app's `SUBMISSION_ENDPOINT`.

## Notes

- The script creates an `Endpoint Check-Ins` tab automatically.
- It stores a flattened set of columns for quick spreadsheet filtering, plus the full raw JSON in `rawJson`.
- Use HTTPS only and keep the URL internal if this data is sensitive.

