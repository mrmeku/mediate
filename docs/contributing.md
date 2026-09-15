# How to contribute

*This document says how the repository builds, tests, writes, and delivers. §1 pins the toolchain. §2 describes the test environment. §3 gives the code rules. §4 gives the prose rules. §5 gives the gate.*

## 1. Toolchain

Nix pins the toolchain and every service. A contributor installs Nix, and the flake supplies the rest. There is no Docker. `direnv` with `use flake` enters the environment on `cd`. CI runs `nix develop --command mix quality`, so dev and CI share one closure.

**Pins.** The table lists each pin and where a check on 2026-09-07 confirmed it.

| Component | Version | Nix expression | Where verified |
|---|---|---|---|
| nixpkgs | `nixos-unstable`, head `c043004d…` (2026-09-05) | the flake's locked input | stable 26.05 has openfga 1.14.2, so only unstable matches every pin at once |
| Erlang/OTP | 29.0.6 | `beam.packages.erlang_29` | https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/development/interpreters/erlang/29.nix, the same on `nixos-unstable` |
| Elixir | 1.20.4 | `beam.packages.erlang_29.elixir_1_20` | https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/development/interpreters/elixir/1.20.nix (minimum OTP 27, maximum 29) |
| PostgreSQL | 18.6 | `postgresql_18`, never the bare `postgresql` alias | https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/servers/sql/postgresql/18.nix. The alias is 18 on unstable and 17 on both stable branches |
| OpenFGA | 1.19.0 | `pkgs.openfga` | https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/op/openfga/package.nix. Release https://api.github.com/repos/openfga/openfga/releases/latest, release date 2026-08-25 |
| Cerbos | 0.55.0 | a `stdenvNoCC` derivation that fetches `cerbos_0.55.0_<Linux\|Darwin>_<x86_64\|arm64>.tar.gz` per system, with hashes in the flake | nixpkgs has no cerbos on any branch (https://github.com/NixOS/nixpkgs/issues/290460). Release https://api.github.com/repos/cerbos/cerbos/releases/latest, release date 2026-08-13. The tag has `v`, the filename does not |
| services-flake | active, last commit 2026-08-18 | the flake's input. It supplies the `postgres` service. Cerbos and OpenFGA run as process-compose processes | https://github.com/juspay/services-flake. It has no cerbos or openfga service module |

**Hex pins.** A check against `https://hex.pm/api/packages/<name>` on 2026-09-07 confirmed each version. `mix.lock` is the pin.

| Package | Version | Note |
|---|---|---|
| `nimble_options` | 1.1.1 | |
| `stream_data` | 1.4.0 | a runtime dependency of `mediate`, because the conformance generators are the product an adopter runs |
| `boundary` | 0.10.4 | two years without a release. It compiles and reports on Elixir 1.20 |
| `styler` | 1.12.2 | |
| `muontrap` | 2.0.0 | a new major. The 2.0 changelog confirms the `MuonTrap.Daemon` API the launchers use |

On Darwin the Cerbos binary arrives as a tarball that Nix unpacks into the store. No quarantine attribute attaches, so Gatekeeper does not prompt. A comment beside the derivation in `flake.nix` says so. In the flake's shell, `cerbos --version` prints 0.55.0 and `openfga version` prints 1.19.0. `nix run .#services` starts Postgres, Cerbos, and OpenFGA on local ports for a thin application run by hand. `mix test` never touches them.

## 2. The test environment

**Every test owns its state**: its own connection, clock, configuration, Cerbos when it changes policies, OpenFGA store, operation ids, and processes. `async: true` is the default. `async: false` is an exception, with its reason in the tag.

**The ephemeral cluster.** `test_helper.exs` in every app calls `Mediate.Dev.Cluster.start/1`. The call does these things:

- It runs `initdb` into `tmp/pg-<random>/` with `--auth=trust`.
- It starts Postgres on a unix socket, with no TCP port and `fsync=off`.
- It creates the role `mediate_owner`, which owns the tables and runs migrations.
- It creates the role `mediate_app`, which owns nothing and carries `NOBYPASSRLS`.
- It creates the databases `mediate_test` and `mediate_committed`.
- It runs the migrations the caller names, as the owner, through the `migrate:` function the caller passes.
- It configures the test repos at boot. This is the one place that can call `Application.put_env`.
- It registers `ExUnit.after_suite/1` and `System.at_exit/1`, which stop every cluster and remove its directory.

Startup takes about one second. The socket directory is random, so `mix test --partitions N` runs N clusters side by side.

Inside the run, the SQL sandbox in `:manual` mode gives each test a connection inside a transaction. Every case template's `setup` calls `Mediate.Dev.Sandbox.setup/2`. A test tagged `:committed` gets no sandbox. It runs real commits on the committed database and truncates through the owner-role repo in `setup` and `on_exit`. The Postgres adapter binds session settings inside `around_query/3` with transaction scope, so they cannot leak between tests.

**Cerbos and OpenFGA.** The launchers live in `mediate_dev`, which does not ship. A launcher starts an OS process, which takes `muontrap`. An adapter package carries no dependency its users do not need.

`Mediate.Dev.Cerbos.start_shared/1` starts one `cerbos server` for the run, under `MuonTrap.Daemon`, on a free loopback port. It serves the app's policy directory. `example_cerbos` serves a copy under `tmp/`, because a scenario that publishes a rule change writes a policy file into the directory the sidecar watches.

`Mediate.Dev.Fga.start_shared/1` starts one `openfga run --datastore-engine memory`. Each test gets a store of its own inside it. A test that publishes a version, or reconciles against out-of-band writes, starts its own instance with `start_supervised` and a temp directory. That takes about one hundred milliseconds, and the test stays async. A test that needs no server runs against `Mediate.Fga.Client.Fake`, an `Agent` in the test support of `mediate_fga`.

**The async patterns.**

| Shared thing | Pattern |
|---|---|
| The clock | `Mediate.Test.Clock.set/1` installs a closure over one moment for the rest of the process. The override travels through `$callers` |
| Configuration | `Mediate.Test.with_config/1` sets it for the rest of the process, and `with_config/2` around a function. `Mediate.Config.resolve/0` checks `self()` and the `$callers` chain. A test must not call `Application.put_env` |
| Telemetry handlers | `Mediate.Test.queries/2` and `changes/1` attach for one function and drop events from other processes. A decision assertion routes events to itself with `:telemetry_test.attach_event_handlers/2` and filters by its operation id |
| The fake adapter | `Mediate.Test.Fake`, an `Agent` per test via `start_supervised`, bound through the override. It returns values of the real types and never raises in their place |
| The OpenFGA store | A store per test. `setup` publishes the model and puts its id in the override |
| The relay's runner | It starts unnamed, with the repo, the job, and the clock injected. Tests call `drain_once/1` and never leave a runner live. `Mediate.Test.settle/0` settles the configured adapter where it has state of its own and answers `:none` otherwise |
| Time | No `Process.sleep/1` outside `Mediate.Test.poll/2`, a deadline loop for latency measurement and for waits on external processes |

**What proves what.** Conformance suites prove that a module which touches the world behaves as every other of its kind. These are `AdapterCase`, `RepoCase`, and the `OutboxCase` and `TupleMappingCase` of `mediate_fga`.

Properties prove a decision is right for inputs nobody thought of, over modules under `domain/` that need no database. Scenarios prove the example obeys its own rules under every binding. Shape tests prove the work has the right size, by counts of queries and events rather than by time. `docs/conformance.md` lists the laws, and `docs/example.md` §4 lists the scenarios.

**The count test.** `use Example.Scenarios` ends with one more test: the scenario ids in the module are the table's ids, all of them and no others. No binding declares a scenario unsupported, so a green run answers every row.

**The structure test**, in `mediate_dev`, reads every `.ex` under `lib` and `test/support` from the syntax tree and holds it to `docs/design.md` §6.

**Committed outputs.** The schema dump is the one output the gate compares against a file. `mix mediate.schema_dump` in a thin application starts a cluster, runs its migrations as the owner, and writes `pg_dump --schema-only` into `priv/schema/<adapter>.sql`. CI's `git diff --exit-code priv/schema/` is the assertion. The Postgres dump is where the row-level security policies are legible as SQL.

## 3. Code

**Write inferable code.** Elixir 1.20 infers the types of function bodies, guards, and clauses across applications. It reports dead clauses and verified bugs and avoids false positives. Every type warning is a bug, and `warnings_as_errors: true` treats it as one. `@spec` and `@type` are documentation, not checker input, and Credo keeps them present. Leave the checker evidence: structs over bare maps, atom unions over strings, generated clauses over attribute lookups, fakes that return real types.

**Records are structs.** No bare map crosses a function boundary inside the library as an ad hoc struct. Every struct has `@enforce_keys` for every field without a meaningful default, `defstruct`, `@type t` with every field typed, and `@moduledoc`. Do not call `Map.put/3`, `Map.merge/2`, `Map.update/4`, `Map.delete/2`, or `Access` on a struct. Update with `%S{s | field: v}`.

Three things stay maps: the environment, `Answer.meta`, and a telemetry payload. One edge builds each of them. Options are `NimbleOptions` schemas. No `opts[:foo]` without a schema.

**The knobs**, all on, in every app:

- `elixir: "~> 1.20.4"`.
- `elixirc_options: [warnings_as_errors: true, infer_signatures: true, no_warn_undefined: []]`.
- `use Boundary` with explicit `deps:` and `exports:` in every root module.
- `@impl true` on every callback.
- `mix format --check-formatted` with `plugins: [Styler]`.
- `mix credo --strict --all` with every check on. Each disabled check carries a comment.
- Coverage thresholds of 90 percent per application, and 100 percent over `domain/` under `MEDIATE_DOMAIN_COVERAGE`.

Dialyzer and runtime type-check libraries are off on purpose. The compiler's checker has the sound half of what they offered.

These Credo checks are off by default and on here: `Readability.Specs`, `StrictModuleLayout`, `ImplTrue`, `WithSingleClause`, `Refactor.WithClauses`, `Apply`, `Warning.UnsafeToAtom`, `MapGetUnsafePass`, and `Design.AliasUsage`. `ABCSize`, `CyclomaticComplexity`, and `Nesting` run at strict thresholds. `TagTODO` and `TagFIXME` are failures. `mediate_credo` ships `Mediate.Credo.NoRawSQL` and `Mediate.Credo.UnmediatedRepo`. The second excepts the owner-role repo.

**Idioms.**

- Module layout follows Styler's order: `@moduledoc`, `@behaviour`, `use`, `import`, `alias`, `require`, attributes, `@enforce_keys` and `defstruct`, `@type`s, `@callback`s, public functions, private functions. One module, one concept. No `Helpers` or `Utils`.
- Every pluggable thing is a `@behaviour`. The behaviour's `behaviour_info/1` enumerates its surface. `function_exported?/3` answers optional callbacks at runtime, so one build serves every adapter. No protocols.
- A declaration compiles to a clause. `use Mediate.Schema` accumulates at compile time, and a `@before_compile` writes `__mediate__/1` with one clause per question. An adapter's `scope_cap/0` and `settle/0` work the same way.
- Errors are values: `{:error, %Mediate.Error{}}` with a reason atom. A programmer error raises. The port never raises on the request path. The seam's refusal raises, because an unmediated call is a programmer error. No `{:error, :atom}`, no strings, no `nil` for not found.
- Predicates end in `?` and return exactly `true` or `false`. Do not call `String.to_atom/1`. Use `Ecto.Enum` for atom-valued fields. Put `nil` in a struct only where absence carries information, and every consumer branches on it.
- Use `with` for a chain of results, and name the shape in every `else` clause. No `try/rescue` for control flow.
- `apply/3`, `__info__/1`, and `Code.*` live only in the conformance templates, and Credo allowlists them by module. The seam's overrides are `@before_compile` with `defoverridable` and `super`. The public macros are `use Mediate.Repo`, `use Mediate.Schema` and its declarations, the case templates, and `scenario`.
- Library code owns one long-lived process, the relay's runner, which starts unnamed. Only the seam's mediation entry, the dynamic-repo entry, and the test configuration resolver touch the process dictionary.
- Ecto: `@primary_key` and field types are explicit. Changesets cast at the edge. Reach the repo only through the seam or the owner-role repo. The `dynamic` that `scope` returns is opaque to the checker. The scope-fidelity law covers it instead.
- `@doc` on every public function, `@typedoc` on every public type, `@doc false` for what a macro needs public. A doctest where an example is cheap and true. A comment says why, never what.
- Names: `Mediate.` for library modules. `Example.`, `ExampleRbac.`, `ExamplePostgres.`, `ExampleCerbos.`, and `ExampleFga.` for the example. A struct's module is a noun, a behaviour's a role. "Adapter", never "provider". Test names are law ids and sentences from `docs/conformance.md`, or scenario ids and sentences from `docs/example.md`.

**Placement** is `docs/design.md` §6: ask its question before you add a module, and put the module where the answer says.

## 4. Prose

Every document, `@moduledoc`, `@doc`, `@typedoc`, and `#` comment follows ASD-STE100, Simplified Technical English, Issue 9. The rules below are the part of the standard this repository holds to. The standard's dictionary is not free to copy, so the plainest common word stands in for it.

**The rules.**

- One claim per sentence.
- A descriptive sentence has 25 words or fewer. A step has 20 words or fewer.
- A paragraph has one topic and six sentences or fewer.
- Active voice, present tense. A step is an imperative.
- `must` for a requirement, `can` for a possibility. Never `should`, `may`, `might`, `could`, or `would`.
- No verb in its `ing` form. A noun that ends in `ing`, such as `marking` or `setting`, is a technical name and stays.
- No semicolon. A new sentence does its work.
- None of *simply, just, obviously, easy, easily, of course, basically, note that, in order to*. No exclamation marks. No em dashes. No name the project had before.
- A list for three or more items. Articles present. Code and technical names in backticks.
- Sentence-case headings. One word per concept: `adapter` never `provider`, and `subject`, `object`, `operation`, and `environment` from NIST SP 800-162.
- Second person in a how-to, impersonal in reference.

**Two registers.** Prose that explains, in `docs/design.md` and each README, states the problem before the mechanism and says why the alternative lost. Reference, in a module doc, a table, a callback spec, `docs/conformance.md`, and `docs/events.md`, says what a thing is and when to use it, then stops.

**What a unit says.**

- `@moduledoc`: the first sentence stands alone in a module list. Then when to use the module and what it is not.
- `@doc`: what the function returns or does, in the third person. Then the arguments, then an example.
- A README summarizes and is the source of nothing. A thin application's README has the rule-to-mechanism table and the translation table. An adapter package's README states the mechanism per rule shape, the declarations, and the measured latency. No sentence in it tells the application what it can do.
- A concept that belongs to someone else gets two sentences in our words and a link, never a section.

**When a unit goes.** A unit is a document section, a `@moduledoc`, a `@doc`, a `@typedoc`, or one `#` block. The first rule that matches decides.

| Rule | Delete when |
|---|---|
| D1 | The sentence adds nothing beyond the function name, the `@spec`, and the argument names. The `@doc` itself stays |
| D2 | A `#` block narrates the lines under it |
| D3 | A `docs/*.md` section makes the same claim. One pointer sentence stays |
| D4 | A why that does not answer "why this and not the obvious alternative" |
| D5 | A README holds a fact alone. Move the fact to its home, unless `docs/example.md` §5 names the README as the home |
| D6 | A `#` block after `@moduledoc false` that states no why |
| D7 | A glossary entry that fewer than two documents use, or that another document defines |
| D8 | A design record that is long, or that does not say when the design changes |

**What a claim needs to stay.** This unit is its home, and it is one of these:

- the first sentence a module list needs
- a when-to-use
- a what-it-is-not
- an argument or a return
- a why

**The gate** is the grep in `CLAUDE.md`, run over every changed document. It must print `exit=1`. This file is the one exception, because it lists the words.

## 5. Delivery

**How a stage runs.**

1. Read `CLAUDE.md` and the files it lists, then what the work needs. Read nothing else.
2. Work on `main`. No worktree, no branch. Stages are sequential.
3. Run every command inside `nix develop --command`, from the directory the gate names. Green means exit 0 with warnings as errors.
4. Run the gate of every package the work touched, then the root gate.
5. Run the prose gate over every document changed.
6. Commit unsigned, one idea per commit: `git -c commit.gpgsign=false commit`. Push after every commit.
7. In the last commit message, quote every gate command and its output. Then record each version pinned or re-verified, and where. Record each open call and which way it went. Record what the next stage needs that no document says.

Do not work around a gate that fails. Report what failed and stop.

**The root gate.** At the root, `mix quality` runs these steps in order:

- `hex.audit` first, because Hex requires it before any task that loads the application.
- `format --check-formatted`.
- `compile --force --warnings-as-errors --all-warnings`.
- `credo --strict --all`.
- `xref graph --label compile-connected --fail-above 0` and `xref graph --format cycles --fail-above 0`.
- `deps.unlock --check-unused`.
- `deps.audit`, with the one acknowledged advisory named by id in `mix.exs` beside its reason.
- `docs --warnings-as-errors`.
- The test step, which runs each app's suite in an OS process of its own. One VM cannot hold two thin applications that bind the same example modules.

`mix test.domain` runs unpartitioned over every app that owns a `domain/` and holds each module there to every line. The two commands keep the design's two numbers: the runtime dependency count of `mediate`, a test in its own suite, and `domain/` at 100 percent.

```
$ mix quality
<green>
$ mix test.domain
<every app that owns a domain/>, 0 failures
```

**The gate per package.** Each package runs its own `mix quality`, which is the root's minus the lock check, and then its own gate.

| Package | Its own gate | What it proves |
|---|---|---|
| `mediate` | `mix test --only committed` | The seam's refusals, `RepoCase` against the test repos, and the template against `Mediate.Test.Fake` |
| `mediate_rbac`, `mediate_postgres`, `mediate_cerbos`, `mediate_fga` | `mix test` | The laws hold for that adapter against its real engine. The latency laws print a measurement |
| `mediate_credo`, `mediate_dev` | `mix test` | The two static checks, and the structure test over every package |
| `example` | `mix quality` | The domain, its contexts, and the scenario bodies every binding shares |
| `example_rbac`, `example_postgres`, `example_cerbos`, `example_fga` | `mix mediate.schema_dump && git diff --exit-code priv/schema/`, then `mix test` | The committed schema is what the migrations produce, and every scenario passes under that binding |

A change to a library package runs before the thin application that binds it. A change to a frozen table runs before the code that reads it. The freeze test in `mediate` holds the adapter's callbacks, the struct fields, the law table, and the guarantee table to their documents. The freeze test in `example` holds the scenario table to its document.

**CI** is one workflow, with `nix develop` everywhere. It has three kinds of job:

- `quality`, with the tests across four partitions, each with its own cluster.
- `domain_coverage` alone, because a partitioned run measures a part.
- One job per thin application, which regenerates the schema dump, diffs it, and runs the scenarios with coverage.

Every app's coverage threshold is 90 percent, and warnings are errors in every job.

**The split that stays.** The library emits and the system stores. A stage that adds a store to a library package is outside the design, not behind a flag.
