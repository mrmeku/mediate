# The events

*What each telemetry event carries, what the library guarantees about it, and the OCSF mapping the example shows. Reference register: what a thing is, then stop.*

Three events on the request path, and one per adapter when the adapter deploys a policy version. The library publishes every one and stores none. A consumer attaches a handler and writes the record in the format it chooses. Each payload carries what an OCSF record needs and invents no value. The library never carries a class, category, or severity identifier, because those move between schema versions and belong to the consumer.

| Event | When | Answers |
|---|---|---|
| `[:mediate, :decision]` | after each port call | AU-2 authorization checks, AC-6(9) privileged functions, AU-3 content |
| `[:mediate, :change]` | inside the write's transaction | AU-2 data changes, deletions, and permission changes, and AC-2(4) account actions |
| `[:mediate, :access]` | after each mediated read | AU-2 data access, AC-2(12) monitoring of use |
| `[:mediate, <adapter>, :policy_version]` | when the adapter deploys a version | CM-3, CM-5 configuration change |

Every event of one operation shares one `operation_id`. That id lets a reviewer join the decision, the reads, and the writes of one request. The caller passes it in `opts`, and the port makes one when the caller does not.

## 1. Decision

The port publishes it after every `authorize`, `check`, `scope`, and `review`, whatever the verdict. `review` publishes one decision per subject and one for the reviewer over `{type, nil}`. A decision is a read, so it has no transaction. The one measurement is `duration`, in microseconds.

| Field | Value |
|---|---|
| `subject`, `subject_kind` | `{kind, id}`, and `:user`, `:non_person_entity`, or `:privileged` |
| `operation` | the operation asked about |
| `object` | `{type, id}` for `authorize` and `check`, and `{type, nil}` for `scope` and `review` |
| `verdict` | `:allow`, `:deny`, or `:scoped` |
| `reason` | an atom of `Mediate.Answer.reasons/0`: `allowed`, `deny_by_default`, `rule_denied`, `engine_unreachable`, `missing_fact`, `unknown_operation`, `unknown_subject_kind` |
| `decider`, `version` | the adapter module, and its policy version string |
| `env` | the environment map as the caller gave it, with `now` stamped from the configured clock |
| `exception` | what broke when the decision failed closed, the exception the adapter raised or the `Mediate.Error` it answered with. Otherwise `nil` |
| `decision_id` | the `Mediate.Decision` id the seam names in access and change events |
| `time`, `operation_id` | the configured clock at the call, and the operation's identifier |

A denial always carries a reason. The port denies an unknown subject kind before it asks the adapter, and an unreachable engine after. Both are one event. No value in the payload equals an attribute value of the world. The decision says the question and the answer, never the clearance or the marking the rule read.

## 2. Change

The seam publishes it inside the write transaction, where it computes the change, for every single-row write to an audited schema. Measurements are empty.

| Field | Value | What a mapper does with it |
|---|---|---|
| `operation` | `:create`, `:update`, or `:delete` | the activity |
| `kind` | `:user`, `:group`, `:role`, or `:entity`, from `audited/1` on the schema | the class |
| `target` | `{type, id}` of the row that changed | the entity type and identifier |
| `changes` | a map of field to `{old, new}`, for the fact fields that changed | the attributes before and after |
| `actor` | `{kind, id}` of the subject whose decision allowed the write, or the library where an exemption carried it | the actor |
| `actor_kind` | `:user`, `:non_person_entity`, or `:privileged` | whether the actor is a person or a process |
| `decision_id` | the decision the write ran under, or `nil` under an exemption | the join to the decision |
| `time` | the configured clock at the moment of the write | the event time |
| `operation_id` | shared by every event of one operation | the correlation identifier |
| `schema` | the Ecto schema module | context for a mapper |

**Audited schemas.** A schema declares what kind of thing its rows are with `audited/1`, and what its columns mean with `fact/2` and `relationship/1`. Only a change to a declared column is a change worth an event.

```elixir
defmodule Example.Domain.Assignment do
  use Ecto.Schema
  use Mediate.Schema

  object_type(:assignment)
  audited(:role)
  # the row is the grant: the subject column, the object column, and the
  # columns that are attributes of the relationship itself
  relationship(subject: :user_id, object: :program_id, attributes: [:role])
end

defmodule Example.Domain.Marking do
  use Ecto.Schema
  use Mediate.Schema

  object_type(:marking)
  audited(:entity)
  fact(:categories, kind: :object_attribute, object: :document_id, element: :category)
  fact(:controls, kind: :object_attribute, object: :document_id, element: :control)
  fact(:list, kind: :relationship, object: :document_id, element: :user)
end

defmodule Example.Domain.User do
  use Ecto.Schema
  use Mediate.Schema

  audited(:user)
  fact(:employment, kind: :subject_attribute, subject: :id)
  fact(:nationality, kind: :subject_attribute, subject: :id)
end
```

`__mediate__(:kind)` answers what `audited/1` declared, or `nil`. `__mediate__(:facts)` answers the `Mediate.Schema.Fact` records in declaration order. `__mediate__(:relationship)` answers the `Mediate.Schema.Relationship`, or `nil`. A fact kind is `:subject_attribute`, `:object_attribute`, or `:relationship`. A set-valued column names the type of its elements with `element:`. So a reader of the event knows what each member of the set refers to.

An audited schema can lack an object type. `Example.Domain.User` declares facts and no object type, so the seam records its writes and passes them without a decision.

**What one write produces.** One change event, with the fact fields that changed and their old and new values. The old value is the row the caller loaded. A change a second writer made between the load and the write is not in the event. The library says so, and takes no lock to make it true.

**What raises.** `update_all`, `delete_all`, and `insert_all` on an audited schema raise `%Mediate.Error{reason: :unmediated}` with `:bulk_write` in the detail. One statement that changes many rows has no changeset and no old value to record. An event per row is then a guess about what the library saw. An upsert, which is any write with `on_conflict:`, raises for the same reason: `RETURNING` cannot say which rows were inserts and which were updates. The owner-role repo is the library's own channel, and both rules exempt it.

An application with a million facts to flip each night has a modeling error, not a missing API. Something with the shape of bookkeeping carries an `audited/1` declaration it does not need.

**Completeness.** Every column a rule reads is a declared fact, so every permission-relevant change is a change event. Each adapter package carries a checker that reads its rules and fails on a column no declaration names. `docs/conformance.md` §2 names them.

## 3. Access

The seam publishes it after every mediated read of a protected schema returns, at the one site every query verb passes through. So it covers `get`, `one`, `all`, `exists?`, `aggregate`, `stream`, `preload`, and `reload` alike. It publishes only when the call carried a decision. An exempt read, a read through the owner-role repo, and a raw query publish nothing. The one measurement is `count`.

| Field | Value |
|---|---|
| `object_type` | the protected schema's object type |
| `schema`, `repo` | the Ecto schema module and the repo the call went through |
| `call` | `{name, arity}` of the repo function |
| `activity` | `:query` for `all`, `all_by`, `stream`, and `aggregate`, and `:read` for the rest |
| `ids` | the primary keys of the root structs the read returned, in order. For `preload`, the keys of the structs it loaded associations for |
| `count` | the length of `ids` |
| `shape` | `:rows`, `:value` for a scalar, boolean, map, or tuple, or `:stream` |
| `subject`, `subject_kind` | from the decision the read ran under |
| `decision_id` | the decision's id |
| `time`, `operation_id` | the configured clock after the read, and the operation's identifier |

The seam publishes a stream once, with `shape: :stream` and `ids: []`, when it builds the stream. The rows the stream yields get no event. A value-shaped result carries `ids: []`. Schemas joined into a query appear in the decision, not here. The access event names the root schema the decision was for.

## 4. Policy version

A policy version is `%Mediate.PolicyVersion{adapter, version, content_hash, content, pointer, author, approval, at}`. `content` is the text by value only where it is under `caps[:policy_content_bytes]`, 64 KB by default. Otherwise `pointer` names the store the text lives in. Each adapter publishes one event when it deploys a version. A decision event carries the version identifier and never the content.

| Adapter | Event | Version | Published by | Carries |
|---|---|---|---|---|
| Roles in code | `[:mediate, :rbac, :policy_version]` | the commit or release | the application at boot | the commit, a hash of the rule modules, and the role to permission table as data where it is under the cap |
| Postgres | `[:mediate, :postgres, :policy_version]` | the migration number | the migration, in the same transaction as its DDL | the `USING` and `WITH CHECK` expressions read back from `pg_policy` |
| Cerbos | `[:mediate, :cerbos, :policy_version]` | the policy repository's commit | the policy repository's CI on merge | the commit, a hash of the files, and the files where they are under the cap |
| OpenFGA | `[:mediate, :fga, :policy_version]` | the model id the server returns on publish | the model repository's CI on publish | the model id, the commit, a hash of the model file, and the DSL text where it is under the cap |

The metadata of each event is `%{version: %Mediate.PolicyVersion{}}`. The conformance suite reads the event an adapter names through its `Mediate.Conformance.Versions` module. That module is what keeps an adapter's name out of the law bodies.

## 5. What the library guarantees

`Mediate.Conformance.RepoCase` asserts five guarantees, `E1` to `E5`, against every mediated repo. `docs/conformance.md` §5 holds them.

It does not guarantee four things:

- that a consumer stores a record
- that a handler stays attached
- that the change committed
- that the old value was current at the write

The library publishes every event and samples none.

**Sizes to plan against.** A decision record is 300 to 600 bytes. An access event is about the same plus its ids. So a thousand port calls a second is about 86 million decision records a day, and tens of gigabytes uncompressed. That is a log-pipeline question for the consumer and not for the library, and the split exists for that reason.

## 6. The OCSF mapping the example shows

`Example.Infrastructure.Siem` attaches to all three events, maps each to an OCSF 1.3.0 record in `apps/example/lib/example/infrastructure/ocsf.ex`, and holds the result in memory. That keeps the mapping under test and puts no schema version in a published package. What OCSF names no field for travels under `unmapped`, which is where OCSF says to put it.

| Event | Class | Activity | Status |
|---|---|---|---|
| decision | API Activity, `class_uid` 6003, category 6 | the operation asked about where OCSF numbers it, otherwise Other | allow and scoped are Success, deny is Failure with a higher severity |
| change, kind `:user` | Account Change, 3001, category 3 | Create, Update, Delete | Success |
| change, kind `:role` | User Access Management, 3005 | Create, Update, Delete | Success |
| change, kind `:group` | Group Management, 3006 | Create, Update, Delete | Success |
| change, kind `:entity` | Entity Management, 3004 | Create, Update, Delete | Success |
| access | Datastore Activity, 6005, category 6 | Read or Query, from `activity` | Success |

The actor is the subject mapped through the example's user table, with `:privileged` as an admin and `:non_person_entity` as a system. `metadata.correlation_uid` is the operation id in every record. A decision's `unmapped` carries the decider, the version, the environment, and the exception. An access record's carries the ids, the count, and the decision id. A change record's carries the field changes and the schema. The example's consumer test asserts that one operation yields records of three classes under one correlation id.
