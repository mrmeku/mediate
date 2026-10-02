# Mediate

*What is Mediate, and how do I run it? For an adopter with an Elixir application and a FedRAMP target.*

Mediate is the authorization API an Elixir application uses for a FedRAMP Rev 5 Moderate target. An application asks four functions whether a subject can perform an action on a resource. An engine answers from roles in code, from Postgres row-level security, from a Cerbos server, or from an OpenFGA store. A mediated Ecto repo refuses a read or write of a protected table that carries no decision, so no access goes unlogged. Three telemetry events, the decision, the identity write, and the resource read, carry what an audit record needs. `docs/controls.md` names the NIST line each part answers.

## The four calls

```elixir
# one resource: the decision the mediated repo accepts
{:ok, decision} = Mediate.authorize(subject, :read, {:repository, id})
Repo.get(Repository, id, authorized_by: decision)

# a yes or no, for a branch that does not reach the repo
Mediate.authorized?(subject, :approve, {:proposal, id})

# a whole type: a rule the query carries, which can only narrow
{rule, decision} = Mediate.filter(subject, :read, :repository)
Repo.all(from(r in Repository, where: ^rule), authorized_by: decision)

# who can do what today, asked by a reviewer
Mediate.review(reviewer, subjects, :read, :repository)
```

A subject is `{kind, id}`, and a resource is `{type, id}`. The `Mediate` moduledoc has the options and says when to use each call.

## The engines

| Engine | Package | Where the rules live | What you deploy beside the app |
|---|---|---|---|
| Roles in code | `mediate_rbac` | Elixir modules | nothing |
| Postgres row-level security | `mediate_postgres` | migrations | nothing new |
| Cerbos | `mediate_cerbos` | policy files | one server |
| OpenFGA | `mediate_openfga` | a model and a tuple store | a server and its datastore |

Each engine's README says how to bind it. An engine of your own takes `mediate_conformance` in the test environment, whose cases hold it to `docs/conformance.md`. Each engine here has a deployment that binds it to one example domain: [`example_rbac`](https://github.com/mrmeku/mediate/blob/main/apps/example_rbac/README.md), [`example_postgres`](https://github.com/mrmeku/mediate/blob/main/apps/example_postgres/README.md), [`example_cerbos`](https://github.com/mrmeku/mediate/blob/main/apps/example_cerbos/README.md), and [`example_openfga`](https://github.com/mrmeku/mediate/blob/main/apps/example_openfga/README.md).

## Quickstart

Install Nix. The flake carries the toolchain and every server.

```
nix develop
mix deps.get
mix test
cd apps/example_rbac && mix test
```

The first `mix test` runs every package's suite on a Postgres cluster of its own. The second runs the example's scenarios under one engine. `docs/example.md` has the scenarios.

## The documents

- `docs/design.md`: why Mediate is shaped this way, and what it rejected.
- `docs/naming.md`: which word names each thing in the API, and why that word.
- `docs/controls.md`: which NIST line each requirement and scenario answers.
- `docs/conformance.md`: what an engine and a mediated repo must satisfy.
- `docs/events.md`: what each telemetry event carries, and when it fires.
- `docs/example.md`: what the example domain protects, and which scenarios prove it.
- `docs/writing.md`: how a document earns its place, and how it is written.
- `CONTRIBUTING.md`: how to make a change this repository accepts.
