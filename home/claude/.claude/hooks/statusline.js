#!/usr/bin/env node
// Claude Code usage monitor — context bar, tokens, cost, rate limits.
// Transcripts are parsed incrementally in /tmp for safeguard flags, context
// fallback, and session-share of the rate-limit window.

const path = require('path');
const fs = require('fs');
const os = require('os');

let input = '';
const timeout = setTimeout(() => process.exit(0), 3000);
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => (input += chunk));
process.stdin.on('end', () => {
  clearTimeout(timeout);
  try {
    const data = JSON.parse(input);
    // Cursor shape (DECSCUSR) is written by statusline.sh before this
    // script starts — node cold-start was adding visible lag.
    const dim = '\x1b[2m';
    const rst = '\x1b[0m';
    const modelId = data.model?.id || '';
    const model = data.model?.display_name || 'Claude';
    const dir = path.basename(data.workspace?.current_dir || process.cwd());
    const cost = data.cost?.total_cost_usd;
    const rate5h = data.rate_limits?.five_hour?.used_percentage;
    const rate5hResets = data.rate_limits?.five_hour?.resets_at;
    const rate7d = data.rate_limits?.seven_day?.used_percentage;
    const rate7dResets = data.rate_limits?.seven_day?.resets_at;

    // Transcripts are append-only, so parse each one once and keep running
    // totals in /tmp keyed by path; later renders only read the tail.
    function transcriptUsage(p) {
        if (!p) return null;
        let size;
        try { size = fs.statSync(p).size; } catch { return null; }
        const cacheFile = path.join(os.tmpdir(),
            'claude-sl-' + p.replace(/[^a-zA-Z0-9]/g, '_').slice(-100) + '.json');
        // v: bump when the cached fields change, so a cache written by an
        // older version is rebuilt from the whole transcript, not its tail.
        const fresh = () => ({ v: 3, size: 0, lastUsage: null, lastModel: null, flag: null });
        let c = fresh();
        try {
            const saved = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
            if (saved.v === c.v) c = { ...c, ...saved };
        } catch {}
        const result = () => ({ lastUsage: c.lastUsage, lastModel: c.lastModel, flag: c.flag });
        if (size === c.size) return result();
        if (c.size > size) c = fresh();
        let text;
        try {
            const fd = fs.openSync(p, 'r');
            const buf = Buffer.alloc(size - c.size);
            fs.readSync(fd, buf, 0, buf.length, c.size);
            fs.closeSync(fd);
            text = buf.toString('utf8');
        } catch { return null; }
        const lines = text.split('\n');
        const partial = lines.pop();          // writer may be mid-line
        let offset = c.size + Buffer.byteLength(text, 'utf8') -
            Buffer.byteLength(partial, 'utf8');
        for (const line of lines) {
            // Safeguard flags (bio, cyber) can hand the rest of the session
            // to a smaller model (support.claude.com/en/articles/16049681).
            // Records: an assistant refusal, a harness note naming
            // refusedMessageId, or a model_refusal_fallback notice (with
            // fallbackModel) at the switch; any of them may be the only one.
            if (line.includes('refus')) {
                let r = null;
                try { r = JSON.parse(line); } catch {}
                const rm = r && r.message;
                const notice = r && r.subtype === 'model_refusal_fallback';
                const cat = !r ? null
                    : rm && rm.stop_reason === 'refusal'
                        ? (rm.stop_details && rm.stop_details.category) || '?'
                    : notice ? r.apiRefusalCategory || '?'
                    : r.refusedMessageId ? '?' : null;
                if (cat) {
                    const f = c.flag || { cat: '?', to: null, picked: false,
                        from: (rm && rm.stop_reason === 'refusal' && rm.model) || c.lastModel };
                    if (f.cat === '?') f.cat = cat;
                    if (notice) { f.to = r.fallbackModel || null; f.picked = false; }
                    c.flag = f;
                }
            }
            // A /model after the flag is the user's choice, not the switch.
            if (c.flag && line.includes('<command-name>/model</command-name>')) {
                let r = null;
                try { r = JSON.parse(line); } catch {}
                const mc = r && r.type === 'user' && r.message && r.message.content;
                if (typeof mc === 'string' &&
                    mc.startsWith('<command-name>/model</command-name>'))
                    c.flag.picked = true;
            }
            if (!line.includes('"usage"')) continue;
            let d = null;
            try { d = JSON.parse(line); } catch {
                // torn write: a later append glued onto an unfinished line.
                // Retry from the last embedded entry boundary so the newest
                // turn's tokens survive; the torn prefix stays lost (ceiling:
                // one turn per race, self-heals on the next append).
                const cut = line.lastIndexOf('{"parentUuid"');
                if (cut > 0) { try { d = JSON.parse(line.slice(cut)); } catch {} }
            }
            if (!d) continue;
            const m = d.message || {};
            const u = m.usage;
            if (!u) continue;
            c.lastUsage = u;
            const raw = m.model || '';
            if (raw && raw !== '<synthetic>' && m.stop_reason !== 'refusal') {
                c.lastModel = raw;
                if (c.flag && !c.flag.from) c.flag.from = raw;
            }
        }
        c.size = offset;
        try { fs.writeFileSync(cacheFile, JSON.stringify(c)); } catch {}
        return result();
    }
    const tu = transcriptUsage(data.transcript_path);

    // Session share of a pool: per-turn weights for every transcript in the
    // window — Claude token volume (ccusage's source data) — cached per file.
    function fileTurns(p) {
      let size;
      try { size = fs.statSync(p).size; } catch { return null; }
      const cf = path.join(os.tmpdir(),
          'claude-sl-f-' + p.replace(/[^a-zA-Z0-9]/g, '_').slice(-80) + '.json');
      let c;
      try { c = JSON.parse(fs.readFileSync(cf, 'utf8')); } catch {}
      if (!c || c.size !== size) {
        const turns = [];
        let text;
        try { text = fs.readFileSync(p, 'utf8'); } catch { return null; }
        for (const line of text.split('\n')) {
          if (!line.includes('"usage"')) continue;
          let d;
          try { d = JSON.parse(line); } catch { continue; }
          const m = d.message || {};
          const u = m.usage;
          if (!u) continue;
          const raw = m.model || '';
          const ts = Date.parse(d.timestamp || '') || 0;
          if (raw.startsWith('claude')) {
            // transcripts carry no costUSD (the CLI prices live), so Claude
            // turns are weighted by token volume in M — pool-share ratio only
            turns.push([ts, (u.input_tokens +
                (u.cache_read_input_tokens || 0) +
                (u.cache_creation_input_tokens || 0) +
                u.output_tokens) / 1e6]);
          }
        }
        c = { size, turns };
        try { fs.writeFileSync(cf, JSON.stringify(c)); } catch {}
      }
      return c.turns;
    }
    function scanWindow(sinceMs, wantFile) {
      const root = path.join(os.homedir(), '.claude', 'projects');
      let dirs;
      try { dirs = fs.readdirSync(root, { withFileTypes: true }); } catch { return null; }
      const out = { cs: 0, ct: 0 };
      try {
        for (const d of dirs) {
          if (!d.isDirectory()) continue;
          for (const f of fs.readdirSync(path.join(root, d.name)))
            if (f.endsWith('.jsonl')) {
              const p = path.join(root, d.name, f);
              try { if (fs.statSync(p).mtimeMs <= sinceMs) continue; } catch { continue; }
              const turns = fileTurns(p);
              if (!turns) continue;
              for (const [ts, cc] of turns) {
                if (ts <= sinceMs) continue;
                out.ct += cc;
                if (p === wantFile) out.cs += cc;
              }
            }
        }
      } catch { return out; }
      return out;
    }

    const parts = [];

    parts.push(`${dim}${model}${rst}`);

    // After a safeguard flag, say so; while the model it switched to is
    // answering, name it. Without a notice, a model change counts unless
    // the user ran /model after the flag.
    if (tu && tu.flag) {
      const f = tu.flag, last = tu.lastModel;
      const short = m => m.replace(/^claude-/, '');
      const moved = f.to ? last === f.to
          : !f.picked && last && f.from && last !== f.from;
      parts.push(`\x1b[33m${f.cat === '?' ? 'safeguard' : f.cat}-flagged` +
          `${moved ? ` → ${short(last)}` : ''}${rst}`);
    }

    // Context window bar (10 segments, fills as context is consumed)
    const AUTO_COMPACT_BUFFER_PCT = 16.5;
    const windowTokens = /1m/i.test(modelId) ? 1e6 : 200000;
    let remaining = data.context_window?.remaining_percentage;
    if (tu && tu.lastUsage && (remaining == null || remaining >= 99.9)) {
        const u = tu.lastUsage;
        const ctx = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) +
            (u.cache_creation_input_tokens || 0) + (u.output_tokens || 0);
        remaining = Math.max(0, 100 * (1 - ctx / windowTokens));
    }
    if (remaining != null) {
      const usable = Math.max(
        0,
        ((remaining - AUTO_COMPACT_BUFFER_PCT) /
          (100 - AUTO_COMPACT_BUFFER_PCT)) *
          100,
      );
      const used = Math.max(0, Math.min(100, Math.round(100 - usable)));
      const filled = Math.floor(used / 10);
      const bar = '█'.repeat(filled) + '░'.repeat(10 - filled);

      let color;
      if (used < 50) color = '\x1b[32m';
      else if (used < 65) color = '\x1b[33m';
      else if (used < 80) color = '\x1b[38;5;208m';
      else color = '\x1b[5;31m';

      parts.push(`${color}${bar} ${used}%${rst}`);
    }

    // Session cost
    if (cost != null && cost > 0) {
      parts.push(`${dim}$${cost.toFixed(2)}${rst}`);
    }

    // Rate-limit windows, 5h then weekly (the reset span tells them apart):
    //   <pct>% <resets-in>            pool
    //   <session>%/<pool>% <resets>   session share of pool
    const fmtDur = secs => {
      const d = Math.floor(secs / 86400), h = Math.floor((secs % 86400) / 3600),
          m = Math.floor((secs % 3600) / 60);
      return d > 0 ? `${d}d${h}h` : h > 0 ? `${h}h${m}m` : `${m}m`;
    };
    const limRow = (pct, resets, prefix = '') => {
      if (pct == null) return null;
      const used = Math.round(pct);
      let color;
      if (used < 50) color = '\x1b[32m';
      else if (used < 80) color = '\x1b[33m';
      else color = '\x1b[31m';
      let time = '';
      if (resets != null) {
        const secs = Math.max(0, resets - Math.floor(Date.now() / 1000));
        time = ` ${fmtDur(secs)}`;
      }
      return `${color}${prefix}${used}%${time}\x1b[0m`;
    };
    // session-share prefixes: fraction of the window's modeled weight,
    // applied to the server pool percent (fraction ≤ 1 by construction)
    let cpre5 = '', cpre7 = '';
    if (data.transcript_path) {
      if (rate5hResets) {
        const s = scanWindow((rate5hResets - 5 * 3600) * 1000, data.transcript_path);
        if (s && s.ct > 0)
          cpre5 = `${Math.round(rate5h * s.cs / s.ct)}%/`;
      }
      if (rate7dResets) {
        const s = scanWindow((rate7dResets - 7 * 86400) * 1000, data.transcript_path);
        if (s && s.ct > 0)
          cpre7 = `${Math.round(rate7d * s.cs / s.ct)}%/`;
      }
    }
    const r5 = limRow(rate5h, rate5hResets, cpre5);
    if (r5) parts.push(r5);
    const r7 = limRow(rate7d, rate7dResets, cpre7);
    if (r7) parts.push(r7);

    // dash: archive server-truth rate limits; the dashboard reads this
    const rl = data.rate_limits;
    if (rl && (rl.five_hour || rl.seven_day)) {
      try {
        const { DatabaseSync } = require('node:sqlite');
        const db = new DatabaseSync(
          path.join(os.homedir(), '.local/state/dash/state.db'));
        db.exec(`CREATE TABLE IF NOT EXISTS claude_limits (
          ts INTEGER PRIMARY KEY, used_5h REAL, resets_5h INTEGER,
          used_7d REAL, resets_7d INTEGER)`);
        // named columns: dash-llm owns an extra `plan` column
        db.prepare(`INSERT OR REPLACE INTO claude_limits
          (ts, used_5h, resets_5h, used_7d, resets_7d) VALUES (?,?,?,?,?)`).run(
          Math.floor(Date.now() / 1000),
          rl.five_hour?.used_percentage ?? null,
          rl.five_hour?.resets_at ?? null,
          rl.seven_day?.used_percentage ?? null,
          rl.seven_day?.resets_at ?? null);
        db.close();
      } catch {}
    }

    parts.push(`${dim}${dir}${rst}`);

    process.stdout.write(parts.join(' │ '));
  } catch {}
});
