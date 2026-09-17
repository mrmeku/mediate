# Design

*Why is Mediate shaped this way, and what did it reject? For a reader who wants to change the shape.*

Each entry is one decision, the alternative it rejected, and why. The moduledocs say what each thing does, and `docs/conformance.md` says what a test asserts.

## What the library is not

- **The library emits records and stores nothing.** A store in a library package, a table or a log, was the alternative. A consumer attaches a handler and owns the record, so retention, protection, and review of the record are the deployer's.
- **The seam is not a reference monitor.** A claim that every access passes through it was the alternative. The seam sees repo calls and nothing else, and no control in the baseline asks for a reference monitor.
- **Each tool enforces what it can see.** The seam sees repo calls, the database sees rows, and a Credo check sees source. One tool that claims the others' ground was the alternative, and no test can hold it to that claim.
- **The port is minimal by a measure.** It carries what the example application needs plus what the conformance laws need. A port that anticipates a need was the alternative, and what neither reaches goes.

## The port

- **Four functions, and no fifth.** A policy language of the library's own was the alternative. The mechanism belongs to the adapter, and the port belongs to the application.
- **A decision is a struct the seam accepts.** A boolean was the alternative. A boolean cannot carry the id, the version, and the subject the repo call must log under.
- **`scope` returns a `dynamic` that can only narrow.** A query the adapter builds was the alternative. A fragment the caller adds to a query it wrote cannot widen the query, and the scope-fidelity law holds the fragment to what `check` says.
- **`review` asks `scope` once per subject under the reviewer's operation id.** A review callback on the adapter was the alternative. An adapter that binds the subject at query time answers a review through the same callback, and the reviewer's own decision joins the subjects' under one id.
- **Deny by default, fail closed.** The port denies an operation no rule names, and denies when the adapter raises or reports its engine unreachable. An engine error passed to the caller was the alternative, and a caller that forgets to handle it allows.
- **A bad call raises, and a bad answer denies.** An option that fails validation and a configuration that never booted are programmer errors, so they raise before the adapter runs. The decision event still fires, with `verdict: nil` and the exception, so no call goes unrecorded.
- **The vocabulary is NIST SP 800-162's.** Subject, object, operation, and environment. Actor, resource, action, and context were the alternative, and the assessor reads 800-162.
- **Three subject kinds, refused before any adapter runs.** A free atom was the alternative. A fixed list is what lets a decision event say that a privileged function ran.
- **The environment is a map the caller fills, with `now` stamped from the configured clock.** A clock in each adapter was the alternative. One clock lets a test set the moment and lets every adapter agree on it.

## The seam

- **A mediated repo refuses a call that carries no decision and no exemption.** A mode that logs and does not raise was the alternative. An unmediated call is an unlogged access, and a log a flag can silence is not complete.
- **The refusal raises.** An error value was the alternative. An unmediated call is a programmer error, and a correct program never reaches it on the request path.
- **The seam judges the root source.** Judging every joined source was the alternative. The root's decision covers the associations the schema declares with `carries/1`, and a joined source it does not carry fails the query.
- **A bulk write to an audited schema is refused.** An event per row was the alternative. One statement that changes many rows gives the seam no old value, and an event built from a guess is not a record.
- **An upsert on a fact schema is refused.** A change event that says insert or update was the alternative. `RETURNING` cannot say which rows were inserts and which were updates.
- **Exemptions are named and recorded.** A silent bypass was the alternative. A declared exemption carries a reason and the caller. The owner-role repo needs none, because it is the library's own channel and records nothing.
- **Declarations live on the schema.** A registry module was the alternative. `use Mediate.Schema` compiles each declaration to a clause of `__mediate__/1`, so the seam and every adapter read one source.
- **An adapter extends the seam through `around_query/3`.** A hook per bucket was the alternative. One wrap around every mediated call is what row-level security needs to bind session settings, and no other adapter needs more.

## The events

- **Three events on the request path, and one per adapter for a policy version.** One event with a kind field was the alternative. Three payloads with fixed fields let a consumer map each to its own record class without a branch.
- **The change event fires inside the write's transaction.** After commit was the alternative. Inside it, a consumer that writes to the same repository joins the transaction, and the record and the row commit together or not at all.
- **The access event fires after the read returns.** Before was the alternative, and the event carries the ids the read returned.
- **No payload carries a class, category, or severity identifier.** A payload that is an OCSF record was the alternative. Those identifiers move between schema versions and belong to the consumer.
- **No payload carries a value the rule read from the world.** The clearance and the marking in the event were the alternative. The controls ask for a record of the question and the answer, and an attribute value in the log is a second copy of a fact.
- **A policy version carries the policy text by value under a cap, and a pointer above it.** Text always, or a pointer always, were the alternatives. A reviewer reads a small policy in the event and a large one where it lives.

## Packages and dependencies

- **One package per adapter.** One package with optional dependencies was the alternative. An adopter of one mechanism carries no other mechanism's dependencies.
- **`mediate` has three runtime dependencies, and a test holds the count.** The conformance suites are a package of their own, which an adapter author takes in the test environment. The suites in `mediate` was the alternative, and then an application that calls the port installs and starts a property-testing library.
- **The test tools are an unpublished package.** The cluster and the engine launchers in `mediate` was the alternative. A launcher starts an OS process, and an adapter package carries no dependency its users do not need.
- **Three interior places under each root.** A free layout was the alternative. `CONTRIBUTING.md` names the places, and the structure test enforces them.
- **Library packages ship migration helpers, and only thin applications carry migrations.** An adapter package that carries the example's migrations names the example's domain, and an adapter is domain-free.
- **Behaviours, not protocols.** A behaviour's `behaviour_info/1` enumerates its surface, and `function_exported?/3` answers an optional callback at runtime. One build then serves every adapter.

## Configuration

- **Boot validates one struct and stores it in `:persistent_term`.** A read of `Application.get_env` at each call was the alternative. One validated read at boot means no call on the request path finds a bad value.
- **A test overrides through the process dictionary, and the resolver walks `$callers`.** `Application.put_env` in tests was the alternative, and it serializes every test.
- **An adapter validates its own options through `options_schema/0`.** A schema per adapter inside `mediate` was the alternative, and it names each adapter in the core.

## What a test may claim

- **The surface is what a test can assert.** A guarantee no test can reach is not a guarantee this repository makes.
- **A decision lives in a module that a test can call directly.** A module that touches the world does nothing else.
- **Every adapter passes the same laws against its real engine.** A fake engine was the alternative, and a fake proves the fake.
- **Each law carries the controls it answers, as data.** A mapping kept by hand was the alternative. The freeze test holds the table to `docs/conformance.md` row for row.
- **Latency is printed and never asserted.** An asserted number flaps, and a number no test asserts has no home in a document.
- **Shape tests count queries and events, never time.** Counts are exact in the sandbox and cannot flap.

## What changes a decision

- A team asks for replay: a consumer that stores change events is the adopter's to write, outside this repository.
- A package passes eighty modules: the structure test grows a rule before the shape goes.
- The application wants durable audit at low volume: a consumer over Oban, still the adopter's.
- No test can show the seam covers some repo call: the enforcement moves to the data layer, as the Postgres adapter already does for writes.
