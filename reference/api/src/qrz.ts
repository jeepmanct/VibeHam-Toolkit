const QRZ_LOGBOOK_API = 'https://logbook.qrz.com/api';

function decodeEntities(s: string): string {
  return s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, '&');
}

/** Fetches all QSOs from the QRZ.com Logbook API and returns the raw ADIF payload. */
export async function fetchQrzAdif(apiKey: string): Promise<string> {
  const res = await fetch(QRZ_LOGBOOK_API, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ KEY: apiKey, ACTION: 'FETCH' }),
  });
  if (!res.ok) {
    throw new Error(`QRZ API request failed: HTTP ${res.status}`);
  }
  const text = await res.text();

  // QRZ's response isn't cleanly form-encoded: the ADIF field's value contains
  // literal `&` (as ADIF record separators) and HTML-escaped `<`/`>`. So we can
  // only trust query-string parsing for the fields *before* ADIF=, and must take
  // everything after it as one raw blob rather than re-splitting on `&`.
  const adifMarker = text.indexOf('ADIF=');
  const head = adifMarker >= 0 ? text.slice(0, adifMarker) : text;
  const headParams = new URLSearchParams(head);
  const result = headParams.get('RESULT');
  if (result !== 'OK') {
    throw new Error(decodeEntities(headParams.get('REASON') ?? `QRZ API returned an error: ${text.slice(0, 200)}`));
  }
  if (adifMarker < 0) return '';
  return decodeEntities(text.slice(adifMarker + 'ADIF='.length));
}
