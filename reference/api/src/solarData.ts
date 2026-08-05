import { db } from './db';

const GFZ_SOURCE_URL = 'https://kp.gfz-potsdam.de/app/files/Kp_ap_Ap_SN_F107_since_1932.txt';

export type SolarRecord = {
  date: string; // YYYYMMDD
  sfi: number | null;
  sfiAdjusted: number | null;
  aIndex: number | null;
  kIndex: number | null;
  kIndexMax: number | null;
  sunspotNumber: number | null;
};

const num = (s: string): number | null => {
  const n = Number(s);
  return Number.isFinite(n) && n >= 0 ? n : null;
};

/**
 * Parses GFZ Potsdam's combined Kp/ap/Ap/SN/F10.7 file. Format documented at
 * https://kp.gfz-potsdam.de/app/files/Kp_ap_Ap_SN_F107_format.txt — space-separated
 * columns, missing values as -1/-1.0/-1.000.
 */
export function parseGfzSolarData(text: string): SolarRecord[] {
  const records: SolarRecord[] = [];
  for (const line of text.split('\n')) {
    if (!line || line.startsWith('#')) continue;
    const f = line.trim().split(/\s+/);
    if (f.length < 28) continue;

    const date = `${f[0]}${f[1]}${f[2]}`;
    const kpValues = f.slice(7, 15).map(Number);
    const hasAllKp = kpValues.every((v) => v >= 0);

    records.push({
      date,
      sfi: num(f[25]),
      sfiAdjusted: num(f[26]),
      aIndex: num(f[23]),
      kIndex: hasAllKp ? kpValues.reduce((a, b) => a + b, 0) / kpValues.length : null,
      kIndexMax: hasAllKp ? Math.max(...kpValues) : null,
      sunspotNumber: num(f[24]),
    });
  }
  return records;
}

export async function fetchGfzSolarData(): Promise<string> {
  const res = await fetch(GFZ_SOURCE_URL);
  if (!res.ok) {
    throw new Error(`GFZ solar data request failed: HTTP ${res.status}`);
  }
  return res.text();
}

const upsertStmt = db.query(`
  INSERT INTO solar_data (date, sfi, sfi_adjusted, a_index, k_index, k_index_max, sunspot_number, updated_at)
  VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
  ON CONFLICT(date) DO UPDATE SET
    sfi = excluded.sfi,
    sfi_adjusted = excluded.sfi_adjusted,
    a_index = excluded.a_index,
    k_index = excluded.k_index,
    k_index_max = excluded.k_index_max,
    sunspot_number = excluded.sunspot_number,
    updated_at = excluded.updated_at
`);

export function importSolarRecords(records: SolarRecord[]): number {
  const insertMany = db.transaction((recs: SolarRecord[]) => {
    for (const r of recs) {
      upsertStmt.run(r.date, r.sfi, r.sfiAdjusted, r.aIndex, r.kIndex, r.kIndexMax, r.sunspotNumber);
    }
  });
  insertMany(records);
  return records.length;
}
