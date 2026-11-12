// Hint keys, as in tridactyl's hint mode: a letter (or two) for every
// control on a sheet, typed to press it. Letters come from the names,
// the first letter of a name where it is free, then the first letters of
// its other words, then its other letters. No code is the start of
// another, so a code is pressed the moment it is complete.
.pragma library

// Without the sheets' own keys (h j k l, and q), for the quick settings.
const KEYS = "asdfgewrtyuiopzxcvbnm";
const ALL = "abcdefghijklmnopqrstuvwxyz";

// One code per name, in order. A name's first letter goes to the first
// of the names that starts with it; the rest take another initial or
// letter of their own words, and as a last resort any letter left.
//
// Past one letter each, the commonest initials become prefixes, as many
// as the overflow needs, and the names that start with one are coded
// as that letter and the next that is theirs and free: "so" for Sound,
// "su" for Suspend, "sh" for Shut down. Whatever still has no code
// takes a prefix and any letter left.
function named(names, allowed) {
    const n = names.length;
    const words = names.map(s => s.toLowerCase().replace(/[^a-z]+/g, " ").split(" ").filter(w => w !== ""));
    const initial = words.map(w => w.length > 0 ? w[0][0] : "");
    const own = i => words[i].map(w => w[0]).concat(Array.from(words[i].join("")));

    // Commonest initials first, ties in the order of the alphabet given.
    let prefixes = "";
    if (n > allowed.length) {
        const count = {};
        initial.forEach(c => count[c] = (count[c] ?? 0) + 1);
        const need = Math.ceil((n - allowed.length) / (allowed.length - 1));
        prefixes = Array.from(allowed).filter(c => count[c]).sort((x, y) => count[y] - count[x]).slice(0, need).join("");
        for (let c of allowed) {
            if (prefixes.length >= need)
                break;
            if (prefixes.indexOf(c) < 0)
                prefixes += c;
        }
    }
    const singles = Array.from(allowed).filter(c => prefixes.indexOf(c) < 0).join("");

    const out = new Array(n).fill("");
    const used = {};
    const take = (i, code) => {
        if (used[code])
            return false;
        used[code] = true;
        out[i] = code;
        return true;
    };
    const single = (i, ch) => singles.indexOf(ch) >= 0 && take(i, ch);

    for (let i = 0; i < n; i++)
        if (prefixes.indexOf(initial[i]) < 0 && initial[i] !== "")
            single(i, initial[i]);
    for (let i = 0; i < n; i++)
        if (out[i] === "" && prefixes.indexOf(initial[i]) >= 0)
            Array.from(words[i].join("")).slice(1).concat(own(i)).some(c => allowed.indexOf(c) >= 0 && take(i, initial[i] + c));
    for (let i = 0; i < n; i++)
        if (out[i] === "")
            own(i).some(ch => single(i, ch));
    for (let i = 0; i < n; i++) {
        if (out[i] !== "")
            continue;
        if (!Array.from(singles).some(ch => single(i, ch)))
            Array.from(prefixes).some(p => Array.from(allowed).some(c => take(i, p + c)));
    }
    return out;
}

// The hint letter a key stands for, or "".
function letter(text, allowed) {
    const t = text.toLowerCase();
    return t.length === 1 && allowed.indexOf(t) >= 0 ? t : "";
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
