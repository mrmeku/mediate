# The events

*What does each telemetry event carry, and when does it fire? For someone writing a consumer.*

Three events fire on the request path, and one fires per adapter when the adapter deploys a policy version. The library publishes every one and stores none. A consumer attaches a handler and writes the record in the format it chooses. Every event of one operation shares one `operation_id`, which the caller passes in `opts` or the port makes.

| Event | When |
|---|---|
| `[:mediate, :decision]` | after each port call, whatever the verdict |
| `[:mediate, :change]` | inside the write's transaction, for each single-row write to an audited schema |
| `[:mediate, :access]` | after each mediated read of a protected schema returns |
| `[:mediate, <adapter>, :policy_version]` | when the adapter deploys a version |

## Decision

The port publishes it after every `authorize`, `check`, `scope`, and `review`. `review` publishes one decision per subject and one for the reviewer over `{type, nil}`. The one measurement is `duration`, in microseconds.

| Field | Type | Meaning |
|---|---|---|
| `subject`, `subject_kind` | `{kind, id}`, atom | the subject, and `:user`, `:non_person_entity`, or `:privileged` |
| `operation` | atom | the operation asked about |
| `object` | `{type, id}` | the id is `nil` for `scope` and `review` |
| `verdict` | `:allow`, `:deny`, `:scoped`, or `nil` | `nil` when the call raised |
| `reason` | atom or `nil` | one of `Mediate.Answer.reasons/0`, and `nil` when the call raised |
| `decider`, `version` | module, string or `nil` | the adapter, and its policy version |
| `env` | map | the environment as the caller gave it, with `now` stamped from the configured clock |
| `exception` | exception or `nil` | what the call raised, when it raised |
| `decision_id` | string or `nil` | the `Mediate.Decision` id the access and change events name |
| `time`, `operation_id` | `DateTime`, string | the configured clock at the call, and the operation's identifier |

A denial carries a reason. A call that raised, for a bad option, a configuration that never booted, or an adapter that raised, carries `verdict: nil`, `reason: nil`, and the exception, and the port reraises after it publishes.

## Change

The seam publishes it inside the write's transaction, so a consumer that writes to the same repository joins that transaction. Only a change to a column the schema declares with `fact/2` or `relationship/1` makes an event. The old value is the row the caller loaded, and the library takes no lock to make it current. Measurements are empty.

| Field | Type | Meaning |
|---|---|---|
| `operation` | `:create`, `:update`, or `:delete` | what the write did |
| `kind` | `:user`, `:group`, `:role`, or `:entity` | what `audited/1` declared on the schema |
| `target` | `{type, id}` | the row that changed |
| `changes` | map of field to `{old, new}` | the declared columns that changed |
| `actor`, `actor_kind` | `{kind, id}`, atom | the subject whose decision allowed the write, or the library under an exemption |
| `decision_id` | string or `nil` | the decision the write ran under, `nil` under an exemption |
| `time`, `operation_id` | `DateTime`, string | the configured clock at the write, and the operation's identifier |
| `schema` | module | the Ecto schema |

A bulk write and an upsert on an audited schema raise instead of publishing. The `Mediate.Repo` moduledoc has the reasons.

## Access

The seam publishes it once per mediated read, after the read returns, at the one site every query verb passes through. An exempt read, a read through the owner-role repo, and a raw query publish nothing. The one measurement is `count`.

| Field | Type | Meaning |
|---|---|---|
| `object_type` | atom | the protected schema's object type |
| `schema`, `repo` | module, module | the Ecto schema and the repo the call went through |
| `call` | `{name, arity}` | the repo function |
| `activity` | `:query` or `:read` | `:query` for `all`, `all_by`, `stream`, and `aggregate`, and `:read` for the rest |
| `ids` | list | the primary keys of the root structs the read returned, in order |
| `count` | integer | the length of `ids` |
| `shape` | `:rows`, `:value`, or `:stream` | `:value` for a scalar, boolean, map, or tuple |
| `subject`, `subject_kind` | `{kind, id}`, atom | from the decision the read ran under |
| `decision_id` | string | the decision's id |
| `time`, `operation_id` | `DateTime`, string | the configured clock after the read, and the operation's identifier |

A stream publishes once, when the seam builds it, with `shape: :stream` and `ids: []`. The rows it yields get no event. A value-shaped result carries `ids: []`. The event names the root schema the decision was for, and a joined schema appears nowhere in it.

## Policy version

Each adapter publishes one event when it deploys a version. The metadata is `%{version: %Mediate.PolicyVersion{}}`, and the struct's moduledoc has the fields.

| Field | Type | Meaning |
|---|---|---|
| `adapter` | module | the adapter that deployed it |
| `version` | string | the commit, migration number, or model id, as the adapter's README says |
| `content_hash` | string | a hash of the policy text |
| `content` | string or `nil` | the policy text, where it is under `caps[:policy_content_bytes]` |
| `pointer` | string or `nil` | where the text lives, where it is over the cap |
| `author`, `approval` | string | who wrote it, and what approved it |
| `at` | `DateTime` | the configured clock at deployment |

## What a consumer must not expect

- No payload carries an OCSF class, category, or severity identifier. Those belong to the consumer. `Example.Infrastructure.Siem` shows one mapping.
- No payload carries a value the rule read from the world. A decision says the question and the answer, never the clearance or the marking.
- No event says a consumer stored it, a handler stayed attached, the write committed, or the old value was current.
- A policy version over the cap carries a pointer and no text.
