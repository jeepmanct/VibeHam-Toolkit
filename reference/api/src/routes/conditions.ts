import { Hono } from 'hono';
import { db } from '../db';
import { ISO_TO_DXCC } from '../dxccIso';

export const conditionsRoutes = new Hono();

conditionsRoutes.get('/today', (c) => {
  const row = db
    .query('SELECT date, sfi, a_index, k_index, sunspot_number FROM solar_data ORDER BY date DESC LIMIT 1')
    .get() as { date: string; sfi: number | null; a_index: number | null; k_index: number | null; sunspot_number: number | null } | null;
  c.header('Cache-Control', 'no-store');
  if (!row) return c.json(null);
  return c.json({
    date: row.date,
    sfi: row.sfi,
    aIndex: row.a_index,
    kIndex: row.k_index,
    sunspotNumber: row.sunspot_number,
  });
});

// Home station coordinates, for sunrise/sunset/grayline calculations client-side.
// Same "most common my_lat/my_lon" trick used for the distance stats — the
// log doesn't have a dedicated "home QTH" setting, so this infers it from
// whatever coordinate appears on the most QSOs.
conditionsRoutes.get('/home', (c) => {
  const row = db
    .query(
      `SELECT my_lat as lat, my_lon as lon, my_gridsquare as grid, COUNT(*) as count
       FROM qsos WHERE my_lat IS NOT NULL AND my_lon IS NOT NULL
       GROUP BY my_lat, my_lon ORDER BY count DESC LIMIT 1`,
    )
    .get() as { lat: number; lon: number; grid: string | null } | null;
  c.header('Cache-Control', 'no-store');
  return c.json(row ? { lat: row.lat, lon: row.lon, grid: row.grid } : null);
});

// "Needed" is only ever true when NONE of a flag's possible DXCC entities are
// worked, and only ever computed for flags we have a mapping for — see
// dxccIso.ts for why this can't be more precise than that (dxheat's spot feed
// only carries an ISO country flag, not true DXCC-entity granularity).
function neededStatus(flag: string | undefined, worked: Set<string>): 'needed' | 'worked' | null {
  if (!flag) return null;
  const entities = ISO_TO_DXCC[flag.toLowerCase()];
  if (!entities) return null;
  return entities.some((e) => worked.has(e)) ? 'worked' : 'needed';
}

// Live DX spots, proxied server-side to avoid a third-party fetch from the
// browser (and so it fails gracefully behind our own API if dxheat is down).
conditionsRoutes.get('/spots', async (c) => {
  try {
    const res = await fetch('https://dxheat.com/source/spots/', { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return c.json([]);
    const spots = (await res.json()) as Record<string, unknown>[];

    const workedRows = db.query('SELECT DISTINCT country FROM qsos WHERE country IS NOT NULL').all() as { country: string }[];
    const worked = new Set(workedRows.map((r) => r.country));

    c.header('Cache-Control', 'no-store');
    return c.json(
      spots.slice(0, 40).map((s) => ({
        spotter: s.Spotter,
        call: s.DXCall,
        frequency: s.Frequency,
        band: s.Band,
        mode: s.Mode,
        comment: s.Comment,
        time: s.Time,
        continent: s.Continent_dx,
        grid: s.DXLocator,
        lotw: s.LOTW,
        needed: neededStatus(s.Flag as string | undefined, worked),
      })),
    );
  } catch {
    return c.json([]);
  }
});

function decodeXmlEntities(s: string): string {
  return s
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .trim();
}

function parseContestRss(xml: string): { title: string; link: string; description: string }[] {
  const items: { title: string; link: string; description: string }[] = [];
  const itemRe = /<item>([\s\S]*?)<\/item>/g;
  let match: RegExpExecArray | null;
  while ((match = itemRe.exec(xml))) {
    const block = match[1];
    const title = decodeXmlEntities(block.match(/<title>([\s\S]*?)<\/title>/)?.[1] ?? '');
    const link = decodeXmlEntities(block.match(/<link>([\s\S]*?)<\/link>/)?.[1] ?? '');
    const description = decodeXmlEntities(block.match(/<description>([\s\S]*?)<\/description>/)?.[1] ?? '');
    if (title) items.push({ title, link, description });
  }
  return items;
}

// Upcoming ham radio contests, proxied from WA7BNM's public RSS feed (the
// standard reference contest calendar) for the same reasons as /spots.
conditionsRoutes.get('/contests', async (c) => {
  try {
    const res = await fetch('https://www.contestcalendar.com/calendar.rss', { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return c.json([]);
    const xml = await res.text();
    c.header('Cache-Control', 'no-store');
    return c.json(parseContestRss(xml).slice(0, 25));
  } catch {
    return c.json([]);
  }
});
