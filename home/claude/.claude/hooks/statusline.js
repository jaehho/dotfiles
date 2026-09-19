#!/usr/bin/env node
// Claude Code usage monitor — context bar, tokens, cost, rate limit
// Run `! claude-hints` to briefly show labels (auto-expires after 30s)

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
    const rst = '\x1b[0m';

    // Check for auto-expiring hints (< 30s old)
    let hints = false;
    try {
      const ts = parseInt(fs.readFileSync('/tmp/claude-statusline-hints', 'utf8'));
      hints = Math.floor(Date.now() / 1000) - ts < 30;
    } catch {}

    const model = data.model?.display_name || 'Claude';
    const modelId = data.model?.id || '';
    const dir = path.basename(data.workspace?.current_dir || process.cwd());
    const session = data.session_id || '';
    const remaining = data.context_window?.remaining_percentage;
    const totalIn = data.context_window?.total_input_tokens || 0;
    const totalOut = data.context_window?.total_output_tokens || 0;
    const cost = data.cost?.total_cost_usd;
    const rate5h = data.rate_limits?.five_hour?.used_percentage;
    const rate5hResets = data.rate_limits?.five_hour?.resets_at;

    // Gateway models (claude-or on z.ai): the CLI can't price them
    // (costUSD stays 0) and its context window can stick at 100% after a
    // resume, so both are computed from the transcript's own usage entries.
    // Credit multipliers per docs.z.ai pricing, per 10k credits
    // [input, cache-read, output]; flash 2.3/0.56/8, glm-5.3 6.9/1.7/24;
    // off-peak (outside 14:00-18:00 Singapore, Mon-Fri) is half price.
    // OpenRouter turns report the "z-ai/..." slug and are skipped: they
    // never billed z.ai credits.
    const glmMult = m => !m ? null
        : m.includes('flash') ? [2.3, 0.56, 8]
        : m.startsWith('glm') ? [6.9, 1.7, 24] : null;
    // OpenRouter list prices per M tokens [input, cache-read, output]:
    // the "what would this session have cost there" counterfactual
    const orPrice = m => !m ? null
        : m.includes('flash') ? [0.09, 0.018, 0.30]
        : m.startsWith('glm') || m.startsWith('z-ai/') ? [0.91, 0.169, 2.86] : null;
    const isPeakSgt = ts => {
        const sgt = new Date(ts + 8 * 3600e3);
        const h = sgt.getUTCHours(), day = sgt.getUTCDay();
        return h >= 14 && h < 18 && day >= 1 && day <= 5;
    };
    function transcriptUsage(transcriptPath) {
        if (!transcriptPath || !fs.existsSync(transcriptPath)) return null;
        let credits = 0, orUsd = 0, anyGlm = false, lastUsage = null;
        try {
            for (const line of fs.readFileSync(transcriptPath, 'utf8').split('\n')) {
                if (!line.includes('"usage"')) continue;
                let d;
                try { d = JSON.parse(line); } catch { continue; }
                const m = d.message || {};
                const u = m.usage;
                if (!u) continue;
                lastUsage = u;
                const raw = m.model || '';
                const orp = orPrice(raw);
                if (orp) {
                    orUsd += (u.input_tokens * orp[0] +
                        (u.cache_read_input_tokens || 0) * orp[1] +
                        (u.cache_creation_input_tokens || 0) * orp[0] +
                        u.output_tokens * orp[2]) / 1e6;
                }
                // turns that ran on OpenRouter (z-ai/... slug) drew no z.ai credits
                const mult = raw.startsWith('z-ai/') ? null : glmMult(raw);
                if (!mult) continue;
                anyGlm = true;
                const ts = Date.parse(d.timestamp || '') || Date.now();
                const c = (u.input_tokens * mult[0] +
                    (u.cache_read_input_tokens || 0) * mult[1] +
                    (u.cache_creation_input_tokens || 0) * mult[0] +
                    u.output_tokens * mult[2]) / 10000;
                credits += isPeakSgt(ts) ? c : c / 2;
            }
        } catch { return null; }
        return { credits: anyGlm ? credits : null, orUsd, lastUsage };
    }
    const tu = transcriptUsage(data.transcript_path);

    const parts = [];

    // Model
    parts.push(`${dim}${model}${rst}`);

    // Context window bar (10 segments, fills as context is consumed)
    const AUTO_COMPACT_BUFFER_PCT = 16.5;
    const windowTokens = /1m/i.test(modelId) ? 1e6 : 200000;
    let effRemaining = remaining;
    if (tu && tu.lastUsage && (effRemaining == null || effRemaining >= 99.9)) {
        const u = tu.lastUsage;
        const ctx = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) +
            (u.cache_creation_input_tokens || 0) + (u.output_tokens || 0);
        effRemaining = Math.max(0, 100 * (1 - ctx / windowTokens));
    }
    if (effRemaining != null) {
      const usable = Math.max(
        0,
        ((effRemaining - AUTO_COMPACT_BUFFER_PCT) /
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

      const label = hints ? `context ${bar} ${used}% full` : `${bar} ${used}%`;
      parts.push(`${color}${label}${rst}`);

      // Bridge file for GSD context-monitor
      if (session) {
        try {
          fs.writeFileSync(
            path.join(os.tmpdir(), `claude-ctx-${session}.json`),
            JSON.stringify({
              session_id: session,
              remaining_percentage: remaining,
              used_pct: used,
              timestamp: Math.floor(Date.now() / 1000),
            }),
          );
        } catch {}
      }
    }

    // Token count
    const total = totalIn + totalOut;
    if (total > 0) {
      let tokens;
      if (total >= 1_000_000) tokens = `${(total / 1_000_000).toFixed(1)}M`;
      else if (total >= 1_000) tokens = `${Math.round(total / 1_000)}K`;
      else tokens = `${total}`;
      const label = hints ? `${tokens} tokens used` : tokens;
      parts.push(`${dim}${label}${rst}`);
    }

    // Session cost — Anthropic sessions only: for glm the CLI falls back to
    // Claude-table pricing (~12x z.ai list), so the credits meter replaces it
    if (cost != null && cost > 0 && !(tu && tu.credits != null)) {
      const label = hints ? `~$${cost.toFixed(2)} worth of API usage` : `$${cost.toFixed(2)}`;
      parts.push(`${dim}${label}${rst}`);
    }

    // z.ai coding-plan credits + the OpenRouter counterfactual
    if (tu && ((tu.credits != null && tu.credits > 0) || tu.orUsd > 0)) {
      const hasCr = tu.credits != null && tu.credits > 0;
      const label = hints
        ? (hasCr ? `${tu.credits.toFixed(0)} z.ai list-price credits` : '') +
          (tu.orUsd > 0 ? `${hasCr ? ' · ' : ''}would be $${tu.orUsd.toFixed(2)} on OpenRouter` : '')
        : (hasCr ? `${tu.credits.toFixed(0)} cr` : '') +
          (tu.orUsd > 0 ? `${hasCr ? ' · ' : ''}$${tu.orUsd.toFixed(2)} or` : '');
      parts.push(`${dim}${label}${rst}`);
    }

    // Rate limit (5h window — Claude Max/Pro)
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

      const label = hints
        ? `⚡${used}% of 5h limit used` + (time ? `, resets in ${time}` : '')
        : `⚡${used}%` + (time ? ` ${time}` : '');
      parts.push(`${color}${label}${rst}`);
    }

    // 7-day subscription window (same server data, slower pool)
    const rate7d = data.rate_limits?.seven_day?.used_percentage;
    if (rate7d != null) {
      const used = Math.round(rate7d);
      let color;
      if (used < 50) color = '\x1b[32m';
      else if (used < 80) color = '\x1b[33m';
      else color = '\x1b[31m';
      const label = hints ? `⚡7d ${used}% of weekly limit used` : `⚡7d ${used}%`;
      parts.push(`${color}${label}${rst}`);
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

    // Working directory
    parts.push(`${dim}${dir}${rst}`);

    process.stdout.write(parts.join(' │ '));
  } catch {}
});
