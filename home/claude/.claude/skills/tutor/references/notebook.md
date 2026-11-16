# The teaching notebook

Read this before you build or extend a notebook that teaches a concept.

**Where.** Put it where the project keeps notebooks and follow the project's rules for them (in a marimo project, also the marimo-research skill). One notebook per concept, linked from the notebook or note whose method it explains. In a project without notebooks, ask where it goes.

**Shape.** The notebook teaches through pictures and equations, with words only to connect them.

- Integrate: every idea comes as a figure, a diagram, or a display equation, with at most two or three sentences of text between visuals. The introduction is a diagram and the question, not paragraphs of background; background enters where it is used, beside its own picture.
- Diagrams are simple and accurate: one idea each, with only the parts that idea needs (no blocks for structures the point does not use), and nothing drawn that is wrong. No diagram tries to show a whole method or structure at once. Where an accurate drawing of the real geometry is impractical, plot the real data or say it in a sentence rather than draw a simplified, wrong picture. Draw them as manim stills (the manim skill), in the style of the project's own diagrams.
- Math: each quantity gets a display equation with every symbol defined, worked once on numbers from the toy and drawn on the figure beside it (the line the formula fits, the distance it measures).
- Start from a toy small enough to see whole: a few dozen points, two or three variables, built so the answer is known.
- Put the contrasting cases side by side in every figure, the same order and colour throughout: the case without the effect beside the cases with it.
- One step per section, one figure per step. Before each figure, one sentence says what to look at; after it, one sentence says what it showed.
- Plain words. Define each term in a sentence where it first appears, with a number from the toy; give the formula after the words, not instead of them.
- After the hand-made steps, run the project's real code on the toy and show that it agrees, so the toy is a true model of the method.
- End on the real data, or link the notebook that does.
- A slider or dropdown only where changing a parameter is the lesson (a noise level, a sample size), and the figures show every case at once otherwise.

**Pace.** Build it a section at a time: write one section (its figure or diagram, its equation, a few sentences), show it, and wait for the learner's response before writing the next, unless they ask for the whole notebook.

**In the session.** Walk through it in chat one section at a time. Before a figure whose result is not obvious, ask the learner to predict it; then show it and compare. Keep the notebook short enough to finish in a session; split a second concept into its own notebook.
