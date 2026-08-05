import type { Context, Next } from 'hono';
import { db } from './db';

const SESSION_DAYS = 30;

export function createSession(): string {
  const token = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000).toISOString();
  db.query('INSERT INTO sessions (token, expires_at) VALUES (?, ?)').run(token, expiresAt);
  return token;
}

export function isValidSession(token: string | undefined): boolean {
  if (!token) return false;
  const row = db
    .query('SELECT expires_at FROM sessions WHERE token = ?')
    .get(token) as { expires_at: string } | null;
  if (!row) return false;
  return new Date(row.expires_at).getTime() > Date.now();
}

export async function requireAuth(c: Context, next: Next) {
  const header = c.req.header('Authorization');
  const token = header?.startsWith('Bearer ') ? header.slice('Bearer '.length) : undefined;
  if (!isValidSession(token)) {
    return c.json({ error: 'unauthorized' }, 401);
  }
  await next();
}
