# Mediate on OpenFGA

`Mediate.Fga` is the adapter that decides from a relationship graph in a store of its own. Facts become tuples in the store. Rules become a model that is immutable and that an id names. A decision is a question about the graph under that model. The server is OpenFGA 1.19.0, self-hosted with a datastore of its own. `docs/contributing.md` §1 has the pin.

The cost of this adapter is a server, a datastore, and a copy. The record is the application's own tables. A relay keeps the copy in step with them, so revocation latency has four components.

A Zanzibar-style system stores tuples, `(user, relation, object)`, and a model that says how relations compose. A condition is a small CEL expression on a tuple, which the server evaluates against the context of each question. [The OpenFGA documentation](https://openfga.dev/docs/concepts) has the concepts.

## Mechanism per rule shape

| Rule shape | Mechanism |
|---|---|
| A role held on a row | a tuple from the user to the relation on the object |
| A test on the subject | membership of the value as an object of its own, because a graph compares by a walk and not by equality |
| A test on the row | a wildcard `user:*` on a relation named for the fact, so a row states one tuple and not one per account |
| A test on the moment | a condition on the tuple that carries the date, against `current_time` in the context of every question |
| A grant held by one kind of subject | a condition on the tuple that carries the kind, against `subject_kind` in the context of every question. The user string names the account alone |
| A rule over a whole type | `ListObjects` under the cap. At the cap the caller asks per row |
| A write gate | the seam refuses a write with no decision for the operation before the adapter asks the model |
| A fact about the session | a `Mediate.Fga.Guard` the binding names, which the adapter asks before the server. A condition on a tuple makes every use of the relation demand that fact |

## Declarations

The configuration entry is `adapter: {Mediate.Fga, endpoint: "127.0.0.1:8080", store_id: "01J...", model_id: "01K..."}`. The `options_schema/0` callback of `Mediate.Adapter` answers the fields. The rest of what the adapter needs comes from the binding, the migration, the outbox, and the relay.

1. Create the outbox table and the cursor table in a migration of your own. `Mediate.Fga.Migration` has the helpers.
2. Bind at boot, after the configuration boots:

```elixir
{:ok, _binding} =
  Mediate.Fga.Binding.bind(
    repo: MyApp.Repo,
    model: "priv/fga/model.fga",
    mapping: MyApp.TupleMapping,
    author: "the model owner",
    approval: "the change record"
  )
```

3. Attach the outbox handler with `Mediate.Fga.Outbox.attach/0`.
4. Start the relay runner in your supervision tree, under the name `Mediate.Fga.Outbox.runner/0` answers:

```elixir
{Mediate.Fga.Relay, runners: [[name: Mediate.Fga.Outbox.runner(), repo: MyApp.Repo, job: Mediate.Fga.Outbox]]}
```

5. Publish the model with `Mediate.Fga.publish/0`, and pin `model_id` to the id it answers.
6. Call `Mediate.Fga.Relay.wake/1` after a write that produced markers, or wait for the runner's next tick.

Hold your mapping to `Mediate.Fga.TupleMappingCase` and your drain to `Mediate.Fga.OutboxCase`. A test calls `Mediate.Fga.Relay.drain_once/1` and starts no runner.

## Latency

Revocation latency has four components for a fact: commit, a relay pass, the engine write, and the check-cache TTL where a cache is on. A rule has one component: a model publication. A publication reaches every question at once, because the caller moves a question to another model when it names another id. The conformance suite prints the measurement beside its run, the relay pass among its components. `docs/conformance.md` §2 says what the suite prints and that it asserts nothing.
