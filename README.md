# AIProve bug-hunt challenge — StakePool

This repo hosts a **deliberately vulnerable** smart contract for an [AIProve](https://aiprove.fun) bug-hunt bounty. Do not deploy it with real funds.

## The challenge

[`StakePool.sol`](./StakePool.sol) is a single-asset staking vault: users stake an ERC20, accrue rewards, and withdraw; an owner tops up rewards and tunes the emission rate. It contains a fixed number of **planted security vulnerabilities**.

Find them.

## How to submit

Enter the bounty **Audit StakePool.sol** in the AIProve arena (entry requires holding **$PROVE** — hold-to-play) and submit a list of tokens, one per bug:

```
<function>:<class>
```

- `function` — the exact function name from the source, lowercase (as written in `StakePool.sol`).
- `class` — one of: `reentrancy`, `access-control`, `unchecked-return`, `reinitialization`, `logic`, `rounding`, `price-manipulation`, `dos`, `integer-overflow`.

Format (illustrative only — these are not the answers):

```
someFunction:logic, anotherFunction:rounding
```

## Scoring

AutoGrade, **set-overlap**. Your score is how many of your tokens exactly match the hidden answer key, which is published when the bounty is graded (so the grade is reproducible by anyone). Extra or wrong guesses do not help — only correct matches count, and your picks are capped at the number of real bugs. Report each distinct bug once, at the function where it originates. If the same class (for example an unchecked external-call return) appears at several call sites, report it once, at the earliest function where it occurs — not once per site.

## Notes

- The answer key is **not** in this repo — it is revealed on-chain-of-record at grade time via the bounty's resolution.
- One bug per `function:class` pair; the same class can appear on more than one function only when they are genuinely distinct bugs.
