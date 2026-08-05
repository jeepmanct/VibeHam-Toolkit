import { Hono } from 'hono';
import { db } from '../db';
import { requireAuth } from '../auth';
import { fetchGfzSolarData, parseGfzSolarData, importSolarRecords } from '../solarData';

export const solarRoutes = new Hono();

// Yearly averages — the raw daily series is 34k+ points, far too dense for a
// readable chart, and a year-over-year view is what actually shows solar
// cycles anyway.
solarRoutes.get('/history', (c) => {
  const rows = db
    .query(
      `SELECT substr(date, 1, 4) as year, AVG(sfi) as avgSfi, AVG(k_index) as avgK, AVG(a_index) as avgA
       FROM solar_data WHERE sfi IS NOT NULL GROUP BY year ORDER BY year ASC`,
    )
    .all() as { year: string; avgSfi: number; avgK: number; avgA: number }[];
  c.header('Cache-Control', 'no-store');
  return c.json(rows);
});

solarRoutes.post('/sync', requireAuth, async (c) => {
  try {
    const text = await fetchGfzSolarData();
    const records = parseGfzSolarData(text);
    const imported = importSolarRecords(records);
    return c.json({ imported, from: records[0]?.date, to: records[records.length - 1]?.date });
  } catch (err) {
    return c.json({ error: err instanceof Error ? err.message : 'Solar data sync failed' }, 502);
  }
});
