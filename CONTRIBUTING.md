# Contributing

*How do I make a change this repository accepts? For someone with a diff.*

## The environment

The Nix flake is the toolchain and every service: Erlang, Elixir, Postgres, Cerbos, and OpenFGA. Install Nix, and `nix develop` supplies the rest. `flake.nix` holds each tool's version, and `mix.exs` with `mix.lock` holds each Hex package's. This document lists no version, so it cannot drift from them.

## The tests

`mix test` in any app starts an ephemeral Postgres cluster under `tmp/`, runs the app's migrations as the owner role, and removes the cluster when the suite ends. `Mediate.Dev.Cluster` has the steps. A suite that needs Cerbos or OpenFGA starts one the same way, through `Mediate.Dev.Cerbos` or `Mediate.Dev.Fga`.

Three rules hold for every test.

- Every test owns its state: its connection, its clock, its configuration, its store, and its processes. `Mediate.Test` has the overrides.
- No test calls `Application.put_env`. `Mediate.Test.with_config/1` puts the override in the process, and the resolver reads it through `$callers`.
- `async: false` is an exception, and the reason is in the module's tag.

## Where a module goes

Under each Boundary root's directory in `lib/` there are at most three interior places.

- The root is the interface: every module a consumer names.
- `domain/` is what the package knows: structs, schemas, and rules as pure functions. A module there touches no process, file, clock, table, or node.
- `application/` is the use cases: modules that orchestrate the domain with the infrastructure.
- `infrastructure/` is what touches the world, or speaks another system's language even when pure.

Calls run one way. The root reaches every place, `application/` reaches `infrastructure/` and `domain/`, and `infrastructure/` reaches `domain/`. Nothing names another package's interior. An interior module of a published package carries `@moduledoc false`. The structure test in `mediate_dev` reads every source file and enforces this.

Ask in this order before a module exists. Does a consumer of a published package name it? The root. Does it touch the world, or exist because of how another system works? `infrastructure/`. Does it orchestrate a use case? `application/`. Otherwise `domain/`.

## What a review looks for

- A record is a struct with `@enforce_keys`, `defstruct`, and `@type t`. Update it with `%S{s | field: v}`.
- Three things stay maps: the environment, `Answer.meta`, and a telemetry payload.
- Options are `NimbleOptions` schemas. No `opts[:foo]` without a schema.
- Errors are values, `{:error, %Mediate.Error{}}` with a reason atom. A programmer error raises.
- `with` for a chain of results, and every `else` clause names its shape.
- Every pluggable thing is a `@behaviour` with `@impl true` on each callback. No protocols.
- Library code owns one long-lived process, the relay's runner, which starts unnamed.
- `@doc` on every public function, `@spec` beside it, and `@typedoc` on every public type.
- A comment says why, never what.
- Predicates end in `?` and return `true` or `false`. No `String.to_atom/1`.
- Every root module has `use Boundary` with `deps:` and `exports:`.
- Reach the repo through the seam or the owner-role repo, never around them.
- Names: `Mediate.` for the library and `Example*.` for the example. A struct's module is a noun, and a behaviour's module is a role. "Adapter", never "provider".
- A test's name is a law id and sentence from `docs/conformance.md`, or a scenario id and sentence from `docs/example.md`.
- Every warning is an error.

## The gate

```
nix develop --command mix quality
```

What it runs is the `quality` alias in `mix.exs`. It must exit 0. Then run the gate of `docs/writing.md` over every document you changed.
