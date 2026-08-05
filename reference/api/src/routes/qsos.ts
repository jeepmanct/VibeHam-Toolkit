import { Hono } from 'hono';
import { db } from '../db';
import { requireAuth } from '../auth';
import { parseAdif } from '../adif';
import { importAdifRecords } from '../qsoImport';
import { fetchQrzAdif } from '../qrz';

export const qsoRoutes = new Hono();

const DEFAULT_PAGE_SIZE = 50;
const MAX_PAGE_SIZE = 200;

qsoRoutes.get('/', (c) => {
  const limit = Math.min(Math.max(Number(c.req.query('limit')) || DEFAULT_PAGE_SIZE, 1), MAX_PAGE_SIZE);
  const offset = Math.max(Number(c.req.query('offset')) || 0, 0);
  const from = c.req.query('from')?.replaceAll('-', '');
  const to = c.req.query('to')?.replaceAll('-', '');

  const clauses: string[] = [];
  const params: (string | number)[] = [];
  inClause('band', c.req.query('bands'), clauses, params);
  inClause('mode', c.req.query('modes'), clauses, params);
  inClause('country', c.req.query('countries'), clauses, params);
  inClause('state', c.req.query('states'), clauses, params);
  if (from) {
    clauses.push('qso_date >= ?');
    params.push(from);
  }
  if (to) {
    clauses.push('qso_date <= ?');
    params.push(to);
  }
  const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';

  const rows = db
    .query(
      `SELECT q.call, q.qso_date, q.time_on, q.band, q.mode, q.freq, q.gridsquare, q.country, q.rst_sent, q.lotw_qsl_rcvd,
              s.sfi, s.a_index, s.k_index
       FROM qsos q
       LEFT JOIN solar_data s ON s.date = q.qso_date
       ${where}
       ORDER BY q.qso_date DESC, q.time_on DESC
       LIMIT ? OFFSET ?`,
    )
    .all(...params, limit, offset) as {
    call: string;
    qso_date: string;
    time_on: string | null;
    band: string | null;
    mode: string | null;
    freq: string | null;
    gridsquare: string | null;
    country: string | null;
    rst_sent: string | null;
    lotw_qsl_rcvd: string | null;
    sfi: number | null;
    a_index: number | null;
    k_index: number | null;
  }[];

  const { total } = db.query(`SELECT COUNT(*) as total FROM qsos q ${where}`).get(...params) as { total: number };

  return c.json({
    qsos: rows.map((r) => ({
      call: r.call,
      qsoDate: r.qso_date,
      timeOn: r.time_on,
      band: r.band,
      mode: r.mode,
      freq: r.freq,
      gridsquare: r.gridsquare,
      country: r.country,
      rstSent: r.rst_sent,
      lotwQslRcvd: r.lotw_qsl_rcvd,
      sfi: r.sfi,
      aIndex: r.a_index,
      kIndex: r.k_index,
    })),
    total,
    offset,
    limit,
  });
});

qsoRoutes.get('/on-this-day', (c) => {
  const now = new Date();
  const monthDay = `${String(now.getUTCMonth() + 1).padStart(2, '0')}${String(now.getUTCDate()).padStart(2, '0')}`;
  const rows = db
    .query(
      `SELECT call, qso_date, band, mode, country, gridsquare
       FROM qsos WHERE substr(qso_date, 5, 4) = ? ORDER BY qso_date DESC LIMIT 50`,
    )
    .all(monthDay) as { call: string; qso_date: string; band: string | null; mode: string | null; country: string | null; gridsquare: string | null }[];
  c.header('Cache-Control', 'no-store');
  return c.json(
    rows.map((r) => ({
      call: r.call,
      qsoDate: r.qso_date,
      band: r.band,
      mode: r.mode,
      country: r.country,
      gridsquare: r.gridsquare,
    })),
  );
});

qsoRoutes.get('/lookup', (c) => {
  const call = c.req.query('call')?.trim();
  if (!call) return c.json([]);
  const rows = db
    .query(
      `SELECT call, qso_date, band, mode, gridsquare, country, lotw_qsl_rcvd
       FROM qsos WHERE call LIKE ? ESCAPE '\\' ORDER BY qso_date DESC LIMIT 50`,
    )
    .all(`%${call.toUpperCase().replaceAll('%', '\\%').replaceAll('_', '\\_')}%`) as {
    call: string;
    qso_date: string;
    band: string | null;
    mode: string | null;
    gridsquare: string | null;
    country: string | null;
    lotw_qsl_rcvd: string | null;
  }[];
  return c.json(
    rows.map((r) => ({
      call: r.call,
      qsoDate: r.qso_date,
      band: r.band,
      mode: r.mode,
      gridsquare: r.gridsquare,
      country: r.country,
      lotwQslRcvd: r.lotw_qsl_rcvd,
    })),
  );
});

qsoRoutes.get('/bands', (c) => {
  const rows = db
    .query('SELECT band, COUNT(*) as count FROM qsos WHERE band IS NOT NULL GROUP BY band ORDER BY count DESC')
    .all() as { band: string; count: number }[];
  return c.json(rows);
});

qsoRoutes.get('/modes', (c) => {
  const rows = db
    .query('SELECT mode, COUNT(*) as count FROM qsos WHERE mode IS NOT NULL GROUP BY mode ORDER BY count DESC')
    .all() as { mode: string; count: number }[];
  return c.json(rows);
});

qsoRoutes.get('/countries', (c) => {
  const rows = db
    .query('SELECT country, COUNT(*) as count FROM qsos WHERE country IS NOT NULL GROUP BY country ORDER BY country ASC')
    .all() as { country: string; count: number }[];
  return c.json(rows);
});

qsoRoutes.get('/states', (c) => {
  const rows = db
    .query('SELECT state, COUNT(*) as count FROM qsos WHERE state IS NOT NULL GROUP BY state ORDER BY state ASC')
    .all() as { state: string; count: number }[];
  return c.json(rows);
});

// A filter param that's present but empty (e.g. "bands=") means the user explicitly
// deselected every option in that category — that should match nothing, not
// everything. Only a genuinely absent param means "no filter, show all."
function inClause(column: string, raw: string | undefined, clauses: string[], params: (string | number)[]) {
  if (raw === undefined) return;
  const values = raw.split(',').filter(Boolean);
  if (values.length === 0) {
    clauses.push('0');
    return;
  }
  clauses.push(`${column} IN (${values.map(() => '?').join(',')})`);
  params.push(...values);
}

const FACET_DIMENSIONS = [
  { key: 'bands', column: 'band', param: 'bands', order: 'count DESC' },
  { key: 'modes', column: 'mode', param: 'modes', order: 'count DESC' },
  { key: 'countries', column: 'country', param: 'countries', order: 'value ASC' },
  { key: 'states', column: 'state', param: 'states', order: 'value ASC' },
] as const;

// Per-category counts reflecting the OTHER active filters, so a chip shows "how many
// results if I also enable this" rather than a fixed global total — the standard
// faceted-search pattern. Each dimension's own selection never restricts its own
// counts (that's what lets you see every option's count within the current filter
// context, including options you haven't picked yet).
qsoRoutes.get('/facets', (c) => {
  const from = c.req.query('from')?.replaceAll('-', '');
  const to = c.req.query('to')?.replaceAll('-', '');

  const result: Record<string, { value: string; count: number }[]> = {};

  for (const dim of FACET_DIMENSIONS) {
    const clauses = [`${dim.column} IS NOT NULL`];
    const params: (string | number)[] = [];
    for (const other of FACET_DIMENSIONS) {
      if (other.key === dim.key) continue;
      inClause(other.column, c.req.query(other.param), clauses, params);
    }
    if (from) {
      clauses.push('qso_date >= ?');
      params.push(from);
    }
    if (to) {
      clauses.push('qso_date <= ?');
      params.push(to);
    }

    result[dim.key] = db
      .query(
        `SELECT ${dim.column} as value, COUNT(*) as count FROM qsos
         WHERE ${clauses.join(' AND ')} GROUP BY ${dim.column} ORDER BY ${dim.order}`,
      )
      .all(...params) as { value: string; count: number }[];
  }

  return c.json(result);
});

qsoRoutes.get('/geo', (c) => {
  const from = c.req.query('from')?.replaceAll('-', '');
  const to = c.req.query('to')?.replaceAll('-', '');

  const clauses = ['lat IS NOT NULL', 'lon IS NOT NULL'];
  const params: (string | number)[] = [];

  inClause('band', c.req.query('bands'), clauses, params);
  inClause('mode', c.req.query('modes'), clauses, params);
  inClause('country', c.req.query('countries'), clauses, params);
  inClause('state', c.req.query('states'), clauses, params);
  if (from) {
    clauses.push('qso_date >= ?');
    params.push(from);
  }
  if (to) {
    clauses.push('qso_date <= ?');
    params.push(to);
  }

  const rows = db
    .query(
      `SELECT q.call, q.qso_date, q.band, q.mode, q.gridsquare, q.country, q.state, q.lat, q.lon,
              s.sfi, s.a_index, s.k_index
       FROM qsos q
       LEFT JOIN solar_data s ON s.date = q.qso_date
       WHERE ${clauses.join(' AND ')}
       ORDER BY q.qso_date DESC`,
    )
    .all(...params) as {
    call: string;
    qso_date: string;
    band: string | null;
    mode: string | null;
    gridsquare: string | null;
    country: string | null;
    state: string | null;
    lat: number;
    lon: number;
    sfi: number | null;
    a_index: number | null;
    k_index: number | null;
  }[];

  const home = db
    .query(
      `SELECT my_lat as lat, my_lon as lon, COUNT(*) as count
       FROM qsos WHERE my_lat IS NOT NULL AND my_lon IS NOT NULL
       GROUP BY my_lat, my_lon ORDER BY count DESC LIMIT 1`,
    )
    .get() as { lat: number; lon: number } | null;

  return c.json({
    home,
    points: rows.map((r) => ({
      call: r.call,
      qsoDate: r.qso_date,
      band: r.band,
      mode: r.mode,
      gridsquare: r.gridsquare,
      country: r.country,
      state: r.state,
      lat: r.lat,
      lon: r.lon,
      sfi: r.sfi,
      aIndex: r.a_index,
      kIndex: r.k_index,
    })),
  });
});

function csvField(value: string | null): string {
  if (value == null) return '';
  return /[",\n]/.test(value) ? `"${value.replaceAll('"', '""')}"` : value;
}

qsoRoutes.get('/export.csv', requireAuth, (c) => {
  const rows = db
    .query(
      `SELECT call, qso_date, time_on, band, mode, freq, gridsquare, country, state, continent, lotw_qsl_rcvd
       FROM qsos ORDER BY qso_date ASC, time_on ASC`,
    )
    .all() as {
    call: string;
    qso_date: string;
    time_on: string | null;
    band: string | null;
    mode: string | null;
    freq: string | null;
    gridsquare: string | null;
    country: string | null;
    state: string | null;
    continent: string | null;
    lotw_qsl_rcvd: string | null;
  }[];

  const header = 'call,qso_date,time_on,band,mode,freq,gridsquare,country,state,continent,lotw_qsl_rcvd';
  const lines = rows.map((r) =>
    [r.call, r.qso_date, r.time_on, r.band, r.mode, r.freq, r.gridsquare, r.country, r.state, r.continent, r.lotw_qsl_rcvd]
      .map(csvField)
      .join(','),
  );
  const csv = [header, ...lines].join('\n');

  c.header('Content-Type', 'text/csv; charset=utf-8');
  c.header('Content-Disposition', 'attachment; filename="n1ah-qsos.csv"');
  return c.body(csv);
});

qsoRoutes.get('/export.adi', requireAuth, (c) => {
  const rows = db.query('SELECT raw_adif FROM qsos ORDER BY qso_date ASC, time_on ASC').all() as { raw_adif: string }[];

  const header = [
    '! ADIF export from {CALLSIGN} — https://n1ah.asuscomm.com',
    `<ADIF_VER:5>3.1.4`,
    `<PROGRAMID:4>{CALLSIGN}`,
    `<EOH>`,
    '',
  ].join('\n');

  const records = rows.map((row) => {
    const fields = JSON.parse(row.raw_adif) as Record<string, string>;
    const parts = Object.entries(fields)
      .filter(([, v]) => v != null && v !== '')
      .map(([k, v]) => `<${k}:${v.length}>${v}`);
    return parts.join(' ') + ' <EOR>';
  });

  c.header('Content-Type', 'text/plain; charset=utf-8');
  c.header('Content-Disposition', 'attachment; filename="n1ah-qsos.adi"');
  return c.body(header + records.join('\n'));
});

qsoRoutes.post('/import', requireAuth, async (c) => {
  const form = await c.req.formData();
  const file = form.get('adif');
  if (!(file instanceof File)) {
    return c.json({ error: 'adif file is required' }, 400);
  }
  const content = await file.text();
  const records = parseAdif(content);
  const imported = importAdifRecords(records);
  return c.json({ imported, total: records.length });
});

// Worked calls whose station has Club Log OQRS enabled (see
// scripts/sync-clublog-oqrs.ts) — a checklist of who might still be worth
// checking for a missed QSL request. Simple exact-call match (no portable-
// suffix stripping like the WPX prefix logic) — good enough for "here's a
// list to check," not trying to be a certified complete match.
qsoRoutes.get('/oqrs-matches', (c) => {
  const rows = db
    .query(
      `SELECT q.call, COUNT(*) as qsoCount, MAX(q.qso_date) as lastWorked,
              MAX(CASE WHEN q.lotw_qsl_rcvd = 'Y' THEN 1 ELSE 0 END) as confirmed
       FROM qsos q
       JOIN clublog_oqrs o ON o.call = UPPER(q.call)
       GROUP BY q.call
       ORDER BY q.call ASC`,
    )
    .all() as { call: string; qsoCount: number; lastWorked: string; confirmed: number }[];

  const synced = db.query('SELECT MAX(synced_at) as syncedAt FROM clublog_oqrs').get() as { syncedAt: string | null };

  c.header('Cache-Control', 'no-store');
  return c.json({
    syncedAt: synced.syncedAt,
    matches: rows.map((r) => ({ call: r.call, qsoCount: r.qsoCount, lastWorked: r.lastWorked, confirmed: r.confirmed === 1 })),
  });
});

qsoRoutes.post('/import/qrz', requireAuth, async (c) => {
  const apiKey = process.env.QRZ_API_KEY;
  if (!apiKey) {
    return c.json({ error: 'QRZ_API_KEY is not configured on the server' }, 500);
  }
  try {
    const adif = await fetchQrzAdif(apiKey);
    const records = parseAdif(adif);
    const imported = importAdifRecords(records);
    return c.json({ imported, total: records.length });
  } catch (err) {
    return c.json({ error: err instanceof Error ? err.message : 'QRZ import failed' }, 502);
  }
});
