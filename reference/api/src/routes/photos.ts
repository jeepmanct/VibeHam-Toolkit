import { Hono } from 'hono';
import path from 'node:path';
import { unlink } from 'node:fs/promises';
import { db, PHOTOS_DIR } from '../db';
import { requireAuth } from '../auth';

export const photoRoutes = new Hono();

photoRoutes.get('/', (c) => {
  const rows = db
    .query('SELECT id, filename, caption FROM photos ORDER BY uploaded_at DESC')
    .all() as { id: number; filename: string; caption: string | null }[];
  return c.json(rows.map((r) => ({ url: `/media/${r.filename}`, caption: r.caption ?? undefined, id: r.id })));
});

photoRoutes.post('/', requireAuth, async (c) => {
  const form = await c.req.formData();
  const file = form.get('photo');
  const caption = form.get('caption');
  if (!(file instanceof File)) {
    return c.json({ error: 'photo file is required' }, 400);
  }
  const ext = path.extname(file.name) || '.jpg';
  const filename = `${crypto.randomUUID()}${ext}`;
  await Bun.write(path.join(PHOTOS_DIR, filename), file);
  db.query('INSERT INTO photos (filename, caption) VALUES (?, ?)').run(
    filename,
    typeof caption === 'string' && caption.length ? caption : null,
  );
  return c.json({ ok: true, url: `/media/${filename}` }, 201);
});

photoRoutes.delete('/:id', requireAuth, async (c) => {
  const id = Number(c.req.param('id'));
  const row = db.query('SELECT filename FROM photos WHERE id = ?').get(id) as { filename: string } | null;
  if (!row) return c.json({ error: 'Photo not found' }, 404);
  db.query('DELETE FROM photos WHERE id = ?').run(id);
  try {
    await unlink(path.join(PHOTOS_DIR, row.filename));
  } catch {
    // File already gone from disk — the DB row is still deleted, which is what matters.
  }
  return c.json({ ok: true });
});
