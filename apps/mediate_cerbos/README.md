# Mediate on Cerbos

*How do I bind this engine, and what mechanism answers each rule shape? For a deployment whose rules are policy files a Cerbos server reads.*

`Mediate.Cerbos` decides through a Cerbos server that reads policy files with an owner of their own. The server runs beside the application, and `flake.nix` pins its version. Revocation of a fact is one commit, and a rule change waits on the server reading the new file.

## The words

Inside `infrastructure/` the package speaks Cerbos, and at its root it speaks the ledger's words. `docs/naming.md` under "Policy files" has every row and why.

| Cerbos says | The ledger says | Here it is |
|---|---|---|
| principal | subject | one `principal/3` block per subject kind |
| role | subject kind | `user`, `service`, or `privileged`, which the request sends as the principal's role |
| resource | resource | one `resource/3` block per resource type |
| attribute | fact | a declared column or subquery whose value travels with the request |
| policy file | policy | the YAML the server reads, versioned by commit |
| plan | filter | what the server answers for a type, compiled to a `dynamic` or refused |
| request id | `request_id` | on the verdict's `meta`, which the server's own log holds too |
| `request.principal.attr.context` | context | `now` and the context facts, from the library's clock |

## How to bind

The configuration entry carries the server's address and nothing else: `engine: {Mediate.Cerbos, address: "127.0.0.1:3592"}`. After the configuration boots, bind the repo, the declarations, the policy directory, and the commit, then release. `Mediate.Cerbos.Binding` has the options and the call.

```elixir
{:ok, _binding} =
  Mediate.Cerbos.Binding.bind(
    repo: MyApp.Repo,
    declarations: MyApp.Declarations,
    policy_dir: "policies",
    commit: "3f2a9c1"
  )

{:ok, _release} = Mediate.Cerbos.release()
```

## The declarations

`use Mediate.Cerbos.Declarations` is the declaration module, and its moduledoc has the full form.

- `principal :kind, schema: Schema do ... end` names a subject kind and the schema whose row is the subject.
- `resource :type, schema: Schema do ... end` names a resource type and the schema whose rows are the resources.
- `attribute :name, column: :column` maps a name the policy files read to a column of the row.
- `attribute :name, subquery: &Module.function/2` maps it to a query of the subject and the context.
- `context do fact :name end` declares the context facts that travel beside `now`.

Every column behind a declaration must be a declared fact of the application, and `Mediate.Cerbos.Facts` checks that. What reaches the server is the declared attributes and a role per subject kind, and nothing else about the subject travels.

## Mechanism per rule shape

| Rule shape | Mechanism |
|---|---|
| A test on the subject | a principal attribute, a column of the subject's schema or a subquery of the subject and the context. The engine reads it at the call and sends it with the request |
| A test on the row | a resource attribute, sent the same way. A policy cannot depend on a value no declaration names |
| A test on the moment or a context fact | the `context` principal attribute: `request.principal.attr.context.now` and one field per declared fact, from the library's clock and not the server's. The engine cuts every moment to the second. A policy compares text, and a plan compares a database column of the same moment |
| A rule over a whole type | the server's plan, compiled over declared attributes alone. The engine refuses a plan it does not compile, and never narrows one |
| A write gate | the mediated repo refuses a write with no decision for the action, before anyone asks the policy |

## What this engine decided

- **The engine sends declared attributes, and the server holds no data.** A server with a database connection was the alternative, and then a policy could read a column no declaration names.
- **The plan compiles to a `dynamic`, and a plan the compiler lacks an operator for is refused.** A plan the engine narrows was the alternative, and a narrowed plan hides rows with no sign of it.
- **The version is the policy repository's commit.** A hash of the directory was the alternative, and a commit is what a reviewer can find.
- **Every moment is cut to the second.** Microseconds were the alternative, and a policy compares text.

Revocation latency has two components: commit for a fact, and release latency for a rule, which the conformance suite prints.
