# Resonant English Braille curriculum

## Lesson 1: Learn Resonant

The first-launch introduction contains ten spoken steps. It teaches the lesson
flow, six-dot cell, dot numbers and positions, selection and clearing, audio and
haptics, the tutor, safe TalkBack navigation, and how letter practice and word
tests work. At the dot practice step, learners must select a dot and clear it
again before continuing. Swipe up in the dedicated lesson footer to continue;
swipe down to review. TalkBack users use the matching custom actions so normal
screen-reader swipes are not captured. The current step is saved offline.
Existing installs replay the revised operating lesson once after upgrade;
saved letter and test results are preserved and resume after Lesson 1.

## Lesson 2 and later: English letters

`LessonCatalog.curriculum` defines the required progression and all stage word
banks. `EnglishGrade1Engine` provides every letter cell and validates submitted
cell sequences.

| Group | Newly taught letters | Allowed test letters | Word bank (all entries required) |
|---|---|---|---|
| A–E | A, B, C, D, E | A–E | BAD, CAB, BED, ACE, DECADE |
| F–J | F, G, H, I, J | A–J | FEED, DECAF, JAB, FACE, CAB |
| K–O | K, L, M, N, O | A–O | JAM, MOON, FAD, MAKE, CODE |
| P–T | P, Q, R, S, T | A–T | TASTE, MARKET, STEAM, THREAD, MIST |
| U–Z | U, V, W, X, Y, Z | A–Z | AMAZE, BELL, FIZZ, WAVE, QUIZ |

After all five stage tests, a cumulative assessment uses these progressively
longer words: AB, BAD, FEED, AMAZE, DECADE. Word banks are checked in tests so
each word uses only letters allowed for its stage. The W cell is taken from the
engine's explicit mapping.

## Practice and progress

Each new letter is taught in order with engine-derived dot numbers and spatial
positions. The learner enters its pattern through the existing six-dot
keyboard. One correct, deterministic cell submission marks that letter
mastered. A word is scored only after all of its cells have been submitted and
the engine decodes the complete sequence to the requested word. All words in a
stage bank must be correct before the next letter group opens. Incorrect words
can be retried. A learner can clear a cell before submitting it.

Letter attempts and each word result are stored in the local offline event
store. The submission ID is unique for each event. On relaunch, the app resumes
the first unmastered letter, first unfinished word in the current stage, next
stage, or cumulative assessment. PostgreSQL synchronization and physical-device
resume behavior have not been verified as part of this curriculum change.

## Chapter 3: English words

After the complete letter course, the learner can continue into five ordered,
persisted word lessons:

1. **Build your first words:** review letters, learn that a word is a sequence
   of cells, and explore CAT, BAT, and MAT.
2. **Read familiar words:** hear and identify SUN, DOG, HAT, and PEN with
   letter-by-letter cell cues.
3. **Write the word:** enter every verified cell with the six-dot keyboard.
   The uppercase lesson words include the engine's capital-word indicator.
4. **Read and identify:** explore Braille cell symbols and identify a word
   without the printed answer being announced first.
5. **Word mastery test:** write five mixed familiar words; at least four must
   be correct on the first try. The learner can retry the test.

Attempts, hints, response times, and mastery test rounds use the existing
offline event log. A group ID keeps each mastery round separate, so a failed
or interrupted attempt cannot combine with older results to unlock the course.
The keyboard matches the current landscape reference image: screen-left dots
4, 5, 6 from top to bottom and screen-right dots 1, 2, 3. Dot values and
six-bit cell encoding remain unchanged.

## Current limits

The curriculum uses uncontracted English cells and does not teach UEB
contractions. Letter and word mappings use the project's documented English
Braille subset. A–E and its full word bank are covered end to end by widget
tests. The stage table, word restrictions, and cell round trips for every bank
are automated-tested; full hands-on interaction with F–Z has not been run on a
physical phone. See [Braille standards](braille-standards.md) for language and
UEB limitations.
