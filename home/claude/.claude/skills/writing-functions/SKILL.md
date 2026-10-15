---
name: writing-functions
description: Rules for writing, naming, or changing a Python function so that a reader and a test can reason about its body alone (parameters, returns, names, levels of abstraction). Use whenever adding or editing a function, method, or helper, in a package, a script, or a notebook.
---

# Writing a function

A reader, and a test, should be able to reason about a body without the rest
of the code (after Logan Smith, "How to write the perfect function").

Before writing one, look for a similar function in the project and reuse it.
Extend it only when the new case is the same job.
Where the function lives, and its docstring and example format, follow the
project's own rules.

## Honest

Everything the result depends on is a parameter: a cutoff, a column name, a
seed, the current time.
A default is fine (`cutoff: int = MIN_COUNT`);
reading a setup constant, the project's config module, a global, or the clock
in the body is not.
Files, the network, and writes belong to the shell (the loaders, the fetch
code, a script's top level), which calls honest functions.
If a test would need a mock or a fixture file, look for what the body reads
that is not a parameter.
A figure function may read the base look (theme, palette) set once at
startup.

## Clear to the caller

- The name is a noun phrase for what it returns (`fit_summary`) or a verb
  phrase for what it does (`add_legend`), reads well at the call site
  (`rows_between(table, start, stop)`), and promises neither less nor more
  than the function does.
  No catch-all words (`output`, `process`, `get`, `data`).
- Parameters are named for their role (`window_size`, not `n`), options are
  keyword-only, and a function asks for no more than its body uses.
- It returns a `NamedTuple`, a dataclass, or a frame whose columns the
  docstring lists, not a dict with string keys, and never `None` or a
  sentinel for failure.
- A precondition the types cannot state raises a `ValueError` that says
  which.

## One level of abstraction

A body calls smaller named functions instead of mixing levels;
a comment that labels a section of the body marks a piece to name.
Reuse what the caller already computes (a CCDF, an overlap index);
a second copy drifts.
Producing data and acting on it (plotting, writing) are two functions.
