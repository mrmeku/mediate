# Mediate on Cerbos

`Mediate.Cerbos` is the adapter whose rules are policy files and whose decisions come from a sidecar that reads them. The sidecar is Cerbos, pinned in the flake (`docs/contributing.md` §1), and it runs beside the application on the same host. The policy files have an owner of their own. Revocation of a fact is one commit. A rule change waits on the sidecar's reload, and the boundary cost is one sidecar. The configuration entry carries `address:` and nothing else, and the binding says what the adapter can read (`Mediate.Cerbos` and `Mediate.Cerbos.Binding`).

## Mechanism per rule shape

| Rule shape | Mechanism |
|---|---|
| A test on the subject | a principal attribute, a column of the subject's schema or a subquery of the subject and the environment. The adapter reads it at the call and sends it with the request |
| A test on the row | a resource attribute, sent the same way. A policy cannot depend on a value no declaration names |
| A test on the moment or a request-time fact | the `environment` principal attribute: `request.principal.attr.environment.now` and one field per declared fact, from the port's clock and not the sidecar's. The adapter cuts every moment to the second. A policy compares text, and a plan compares a database column of the same moment |
| A rule over a whole type | the sidecar's query plan, compiled over declared attributes alone. The adapter refuses an operator the compiler does not carry, and never narrows the plan |
| A write gate | the seam refuses a write with no decision for the operation, before anyone asks the policy (`docs/design.md` §4) |

What reaches the sidecar is the declared attributes and a role per subject kind. So a policy says which kinds it answers for when it names roles, and nothing else about the subject travels.

## The declarations

`use Mediate.Cerbos.Attributes` is the declaration module. `Mediate.Cerbos.Attributes` has the full form.

- `principal :kind, schema: Schema do ... end` names a subject kind and the schema whose row is the subject
- `resource :type, schema: Schema do ... end` names an object type and the schema whose rows are the objects
- `attribute name, column: :column` maps a name the policies read to a column of the row
- `attribute name, subquery: &Module.function/2` maps it to a query of the subject and the environment. A value that depends on who asks, or on the moment, becomes one query
- `environment do fact :name end` declares the request-time facts that travel beside `now`

Every column behind a declaration must be a declared fact of the application. `Mediate.Cerbos.Coverage` checks that (`docs/conformance.md` §2, `au12-07`).

## Latency

Two components. Commit, for a fact: the adapter reads the attribute values at each request. Policy propagation, for a rule: the interval between a write of the file and the sidecar's first answer by it. `Mediate.Cerbos.Propagation` measures it. The conformance suite prints both beside its run and asserts nothing about them (`docs/conformance.md` §2).
