# The example under a policy sidecar

The controlled-unclassified-information example of `example`, bound to the `Mediate.Cerbos` adapter. This application is thin. It boots the configuration, binds the attribute declarations and the policy directory to the example's repo, and carries the migrations. The tables below say what enforces each rule of the example under this binding. The domain, its contexts, and every scenario live in the example, and the mechanism lives in the adapter.

The rules are files a separate process evaluates. A policy names actions on a resource kind and conditions over attributes. An attribute reaches the policy because this application declares its source. The source is a column of the row or a subquery of the account that asks. The sidecar reads what a declaration names and nothing else.

## What binding costs

- `ExampleCerbos.Application`: the boot. It binds the repo, the declarations, the policy directory, and the commit. It starts the repos and the consumer, and publishes the commit as a policy version.
- `ExampleCerbos.Infrastructure.Attributes`: what the policies can read, per subject kind and per object type.
- `ExampleCerbos.Infrastructure.Facts`: the subquery behind each attribute whose value depends on who asks or on a derivation the policy language does not carry.
- `lib/example_cerbos/infrastructure/controls.ex`: which controls are in force on a marking. It decides and touches nothing, so a test calls it directly.
- `priv/policies/`: one policy file per resource kind, which the sidecar reads and a policy version carries as its content.
- `priv/repo/migrations/`: the example's tables through the library helpers, then one migration that creates nothing, because the rules of this binding are outside the database.
- `priv/schema/cerbos.sql`: the schema the migrations produce, which the gate regenerates and compares.
- `config/config.exs`: the sidecar's address, the policy directory, and `POLICY_COMMIT`, the commit every decision under this binding names.
- `ExampleCerbos.CoverageTest`: every column the policies read is a declared fact of the example.

## The example's words in the policy's words

| The example says | The policy says |
|---|---|
| A program member or lead | `"member" in request.resource.attr.program_roles`, a subquery over `assignments` joined to an open program |
| A designating office's designator | `"designator" in request.resource.attr.office_roles`, a subquery over `office_roles` on the document's office |
| An approver of the office | `"approver" in request.resource.attr.office_roles`, the same subquery |
| Who asks | `request.principal.id`, and the account's own columns as `request.principal.attr` |
| The banner's controls and the categories' implied controls | `request.resource.attr.effective_controls`, one query per control name. Each widens the declared controls by the implied ones of a specified category |
| The decontrol date | `request.resource.attr.decontrol` compared with `request.principal.attr.environment.now`, the moment the port stamped the request with |
| A portion under its document's decontrol date | the same test inside the portion's own controls subquery, since the portion row carries no date |
| The nationalities REL TO releases to | `request.principal.attr.nationality in request.resource.attr.releasable_to` |
| The designating agency's nationality | `request.principal.attr.nationality in request.resource.attr.agency_nationalities` |
| A named list | `request.principal.id in request.resource.attr.listed` |
| Re-authentication within the window | `request.principal.attr.environment.reauthenticated_at` within `duration("900s")` of the request's moment |
| A different approver | the proposal's `proposer_id` set against `request.principal.id`, which the rule requires to differ |
| The version a decision names | the commit of the repository the policy files come from, which the binding names |

## The mechanism per rule

| Rule | Mechanism | Enforced by |
|---|---|---|
| C1 Lawful purpose | the allow rule of each resource kind, over the two role subqueries | the engine |
| C2 Controls, all of | one deny rule per control, each over the effective controls and the account's own columns | the engine |
| C3 Specified categories | the derivation is in the subquery the declaration names, so the policy tests membership in a set the database widened (limited) | the engine |
| C4 Banner | the banner `Example.Application.Documents` keeps at write time, beside the `portion` resource kind. A portion's decontrol is its document's, so its subqueries test the date (limited) | the application and the engine |
| C5 Decontrol | the request's own moment, sent as an environment fact beside the account's attributes, compared with the document's date | the engine |
| C6 Named list | the `listed` subquery, which selects the identifier of the account that asks where the banner names it | the engine |
| C7 Marking gates | the seam refuses a write with no decision for the operation before anyone asks the policy | the seam |
| C8 Re-authentication | `reauthenticated_at`, a declared request-time fact, against the request's moment inside the marking rules | the engine |
| C9 Separation of duties | the `proposal` resource kind, whose allow rule requires an approver of the office and a proposer who is someone else | the engine |
| C10 Audited override | the read runs under a declared exemption. Permission, justification, event, and report are the example's code | the application |
| C11 Continuous evaluation | the adapter reads the attribute values for each request, so the next request no longer admits a revoked row | the engine |
| C12 Revocation clock | measured and recorded beside the configured maximum, never asserted | the adapter |
| C13 Scope fidelity | the query plan the sidecar answers with, compiled to a rule over declared attributes. The adapter refuses an expression the compiler does not carry and never narrows it (limited) | the engine |
