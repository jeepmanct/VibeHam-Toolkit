import { Database } from 'bun:sqlite';
import { mkdirSync } from 'node:fs';
import path from 'node:path';

const DATA_DIR = process.env.DATA_DIR ?? path.join(import.meta.dir, '..', 'data');
mkdirSync(DATA_DIR, { recursive: true });
mkdirSync(path.join(DATA_DIR, 'photos'), { recursive: true });

export const PHOTOS_DIR = path.join(DATA_DIR, 'photos');

export const db = new Database(path.join(DATA_DIR, 'n1ah.sqlite'));
db.exec('PRAGMA journal_mode = WAL;');

db.exec(`
  CREATE TABLE IF NOT EXISTS qsos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    call TEXT NOT NULL,
    qso_date TEXT NOT NULL,
    time_on TEXT,
    band TEXT,
    mode TEXT,
    freq TEXT,
    rst_sent TEXT,
    rst_rcvd TEXT,
    gridsquare TEXT,
    country TEXT,
    lotw_qsl_rcvd TEXT,
    lotw_qsl_rcvd_date TEXT,
    raw_adif TEXT,
    imported_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(call, qso_date, time_on, band, mode)
  );

  CREATE TABLE IF NOT EXISTS photos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL,
    caption TEXT,
    uploaded_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS sessions (
    token TEXT PRIMARY KEY,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL
  );

  -- date in YYYYMMDD, matching qsos.qso_date, so it joins directly with no conversion.
  CREATE TABLE IF NOT EXISTS solar_data (
    date TEXT PRIMARY KEY,
    sfi REAL,
    sfi_adjusted REAL,
    a_index REAL,
    k_index REAL,
    k_index_max REAL,
    sunspot_number REAL,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  -- Base callsigns (portable "_YY" trip suffixes stripped) known to have Club
  -- Log OQRS enabled, from their public clublog-users.json.zip bulk export.
  -- Membership-only — we don't need any of the other fields in that file.
  CREATE TABLE IF NOT EXISTS clublog_oqrs (
    call TEXT PRIMARY KEY,
    synced_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  -- Curated list of ham satellites worth tracking (Voice/FT8-capable only —
  -- see scripts/seed-satellites.ts for the source verification behind each
  -- entry). "enabled" is user-configurable via the admin-protected toggle on
  -- /satellites; the seed data itself doesn't change unless a satellite goes
  -- permanently silent and needs replacing.
  CREATE TABLE IF NOT EXISTS satellites (
    norad_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    mode TEXT NOT NULL,
    uplink TEXT,
    downlink TEXT,
    notes TEXT,
    enabled INTEGER NOT NULL DEFAULT 1
  );

  -- Latest two-line element set per satellite, refreshed from CelesTrak.
  CREATE TABLE IF NOT EXISTS satellite_tle (
    norad_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    line1 TEXT NOT NULL,
    line2 TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
`);

const SEED_SATELLITES: {
  noradId: number;
  name: string;
  mode: string;
  uplink: string;
  downlink: string;
  notes: string;
}[] = [
  {
    noradId: 25544,
    name: 'ISS (Crossband Repeater)',
    mode: 'FM Voice',
    uplink: '145.990 MHz (67.0 Hz PL)',
    downlink: '437.800 MHz',
    notes: 'Not always active — the crew sometimes reconfigures the radio for packet/SSTV instead of the FM repeater.',
  },
  {
    noradId: 27607,
    name: 'SO-50',
    mode: 'FM Voice',
    uplink: '145.850 MHz (67.0 Hz PL)',
    downlink: '436.795 MHz',
    notes: 'The classic beginner-friendly FM bird — single channel, no Doppler-tuning the uplink needed.',
  },
  {
    noradId: 43017,
    name: 'AO-91 (RadFxSat / Fox-1B)',
    mode: 'FM Voice',
    uplink: '435.250 MHz (67.0 Hz PL)',
    downlink: '145.960 MHz',
    notes: '',
  },
  {
    noradId: 7530,
    name: 'AO-7',
    mode: 'SSB/CW Linear',
    uplink: '432.125–432.175 MHz',
    downlink: '145.925–145.975 MHz',
    notes: 'Launched 1974, the oldest active amateur satellite — only transmits in direct sunlight, its batteries died decades ago.',
  },
  {
    noradId: 24278,
    name: 'FO-29',
    mode: 'SSB/CW Linear',
    uplink: '145.900–146.000 MHz',
    downlink: '435.800–435.900 MHz',
    notes: 'Inverting transponder — uplink + downlink frequency always sums to 581.800 MHz.',
  },
  {
    noradId: 44909,
    name: 'RS-44',
    mode: 'SSB/CW Linear',
    uplink: '435.130–435.150 MHz (LSB)',
    downlink: '145.950–145.970 MHz (USB)',
    notes: 'Inverting transponder, consistently well-reported signal reports.',
  },
];
const insertSat = db.query(
  `INSERT OR IGNORE INTO satellites (norad_id, name, mode, uplink, downlink, notes) VALUES (?, ?, ?, ?, ?, ?)`,
);
for (const sat of SEED_SATELLITES) {
  insertSat.run(sat.noradId, sat.name, sat.mode, sat.uplink, sat.downlink, sat.notes);
}

const existingColumns = new Set(
  (db.query('PRAGMA table_info(qsos)').all() as { name: string }[]).map((c) => c.name),
);
for (const [name, type] of [
  ['lat', 'REAL'],
  ['lon', 'REAL'],
  ['my_lat', 'REAL'],
  ['my_lon', 'REAL'],
  ['my_gridsquare', 'TEXT'],
  ['state', 'TEXT'],
  ['continent', 'TEXT'],
  ['cqz', 'TEXT'],
  ['cnty', 'TEXT'],
  ['iota', 'TEXT'],
] as const) {
  if (!existingColumns.has(name)) {
    db.exec(`ALTER TABLE qsos ADD COLUMN ${name} ${type}`);
  }
}
db.exec('CREATE INDEX IF NOT EXISTS idx_qsos_band ON qsos(band)');
db.exec('CREATE INDEX IF NOT EXISTS idx_qsos_qso_date ON qsos(qso_date)');
db.exec('CREATE INDEX IF NOT EXISTS idx_qsos_country ON qsos(country)');
db.exec('CREATE INDEX IF NOT EXISTS idx_qsos_state ON qsos(state)');
db.exec('CREATE INDEX IF NOT EXISTS idx_qsos_cnty ON qsos(cnty)');
db.exec('CREATE INDEX IF NOT EXISTS idx_qsos_iota ON qsos(iota)');
db.exec('CREATE INDEX IF NOT EXISTS idx_qsos_continent ON qsos(continent)');
db.exec('CREATE INDEX IF NOT EXISTS idx_qsos_cqz ON qsos(cqz)');
