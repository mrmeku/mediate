# The events

*What does each telemetry event carry, and when does it fire? For someone writing a consumer.*

Three events fire on the request path, and one fires when an engine releases a policy version. The library publishes every one and stores none. A consumer attaches a handler and writes the record in the format it chooses. Every event of one call shares one `correlation_id`, which the caller passes as the `correlation_id:` option or the library makes. `docs/naming.md` under "The events" says why each key has its name.

| Event | When |
|---|---|
| `[:mediate, :decision]` | after each of the four calls, whatever the effect |
| `[:mediate, :identity, :write]` | inside the write's transaction, for each single-row write to an identity schema |
| `[:mediate, :resource, :read]` | after each mediated read of a protected schema returns |
| `[:mediate, :policy, :release]` | when an engine releases a policy version |

## Decision

The library publishes it after every `authorize`, `authorized?`, `filter`, and `review`. `review` publishes one decision per subject and one for the reviewer over `{type, :all}`. The one measurement is `duration_microseconds`.

| Key | Type | Meaning |
|---|---|---|
| `subject`, `subject_kind` | `{kind, id}`, atom | the subject, and `:user`, `:service`, `:privileged`, or `:unknown` for a kind the library refused |
| `action` | atom | the action asked about |
| `resource` | `{type, id}` | the id is `:all` for `filter` and `review`, and a `filter` call puts its rule in this key's place |
| `effect` | `:allow`, `:deny`, `:filter`, or `nil` | `nil` when the call raised |
| `reason` | atom or `nil` | one of `Mediate.Verdict.reasons/0`, and `nil` when the call raised |
| `engine`, `policy_version` | module, string or `nil` | the engine, and its policy version |
| `context` | map | the context as the caller gave it, before `now` is stamped |
| `exception` | exception or `nil` | what the engine raised, or what the call raised |
| `decision_id` | string or `nil` | the `Mediate.Decision` id the read and write events name |
| `decided_at`, `correlation_id` | `DateTime`, string | the configured clock at the call, and the call's identifier |

A denial carries a reason. An engine that raises or reports itself unreachable denies with `:engine_failed`, and the event carries the exception. A bad option and a configuration that never booted raise before the event. A call that raises after the engine answered publishes with `effect: nil`, `reason: nil`, and the exception, and the library reraises after it publishes.

## Identity write

The mediated repo publishes it inside the write's transaction, so a consumer that writes to the same repository joins that transaction. Only a change to a column the schema declares with `fact/2` or `grant/1` makes a non-empty `changes`. The old value is the row the caller loaded, and the library takes no lock to make it current. Measurements are empty.

| Key | Type | Meaning |
|---|---|---|
| `operation` | `:create`, `:update`, or `:delete` | what the write did |
| `identity_kind` | `:account`, `:group`, `:role`, or `:other` | what `identity/1` declared on the schema |
| `resource` | `{type, id}` | the row that changed, under the schema's resource type or its identity kind |
| `changes` | map of column to `{old, new}` | the declared columns that changed |
| `subject`, `subject_kind` | `{kind, id}`, atom | the subject whose decision allowed the write, or `{:service, "mediate"}` under an exemption |
| `decision_id` | string or `nil` | the decision the write ran under, `nil` under an exemption |
| `written_at`, `correlation_id` | `DateTime`, string | the configured clock at the write, and the call's identifier |
| `schema` | module | the Ecto schema |

A bulk write and an upsert on an identity schema raise instead of publishing. The `Mediate.Repo` moduledoc has the reasons.

## Resource read

The mediated repo publishes it once per mediated read, after the read returns, at the one site every query function passes through. An exempt read, a read through the owner-role repo, and a raw query publish nothing. The one measurement is `count`.

| Key | Type | Meaning |
|---|---|---|
| `resource_type` | atom | the protected schema's resource type |
| `schema`, `repo` | module, module | the Ecto schema and the repo the call went through |
| `repo_function` | `{name, arity}` | the repo function |
| `cardinality` | `:one` or `:many` | `:many` for `all`, `all_by`, `stream`, and `aggregate`, and `:one` for the rest |
| `primary_keys` | list | the primary keys of the root structs the read returned, in order |
| `count` | integer | the length of `primary_keys` |
| `result_shape` | `:rows`, `:scalar`, or `:stream` | `:scalar` for a number, boolean, map, or tuple |
| `subject`, `subject_kind` | `{kind, id}`, atom | from the decision the read ran under |
| `decision_id` | string | the decision's id |
| `read_at`, `correlation_id` | `DateTime`, string | the configured clock after the read, and the call's identifier |

A stream publishes once, when the mediated repo builds it, with `result_shape: :stream` and `primary_keys: []`. The rows it yields get no event. A scalar result carries `primary_keys: []`. The event names the root schema the decision was for, and a joined schema appears nowhere in it.

## Policy release

Each engine publishes one event when it releases a version, through `Mediate.PolicyRelease.publish/1`. The payload is `%{release: %Mediate.PolicyRelease{}}`, and the struct's moduledoc has the fields. A release whose text is over `caps[:policy_text_bytes]` carries `text_location` and no `text`.

## What a consumer must not expect

- No payload carries an OCSF class, category, or severity identifier. Those belong to the consumer. `Example.Infrastructure.Siem` shows one mapping.
- No payload carries a value the rule read from the world. A decision says the question and the answer, never the subject's clearance or the resource's visibility.
- No event says a consumer stored it, a handler stayed attached, the write committed, or the old value was current.
- A policy release over the cap carries a location and no text.
