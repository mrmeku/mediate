# Mediate roles in code

*How do I bind this engine, and what mechanism answers each rule shape? For a deployment whose policy is an Elixir module.*

`Mediate.Rbac` decides from a policy module the deployment compiles. Nothing runs beside the deployment, a deploy is a policy version, and revocation is one commit.

## The words

Inside `infrastructure/` the package speaks in its own words, and at its root it speaks the ledger's. `docs/naming.md` under "Roles in code" has every row and why.

| This engine says | The ledger says | Here it is |
|---|---|---|
| policy module | policy | the versioned whole, one module under `use Mediate.Rbac.Policy` |
| role table | actions | what `role/2` declares: a role and the actions it allows |
| resource block | protected schema | what `resource/2` names, and the rules inside the block |
| grant rule | grant | a rule that reads the rows a schema declared with `grant/1` |
| predicate rule | rule | one line that runs a function of the subject and the context |
| hop, hop filter | grant | one step of a `through:` chain, and the `where:` that narrows it |
| binding | configuration | the policy module and the repo kept at boot, beside the core's configuration |
| `rule`, `matched` | `meta` | the rule that spoke and every rule that held, on the verdict |

## How to bind

The configuration entry is the bare module, `engine: Mediate.Rbac`. After the configuration boots, bind the policy module and the repo, then release the policy version. `Mediate.Rbac.Binding` has the options.

```elixir
{:ok, _binding} = Mediate.Rbac.Binding.bind(policy: MyApp.Policy, repo: MyApp.Repo)
{:ok, _release} = Mediate.Rbac.release()
```

## The declarations

A policy module is `use Mediate.Rbac.Policy`, and its moduledoc has the options in full.

- `role name, actions` is one row of the role table.
- `resource Schema do ... end` is the resource block: a protected schema and its rules.
- `grant name, GrantSchema` is a grant rule. It holds a role on a row through the grant the schema declares, with `on:`, `role_column:`, `role:`, or `through:` where the declaration is not enough.
- `predicate name, &Module.function/2` is a predicate rule: a function of the subject and the context that returns a `dynamic` over the row or a boolean, limited to some actions with `actions:`.
- `use` takes `version:`, `author:`, and `approval:`.

The rules allow an action on a row when any grant rule holds a role that permits it and every predicate rule that applies holds.

## Mechanism per rule shape

| Rule shape | Mechanism |
|---|---|
| A role held on a row | a grant rule through the grant schema, with `through:` where the grant is one or more hops away |
| A test on the subject or the row | a predicate rule that returns a `dynamic`, read at the call from the context the core stamped |
| A rule over a whole type | the same rules composed into the `dynamic` that `filter` returns, so a filtered query and an authorized row agree |
| A write gate | the role table alone. The core refuses the write itself when no decision for the action exists |

## What this engine decided

- **Predicates return a `dynamic`, and the engine puts it in the query.** A predicate that loads the row and answers in Elixir was the alternative. One query answers `authorize` and `filter` alike, so the two cannot disagree.
- **The role table is declared data.** A function per role was the alternative. Data is what the access review reports and what the version hashes.
- **The policy version is the one the deployment names, and the text is the module list with each module's digest and the role table.** The source text was the alternative, and a hash is what a reviewer compares.
- **Every message names the policy module first.** The reader opens the right file before reading the rest.

Revocation latency has one component, commit. A write that revokes is visible to the next query.
