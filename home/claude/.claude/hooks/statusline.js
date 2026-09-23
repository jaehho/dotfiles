#!/usr/bin/env node
// Claude Code usage monitor — context bar, tokens, cost/credits, rate limits.
// On gateway models (claude-open on z.ai) the CLI's cost is a Claude-table
// mispricing and its context window can stick at 100% after a resume, so both
// are computed from the transcript's usage entries instead (cached
// incrementally — transcripts are append-only).

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
    const dim = '\x1b[2m';
    const rst = '\x1b[0m';    const modelId = data.model?.id || '';
    const glm = /glm/i.test(modelId);
    // show what is actually serving, not the alias ("opus" on glm is a lie)
    const model = glm ? modelId.replace(/\[1m\]/i, '') :
        data.model?.display_name || 'Claude';
    const dir = path.basename(data.workspace?.current_dir || process.cwd());
    const session = data.session_id || '';
    const cost = data.cost?.total_cost_usd;
    const rate5h = data.rate_limits?.five_hour?.used_percentage;
    const rate5hResets = data.rate_limits?.five_hour?.resets_at;
    const rate7d = data.rate_limits?.seven_day?.used_percentage;
    const rate7dResets = data.rate_limits?.seven_day?.resets_at;

    // z.ai credit multipliers per 10k credits [input, cache-read, output],
    // docs.z.ai pricing: flash 2.3/0.56/8, glm-5.3 6.9/1.7/24; off-peak
    // (outside 14:00-18:00 Singapore, Mon-Fri) is half price. Turns that ran
    // on OpenRouter (z-ai/... slug) drew no z.ai credits.
    const glmMult = m => !m ? null
        : m.includes('flash') ? [2.3, 0.56, 8]
        : m.startsWith('glm') ? [6.9, 1.7, 24] : null;
    // OpenRouter list prices per M tokens [input, cache-read, output] —
    // what this session would have cost there
    const orPrice = m => !m ? null
        : m.includes('flash') ? [0.09, 0.018, 0.30]
        : m.startsWith('glm') || m.startsWith('z-ai/') ? [0.91, 0.169, 2.86] : null;
    const isPeakSgt = ts => {
        const sgt = new Date(ts + 8 * 3600e3);
        const h = sgt.getUTCHours(), day = sgt.getUTCDay();
        return h >= 14 && h < 18 && day >= 1 && day <= 5;
    };
    // Flash campaign through Sep 20 2026: non-ZCode agents draw flash at
    // half quota inside 23:00-09:00 SGT (ponytail: date gate is a display
    // estimate; delete when the campaign ends)
    const CAMPAIGN_END = Date.UTC(2026, 8, 20, 16, 0, 0);
    const flashCampaignHalf = ts => {
        if (Date.now() > CAMPAIGN_END) return false;
        const h = new Date(ts + 8 * 3600e3).getUTCHours();
        return h >= 23 || h < 9;
    };

    // Transcripts are append-only, so parse each one once and keep running
    // totals in /tmp keyed by path; later renders only read the tail.
    function transcriptUsage(p) {
        if (!p) return null;
        let size;
        try { size = fs.statSync(p).size; } catch { return null; }
        const cacheFile = path.join(os.tmpdir(),
            'claude-sl-' + p.replace(/[^a-zA-Z0-9]/g, '_').slice(-100) + '.json');
        let c = { size: 0, credits: 0, drawn: 0, orUsd: 0, anyGlm: false, lastUsage: null };
        try { c = { ...c, ...JSON.parse(fs.readFileSync(cacheFile, 'utf8')) }; } catch {}
        if (size === c.size)
            return { credits: c.anyGlm ? c.credits : null,
                drawn: c.anyGlm ? c.drawn : null, orUsd: c.orUsd, lastUsage: c.lastUsage };
        if (c.size > size) c = { size: 0, credits: 0, drawn: 0, orUsd: 0, anyGlm: false, lastUsage: null };
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
            const orp = orPrice(raw);
            if (orp) {
                c.orUsd += (u.input_tokens * orp[0] +
                    (u.cache_read_input_tokens || 0) * orp[1] +
                    (u.cache_creation_input_tokens || 0) * orp[0] +
                    u.output_tokens * orp[2]) / 1e6;
            }
            const mult = raw.startsWith('z-ai/') ? null : glmMult(raw);
            if (!mult) continue;
            c.anyGlm = true;
            const ts = Date.parse(d.timestamp || '') || Date.now();
            const cr = (u.input_tokens * mult[0] +
                (u.cache_read_input_tokens || 0) * mult[1] +
                (u.cache_creation_input_tokens || 0) * mult[0] +
                u.output_tokens * mult[2]) / 10000;
            const adj = isPeakSgt(ts) ? cr : cr / 2;
            c.credits += adj;
            c.drawn += raw.includes('flash') && flashCampaignHalf(ts) ? adj / 2 : adj;
        }
        c.size = offset;
        try { fs.writeFileSync(cacheFile, JSON.stringify(c)); } catch {}
        return { credits: c.anyGlm ? c.credits : null,
            drawn: c.anyGlm ? c.drawn : null, orUsd: c.orUsd, lastUsage: c.lastUsage };
    }
    const tu = transcriptUsage(data.transcript_path);

    // Session share of a pool: per-turn weights for every transcript in the
    // window — z.ai credits, Claude token volume (ccusage's source data) —
    // cached per file. The modeled absolutes drift ~10%, but the error is
    // uniform, so the session's fraction of the window total is accurate;
    // apply it to the server-truth pool percent.
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
            turns.push([ts, 0, (u.input_tokens +
                (u.cache_read_input_tokens || 0) +
                (u.cache_creation_input_tokens || 0) +
                u.output_tokens) / 1e6]);
            continue;
          }
          const mult = raw.startsWith('z-ai/') ? null : glmMult(raw);
          if (!mult) continue;
          const cr = (u.input_tokens * mult[0] +
              (u.cache_read_input_tokens || 0) * mult[1] +
              (u.cache_creation_input_tokens || 0) * mult[0] +
              u.output_tokens * mult[2]) / 10000;
          const adj = isPeakSgt(ts) ? cr : cr / 2;
          turns.push([ts, raw.includes('flash') && flashCampaignHalf(ts) ? adj / 2 : adj, 0]);
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
      const out = { zs: 0, zt: 0, cs: 0, ct: 0 };
      try {
        for (const d of dirs) {
          if (!d.isDirectory()) continue;
          for (const f of fs.readdirSync(path.join(root, d.name)))
            if (f.endsWith('.jsonl')) {
              const p = path.join(root, d.name, f);
              try { if (fs.statSync(p).mtimeMs <= sinceMs) continue; } catch { continue; }
              const turns = fileTurns(p);
              if (!turns) continue;
              for (const [ts, z, cc] of turns) {
                if (ts <= sinceMs) continue;
                out.zt += z; out.ct += cc;
                if (p === wantFile) { out.zs += z; out.cs += cc; }
              }
            }
        }
      } catch { return out; }
      return out;
    }

    // z.ai pool pressure: the CLI never sends rate_limits on a gateway, so
    // take the 5h/weekly percentages from the console endpoint — cached for
    // a minute, refreshed out-of-band so a slow endpoint never blocks a render
    let zai5h = null, zai5hResets = null, zaiWeek = null, zaiResetsWeek = null;
    const onZai = glm && !/^(z-ai\/|@preset)/.test(modelId);
    if (onZai) {
      const qf = path.join(os.tmpdir(), 'claude-sl-zai-quota.json');
      let q = null;
      try { q = JSON.parse(fs.readFileSync(qf, 'utf8')); } catch {}
      if (!q || Date.now() - q.ts > 60000) {
        try {
          const key = fs.readFileSync(
            path.join(os.homedir(), '.config/zai.env'), 'utf8')
            .match(/^ZAI_API_KEY=(.*)$/m)[1].trim();
          const child = require('child_process').spawn(process.execPath, ['-e', `
            const fs = require('fs'), https = require('https');
            https.get({ hostname: 'api.z.ai',
                path: '/api/monitor/usage/quota/limit',
                headers: { Authorization: 'Bearer ' + process.env.ZK } },
              r => { let d = '';
                r.on('data', c => (d += c));
                r.on('end', () => { try {
                  const by = {};
                  (JSON.parse(d).data.limits || []).forEach(l => (by[l.number] = l));
                  fs.writeFileSync(${JSON.stringify(qf)}, JSON.stringify({
                    ts: Date.now(),
                    pct5h: by[5] ? by[5].percentage : null,
                    resets5h: by[5] ? Math.floor(by[5].nextResetTime / 1000) : null,
                    total5h: by[5] ? by[5].usage : null,
                    pctWeek: by[1] ? by[1].percentage : null,
                    resetsWeek: by[1] ? Math.floor(by[1].nextResetTime / 1000) : null }));
                } catch {} });
              });`],
            { env: { ...process.env, ZK: key }, detached: true, stdio: 'ignore' }).unref();
        } catch {}
      }
      if (q) {
        zai5h = q.pct5h; zai5hResets = q.resets5h;
        zaiWeek = q.pctWeek; zaiResetsWeek = q.resetsWeek;
      }
    }

    const parts = [];

    parts.push(`${dim}${model}${rst}`);

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

    // Session cost, same slot both windows: Anthropic sessions show the
    // server-priced figure; glm sessions show the OpenRouter list-price
    // counterfactual (the CLI's own glm number is a Claude-table mispricing)
    if (cost != null && cost > 0 && !(tu && tu.credits != null)) {
      parts.push(`${dim}$${cost.toFixed(2)}${rst}`);
    }
    if (tu && tu.orUsd > 0) {
      parts.push(`${dim}$${tu.orUsd.toFixed(2)}${rst}`);
    }

    // Rate-limit windows, 5h then weekly (the reset span tells them apart):
    //   <pct>% <resets-in>            pool
    //   <session>%/<pool>% <resets>   z.ai 5h with this session's share
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
    let pre5 = '', pre7 = '', cpre5 = '', cpre7 = '';
    if (data.transcript_path) {
      if (zai5hResets) {
        const s = scanWindow((zai5hResets - 5 * 3600) * 1000, data.transcript_path);
        if (s && s.zt > 0 && zai5h != null)
          pre5 = `${Math.round(zai5h * s.zs / s.zt)}%/`;
      }
      if (zaiResetsWeek) {
        const s = scanWindow((zaiResetsWeek - 7 * 86400) * 1000, data.transcript_path);
        if (s && s.zt > 0 && zaiWeek != null)
          pre7 = `${Math.round(zaiWeek * s.zs / s.zt)}%/`;
      }
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
    const z5 = limRow(zai5h, zai5hResets, pre5);
    if (z5) parts.push(z5);
    const z7 = limRow(zaiWeek, zaiResetsWeek, pre7);
    if (z7) parts.push(z7);

    // idle-dash: archive server-truth rate limits; the dashboard reads this
    const rl = data.rate_limits;
    if (rl && (rl.five_hour || rl.seven_day)) {
      try {
        const { DatabaseSync } = require('node:sqlite');
        const db = new DatabaseSync(
          path.join(os.homedir(), '.local/state/idle-dash/state.db'));
        db.exec(`CREATE TABLE IF NOT EXISTS claude_limits (
          ts INTEGER PRIMARY KEY, used_5h REAL, resets_5h INTEGER,
          used_7d REAL, resets_7d INTEGER)`);
        // named columns: idle-dash-llm owns an extra `plan` column
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
