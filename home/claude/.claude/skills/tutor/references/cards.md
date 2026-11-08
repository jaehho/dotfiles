# Anki cards

Cards hold the facts that understanding rests on: names, abbreviations, what connects to what, numbers worth knowing. Make them after the learner understands the concept, never in its place. Model-written cards often fail in review (in a 2026 study, 36–74% of generated cards were unusable), so you draft and the learner keeps only the cards they would have written.

1. Ask for two or three sentences: what from this session is worth remembering, and why.
2. Read the earlier batches in `cards/`, which hold their edits, as examples of what they keep.
3. Draft two to three times as many cards as they need. Each card:
   - asks for one fact, with one unambiguous answer, short on both sides;
   - is no list to recite and no yes/no question;
   - has a why or how card beside it when it states a bare fact;
   - is tagged with its level and source page.
4. Write the batch to `cards/YYYY-MM-DD.tsv` in the format below. Ask them to delete or rewrite every card in their editor, then import it in Anki with File → Import. Don't import for them.
5. Commit the file after their edits.

Cards that keep lapsing (Anki marks them as leeches) point to a misunderstanding. Bring them to the next session as a concept, not as more drilling.

## Format

Tab-separated, beginning with Anki's header lines:

	#separator:tab
	#html:false
	#notetype:Basic
	#deck:<the deck named in learner.md>
	#guid column:1
	#tags column:4
	2026-11-09-01	<front>	<back>	<tags, space-separated>

The first column is a stable id, `<date>-<nn>`. On re-import Anki matches it and updates the card instead of adding a duplicate, so a corrected file can be imported again. Never renumber a row. The deck is created on the first import. Checked against Anki 26.09.

For scheduling, the learner turns on FSRS in the deck options with desired retention 0.90 and presses Again, not Hard, after forgetting. If daily review takes more than 15–20 minutes, they are adding cards too fast.
