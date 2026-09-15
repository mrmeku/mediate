# Mediate: rules for agents

## Read first

Read `README.md`, then `docs/design.md`, `docs/requirements.md`, `docs/conformance.md`, `docs/events.md`, and `docs/contributing.md`, in that order, before any stage. `docs/contributing.md` says how a stage runs, what it records, and which gate each package passes.

## Prose

`docs/contributing.md` §4 has the rules. The gate, over every changed document, must print `exit=1`. `docs/contributing.md` §4 is the one exception, because it lists the words:

```
grep -rniE "\b(simply|just|obviously|easy|easily|of course|basically|note that|in order to)\b|!|—" <files> ; echo "exit=$?"
```

## Placement and code

- `docs/design.md` §6 says where a module goes and which way calls run. Ask its question before you add a module.
- `docs/contributing.md` §3 has the code rules, and §1 has the pins. Pin every external version and say where you verified it.

## Process

- Stages run one at a time, on `main`, with no worktree, by the steps in `docs/contributing.md` §5.
- A stage ends when its gate from `docs/contributing.md` §5 passes. Then one or more commits follow, unsigned: `git -c commit.gpgsign=false commit`. One idea per commit. The last commit message quotes the gate's output and records what `docs/contributing.md` §5 asks.
- Push after every commit.
- A question to the owner carries a plain-language preamble inside the question text itself, before the choices. The preamble says what the thing is, why it matters, and what each choice costs. Prose outside the question does not reach the owner.
