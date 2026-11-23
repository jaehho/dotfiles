// Fuzzy matching for the launcher, in the manner of fzf, which rofi
// sorted drun by: the query's letters in order anywhere in the text,
// scored higher where they start a word, run together or come early.
// Smart case: a query with a capital letter matches case exactly.
.pragma library

const SEPARATORS = " -_./:";

// A match at the start of the text, or of a word in it (after a
// separator, or a capital after a small letter).
function boundary(text, j) {
    if (j === 0)
        return 8;
    const before = text[j - 1];
    if (SEPARATORS.indexOf(before) >= 0)
        return 6;
    if (before === before.toLowerCase() && text[j] !== text[j].toLowerCase())
        return 5;
    return 0;
}

// The best score of `query` in `text`, or -Infinity when the letters do
// not all appear in order. One pass per query letter: each letter's best
// score at every position, from the previous letter's run (+4) or across
// a gap (-0.5 a skipped letter).
function score(query, text) {
    if (query === "")
        return 0;
    if (!text)
        return -Infinity;
    const exact = query !== query.toLowerCase();
    const q = exact ? query : query.toLowerCase();
    const t = exact ? text : text.toLowerCase();
    const n = t.length;
    let row = new Array(n).fill(-Infinity);
    for (let j = 0; j < n; j++)
        if (t[j] === q[0])
            row[j] = 1 + boundary(text, j) - 0.1 * j;
    for (let i = 1; i < q.length; i++) {
        const next = new Array(n).fill(-Infinity);
        // max over k < j - 1 of row[k] + 0.5 k, for the gapped step.
        let reach = -Infinity;
        for (let j = 1; j < n; j++) {
            if (j >= 2)
                reach = Math.max(reach, row[j - 2] + 0.5 * (j - 2));
            if (t[j] !== q[i])
                continue;
            const run = row[j - 1] + 4;
            const gap = reach - 0.5 * (j - 1);
            const best = Math.max(run, gap);
            if (best > -Infinity)
                next[j] = best + 1 + boundary(text, j);
        }
        row = next;
    }
    let best = -Infinity;
    for (let j = 0; j < n; j++)
        best = Math.max(best, row[j]);
    if (best === -Infinity)
        return best;
    // A prefix beats any scattered match; shorter texts edge out longer.
    return best + (t.startsWith(q) ? 10 : 0) - 0.02 * n;
}
