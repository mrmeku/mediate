# Mediate

*What is Mediate, and how do I run it? For an adopter with an Elixir application and a FedRAMP target.*

Mediate is the port-and-adapters API an Elixir application uses to express its authorization for a FedRAMP Rev 5 Moderate target. An application asks one port whether a subject can perform an operation on an object. An adapter answers from roles in code, from Postgres row-level security, from a Cerbos sidecar, or from an OpenFGA store. A mediated Ecto repo refuses a read or write of a protected table that carries no decision, so no access goes unlogged. Three telemetry events, decision, change, and access, carry what an audit record needs. `docs/controls.md` names the NIST line each part answers.

## The port

```elixir
# one object: the decision the seam accepts
{:ok, decision} = Mediate.authorize(subject, :read, {:document, id})
Repo.get(Document, id, mediate: decision)

# a yes or no, for a branch that does not reach the repo
Mediate.check(subject, :approve, {:proposal, id})

# a whole type: a rule the query carries, which can only narrow
{rule, decision} = Mediate.scope(subject, :read, :document)
Repo.all(from(d in Document, where: ^rule), mediate: decision)

# who can do what today, asked by a reviewer
Mediate.review(reviewer, subjects, :read, :document)
```

A subject is `{kind, id}`, and an object is `{type, id}`. The `Mediate` moduledoc has the options and says when to use each call.

## The adapters

| Adapter | Package | Where the rules live | What you deploy beside the app |
|---|---|---|---|
| Roles in code | `mediate_rbac` | Elixir modules | nothing |
| Postgres row-level security | `mediate_postgres` | migrations | nothing new |
| Cerbos | `mediate_cerbos` | policy files | one sidecar |
| OpenFGA | `mediate_fga` | a model and a tuple store | a server and its datastore |

Each adapter's README says how to bind it. Each has a thin application that binds it to one example domain: [`example_rbac`](apps/example_rbac/README.md), [`example_postgres`](apps/example_postgres/README.md), [`example_cerbos`](apps/example_cerbos/README.md), and [`example_fga`](apps/example_fga/README.md).

## Quickstart

Install Nix. The flake carries the toolchain and every service.

```
nix develop
mix deps.get
mix test
cd apps/example_rbac && mix test
```

The first `mix test` runs every package's suite on an ephemeral Postgres cluster. The second runs the example's scenarios under one adapter. `docs/example.md` has the scenarios.

## The documents

- `docs/design.md`: why Mediate is shaped this way, and what it rejected.
- `docs/controls.md`: which NIST line each law, guarantee, and scenario answers.
- `docs/conformance.md`: what an adapter and a mediated repo must satisfy.
- `docs/events.md`: what each telemetry event carries, and when it fires.
- `docs/example.md`: what the example domain protects, and which scenarios prove it.
- `docs/writing.md`: how a document earns its place, and how it is written.
- `CONTRIBUTING.md`: how to make a change this repository accepts.
