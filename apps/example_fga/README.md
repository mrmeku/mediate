# The example on a relationship graph

The controlled-unclassified-information example of `example`, bound to the `Mediate.Fga` adapter. This application is thin. It boots the configuration, binds the model file, the tuple mapping, and the guard to the example's repo, starts the relay, and carries the migrations. The tables below say what enforces each rule of the example under this binding. The domain, its contexts, and every scenario live in the example, and the mechanism lives in the adapter.

The rules are a model a server holds. The facts are tuples of `(user, relation, object)` in a store, and the store is a copy of the example's own tables. A write leaves a marker in its own transaction, and a relay pass brings the store to what those rows require, object by object.

## What binding costs

- `ExampleFga.Application`: the boot. It binds the repo, the model file, the mapping, and the guard, and attaches the marker handler. It starts the repos, the consumer, and the runner, and publishes the model as a policy version.
- `ExampleFga.Infrastructure.TupleMapping`: which objects the tables hold, which objects a change affects, and which rows an object's tuples come from.
- `lib/example_fga/infrastructure/tuples.ex`: what a row states, once the mapping has fetched it. It decides and touches nothing, so a test calls it directly.
- `ExampleFga.Infrastructure.Guard`: the re-authentication window. The guard reads it from the environment before the adapter asks the server, because no tuple carries a fact about the session.
- `priv/fga/model.fga`: the model as text. It is the artifact under review, and a policy version carries it as its content.
- `priv/repo/migrations/`: the example's tables through the library helpers, then the marker outbox and the cursor of the relay.
- `priv/schema/fga.sql`: the schema the migrations produce, which the gate regenerates and compares.
- `config/config.exs`: `FGA_ENDPOINT` and `FGA_STORE_ID`, which this application boots with.

## The example's words in the model's words

| The example says | The model says |
|---|---|
| A program member or a program lead | `user:U member program:P`, `user:U lead program:P`. The relay writes them while the program is open and deletes them when it closes |
| A designating office's designator or approver | `user:U designator office:O`, `user:U approver office:O`, one tuple per office-role row, so an account that holds both roles in one office holds both relations |
| An office of an agency | `agency:A agency office:O` |
| A document's program and designating office | `program:P program document:D`, `office:O designating_office document:D` |
| A portion of a document | `portion:X portion document:D`, `document:D document portion:X` |
| A control the banner carries | `user:* fedonly_applies document:D` and the three flags beside it. The wildcard means the control applies to everyone |
| A category the banner names | `category:C category document:D`, and the same on a portion that names one |
| A specified category's implied controls | `user:* fedonly_applies category:C`, which `fedonly_applies from category` reaches, so the mapping copies nothing into the document |
| A decontrol date | `before_decontrol` with the date on the flag and category tuples, compared with `current_time`, which the adapter sends with every question |
| The countries REL TO releases to | `country:CC releasable_to document:D`, cleared by `member from releasable_to` |
| A named list | `user:U listed document:D`, which combines with nothing else |
| An account's employment and nationality | `user:U member employment:federal`, `user:U member country:CC`, the value as an object of its own, because a graph compares by a walk |
| An agency's nationality and its own staff | `country:CC domestic agency:A`, `employment:federal federal agency:A` |
| A marking proposal | `office:O office proposal:R`, `user:U proposer proposal:R`, and the approval is the approver less the proposer |
| Who asks | `user:U`, the user of every check, whatever kind the subject carries |
| Re-authentication within the window | nothing: the guard reads it from the environment before the adapter asks the server |
| The override permission | nothing: the override is Elixir under a declared exemption, and the model has no relation for it |
| The version a decision names | the id the server gave the model at its publication |

## The mechanism per rule

| Rule | Mechanism | Enforced by |
|---|---|---|
| C1 Lawful purpose | `lawful_purpose`, the members of the document's program or of its designating office | the engine |
| C2 Controls, all of | `can_read: lawful_purpose but not blocked`, where the subject must clear each flag that applies, and an absent flag blocks nobody | the engine |
| C3 Specified categories | the category carries its own flags, and the document inherits them through `from category`. A category that is not specified has no flags, so it implies nothing | the engine |
| C4 Banner | the document's flags include `from portion`, so a control a portion carries applies to the document by construction. `relto_clear` reads the document's own country tuples, which are the banner `Example.Application.Documents` keeps at write time. The redacted read is `can_read_redacted` on the document with `can_read` per portion | the application |
| C5 Decontrol | the condition `before_decontrol` on the tuples a date lapses. It holds the date and compares it with the moment of the question in the context, so a date that passes needs no write | the engine |
| C6 Named list | `listed`, a grant per document, with no path from it to `lawful_purpose` | the engine |
| C7 Marking gates | `can_change_marking` and the relations computed from it. The seam refuses the write itself before the adapter asks the model | the seam |
| C8 Re-authentication | the guard the binding names, which reads `reauthenticated_at` from the environment and refuses before the call | the adapter |
| C9 Separation of duties | `can_approve_marking: approver from office but not proposer`, on the proposal | the engine |
| C10 Audited override | the read is Elixir under a declared exemption. Permission, justification, event, and report are the example's code, and the model has no relation for it | the application |
| C11 Continuous evaluation | every check walks the tuples the store holds, which the relay brings to what the tables require, marker by marker | the engine |
| C12 Revocation clock | measured and recorded beside the configured maximum, the relay pass included, never asserted | the adapter |
| C13 Scope fidelity | `ListObjects` under the cap becomes a rule over identifiers. At the cap or above it the answer is short of the truth with no sign of it. So the adapter refuses, and the caller asks per row (limited) | the engine |
