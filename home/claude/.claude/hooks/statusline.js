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
    const dir = path.basename(data.workspace?.current_dir || process.cwd());
    const session = data.session_id || '';
    const remaining = data.context_window?.remaining_percentage;
    const totalIn = data.context_window?.total_input_tokens || 0;
    const totalOut = data.context_window?.total_output_tokens || 0;
    const cost = data.cost?.total_cost_usd;
    const rate5h = data.rate_limits?.five_hour?.used_percentage;
    const rate5hResets = data.rate_limits?.five_hour?.resets_at;

    const parts = [];

    // Model
    parts.push(`${dim}${model}${rst}`);

    // Context window bar (10 segments, fills as context is consumed)
    const AUTO_COMPACT_BUFFER_PCT = 16.5;
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

    // Session cost
    if (cost != null && cost > 0) {
      const label = hints ? `~$${cost.toFixed(2)} worth of API usage` : `$${cost.toFixed(2)}`;
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

    // Working directory
    parts.push(`${dim}${dir}${rst}`);

    process.stdout.write(parts.join(' │ '));
  } catch {}
});
