# Finding and attaching PDFs

Routes seen in 2026-10. Hosts change their blocking, so recheck a route that fails before calling a paper unavailable.

## Attach

- `zotero_add_item(if_exists='file')` stops at an existing item and never attaches the open-access PDF, even with `attach_mode='required'`. Download the file locally, then `zotero_attach_file`.
- Attach a preprint only when its title matches the item. An older, differently titled preprint on a published item misrepresents the record.

## Where to look, in order

1. Unpaywall, and Europe PMC's core search, for a PMCID or PDF URL.
2. Europe PMC `SRC:PPR` title search, for preprints hosted elsewhere (it finds preprints of paywalled papers).
3. OpenAlex or Semantic Scholar, for repository mirrors. The fatcat.wiki API is dead.

## Hosts

- These refuse curl with a browser user agent and the MCP's server-side downloader (`url=`) alike, with 403 or 406: cell.com, sciencedirect.com, nature.com, elifesciences.org, europepmc.org, researchgate.net, direct.mit.edu.
- bioRxiv works directly (`https://www.biorxiv.org/content/{doi}v1.full.pdf`) but answers 429 when rushed: space requests about 10 s apart and retry.
- PMC (`https://pmc.ncbi.nlm.nih.gov/articles/{PMCID}/pdf/`) first returns a proof-of-work page with `POW_CHALLENGE` and a difficulty N. Find a nonce for which `sha256(challenge + nonce).hexdigest()` starts with N zeros, then request again with the cookie `{POW_COOKIE_NAME}={challenge},{nonce}`.
