# CUE/Fibonacci story points

Story points are a relative planning signal, not a duration, SLA, agent quota, or performance score. Use Fibonacci values `1, 2, 3, 5, 8, 13`.

Judge Complexity, Uncertainty, and Effort (CUE) together; do not add them as a formula or score each factor independently. Prefer independently acceptable 1–5 point slices. Challenge 8/13 point work; anything above 13 must be decomposed before it is ready.

## Required card evidence

Each delivery card records its story-point value, `estimation_model=CUE/Fibonacci`, a brief CUE rationale, complexity tier and rationale, routing lane, exact write set, dependencies, and observable acceptance criteria. Exactly one `SP:<N>` label and one matching numeric metadata value are allowed.

Estimate coordination only for a genuine coordination umbrella; implementation, QA, integration, release, migration, and Windows validation remain real independently scoped outcomes when required. A documentation-only slice is still estimated by uncertainty and review burden, not by line count.

The PM owns readiness and may re-estimate when evidence changes. The dispatcher performs no product or estimation judgment. Developers and QA report evidence; they do not self-claim or rewrite a card's estimates.
