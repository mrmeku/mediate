# Mediate on row-level security

*How do I bind this engine, and what mechanism answers each rule shape? For a deployment whose rules are Postgres policies.*

`Mediate.Postgres` decides from policies on the tables themselves. The database enforces a policy on every statement, the statements this library never sees among them, so the rules hold for a report tool and a console session alike. A migration is a policy version, and revocation is one commit.

## The words

Inside `infrastructure/` the package speaks Postgres, and at its root it speaks the ledger's words. `docs/naming.md` under "Row-level security" has every row and why.

| Postgres says | The ledger says | Here it is |
|---|---|---|
| table | protected schema | the source of a schema that declares a resource type |
| policy, a row of `pg_policy` | rule | one line of the policy; the migration number is the policy version |
| `mediate_filter_<action>`, `mediate_gate_<action>` | filter rule, gate rule | the rules the migration helpers write, with the admit rule and the exempt rule |
| `current_setting` | settings | `mediate.subject_id`, `mediate.subject_kind`, `mediate.action`, `mediate.now`, and one per context fact |
| `set_config` | settings in force | what `around_query/3` sets for the session, which is the stretch of one call |
| catalog | policy | what the database says its rules are, which is the text a release carries |
| `GRANT` | privileges | what the app role may do, which is never a grant |
| replica lag | revocation latency | the one component this engine does not measure |

## How to bind

The configuration entry is the bare module, `engine: Mediate.Postgres`. After the configuration boots, bind the repo and the schemas the rules protect and read, then load the catalog. `Mediate.Postgres.Binding` has the options. The binding is not an Ecto query binding: it is what the engine needs beyond the configuration.

```elixir
{:ok, _binding} = Mediate.Postgres.Binding.bind(repo: MyApp.Repo, schemas: [MyApp.Folder, MyApp.Membership])
{:ok, _catalog} = Mediate.Postgres.load_catalog()
```

## The declarations

A migration declares the rules through the helpers of `Mediate.Postgres.Migration`, whose moduledoc says what each one writes: protect a table, add a filter rule, a gate rule, an admit rule, an exempt rule, grant privileges, and release the version. The application's role must carry `NOBYPASSRLS` and must not own the protected tables. A role with `BYPASSRLS` is not subject to the rules, and a table's owner is not either. The protect helper forces row-level security, which closes the owner's way around them.

## Mechanism per rule shape

| Rule shape | Mechanism |
|---|---|
| Who can see a row under an action | the filter rule: a `SELECT` policy named `mediate_filter_<action>` under the action guard `current_setting('mediate.action', true) = '<action>'`. Permissive policies combine with OR, so without the guard the rule of one action widens another |
| A write gate | the gate rule: an `UPDATE` policy named `mediate_gate_<action>` with no guard. The database applies its `WITH CHECK` to a write whether or not anything asked first. `authorize` reads its `USING` in the statement that answers visibility, so a verdict given before a write agrees with what the write meets |
| A test on the subject or the moment | a session setting the engine sets inside `around_query/3`, read with `current_setting(name, true)` |
| A rule over a whole type | the filter rule itself. `filter` answers `true`, and the database narrows the query |
| A row written outside a decision | the admit rule of that command. A table that takes writes under an exemption needs one under forced row-level security |

## What this engine decided

- **Session settings, not a role per subject.** A database role per user was the alternative, and a connection pool cannot switch roles per call.
- **An action guard on every filter rule.** One policy per table was the alternative. Permissive policies combine with OR, so an unguarded read rule widens every other action.
- **The version is the migration number, and the text is the rules read back from `pg_policy`.** The migration file was the alternative, and the catalog is what the database enforces.
- **The release event fires in the migration's transaction.** A release at boot was the alternative, and then a rule change and its record could commit apart.
- **A hidden row and an absent row deny the same way.** A second statement outside the rules was the alternative, and it would tell a subject that a row it cannot see exists.

Revocation latency has one component, commit, because every statement goes to the primary. A rule change propagates with the migration that carries it.
