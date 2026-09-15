# Design

*What Mediate is, what its port says, what the seam is for, and where each thing lives. This is the document the others assume.*

## 1. What Mediate is

Mediate is the minimal port-and-adapters API an Elixir application needs to express its authorization for a FedRAMP Rev 5 Moderate target. It ships with four adapters: roles in code, Postgres row-level security, Cerbos, and OpenFGA. A reader can see what each decision strategy costs, in adapter code and in what the application must express.

The requirements come from NIST SP 800-53 Rev 5 as the FedRAMP Rev 5 Moderate baseline selects and parameterizes them. `docs/requirements.md` lists the lines that reach this library and what answers each. The word "minimal" has a measure. The port carries what the example application needs plus what the conformance laws need. What neither reaches goes.

Five commitments hold across every package.

1. The library emits records and stores nothing. No statement, no history, no log lives in a library package. A consumer attaches a handler and owns the record.
2. A decision lives in a module that a test can call directly. A module that touches the world does nothing else.
3. The surface is what a test can assert. A guarantee that no test can reach is not a guarantee this repository makes.
4. Each tool enforces only what it can see. The seam sees repo calls, the database sees rows, and a Credo check sees source. None of them claims the others' ground.
5. The conformance suites are the asset. Every adapter passes the same laws against its real engine. Each law carries the name of the requirement line it answers.

## 2. The port

The port is `Mediate`, four functions, and nothing else.

| Function | Answers | Returns |
|---|---|---|
| `authorize(subject, operation, object, opts)` | Can this subject perform this operation on this object, and under which decision | `{:ok, %Mediate.Decision{}}` or `{:error, %Mediate.Error{}}` |
| `check(subject, operation, object, opts)` | The same question as a boolean, for a branch that does not go on to the repo | `true` or `false` |
| `scope(subject, operation, object_type, opts)` | Which objects of a type can this subject perform this operation on | `{dynamic, %Mediate.Decision{}}`, an Ecto `dynamic` that can only narrow |
| `review(reviewer, subjects, operation, object_type, opts)` | For each of these subjects, which objects of a type can it perform this operation on, asked by a reviewer | `%{subject => {dynamic, %Mediate.Decision{}}}` |

**The vocabulary** is NIST SP 800-162's. A subject is `{kind, id}`. The kind is `:user`, `:non_person_entity`, or `:privileged`. The port refuses a kind it does not know before it calls any adapter.

An object is `{type, id}`. A decision over a whole type, which `scope` and `review` make, carries `nil` for the id. An operation is an atom. The environment is a map of the facts only the caller knows, given as `opts[:env]`. The port stamps `now` from the configured clock beside them, so a decider reads the moment of the request from the environment.

**Options** are `env`, the environment map, and `operation_id`, one identifier that every event of one operation shares. The port generates one where the caller gives none.

**The structs.** `%Mediate.Answer{verdict, reason, version, meta}` is what an adapter says about one question. The verdict is `:allow` or `:deny`. The reason is one word from a fixed list. The version names the rules that answered, and `meta` is the adapter's own map.

`%Mediate.Decision{id, subject, object, operation, verdict, reason, adapter, policy_version, operation_id, at}` is what the port said, with a stamp. It is the value the seam accepts. `%Mediate.Error{reason, detail}` is the error value. Its reason is the denial's reason where the failure follows a denial. It is `:unsupported`, `:invalid`, or `:unmediated` where the failure is the library's.

**Deny by default and fail closed.** The port never raises on the request path. An adapter that raises, or answers that its engine is unreachable, produces a denial whose decision event carries the exception. The port denies an operation no rule names.

**Review.** `review` asks `scope` once per subject under the reviewer's operation id. It stamps each decision for its subject and emits it. Then it emits the reviewer's own `:scoped` decision over `{type, nil}`. A caller runs each subject's rule as a query that carries that subject's decision. That is what lets an adapter which binds the subject at query time answer a review.

## 3. The adapter behaviour

`Mediate.Adapter` is what a mechanism implements.

| Callback | Required | What it does |
|---|---|---|
| `decide(subject, operation, object, environment, options)` | yes | Answers one question with a `%Mediate.Answer{}`. `authorize` and `check` both route here |
| `scope(subject, operation, object_type, environment, options)` | yes | Answers a `dynamic` over the object type, or an error |
| `scope_cap()` | yes | The most objects one `scope` can name, or `:none` where the rule is a predicate rather than a list |
| `around_query(query_or_changeset, decision, continue)` | optional | Runs around every mediated call, with the decision in force. For an adapter that binds the subject at query time |
| `options_schema()` | optional | The `NimbleOptions` schema of the adapter's own configuration |
| `settle()` | optional | Brings the adapter's own state into step with the tables. `:none` where it reads the tables directly |

An adapter is domain-free. It names no schema of any application and no rule id of the example. A rule reads only the facts the application declares on its schemas (`docs/events.md` §3). The coverage tests each adapter carries hold it to that. An adapter owns mechanism. No sentence in its docs tells the application what it can do.

## 4. The seam

`use Mediate.Repo`, after `use Ecto.Repo`, makes a repo that refuses any call on a protected schema that carries neither a decision nor an exemption. Its purpose is log completeness. The record holds every read and every write of a protected schema, with the subject and the decision it ran under. The seam refuses an unmediated call because that call is an unlogged access.

The same reason refuses a bulk write to an audited schema, which has no old value to record. The seam claims nothing beyond this. It is not a reference monitor, and no control this library answers asks for one.

**What a schema declares.** `use Mediate.Schema` gives a schema four declarations:

- `object_type/1`, which makes it protected.
- `carries/1`, the associations the parent's decision covers.
- `audited/1`, what kind of thing its rows are.
- `fact/2` and `relationship/1`, which columns a rule can read and what they mean.

`docs/events.md` §3 has the declarations in full.

**The surface** is every function `use Ecto.Repo` defines, by name and arity. Each sits in one of four buckets:

- Query: `all`, `one`, `get`, `get_by`, `reload`, `aggregate`, `exists?`, `stream`, `preload`, `all_by`, and the bulk `update_all` and `delete_all`.
- Write: `insert`, `update`, `delete`, `insert_or_update`, `insert_all`, and their forms that raise.
- Raw: `query`, `query_many`, and their forms that raise.
- Plumbing: transactions, checkout, configuration, and the rest.

The seam mediates query and write calls. It refuses a raw call that carries no exemption. Plumbing passes.

**The match.** The seam judges a call by its root source: the schema the query is from, or the changeset is of. A protected root needs a decision whose object type is the root's. A preload needs a decision of its own unless the parent carries the association.

The root judges a query that joins several protected sources, and the root must carry the other sources. A schema that declares no object type passes. That is how `schema_migrations` and the framework's own tables pass without an exemption.

**Exemptions**, one struct: `%Mediate.Exemption{on, caller, reason, kind}`. Per call, `mediate: {:exempt, reason}` with a non-empty reason. The record holds the root source and the caller module. From a `Mediate.*` caller, `mediate: {:exempt, :library}`, which the seam accepts after it reads the caller off the stack. `use Mediate.Repo, role: :owner` is the library's own channel: it runs migrations, it records nothing, and every call on it is library-exempt.

**Refusal** raises `%Mediate.Error{reason: :unmediated}`. The error carries the function and arity, the root source, the decision's object type where there was one, and the caller. There is no mode that logs and does not raise.

**Extension points**, for an adapter:

- `prepare_query/3`, which the seam defines and an adapter's rewrite runs inside.
- The write overrides.
- The raw wrap.
- `around_query/3`. `mediate_postgres` uses it to open a transaction where none exists and bind the subject's session settings on every call.

## 5. The events

Three telemetry events. Each carries what an OCSF 1.3.0 record needs and invents no value. The library stores none of them.

| Event | Published | Answers |
|---|---|---|
| `[:mediate, :decision]` | after every port call | authorization checks, and the execution of privileged functions by subject kind |
| `[:mediate, :change]` | inside the transaction of a single-row write to an audited schema | data changes, deletions, and permission changes. Account creation, modification, and removal |
| `[:mediate, :access]` | after every mediated read of a protected schema | data access: the rows returned and the decision they ran under |

Each adapter also publishes a policy-version event when it puts a version in force. `docs/events.md` has every payload and the guarantees the seam makes about them.

## 6. Packages and placement

| Package | Published | What it holds |
|---|---|---|
| `mediate` | yes | The port, the behaviour, the seam, the schema declarations, the events, and the conformance suites. Its runtime deps are `ecto`, `telemetry`, `nimble_options`, and `stream_data`, and a test in its suite holds that count |
| `mediate_credo` | yes | Two static checks: no raw SQL outside an allowlist, no `use Ecto.Repo` without the seam |
| `mediate_rbac` | yes | Roles in code: a policy module of grants and predicates over the application's tables |
| `mediate_postgres` | yes | Row-level security: policies the migrations write, session settings bound per call |
| `mediate_cerbos` | yes | A sidecar policy engine, fed attributes the application declares |
| `mediate_fga` | yes | OpenFGA: a tuple store that an outbox and a relay keep in step with the tables |
| `mediate_dev` | no | The ephemeral Postgres cluster, the sandbox, the schema dump, the structure test, and the engine runners the suites start |
| `example` | no | The CUI domain, its rules C1 to C13, and the scenario bodies every binding shares |
| `example_rbac`, `example_postgres`, `example_cerbos`, `example_fga` | no | One binding of the example to one adapter, with that adapter's migrations, policies, or model |

**The places** inside a package's `lib/`. Under each Boundary root's directory there are at most three interior places, always with these names. A package uses only the places it needs.

| Place | Holds | Reaches | Rules |
|---|---|---|---|
| root | The interface. In a published package: every module a consumer names (the facade, structs, behaviours, macros, config, case templates, clients). In an unpublished package: the manifest module and the OTP `Application` only. | everything | `@moduledoc` present |
| `domain/` | What the package knows: entities and value objects (structs, Ecto schemas), rules and policies as pure functions, tables of data the rules read. | `domain/` only | Calls nothing that touches a process, a file, a clock, a table, or a node. Names nothing under `application/` or `infrastructure/`. 100 percent line coverage. `@moduledoc false` in published packages |
| `application/` | Use cases: modules that orchestrate the domain with the infrastructure, ask the port, and write through the seam. | `domain/`, `infrastructure/` | Names nothing at another package's interior. `@moduledoc false` in published packages |
| `infrastructure/` | What touches the world: a database, an engine, a file, a clock, a process. Also what speaks another system's language even when pure: codecs, query builders, wire shapes, identifier rules, session settings, event consumers, repos, migration helpers. | `domain/` | Names nothing under `application/`. `@moduledoc false` in published packages |

Calls run one way. The root reaches `application/`, `infrastructure/`, and `domain/`. `application/` reaches `infrastructure/` and `domain/`. `infrastructure/` reaches `domain/`. A nested Boundary owns its own three places under its own directory. `test/support` has no layers and stays flat under the package namespace.

Mix tasks stay under `lib/mix/tasks/`. A path names its module. Nothing in one package names another package's interior. A package's concepts appear only in that package's directory.

**The placement question**, asked in order before a module exists:

- Does a consumer of a published package name it? The root.
- Does it touch the world, or exist because of how another system works? `infrastructure/`.
- Does it orchestrate a use case? `application/`.
- Otherwise `domain/`.

`boundary` and the structure test in `mediate_dev` enforce what the compiler can see. `mix xref graph --label compile-connected --fail-above 0` and `--format cycles --fail-above 0` hold the dependency graph flat.

Library packages ship migration helpers. Migrations exist only in the thin applications, one set each. The thin application states what enforces each rule of the example. An adapter package never does.

## 7. Configuration

Boot validates `%Mediate.Config{}` once, from a `NimbleOptions` schema, and puts it in `:persistent_term`. It is the only runtime configuration the library reads.

| Field | Type | Default |
|---|---|---|
| `adapter` | `module` or `{module, keyword}`. The adapter's own `options_schema/0` validates the keyword. A bare module means `[]` | required |
| `clock` | a zero-arity function that answers the current time in UTC | `&DateTime.utc_now/0` |
| `caps` | keyword with one key, `policy_content_bytes`: the policy text a version carries by value before a pointer takes its place | `[policy_content_bytes: 65_536]` |

Adapter options: `mediate_cerbos` takes an `address`. `mediate_fga` takes an `endpoint`, a `store_id`, a `model_id`, and a `client`. `mediate_rbac` and `mediate_postgres` take none. Tests override any field through `Mediate.Test.with_config/1`, which puts the override in the process dictionary. The resolver checks `self()`, then the `$callers` chain, then the boot struct.

## 8. What reverses a decision

- A team asks for replay: a consumer that stores change events is the adopter's to write, outside this repository.
- A package passes eighty modules: the structure test grows a rule before the shape goes.
- The application wants durable audit at low volume: a consumer over Oban, still the adopter's.
- No test can show the seam covers some repo call: the enforcement moves to the data layer, as the Postgres adapter already does for writes.

## 9. Words

| Term | What it means |
|---|---|
| Subject / object / operation / environment | Who asks, about what, to do what, under what conditions |
| Subject kind | `:user`, a person. `:non_person_entity`, software that acts alone. `:privileged`, a person who can change the system |
| Attribute, fact | A value about a subject or object that a rule can test. Declared on a schema with `fact/2` |
| Grant | A row that gives a subject a role on an object. Declared with `relationship/1` |
| Port / adapter | The four functions in `mediate` / an implementation of `Mediate.Adapter` for one mechanism |
| Answer / decision | What an adapter says about one question / what the port said, with a stamp and an id |
| Deny by default / fail closed | No unless a rule says yes / no when the system cannot decide |
| `scope` / `dynamic` | Narrow a query to what the subject can see / the Ecto where fragment it returns, which can only narrow |
| Scope fidelity | `scope` returns exactly the rows `check` allows |
| `review` | Who can do what, today, asked by a reviewer |
| The seam, mediated repo | A repo that refuses calls that carry no decision and no exemption |
| Surface / bucket | Every function `use Ecto.Repo` defines, by name and arity / the one of query, write, raw, or plumbing each sits in |
| Mediation | The `mediate:` option resolved for one call: the decision or exemption, the caller, and the schemas the decision carries |
| Ambient mediation | The parent write's mediation, held in the process for the nested association writes Ecto makes without the option |
| Caller | The module that called the repo, read from the stack past the repo, the seam, Ecto, and the standard library |
| Exemption (declared / library) | A named, recorded opt-out from mediation, per call, with a reason / the same from a `Mediate.*` caller, or every call on an owner-role repo |
| Owner-role repo | `use Mediate.Repo, role: :owner`: the library's own channel, library-exempt on every call, which records nothing |
| Protected schema / carried relation | A schema that declares an object type / an association the parent's decision covers |
| Audited schema / kind | A schema that declares what kind of thing its rows are / `:user`, `:group`, `:role`, or `:entity` |
| Fact kind | Subject attribute, object attribute, or relationship: what a declared column holds |
| Decision event / change event / access event | One port call / one single-row write to an audited schema / one mediated read, each as telemetry |
| Policy version | The rules an adapter decides under, with an author, an approval, and a content hash. An event announces it when it takes force |
| Consumer | A handler that stores what an event carries. The library emits and the system stores |
| SIEM | The security team's central log system. The example's consumer holds its records in memory |
| Settle | The act that puts an adapter's own state in step with the tables. An adapter that reads those tables has nothing to do |
| Continuous evaluation | Facts read on every check, never cached across requests |
| Revocation latency | Time from a change that revokes to the first denial. Measured and printed, never asserted |
| World / seed | A population of the neutral fixture the conformance laws run over / the module that loads one into an adapter's own state |
| Law | One conformance test, named by a requirement id and a sentence, run by every adapter |
| Scenario | One row of the example's table: an id, a sentence, the rule it shows, and the controls it cites |
| Shape test | A test of what a call does rather than what it answers: the queries it runs and the events it emits |
| Thin application | One of the four applications that bind the example to an adapter |
