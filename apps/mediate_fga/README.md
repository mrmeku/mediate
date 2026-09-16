# Mediate on OpenFGA

*How do I bind this adapter, and what mechanism answers each rule shape? For an adopter whose rules are a relationship model in a store of its own.*

`Mediate.Fga` decides from a relationship graph a server holds. Facts become tuples in the store, rules become a model that an id names, and a decision is a question about the graph under that model. `flake.nix` pins the server. The cost is a server, a datastore, and a copy of the application's own tables, which a relay keeps in step.

A Zanzibar-style system stores tuples, `(user, relation, object)`, and a model that says how relations compose. A relation can be a direct tuple, a union, a difference, or a walk from a related object. A condition is a small CEL expression on a tuple, which the server evaluates against the context of each question. A check asks whether one user reaches one relation on one object, and a list asks which objects a user reaches. [The OpenFGA documentation](https://openfga.dev/docs/concepts) has the concepts.

## How to bind

The configuration entry is `adapter: {Mediate.Fga, endpoint: "127.0.0.1:8080", store_id: "01J...", model_id: "01K..."}`, and `options_schema/0` on `Mediate.Fga` answers the fields. `Mediate.Fga.Binding` has the binding options.

1. Create the outbox table and the cursor table in a migration of your own, with the helpers of `Mediate.Fga.Migration`.
2. Bind at boot, after the configuration boots, with the repo, the model file, the tuple mapping, the author, and the approval.
3. Attach the outbox handler with `Mediate.Fga.Outbox.attach/0`.
4. Start `Mediate.Fga.Relay` in your supervision tree, with one runner under the name `Mediate.Fga.Outbox.runner/0` answers.
5. Publish the model with `Mediate.Fga.publish/0`, and pin `model_id` to the id it answers.
6. Call `Mediate.Fga.Relay.wake/1` after a write that produced markers, or wait for the runner's next tick.

Hold your mapping to `Mediate.Fga.TupleMappingCase` and your drain to `Mediate.Fga.OutboxCase`. A test calls `Mediate.Fga.Relay.drain_once/1` and starts no runner.

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

## What this adapter decided

- **The tables are the record, and the store is a copy.** The store as the record was the alternative, and then the change event has no old value and the seam sees no write.
- **A marker in the write's transaction, and a relay pass per object.** A write to the store inside the transaction was the alternative, and a network call cannot join a database transaction.
- **`scope` refuses at the cap.** A truncated list was the alternative, and a list short of the truth carries no sign of it.
- **The session fact is a guard before the call.** A tuple per session was the alternative, and the store would then copy the identity layer.
- **The version is the model id the server returns.** The commit alone was the alternative, and the id is what a question names.

Revocation latency has four components for a fact: commit, a relay pass, the engine write, and the check-cache TTL where a cache is on. A rule has one, a model publication.
