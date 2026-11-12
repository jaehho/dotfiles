// Hint keys, as in tridactyl's hint mode: a letter (or two) for every
// control on a sheet, typed to press it. No code is the start of
// another, so a code is pressed the moment it is complete. The letters
// leave out the sheets' own keys (h j k l, and q), so the two never
// meet.
.pragma library

const KEYS = "asdfgewrtyuiopzxcvbnm";

// n codes, singles first: with more controls than letters, the last
// letters become prefixes and carry the overflow as two-letter codes.
function codes(n) {
    const k = KEYS.length;
    if (n <= k)
        return Array.from(KEYS.slice(0, n));
    const prefixes = Math.ceil((n - k) / (k - 1));
    const singles = k - prefixes;
    const out = Array.from(KEYS.slice(0, singles));
    for (let p = singles; p < k && out.length < n; p++)
        for (let q = 0; q < k && out.length < n; q++)
            out.push(KEYS[p] + KEYS[q]);
    return out;
}

// The hint letter a key stands for, or "".
function letter(text) {
    const t = text.toLowerCase();
    return t.length === 1 && KEYS.indexOf(t) >= 0 ? t : "";
}

// One more letter typed: the new buffer, and the index of the code it
// completes, or -1. A letter that starts no code clears the buffer.
function step(typed, ch, list) {
    const next = typed + ch;
    const hit = list.indexOf(next);
    if (hit >= 0)
        return {
            typed: "",
            hit: hit
        };
    return {
        typed: list.some(c => c.startsWith(next)) ? next : "",
        hit: -1
    };
}
