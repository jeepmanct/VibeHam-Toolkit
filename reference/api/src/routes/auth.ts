import { Hono } from 'hono';
import { createSession } from '../auth';

export const authRoutes = new Hono();

authRoutes.post('/login', async (c) => {
  const { password } = await c.req.json<{ password?: string }>();
  const hash = process.env.ADMIN_PASSWORD_HASH;
  if (!hash || !password) {
    return c.json({ error: 'unauthorized' }, 401);
  }
  const ok = await Bun.password.verify(password, hash);
  if (!ok) {
    return c.json({ error: 'unauthorized' }, 401);
  }
  const token = createSession();
  return c.json({ token });
});
