#!/usr/bin/env node
// Claude Code usage monitor — context bar, tokens, cost/credits, rate limits.
// On gateway models (claude-or on z.ai) the CLI's cost is a Claude-table
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

    // Transcripts are append-only, so parse each one once and keep running
    // totals in /tmp keyed by path; later renders only read the tail.
    function transcriptUsage(p) {
        if (!p) return null;
        let size;
        try { size = fs.statSync(p).size; } catch { return null; }
        const cacheFile = path.join(os.tmpdir(),
            'claude-sl-' + p.replace(/[^a-zA-Z0-9]/g, '_').slice(-100) + '.json');
        let c = { size: 0, credits: 0, orUsd: 0, anyGlm: false, lastUsage: null };
        try { c = { ...c, ...JSON.parse(fs.readFileSync(cacheFile, 'utf8')) }; } catch {}
        if (size === c.size)
            return { credits: c.anyGlm ? c.credits : null, orUsd: c.orUsd, lastUsage: c.lastUsage };
        if (c.size > size) c = { size: 0, credits: 0, orUsd: 0, anyGlm: false, lastUsage: null };
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
            c.credits += isPeakSgt(ts) ? cr : cr / 2;
        }
        c.size = offset;
        try { fs.writeFileSync(cacheFile, JSON.stringify(c)); } catch {}
        return { credits: c.anyGlm ? c.credits : null, orUsd: c.orUsd, lastUsage: c.lastUsage };
    }
    const tu = transcriptUsage(data.transcript_path);

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

    // Token count
    const totalIn = data.context_window?.total_input_tokens || 0;
    const totalOut = data.context_window?.total_output_tokens || 0;
    const total = totalIn + totalOut;
    if (total > 0) {
      let tokens;
      if (total >= 1_000_000) tokens = `${(total / 1_000_000).toFixed(1)}M`;
      else if (total >= 1_000) tokens = `${Math.round(total / 1_000)}K`;
      else tokens = `${total}`;
      parts.push(`${dim}${tokens}${rst}`);
    }

    // Session cost — Anthropic sessions only: for glm the CLI falls back to
    // Claude-table pricing (~12x z.ai list), so credits replace it
    if (cost != null && cost > 0 && !(tu && tu.credits != null)) {
      parts.push(`${dim}$${cost.toFixed(2)}${rst}`);
    }

    // z.ai coding-plan credits + the OpenRouter counterfactual
    if (tu && ((tu.credits != null && tu.credits > 0) || tu.orUsd > 0)) {
      const hasCr = tu.credits != null && tu.credits > 0;
      const label = (hasCr ? `${tu.credits >= 10 ? tu.credits.toFixed(0) : tu.credits.toFixed(1)} cr` : '') +
        (tu.orUsd > 0 ? `${hasCr ? ' · ' : ''}$${tu.orUsd.toFixed(2)} or` : '');
      parts.push(`${dim}${label}${rst}`);
    }

    // 5h subscription window
    if (rate5h != null) {
      const used = Math.round(rate5h);

      let color;
      if (used < 50) color = '\x1b[32m';
      else if (used < 80) color = '\x1b[33m';
      else color = '\x1b[31m';

      let time = '';
      if (rate5hResets != null) {
        const secs = Math.max(0, rate5hResets - Math.floor(Date.now() / 1000));
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        time = h > 0 ? `${h}h${m}m` : `${m}m`;
      }

      parts.push(`${color}⚡${used}%${time ? ` ${time}` : ''}\x1b[0m`);
    }

    // 7-day subscription window (same server data, slower pool)
    if (rate7d != null) {
      const used = Math.round(rate7d);
      let color;
      if (used < 50) color = '\x1b[32m';
      else if (used < 80) color = '\x1b[33m';
      else color = '\x1b[31m';
      parts.push(`${color}⚡7d ${used}%\x1b[0m`);
    }

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
        db.prepare('INSERT OR REPLACE INTO claude_limits VALUES (?,?,?,?,?)').run(
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
