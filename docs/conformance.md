# Conformance

*What must an engine and a mediated repo satisfy? For someone who writes an engine or binds a repo.*

A requirement is one test, named by its id and its text. The engine requirements are the tests of `Mediate.Conformance.EngineCase`. An engine is conformant when every one of them passes against its real server over a world it did not write. A requirement an engine cannot run prints its reason and never skips in silence. The repo requirements are the tests of `Mediate.Conformance.RepoCase`, which every mediated repo passes. `Mediate.Conformance.Requirement.all/1` holds each table below as data, and the freeze test in `mediate_conformance` holds it to this document row for row.

## The engine requirements

| Id | Text | Controls |
|---|---|---|
| `ac2-01` | A single-row write of an account through the mediated repo emits one identity write event with the subject, the resource, and the clearance before and after | AC-2, AC-2(4) |
| `ac2-02` | By the configured clock and not the database's, a grant that expires one second later allows and one that expired one second earlier denies | AC-2(2), AC-2(3) |
| `ac2-03` | When an account fact no longer satisfies the rule, the next authorized? denies the subject with no other change | AC-2(3), PS-5 |
| `ac2-04` | review answers every subject with exactly the resources authorized? allows, and emits one decision per subject and one for the reviewer under one correlation id | AC-2(7), AC-6(7) |
| `ac2-05` | After a revocation the next authorized? denies, and the test prints the revocation latency and never asserts it | AC-2(13), PS-4 |
| `ac3-01` | authorized? agrees with the world's own rule for every subject, action, and resource drawn | AC-3 |
| `ac3-02` | The library denies an ungranted resource, an unknown action, and an unknown subject, and denies an unknown subject kind before it calls the engine | AC-3 |
| `ac3-03` | filter returns exactly the rows authorized? allows for every protected schema, and a denied filter admits no row | AC-3 |
| `ac3-04` | filter over a thousand rows is one decision and one query beyond the engine's own | AC-3 |
| `ac3-05` | An unreachable engine denies every call and emits one decision event per call that carries the exception | AC-3 |
| `ac6-01` | authorized? allows the user that holds a grant and denies the privileged subject of the same account on the same resource | AC-6(2) |
| `au2-01` | Every authorize and authorized? emits exactly one decision event with the subject, its kind, the action, the resource, the effect, the reason, the policy version, the correlation id, and the moment | AU-2, AC-6(9) |
| `au2-02` | A denial's decision event carries the reason for it | AU-2 |
| `au2-03` | filter and review emit decisions whose effect is filter | AU-2 |
| `au3-01` | No decision event carries a value the rule reads from the world | AU-3 |
| `au3-02` | An identity write event carries the operation, the identity kind, the resource, the subject, the moment, the correlation id, and the old and new value of every fact column that changed | AU-3 |
| `au3-03` | A resource read event carries the resource type, the primary keys, the decision id, the subject, the correlation id, and the moment | AU-3 |
| `au3-04` | The decision, identity write, and resource read events of one call each carry its correlation id and its decision id | AU-3(1) |
| `au12-01` | A single-row write to an identity schema emits its identity write event inside the write's transaction | AU-12, AC-2(4) |
| `au12-02` | A bulk write to an identity schema raises and changes nothing | AU-12 |
| `au12-03` | A write that goes around the mediated repo emits nothing | AU-12 |
| `au12-04` | A write the database refuses leaves no row and no event | AU-12 |
| `au12-05` | The mediated repo refuses a read or a write of a protected schema that carries no decision | AU-12 |
| `au12-06` | Every mediated read of a protected schema emits one resource read event, and a read under an exemption emits none | AU-12 |
| `cm3-01` | When the engine releases a policy version, it emits the policy release event, and the release names its author and its approval | CM-3, CM-5 |
| `cm3-02` | A decision reports the policy version in force when the engine took it, before and after the engine releases a new version | CM-3(2) |
| `cm3-03` | A tightened rule is a policy release that carries its text or its location, and denies the reader it excludes | CM-5(1) |
| `cm3-04` | After the engine releases a tightened rule, authorized? denies the reader it excludes, and the test prints the release latency and never asserts it | CM-3(2) |

Beside the table, the engine case defines two more tests: the engine declares its filter limit, and the grant write budget, under which a single-row grant write is one insert and one identity write event. `au12-07`, every column a rule reads is a declared fact, is one coverage test per engine package whose rules read columns: `Mediate.Rbac.Facts`, `Mediate.Postgres.Facts`, and `Mediate.Cerbos.Facts`. For OpenFGA the mapping case stands in, because the mapping is the declaration. Each deployment runs its own coverage test too.

`ac3-01`, `ac3-02`, and `ac3-03` are `stream_data` properties over worlds `Mediate.Conformance.Generators` draws. `ac3-04` and the grant write budget count queries and events, and the counts are exact in the sandbox. `ac2-05` and `cm3-04` write on the durable repo, poll until the first denial, and print the latency and its components.

## The repo requirements

The repo case also holds the repo's exports to the surface the mediated repo classifies, and asserts that every query, write, and raw function refuses a call on a protected schema that carries no decision.

| Id | Text | Controls |
|---|---|---|
| `repo-01` | A single-row write to an identity schema emits one identity write event with every fact field that changed | AU-12, AC-2(4) |
| `repo-02` | A bulk write to an identity schema raises and emits nothing | AU-12 |
| `repo-03` | A write that goes around the mediated repo emits nothing | AU-12 |
| `repo-04` | A consumer that writes to the same repository from its handler joins the write transaction | AU-12 |
| `repo-05` | A mediated read of a protected schema emits one resource read event with its primary keys and its decision, and a read under an exemption emits none | AU-12 |

## Running the cases against your engine

An engine outside this repository supplies its own `Mediate.Conformance.World`, its own repo, its own Postgres, and the policy its mechanism needs. The `Mediate.Conformance.EngineCase` moduledoc has the options and what each engine in this repository passes. The `Mediate.Conformance.RepoCase` moduledoc has the `specimen:` module a repo supplies. The cases read nothing else.

Every word this document uses is a row of `docs/naming.md`, under "The conformance kit" and "Words in prose".
