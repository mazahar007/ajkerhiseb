// Vercel serverless proxy: forwards Supabase REST/Auth requests so the app
// reaches Supabase through its own Vercel origin instead of supabase.co
// directly (some phone networks block supabase.co, while the Vercel site
// itself loads fine). The target is HARDCODED below and must match the
// Supabase Project URL — never take the target from the request, this is
// not an open proxy. No secrets in this file: the anon key arrives
// per-request in headers from the app.
// CommonJS on purpose: the repo has no package.json, so Vercel treats
// api/*.js as CommonJS (an `export default` would fail to load).
const TARGET = 'https://qpdrztemjyafrjodqacq.supabase.co';

module.exports = async function handler(req, res) {
  const path = (req.url || '').replace(/^\/api\/supabase/, '') || '/';
  const url = TARGET + path;
  const headers = {};
  for (const [k, v] of Object.entries(req.headers || {})) {
    const lk = k.toLowerCase();
    if (lk === 'host' || lk === 'connection' || lk === 'content-length') continue;
    headers[k] = v;
  }
  let body;
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    if (req.body != null) {
      body = typeof req.body === 'string' || Buffer.isBuffer(req.body)
        ? req.body
        : JSON.stringify(req.body);
    }
  }
  try {
    const r = await fetch(url, { method: req.method, headers, body });
    const buf = Buffer.from(await r.arrayBuffer());
    const out = {};
    const ct = r.headers.get('content-type');
    if (ct) out['content-type'] = ct;
    res.writeHead(r.status, out);
    res.end(buf);
  } catch (e) {
    const msg = e && e.message ? e.message : String(e);
    res.writeHead(502, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ message: 'proxy: ' + msg }));
  }
};
