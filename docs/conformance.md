# Conformance

*The tests every adapter must pass, and the tests every mediated repo must pass. Tier 1 is the contract. `docs/requirements.md` says which requirement line each law answers.*

## 1. What conformance is

An adapter is conformant when `Mediate.Conformance.AdapterCase` passes against its real engine over a population it did not write. A requirement id and one sentence name each law below. Each law is a test, and the test's name is that sentence.

Every adapter in this repository runs the laws in its own `mix test`. An adapter outside this repository runs them the same way (§6). No law skips in silence. A law an adapter cannot run prints its reason.

A repo is conformant when `Mediate.Conformance.RepoCase` passes against it. The case holds the repo to three things:

- Its exports are the surface the seam classifies.
- The repo refuses every non-plumbing call that carries no decision.
- The guarantees E1 to E5 hold.

## 2. The laws

`Mediate.Conformance.Law.all/0` holds this table as data. The freeze test in `mediate` holds the module to this document row for row. The bodies are in `Mediate.Conformance.AdapterCase.Laws` and its modules:

- `Accounts` holds `ac2-01` to `ac2-04` and `ac6-01`.
- `Audit` holds the `au` laws.
- `Versions` holds the `cm3` laws.
- `Laws` itself holds the `ac3` laws, `ac2-05`, and the helpers every body shares.

| Id | Sentence | Controls |
|---|---|---|
| `ac2-01` | A single-row write of an account through the seam emits one change event with the actor, the target, and the clearance before and after | AC-2, AC-2(4) |
| `ac2-02` | By the configured clock and not the database's, a grant that expires one second later allows and one that expired one second earlier denies | AC-2(2), AC-2(3) |
| `ac2-03` | When an account fact no longer satisfies the rule, the next check denies the subject with no other change | AC-2(3), PS-5 |
| `ac2-04` | Review answers every subject with exactly the objects check allows, and emits one decision per subject and one for the reviewer under one operation id | AC-2(7), AC-6(7) |
| `ac2-05` | After a revocation the next check denies, and the test prints the latency from revocation to denial and never asserts it | AC-2(13), PS-4 |
| `ac3-01` | check agrees with the world's own rule for every subject, operation, and object drawn | AC-3 |
| `ac3-02` | The seam denies an ungranted object, an unknown operation, and an unknown subject, and denies an unknown subject kind before it calls the adapter | AC-3 |
| `ac3-03` | scope returns exactly the rows check allows for every protected schema, and a denied scope admits no row | AC-3 |
| `ac3-04` | scope over a thousand rows is one decision and one query beyond setup | AC-3 |
| `ac3-05` | An unreachable engine denies every call and emits one decision event per call that carries the exception | AC-3 |
| `ac6-01` | check allows the user that holds a grant and denies the privileged subject of the same account on the same object | AC-6(2) |
| `au2-01` | Every authorize and check emits exactly one decision event with subject, kind, operation, object, verdict, reason, version, operation id, and time | AU-2, AC-6(9) |
| `au2-02` | A denial's decision event carries the reason for it | AU-2 |
| `au2-03` | scope and review emit decisions with a scoped verdict | AU-2 |
| `au3-01` | No decision event carries a value the rule reads from the world | AU-3 |
| `au3-02` | A change event carries operation, kind, target, actor, time, operation id, and the old and new value of every fact column that changed | AU-3 |
| `au3-03` | An access event carries object type, ids, decision id, subject, operation id, and time | AU-3 |
| `au3-04` | The decision, change, and access events of one operation each carry its operation id and its decision id | AU-3(1) |
| `au12-01` | A single-row write to an audited schema emits its change event inside the write's transaction | AU-12, AC-2(4) |
| `au12-02` | A bulk write to an audited schema raises and changes nothing | AU-12 |
| `au12-03` | A write that goes around the seam emits nothing | AU-12 |
| `au12-04` | A write the database refuses leaves no row and no event | AU-12 |
| `au12-05` | The repo refuses an unmediated read or write of a protected schema | AU-12 |
| `au12-06` | Every mediated read of a protected schema emits one access event, and a read under an exemption emits none | AU-12 |
| `cm3-01` | When the adapter publishes a version, it emits its version event, and the version names its author and its approval | CM-3, CM-5 |
| `cm3-02` | A decision reports the version in force when the adapter took it, before and after the adapter publishes a new version | CM-3(2) |
| `cm3-03` | A tightened rule is a policy version that names its artifact as content or as a pointer, and denies the reader it excludes | CM-5(1) |
| `cm3-04` | After the adapter publishes a tightened rule, check denies the reader it excludes, and the test prints the propagation latency and never asserts it | CM-3(2) |

**Beside the laws**, the template defines two more tests. The adapter declares its scope cap. A single-row fact write is the write alone and one change event.

**`au12-07`**, every column a rule reads is a declared fact, is one coverage test per adapter package whose rules read columns: `Mediate.Rbac.Coverage`, `Mediate.Postgres.Coverage`, and `Mediate.Cerbos.Coverage`. Each thin application runs its own too. For OpenFGA the tuple mapping case stands in, because the mapping is the declaration. The Postgres checker reads the bound schemas. So a Postgres binding names every schema its policies read, beside the ones they protect.

**Properties and shapes.** `ac3-01`, `ac3-02`, and `ac3-03` are `stream_data` properties. `Mediate.Conformance.Gen` draws their populations from the world's generator. `ac3-04` and the fact-write shape count queries with `Mediate.Test.queries/2` and events with `Mediate.Test.changes/1`. The counts are exact in the sandbox and cannot flap. An adapter that adds queries of its own to every call declares how many through `setup_queries:`.

**Measurements.** `ac2-05` and `cm3-04` write on the committed repo and read the monotonic clock. They settle the adapter where it has state to settle. They poll until the first denial with `Mediate.Test.poll/2`. They print the total, its components, and the poll interval as the floor. Nothing in the suite fails on a latency number.

## 3. The world

`Mediate.Conformance.World` is the behaviour through which the template reads a population. The template learns no schema from it. The neutral fixture that implements it in this repository is `Mediate.Fixture`. It lives in `mediate`'s `test/support`, and it is not a published module. Its population has four parts:

- accounts, each with a clearance and a kind
- folders
- items, each under a folder
- memberships, each a grant of a role on a folder to an account, with an expiry

The rule is one sentence. A live membership of the right role, for a subject of the right kind, allows the operation on the folder and its items.

| Callback | What it answers |
|---|---|
| `schemas/0`, `scope_schema/0` | Every protected schema the properties scope over, and the one the shape cases fill with rows |
| `operations/0` | The operations the rule knows |
| `exemption/0` | The exemption every write of a population declares through the seam |
| `object_of/1` | The object a grant on this thing covers |
| `generator/0` | A random population, for the properties |
| `granted/0`, `ungranted/0`, `scoped/0` | One subject, one object, and one grant. The same without the grant. The same with more objects than the grant covers |
| `focus/1` | The subject the fixed worlds grant to, and what they grant it on |
| `subjects/1`, `objects/1` | Every subject, one of kind `:privileged` among them, and every object the population knows |
| `allowed?/4` | The rule: what the population says about one subject, operation, and object |
| `facts/1` | The values the rule reads from the population. No decision event carries one |
| `clear/1`, `insert/2`, `fill/3` | Delete every row through the seam one at a time. Write the population. Add rows to the scope schema |
| `insert_grant/5`, `revoke/4`, `disqualify/3` | Write one grant with attributes. Take a grant away. Change the account fact the rule reads |
| `module/1` | The module behind a population |

The laws set two grant attributes. `expires_at` is the expiry. `mediation` is the `mediate:` option the write carries in place of the exemption.

Each adapter package carries what the fixture needs on its own mechanism. It lives in the package's `test/support`, under a `Conformance` module of the package's namespace:

- `mediate_rbac`: the role table and the predicates
- `mediate_postgres`: the row-level security migration for the fixture tables
- `mediate_cerbos`: the attribute declarations
- `mediate_fga`: the tuple mapping

What an engine reads as text stays under `priv/conformance/`: the Cerbos policies and the OpenFGA model. The example's domain appears in none of them.

## 4. Seed and versions

`Mediate.Conformance.Seed` is for an adapter whose own state is not the tables. `seed/1` loads a world into the adapter's own state. `outage/0` makes its engine unreachable for the fail-closed law. An adapter that reads the tables passes none.

`Mediate.Conformance.Versions` is what the `cm3` laws need and a test cannot write without the adapter's name:

- `event/0`, the telemetry event the adapter publishes a policy version on
- `tighten/0`, which publishes a version that excludes the granted reader
- `restore/0`, which puts the original back
- `setup/1`, optional, for an engine that keeps state per test

Each adapter package carries its own under `test/support/mediate/<adapter>/conformance/versions.ex`. An adapter that passes no `versions:` skips the `cm3` laws and prints the reason.

## 5. The repo case

`use Mediate.Conformance.RepoCase, repo: MyApp.Repo` writes the tests itself. The repo answers `__mediate__/1`. It exports nothing outside the list in `infrastructure/surface.ex`, and an export outside the list fails with the function's name and arity. The case calls every query, write, and raw function on a protected schema without a decision. It asserts that each raises `%Mediate.Error{reason: :unmediated}` before any SQL.

With a `rows:` module, the case also holds the repo to five guarantees. `Mediate.Conformance.RepoCase.guarantees/0` holds this table as data, and the freeze test in `mediate` holds it to the document row for row.

| Id | Sentence |
|---|---|
| `E1` | A single-row write to an audited schema emits one change event with every fact field that changed |
| `E2` | A bulk write to an audited schema raises and emits nothing |
| `E3` | A write that goes around the seam emits nothing |
| `E4` | A consumer that writes to the same repository from its handler joins the write transaction |
| `E5` | A mediated read of a protected schema emits one access event with its rows and its decision, and a read under an exemption emits none |

The `rows:` module is a `Mediate.Conformance.RepoCase.Rows`:

- `row/0`, an unwritten row of an audited schema
- `change/1`, a change of a written row that sets a fact field
- `mediation/0`, the `mediate:` option those writes carry
- `around/1`, the way this deployment changes the row without the seam
- `protected/0`, an unwritten row of a schema that declares an object type
- `decision/1`, a decision from `Mediate.authorize/4` that admits a read of it
- `setup/1`, optional, run first in every test with the test's tags

## 6. How to run the suite

Inside this repository, each adapter's test module is one `use`:

```elixir
use Mediate.Conformance.AdapterCase,
  adapter: Mediate.Postgres,
  repo: Mediate.TestRepos.Sandboxed,
  world: Mediate.Fixture.World,
  versions: Mediate.Postgres.Conformance.Versions,
  committed: [repo: Mediate.TestRepos.Committed, owner: Mediate.TestRepos.Owner, tables: [...]]
```

`seed:` and `outage:` name a `Mediate.Conformance.Seed`. `setup_queries:` is the count of queries the adapter adds to every call. `committed:` is the repo the latency laws write on. The adapter binds through the configuration override, so all four adapters run in one `mix test` as async modules. A test tagged `:committed` runs on the committed database and truncates through the owner repo.

An adapter outside this repository supplies four things: its own `World`, its own repo, its own Postgres, and the artifacts its mechanism needs. The template reads nothing else. `mediate_dev` holds the ephemeral cluster this repository's suites start, and it is not a published package. An adopter's `test_helper.exs` starts whatever database it has.
