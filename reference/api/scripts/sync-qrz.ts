// Run daily via the n1ah-qrz-sync systemd timer (see deploy/). Calls the
// same import pipeline as the authenticated POST /api/qsos/import/qrz
// route, just invoked directly instead of over HTTP, so a timer doesn't
// need a login session/token to trigger it.
import { parseAdif } from '../src/adif';
import { importAdifRecords } from '../src/qsoImport';
import { fetchQrzAdif } from '../src/qrz';

const apiKey = process.env.QRZ_API_KEY;
if (!apiKey) {
  console.error('QRZ_API_KEY is not configured');
  process.exit(1);
}

const adif = await fetchQrzAdif(apiKey);
const records = parseAdif(adif);
const imported = importAdifRecords(records);
console.log(`Synced ${imported} of ${records.length} QRZ record(s).`);
