# Mediate

Mediate is the minimal port-and-adapters API an Elixir application needs to express its authorization for a FedRAMP Rev 5 Moderate target. It has four parts:

- An application asks one port whether a subject can perform an operation on an object.
- An adapter answers from roles in code, from Postgres row-level security, from a Cerbos sidecar, or from an OpenFGA store.
- A mediated Ecto repo refuses a read or write of a protected table that carries no decision, so no access goes unlogged.
- Three telemetry events, decision, change, and access, carry what an audit record needs.

`docs/requirements.md` lists the NIST lines this answers. The conformance suite is what says an adapter answers them.

## The port

```elixir
# one object: the decision the seam accepts
with {:ok, decision} <- Mediate.authorize(subject, :read, {:document, id}) do
  Repo.get(Document, id, mediate: decision)
end

# a yes or no, for a branch that does not reach the repo
Mediate.check(subject, :approve, {:proposal, id})

# a whole type: a rule the query carries, which can only narrow
{rule, decision} = Mediate.scope(subject, :read, :document)
Repo.all(from(d in Document, where: ^rule), mediate: decision)

# who can do what today, which a reviewer asks
Mediate.review(reviewer, subjects, :read, :document)
```

A subject is `{kind, id}`, and an object is `{type, id}`. The options carry the caller's environment facts and an operation id that every event of one operation shares.

## The four adapters

One port, four mechanisms. Each mechanism is a package. Each package has a thin application that binds it to the same example domain, and the thin application's README says what enforces each rule of that domain.

| Adapter | Package | Example | Rules live in | Revocation latency components | Boundary cost |
|---|---|---|---|---|---|
| Roles in code | `mediate_rbac` | [`example_rbac`](apps/example_rbac/README.md) | Elixir modules. A deploy is a policy version | commit | none |
| Postgres row-level security | `mediate_postgres` | [`example_postgres`](apps/example_postgres/README.md) | migrations. A migration is a policy version | commit | none new |
| Cerbos | `mediate_cerbos` | [`example_cerbos`](apps/example_cerbos/README.md) | policy files with an owner of their own | commit for facts, and policy propagation for rules | one sidecar |
| OpenFGA | `mediate_fga` | [`example_fga`](apps/example_fga/README.md) | a model with an immutable id, and tuples an outbox keeps in step | commit, a relay pass, the engine write, and the check-cache TTL | a server and a datastore |

## Quickstart

The Nix flake carries the toolchain and every service, so the one thing to install is Nix. From the repository root:

```
nix develop
mix deps.get
mix test
```

`mix test` starts an ephemeral Postgres cluster on a unix socket under `tmp/` and removes it on exit. Then run one thin application's scenarios to see one adapter decide the example:

```
cd apps/example_rbac
mix test
```

Every scenario of `docs/example.md` §4 is a test there, with its id and sentence as the name. The other three thin applications run the same scenarios with the rules in migrations, in policy files, and in a relationship graph.

## Layout

An umbrella. `apps/mediate` is the port, the seam, the events, and the conformance suites. `apps/mediate_rbac`, `apps/mediate_postgres`, `apps/mediate_cerbos`, and `apps/mediate_fga` are the adapters. `apps/mediate_credo` holds the two static checks. `apps/mediate_dev` holds the test cluster and the engine launchers, and it is not published. `apps/example` is the domain and its scenarios. `apps/example_rbac`, `apps/example_postgres`, `apps/example_cerbos`, and `apps/example_fga` bind it to one adapter each.

Inside every package the same places mean the same thing:

- the root of `lib/` is the interface
- `domain/` is what the package knows
- `application/` is its use cases
- `infrastructure/` is what touches the world or speaks another system's language

`docs/design.md` §6 has the table.

## Working on it

```
nix develop --command mix quality
```

`docs/contributing.md` §5 says what `quality` runs and how a stage delivers.

## The documents

- `docs/design.md`: what Mediate is, the port, the seam, the events, the packages, and the words.
- `docs/requirements.md`: the NIST lines, one row per applicable control, and what answers each.
- `docs/conformance.md`: the laws every adapter passes and the guarantees every repo passes.
- `docs/events.md`: the payload of each event and the OCSF mapping the example shows.
- `docs/example.md`: the CUI domain, its thirteen rules, and the scenario table.
- `docs/contributing.md`: toolchain pins, the test environment, code and prose conventions, and the gate.
