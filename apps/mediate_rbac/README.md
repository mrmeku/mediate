# Mediate RBAC in code

The adapter whose rules are Elixir modules: `Mediate.Rbac`. A deploy is a policy version, and revocation is one commit. The boundary cost is none, because nothing runs beside the application. The adapter takes no options, so its configuration entry is the bare module.

## Mechanism per rule shape

| Rule shape | Mechanism |
|---|---|
| A role held on a row | a grant through the relationship schema, with `through:` where the relationship is one or more hops away |
| A test on the subject or the row | a predicate that returns a `dynamic`, read at the call from the environment the port stamped |
| A rule over a whole type | the same clauses composed into the `dynamic` that `scope` returns, so a scoped query and a checked row agree |
| A write gate | the role table alone. The seam refuses the write itself when no decision for the operation exists |

## The declarations

A policy module is `use Mediate.Rbac.Policy`. It declares the role table and, per protected schema, the clauses of its rule:

- `role name, permissions` is one row of the role table, declared data.
- `object Schema do ... end` names a protected schema and its clauses.
- `grant name, RelationshipSchema` holds a role on a row through the relationship the schema declares with `Mediate.Schema.relationship/1`. It takes `on:`, `role:`, or `as:` when the declaration is not enough, and `through:` when the relationship names a row the protected row points at.
- `predicate name, &Module.function/2` is a function of the subject and the environment. It returns a `dynamic` over the row, or a boolean. `only: [operations]` limits it to some operations.
- `use` takes `version:`, `author:`, and `approval:`.

The rule allows an operation on a row when any grant holds a role that permits it, and when every applicable predicate holds. `Mediate.Rbac.Policy` has the options in full.

After the configuration boots with `adapter: Mediate.Rbac`, bind the policy and the repo, then publish the version:

```elixir
{:ok, _binding} = Mediate.Rbac.Binding.bind(policy: MyApp.Roles, repo: MyApp.Repo)
{:ok, _event} = Mediate.Rbac.publish()
```

## Latency

Revocation latency has one component, commit. A write that revokes is visible to the next query. `docs/conformance.md` §2 says how the suite measures it and prints it.
