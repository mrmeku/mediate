# Mediate on OpenFGA

*How do I bind this engine, and what mechanism answers each rule shape? For a deployment whose rules are a relationship model in a store of its own.*

`Mediate.OpenFGA` decides from a relationship graph an OpenFGA server holds. Facts become tuples in the store, rules become a model the server names by id, and a decision is a question about the graph under that model. `flake.nix` pins the server. The cost is a server, a datastore, and a copy of the application's own tables, which a relay keeps in step.

A Zanzibar-style system stores tuples, `(user, relation, object)`, and a model that says how relations compose. A relation can be a direct tuple, a union, a difference, or a walk from a related object. A condition is a small expression on a tuple, which the server evaluates against the context of each question. A check asks whether one user reaches one relation on one object, and a list asks which objects a user reaches. [The OpenFGA documentation](https://openfga.dev/docs/concepts) has the concepts.

## The words

Inside `infrastructure/` the package speaks OpenFGA, and at its root it speaks the ledger's words. `docs/naming.md` under "OpenFGA" has every row and why.

| OpenFGA says | The ledger says | Here it is |
|---|---|---|
| user | subject | the account alone, with the kind in the condition's context |
| object | resource | one object type per resource type the mapping states |
| relation | action, or fact | what a check asks, and what a wildcard tuple states about a row |
| tuple | grant | one row of the store, which the mapping states from a table row |
| store | tables | a copy of the application's tables under `store_id`, which sync keeps in step |
| model | policy | the file the deployment binds, and the id the server gives it is the policy version |
| condition, `current_time`, `subject_kind` | context | what every question carries from `now` and the subject kind |
| check, list objects | authorize, filter | the two questions the engine asks |
| marker, relay, pass, cursor | sync | how a write reaches the store: a mark in the write's transaction, delivered one pass at a time |
| guard | rule | the precondition a deployment holds outside the graph, which denies as `rule: "guard"` |

## How to bind

The configuration entry names the server, the store, and the model: `engine: {Mediate.OpenFGA, address: "127.0.0.1:8080", store_id: "01J...", model_id: "01K..."}`. `Mediate.OpenFGA` has the fields of the entry, and `Mediate.OpenFGA.Binding` has the binding options.

1. Create the outbox table and the cursor table in a migration of your own, with `Mediate.OpenFGA.Migration` and `Mediate.Relay.Migration`.
2. After the configuration boots, bind the repo, the model file, the mapping, the author, and the approval.
3. Attach the outbox handler with `Mediate.OpenFGA.Outbox.attach/0`.
4. Start `Mediate.Relay` in your supervision tree, with one runner under the name `Mediate.OpenFGA.Outbox.runner/0` answers.
5. Release the model with `Mediate.OpenFGA.release/0`, and pin `model_id` to the policy version it answers.
6. Call `Mediate.Relay.wake/1` after a write that left markers, or wait for the runner's next pass.

```elixir
{:ok, _binding} =
  Mediate.OpenFGA.Binding.bind(
    repo: MyApp.Repo,
    model_file: "priv/openfga/model.fga",
    mapping: MyApp.Mapping,
    author: "my_app",
    approval: "the review of priv/openfga/model.fga"
  )

:ok = Mediate.OpenFGA.Outbox.attach()
{:ok, _release} = Mediate.OpenFGA.release()
```

Hold your mapping to `Mediate.OpenFGA.MappingCase` and your outbox to `Mediate.OpenFGA.OutboxCase`. A test syncs the store through the engine and starts no runner.

## Mechanism per rule shape

| Rule shape | Mechanism |
|---|---|
| A role held on a row | a tuple from the user to the relation on the object |
| A test on the subject | membership of the value as an object of its own, because a graph compares by a walk and not by equality |
| A test on the row | a wildcard `user:*` on a relation named for the fact, so a row states one tuple and not one per account |
| A test on the moment | a condition on the tuple that carries the date, against `current_time` in the context of every question |
| A grant held by one kind of subject | a condition on the tuple that carries the kind, against `subject_kind` in the context of every question. The user string names the account alone |
| A rule over a whole type | `ListObjects` under the filter limit. At the limit the engine fails the filter, and the caller authorizes each row |
| A write gate | the mediated repo refuses a write with no decision for the action, before the engine asks the model |
| A fact about the session | a `Mediate.OpenFGA.Guard` the binding names, which the engine asks before the server. A condition on a tuple makes every use of the relation demand that fact |

## What this engine decided

- **The tables are the record, and the store is a copy.** The store as the record was the alternative, and then the change event has no old value and the mediated repo sees no write.
- **A marker in the write's transaction, and a relay pass per object.** A write to the store inside the transaction was the alternative, and a network call cannot join a database transaction.
- **A filter at the limit fails.** A truncated list was the alternative, and a list short of the truth carries no sign of it.
- **The session fact is a guard before the call.** A tuple per session was the alternative, and the store would then copy the identity layer.
- **The policy version is the model id the server answers.** The commit alone was the alternative, and the id is what a question names.

Revocation latency has four components for a fact: commit, a relay pass, the store write, and the check-cache TTL where a cache is on. A rule has one, a model release.
