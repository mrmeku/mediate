# Mediate on Cerbos

*How do I bind this adapter, and what mechanism answers each rule shape? For an adopter whose rules are policy files a sidecar reads.*

`Mediate.Cerbos` decides through a sidecar that reads policy files with an owner of their own. The sidecar runs beside the application on the same host, and `flake.nix` pins its version. Revocation of a fact is one commit, and a rule change waits on the sidecar's reload.

## How to bind

The configuration entry carries the sidecar's address and nothing else: `adapter: {Mediate.Cerbos, address: "127.0.0.1:3592"}`. After the configuration boots, bind the repo, the attribute declarations, the policy directory, and the commit, then publish. `Mediate.Cerbos.Binding` has the options and the call.

## The declarations

`use Mediate.Cerbos.Attributes` is the declaration module, and its moduledoc has the full form.

- `principal :kind, schema: Schema do ... end` names a subject kind and the schema whose row is the subject.
- `resource :type, schema: Schema do ... end` names an object type and the schema whose rows are the objects.
- `attribute name, column: :column` maps a name the policies read to a column of the row.
- `attribute name, subquery: &Module.function/2` maps it to a query of the subject and the environment.
- `environment do fact :name end` declares the request-time facts that travel beside `now`.

Every column behind a declaration must be a declared fact of the application, and `Mediate.Cerbos.Coverage` checks that. What reaches the sidecar is the declared attributes and a role per subject kind, and nothing else about the subject travels.

## Mechanism per rule shape

| Rule shape | Mechanism |
|---|---|
| A test on the subject | a principal attribute, a column of the subject's schema or a subquery of the subject and the environment. The adapter reads it at the call and sends it with the request |
| A test on the row | a resource attribute, sent the same way. A policy cannot depend on a value no declaration names |
| A test on the moment or a request-time fact | the `environment` principal attribute: `request.principal.attr.environment.now` and one field per declared fact, from the port's clock and not the sidecar's. The adapter cuts every moment to the second. A policy compares text, and a plan compares a database column of the same moment |
| A rule over a whole type | the sidecar's query plan, compiled over declared attributes alone. The adapter refuses an operator the compiler does not carry, and never narrows the plan |
| A write gate | the seam refuses a write with no decision for the operation, before anyone asks the policy |

## What this adapter decided

- **The adapter sends declared attributes, and the sidecar holds no data.** A sidecar with a database connection was the alternative, and then a policy could read a column no declaration names.
- **The query plan compiles to a `dynamic`, and an operator the compiler lacks refuses.** A plan the adapter narrows was the alternative, and a narrowed plan hides rows with no sign of it.
- **The version is the policy repository's commit.** A hash of the directory was the alternative, and a commit is what a reviewer can find.
- **Every moment is cut to the second.** Microseconds were the alternative, and a policy compares text.

Revocation latency has two components: commit for a fact, and policy propagation for a rule, which `Mediate.Cerbos.Propagation` measures.
