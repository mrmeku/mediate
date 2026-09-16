# Conformance

*What must an adapter and a mediated repo satisfy? For someone who writes an adapter or binds a repo.*

A law is one test in `Mediate.Conformance.AdapterCase`, named by a law id and one sentence. An adapter is conformant when every law passes against its real engine over a population it did not write. A law an adapter cannot run prints its reason and never skips in silence. `Mediate.Conformance.Law.all/0` holds the table below as data, and the freeze test in `mediate` holds it to this document row for row.

## The laws

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

Beside the laws, the template defines two more tests: the adapter declares its scope cap, and a single-row fact write is the write alone and one change event. `au12-07`, every column a rule reads is a declared fact, is one coverage test per adapter package whose rules read columns: `Mediate.Rbac.Coverage`, `Mediate.Postgres.Coverage`, and `Mediate.Cerbos.Coverage`. For OpenFGA the tuple mapping case stands in, because the mapping is the declaration. Each thin application runs its own coverage test too.

`ac3-01`, `ac3-02`, and `ac3-03` are `stream_data` properties over populations `Mediate.Conformance.Gen` draws from the world. `ac3-04` and the fact-write shape count queries and events, and the counts are exact in the sandbox. `ac2-05` and `cm3-04` write on the committed repo, poll until the first denial, and print the latency and its components.

## The guarantees

A guarantee is one test in `Mediate.Conformance.RepoCase`, which every mediated repo passes. The case also holds the repo's exports to the surface the seam classifies, and asserts that every query, write, and raw function refuses a call on a protected schema that carries no decision. `Mediate.Conformance.RepoCase.guarantees/0` holds this table as data, and the freeze test holds it to this document row for row.

| Id | Sentence |
|---|---|
| `E1` | A single-row write to an audited schema emits one change event with every fact field that changed |
| `E2` | A bulk write to an audited schema raises and emits nothing |
| `E3` | A write that goes around the seam emits nothing |
| `E4` | A consumer that writes to the same repository from its handler joins the write transaction |
| `E5` | A mediated read of a protected schema emits one access event with its rows and its decision, and a read under an exemption emits none |

## Running the suite against your adapter

An adapter outside this repository supplies its own `Mediate.Conformance.World`, its own repo, its own Postgres, and the artifacts its mechanism needs. The `Mediate.Conformance.AdapterCase` moduledoc has the options and what each adapter in this repository passes. The `Mediate.Conformance.RepoCase` moduledoc has the `rows:` module a repo supplies. The template reads nothing else.

## Words

- **Attribute, fact.** A value about a subject or object that a rule can test, declared on a schema with `fact/2`.
- **Grant.** A row that gives a subject a role on an object, declared with `relationship/1`.
- **Fail closed.** No, when the system cannot decide.
- **Scope fidelity.** `scope` returns exactly the rows `check` allows.
- **Consumer.** The handler the deployer attaches to the events, which writes the record.
- **Revocation latency.** The time from a revoked fact to the first denial, printed and never asserted.
- **Shape test.** A test that counts queries and events, never time.
- **Thin application.** The binding of one domain to one adapter.
- **Protected schema.** A schema that declares an object type, which the seam refuses to read or write without a decision.
