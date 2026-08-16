## Next-phase contract

`next_phase_contract.feature.json` is a single discoverable, default-off feature
manifest. The feature offers a bounded opt-in before its own normal-battle
phase. Decline or timeout persist no risk; Accept checkpoints `armed` before
spawning the marked phase. An interrupted run resumes the armed phase on retry.

The reward is derived from route depth, capped by manifest data, and claimed
only after a persisted success checkpoint. The claim checkpoint is written
before reward transfer so retries cannot duplicate XP or gold.
