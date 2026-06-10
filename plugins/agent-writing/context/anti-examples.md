# Anti-examples

Real lines cut from shipped drafts, with the fix that replaced each one. These are not hypotheticals — every "before" survived a writer draft and at least one editor pass before the author caught it. The writer and editor load this file alongside `voice.md`; concrete negatives steer better than abstract rules.

When the editor finds a new instance of a banned shape in a shipped draft, the cut line and its fix get appended here.

## Fake accents

Emphasis constructions that carry no information. Test each: unwind into plain word order or delete — if no fact disappears, it was an accent.

**Contrastive appositive fragments**

> ~~No network — verified, not assumed.~~
> → No network, checked at runtime.

> ~~"Couldn't verify the input is clean" resolves to *refuse*, not *proceed*.~~
> → A run that can't verify its input is clean refuses to start.

> ~~Recall without a true-negative bucket measures eagerness, not judgment.~~
> → Recall without a true-negative bucket only measures how eager the agent is.

> ~~Read these as directional, not benchmark-grade.~~
> → Read these as directional estimates.

> ~~Diagnostics get logged, not gated.~~
> → Diagnostics are logged but never gate a decision.

**Staccato fragment runs**

> ~~Pick an early commit, get one number. Pick a late one, get a different number. Same agent, same reviewer, same PR.~~
> → Pick an early commit, get one number; pick a late one, get a different number — with the agent, the reviewer, and the PR unchanged.

> ~~Not flattering. Not an outlier.~~
> → The result sits right where the public floors predict.

> ~~Recall. Clean, simple, one number.~~
> → Recall: one clean number.

**Antithesis-by-negation**

> ~~"Please don't peek" is not a security boundary. It's a comment.~~
> → A prompt instruction is worth nothing once the model isn't one you tuned.

> ~~A broken eval doesn't give you a low number. It gives you an unstable one.~~
> → A broken eval usually shows up as an unstable number before it shows up as a wrong one.

> ~~you're measuring clairvoyance, not capability~~
> → the eval starts measuring clairvoyance.

> ~~it's the eval, not the agent, that compounds~~
> → the eval is the part that compounds.

**Punchline fragments restating their own paragraph**

> ~~More context, higher ceiling.~~
> → (deleted — the paragraph already said it: repo access moved recall up a third via cross-file comments.)

> ~~Pin the scorer.~~
> → (deleted — the prior sentence already says the grader sits in `immutable` and why.)

**Aphorisms paying twice for one fact**

> ~~An instruction in a prompt is a request, and you don't get to assume the next model honors your requests.~~
> → (deleted — the piece already said "a prompt instruction is worth nothing once the model isn't one you tuned.")

> ~~— nothing grades a copy of its own homework.~~
> → (deleted — the rule "the judge is a different model from the reviewer, always" plus the measured leniency already carry it.)

> ~~You can't fix a bug you mistook for a result.~~
> → (deleted — the paragraph already says the flaw hid inside a plausible-looking low recall.)

**Mirrored parallel punchlines**

> ~~Freshness hopes the model hasn't seen it. The sandbox makes having seen it useless.~~
> → (deleted — the preceding sentences already said it: the refresh protects the newest month, the sandbox protects the whole set.)

**Aphorism closers**

> ~~That's the difference between a number you report and a number you believe.~~
> → (deleted — the procedure in the same paragraph already is the point.)

## The invented narrator

Beliefs, convictions, and emotional arcs the source material doesn't document. The real story is almost always a competent engineer iterating; flaws belong to versions of the work.

> ~~Wrong #3: I trusted the prompt~~
> → Wrong #3: anti-cheat by prompt instruction

> ~~Wrong #4: I trusted recall~~
> → Wrong #4: recall without a precision control

> ~~The number came back dismal. It wasn't the clone. It was me.~~
> → The number came back dismal, and the clone had nothing to do with it.

> ~~I had been reading recall as the score, and recall had been quietly rewarding noise the whole time.~~
> → Recall was the first metric because it's the cheapest to build, and it can't be the only one.

> ~~I stared at that for a while before the lesson landed, and it's the one that changed how I think about evals.~~
> → The general point: …

> ~~several deltas I'd been quietly proud of dissolved once I knew the spread~~
> → several earlier deltas turned out to be smaller than the measured spread, so I stopped citing them.

> ~~The squash taught me to anchor to the unit I judge. The snapshot taught me… The model swap taught me…~~
> → Four flawed versions, four fixes that survived: anchor the truth to the exact unit you judge. …

## Openers

> ~~You built X, then Y happened. / Imagine you have to Y. / You're staring at X…~~
> → One opener among many; a tell when it's every piece's first move. Open on a flat statement of the work, a concrete result, or a specific moment that actually happened.
