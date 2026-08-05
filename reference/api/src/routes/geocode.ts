import { Hono } from 'hono';

export const geocodeRoutes = new Hono();

// Proxied server-side rather than called from the browser: Nominatim's usage
// policy requires a descriptive User-Agent identifying the application,
// which browsers won't let client-side fetch() set.
geocodeRoutes.get('/', async (c) => {
  const q = c.req.query('q')?.trim();
  if (!q) return c.json({ error: 'q is required' }, 400);
  try {
    const url = `https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${encodeURIComponent(q)}`;
    const res = await fetch(url, {
      headers: { 'User-Agent': '{CALLSIGN}-hamradio-site/1.0 (https://n1ah.asuscomm.com)' },
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return c.json({ error: 'Geocoding service unavailable' }, 502);
    const results = (await res.json()) as { lat: string; lon: string; display_name: string }[];
    c.header('Cache-Control', 'no-store');
    if (!results.length) return c.json(null);
    const r = results[0];
    return c.json({ lat: Number(r.lat), lon: Number(r.lon), displayName: r.display_name });
  } catch {
    return c.json({ error: 'Geocoding failed' }, 502);
  }
});
