# Mediate RBAC in code

*How do I bind this adapter, and what mechanism answers each rule shape? For an adopter whose rules are Elixir modules.*

`Mediate.Rbac` decides from a policy module the application compiles. Nothing runs beside the application, a deploy is a policy version, and revocation is one commit.

## How to bind

The configuration entry is the bare module, `adapter: Mediate.Rbac`. After the configuration boots, bind the policy and the repo, then publish the version. `Mediate.Rbac.Binding` has the options.

```elixir
{:ok, _binding} = Mediate.Rbac.Binding.bind(policy: MyApp.Roles, repo: MyApp.Repo)
{:ok, _event} = Mediate.Rbac.publish()
```

## The declarations

A policy module is `use Mediate.Rbac.Policy`, and its moduledoc has the options in full.

- `role name, permissions` is one row of the role table.
- `object Schema do ... end` names a protected schema and its clauses.
- `grant name, RelationshipSchema` holds a role on a row through the relationship the schema declares, with `on:`, `role:`, `as:`, or `through:` where the declaration is not enough.
- `predicate name, &Module.function/2` is a function of the subject and the environment that returns a `dynamic` over the row or a boolean, limited to some operations with `only:`.
- `use` takes `version:`, `author:`, and `approval:`.

The rule allows an operation on a row when any grant holds a role that permits it and every applicable predicate holds.

## Mechanism per rule shape

| Rule shape | Mechanism |
|---|---|
| A role held on a row | a grant through the relationship schema, with `through:` where the relationship is one or more hops away |
| A test on the subject or the row | a predicate that returns a `dynamic`, read at the call from the environment the port stamped |
| A rule over a whole type | the same clauses composed into the `dynamic` that `scope` returns, so a scoped query and a checked row agree |
| A write gate | the role table alone. The seam refuses the write itself when no decision for the operation exists |

## What this adapter decided

- **Predicates return a `dynamic`, and the adapter puts it in the query.** A predicate that loads the row and answers in Elixir was the alternative. One query answers `check` and `scope` alike, so the two cannot disagree.
- **The role table is declared data.** A function per role was the alternative. Data is what the access review reports and what the version hashes.
- **The version is the commit the application names, and the content is the rule modules' hash and the role table.** The source text was the alternative, and a hash is what a reviewer compares.

Revocation latency has one component, commit. A write that revokes is visible to the next query.
