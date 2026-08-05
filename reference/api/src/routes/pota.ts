import { Hono } from 'hono';

export const potaRoutes = new Hono();

const POTA_CALLSIGN = '{CALLSIGN}';

potaRoutes.get('/profile', async (c) => {
  try {
    const res = await fetch(`https://api.pota.app/profile/${POTA_CALLSIGN}`, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return c.json(null);
    const data = await res.json();
    c.header('Cache-Control', 'no-store');
    return c.json(data);
  } catch {
    return c.json(null);
  }
});
