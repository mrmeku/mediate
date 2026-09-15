# Mediate on row-level security

`Mediate.Postgres` is the adapter whose rules are Postgres policies on the tables themselves. The database enforces a policy on every statement, with the statements this library never sees among them. So the rules hold for a report tool, a console session, and a migration alike. A migration is a policy version, revocation is one commit, and the boundary cost is nothing new. The moduledoc of `Mediate.Postgres` has the mechanism.

## Mechanism per rule shape

| Rule shape | Mechanism |
|---|---|
| Who can see a row under an operation | the scope policy: a `SELECT` policy named `mediate_scope_<operation>` under the guard `current_setting('mediate.operation', true) = '<operation>'`. Permissive policies combine with OR, so without the guard the policy of one operation widens another |
| A write gate | the gate policy: an `UPDATE` policy named `mediate_gate_<operation>` with no guard. The database applies its `WITH CHECK` to a write whether or not anything asked first. `decide` reads its `USING` in the statement that answers visibility, so an answer given before a write agrees with what the write meets |
| A test on the subject or the moment | a session setting the adapter binds inside `around_query/3`, read with `current_setting(name, true)` |
| A rule over a whole type | the scope policy itself. `scope` answers `true`, and the database narrows the query |
| A row written outside a decision | the permissive `true` policy of that command. A table that takes writes under an exemption needs one under forced row-level security |

## Declarations

Bind at boot, after the configuration boots with `adapter: Mediate.Postgres`:

```elixir
{:ok, _binding} = Mediate.Postgres.Binding.bind(repo: MyApp.Repo, schemas: [MyApp.Folder, MyApp.Membership])
```

Then call `Mediate.Postgres.load!/0` to read the catalog at boot. A binding that skips the call reads it on first use.

A migration declares the policies through `Mediate.Postgres.Migration`: `protect!/2`, `policy!/2`, `gate!/2`, `admit!/2`, `exempt!/2`, `grant!/2`, and `publish!/2`. Its moduledoc says what each one writes.

The application's role must carry `NOBYPASSRLS` and must not own the protected tables. A role with `BYPASSRLS` is not subject to the policies, and a table's owner is not either. `protect!/2` forces row-level security, which closes the owner's way around them. The role's own definition closes the other.

## Latency

Revocation latency has one component, commit. Every statement goes to the primary, so the adapter reports replica lag as not measured. A rule change propagates with the migration that carries it, in the same transaction as its DDL. The conformance suite prints both measurements and asserts nothing about them (`docs/conformance.md` §2).
