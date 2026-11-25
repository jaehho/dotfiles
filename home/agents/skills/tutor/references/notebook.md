# The primer in a session

Read this before you build or extend the subject's primer in a session. The primer reference that SKILL.md names sets its shape; this file adds only what a session needs.

- **Which primer.** One per subject; a new concept in the subject is a new section. When the learner studies a paper, ask whether it gets its own primer or sections of the subject's, and, until a notebook links to it, where it goes.
- **Outside marimo-research projects.** In a project whose notebooks are not marimo research notebooks, follow the project's notebook rules and keep the primer reference's Shape, Figures and Toy examples. In a project without notebooks, ask where it goes; a standalone primer declares its dependencies inline (`marimo edit --sandbox`).
- **Pace.** One section per step of the session: walk through it in chat and wait for the learner before the next, unless they ask for the whole primer. Before a section whose figure's result is not obvious, ask for the prediction first, then write the section and compare. Keep a session to what can be finished in it.
- **Session-only work** goes in a scratch notebook in the learning folder (`scratch.py`), never in the primer: a figure drawn for a stuck learner (one of a wrong belief included), a changed toy, worked-example blanks with `TODO(human)`, and pass-three reproductions. The primer holds only what reads without the session.
