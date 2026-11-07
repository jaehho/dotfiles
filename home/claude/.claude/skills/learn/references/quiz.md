# Quizzes and the closed-book test

A grade worked out after the learner answers drifts toward their answer. A key written and committed before they answer cannot, and the commit time shows it came first. Keep the key out of sight as well: the learner can read every tool call in the terminal, and your own hints drift toward a key you have in context.

## Weekly quiz

1. Choose the material: concepts met so far, the retests due in learner.md, and two or three earlier concepts that are easy to confuse with recent ones. Aim for a level they get mostly right; below about half right, retrieval teaches little.
2. Hand the writing to a subagent, so neither the learner nor you sees the key. Give it the learning folder, the concepts, the sources to draw on, and the number of questions (eight to ten unless the learner asks otherwise). Tell it to:
   - write short-answer questions at three levels: what (a definition or fact), why or how (a mechanism), and apply (an experiment or case not in the sources);
   - write the questions alone to `quizzes/YYYY-MM-DD.md`, one `##` section each;
   - write the key to `quizzes/.keys/YYYY-MM-DD.md`: for each question the answer, its source (page or figure), and a common wrong answer;
   - commit both files, and reply with only the path of the questions file.

   Without a subagent tool, write the key yourself and tell the learner beforehand to look away from that tool call.
3. Ask the questions one at a time. After each answer, ask for their confidence from 1 (a guess) to 4 (certain). Give no feedback until every question is answered, and don't open the key before then.
4. Write their answers and confidence into the quiz file and commit, then read the key and grade each answer against it rather than judging afresh. If an answer is right but not in the key, say so and say why the key missed it.
5. Add each grade, and on a miss the key's answer and source, to the quiz file. In learner.md, log every wrong answer rated 3 or 4 under Confident errors, update statuses and retests, and commit.
6. Spend the rest of the session on the confident errors first.

## Closed-book test

Every three to four weeks, a longer test on material from one to three weeks back. The subagent writes it as above, to `quizzes/YYYY-MM-DD-closed.md`. The learner takes it on paper or in the file, without notes, without AI and outside this session, and adds a confidence rating to each answer. Grade it the same way when they return. It is the only measure of what they can do alone, so give no help during it.
