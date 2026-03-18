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
- It flattens the request body into one column per JSON leaf.
- Column names use JSON pointer-style paths such as `/owner/name` and `/checks/0/reviewedStatus`.
- New keys automatically extend the header row, so schema changes do not require script edits.
- Keys containing `/` or `~` are escaped using JSON pointer rules.
- Empty arrays and empty objects are stored as `[]` and `{}` in their own columns so the sheet still captures those values.
- Use HTTPS only and keep the URL internal if this data is sensitive.
