# Mediate on row-level security

*How do I bind this adapter, and what mechanism answers each rule shape? For an adopter whose rules are Postgres policies.*

`Mediate.Postgres` decides from policies on the tables themselves. The database enforces a policy on every statement, the statements this library never sees among them, so the rules hold for a report tool and a console session alike. A migration is a policy version, and revocation is one commit.

## How to bind

The configuration entry is the bare module, `adapter: Mediate.Postgres`. After the configuration boots, bind the repo and the schemas the policies protect and read. `Mediate.Postgres.Binding` has the options. The adapter reads the catalog on first use, and the `Mediate.Postgres` moduledoc names the function that reads it at boot instead.

```elixir
{:ok, _binding} = Mediate.Postgres.Binding.bind(repo: MyApp.Repo, schemas: [MyApp.Folder, MyApp.Membership])
```

## The declarations

A migration declares the policies through the helpers of `Mediate.Postgres.Migration`, whose moduledoc says what each one writes: protect a table, add a scope policy, a gate, an admit, an exempt, a grant, and publish the version. The application's role must carry `NOBYPASSRLS` and must not own the protected tables. A role with `BYPASSRLS` is not subject to the policies, and a table's owner is not either. The protect helper forces row-level security, which closes the owner's way around them.

## Mechanism per rule shape

| Rule shape | Mechanism |
|---|---|
| Who can see a row under an operation | the scope policy: a `SELECT` policy named `mediate_scope_<operation>` under the guard `current_setting('mediate.operation', true) = '<operation>'`. Permissive policies combine with OR, so without the guard the policy of one operation widens another |
| A write gate | the gate policy: an `UPDATE` policy named `mediate_gate_<operation>` with no guard. The database applies its `WITH CHECK` to a write whether or not anything asked first. `decide` reads its `USING` in the statement that answers visibility, so an answer given before a write agrees with what the write meets |
| A test on the subject or the moment | a session setting the adapter binds inside `around_query/3`, read with `current_setting(name, true)` |
| A rule over a whole type | the scope policy itself. `scope` answers `true`, and the database narrows the query |
| A row written outside a decision | the permissive `true` policy of that command. A table that takes writes under an exemption needs one under forced row-level security |

## What this adapter decided

- **Session settings, not a role per subject.** A database role per user was the alternative, and a connection pool cannot switch roles per call.
- **An operation guard on every scope policy.** One policy per table was the alternative. Permissive policies combine with OR, so an unguarded read policy widens every other operation.
- **The version is the migration number, and the content is the policy text read back from `pg_policy`.** The migration file was the alternative, and the catalog is what the database enforces.
- **The version event fires in the migration's transaction.** A publish at boot was the alternative, and then a rule change and its record could commit apart.

Revocation latency has one component, commit, because every statement goes to the primary. A rule change propagates with the migration that carries it.
