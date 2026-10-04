# Custom kitten hints processor: one picker for every link kitty can see.
# Stock --type is single (url | hyperlink | regex). This unions:
#   1. OSC 8 hyperlinks (any href, label may not be the URL)
#   2. scheme URLs as plain text
#   3. bare GitHub refs (owner/repo#N, #N)
# Used by: kitten hints --customize-processing open-screen-link.py
import re

# OSC 8: ESC ] 8 ; params ; URI (BEL | ESC \) text ESC ] 8 ; ; (BEL | ESC \)
OSC8 = re.compile(
    r'\x1b\]8;[^;]*;([^\x07\x1b]*)(?:\x07|\x1b\\)(.*?)\x1b\]8;;(?:\x07|\x1b\\)',
    re.DOTALL,
)
# Any escape sequence (CSI / OSC) so we never mark inside one.
ANSI = re.compile(r'\x1b(?:\[[0-9;?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\))')
SCHEME_OR_REF = re.compile(
    r'(?:https?|ftp|file|mailto|git|ssh|sftp):[^\s]+'
    r'|(?:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+'
)


def _expand_ref(ref: str) -> str:
    m = re.match(r'^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)#([0-9]+)$', ref)
    if m:
        return f'https://github.com/{m.group(1)}/{m.group(2)}/issues/{m.group(3)}'
    m = re.match(r'^#([0-9]+)$', ref)
    if m:
        return f'https://github.com/jaehho/dotfiles/issues/{m.group(1)}'
    return re.sub(r'[.,;:!?)\]}]+$', '', ref)


def _clean(s: str) -> str:
    return s.replace('\n', '').replace('\0', '')


def mark(text, args, Mark, extra_cli_args, *a):
    """Yield one Mark per link. groupdict['url'] is what to open."""
    idx = 0
    taken = []

    def overlaps(start, end):
        return any(not (end <= s or start >= e) for s, e in taken)

    for m in ANSI.finditer(text):
        taken.append(m.span())

    # 1. OSC 8 — open the href, show the label. Label spans sit outside escapes.
    for m in OSC8.finditer(text):
        href, label = m.group(1), m.group(2)
        start, end = m.start(2), m.end(2)
        label_c = _clean(label)
        if not label_c or not href:
            continue
        # Claim only the label; the OSC sequences are already in taken.
        yield Mark(idx, start, end, label_c, {'url': href, 'kind': 'hyperlink'}, is_hyperlink=True)
        idx += 1
        taken.append((start, end))

    # 2. Plain text URLs / bare refs outside escapes and OSC 8 labels.
    for m in SCHEME_OR_REF.finditer(text):
        start, end = m.span()
        if overlaps(start, end):
            continue
        raw = _clean(m.group(0))
        if not raw:
            continue
        taken.append((start, end))
        yield Mark(idx, start, end, raw, {'url': _expand_ref(raw), 'kind': 'text'})
        idx += 1


def handle_result(args, data, target_window_id, boss, extra_cli_args, *a):
    for match, g in zip(data['match'], data['groupdicts']):
        if not match:
            continue
        url = (g or {}).get('url') or _expand_ref(match)
        if url:
            boss.open_url(url)
