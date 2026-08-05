import { Hono } from 'hono';
import { serveStatic } from 'hono/bun';
import { authRoutes } from './routes/auth';
import { photoRoutes } from './routes/photos';
import { qsoRoutes } from './routes/qsos';
import { solarRoutes } from './routes/solar';
import { awardsRoutes } from './routes/awards';
import { conditionsRoutes } from './routes/conditions';
import { potaRoutes } from './routes/pota';
import { statsRoutes } from './routes/stats';
import { satelliteRoutes } from './routes/satellites';
import { geocodeRoutes } from './routes/geocode';
import { PHOTOS_DIR } from './db';

const app = new Hono();

app.get('/api/health', (c) => c.json({ ok: true }));
app.route('/api/auth', authRoutes);
app.route('/api/photos', photoRoutes);
app.route('/api/qsos', qsoRoutes);
app.route('/api/solar', solarRoutes);
app.route('/api/awards', awardsRoutes);
app.route('/api/conditions', conditionsRoutes);
app.route('/api/pota', potaRoutes);
app.route('/api/stats', statsRoutes);
app.route('/api/satellites', satelliteRoutes);
app.route('/api/geocode', geocodeRoutes);
app.use('/media/*', serveStatic({ root: PHOTOS_DIR, rewriteRequestPath: (p) => p.replace(/^\/media/, '') }));

const port = Number(process.env.PORT ?? 3000);
console.log(`{CALLSIGN} API listening on :${port}`);

export default { port, fetch: app.fetch };
