# The example under row-level security

The controlled-unclassified-information example of `example`, bound to the `Mediate.Postgres` adapter. This application is thin. It boots the configuration, binds the example's schemas to the example's repo, and carries the migrations that write the policies. The tables below say what enforces each rule of the example under this binding. The domain, its contexts, and every scenario live in the example, and the mechanism lives in the adapter.

The rules are the database's own. A policy is a sentence on a table. The database applies it to every statement that reaches that table. So the answer a call gets and the rows a query returns come from one place.

## What binding costs

- `ExamplePostgres.Application`: the boot. It binds the repo and the schemas, starts the repos and the consumer, and publishes the version the catalog holds.
- `ExamplePostgres.Infrastructure.Policies`: every SQL expression the migrations write, one function per policy.
- `priv/repo/migrations/`: the example's tables through the library helpers, then one migration written by hand. It enables row-level security and adds the policies and the write gates.
- `priv/schema/postgres.sql`: the schema the migrations produce, which the gate regenerates and compares. It is where the policies read as SQL.
- `ExamplePostgres.CoverageTest`: every column the policies read is a declared fact of the example.
- `ExamplePostgres.WriteGateTest`: a gate holds a write that never passed the seam, which is a property of this binding and no rule of the example.

## The example's words in the database's words

| The example says | The policy says |
|---|---|
| A program member or lead | `assignments.role = ANY (ARRAY['lead', 'member'])` joined to an open `programs` row |
| A designating office's designator | `office_roles.role = 'designator'` on `documents.designating_office_id` |
| An approver of the office | `office_roles.role = 'approver'` on the same office |
| Who asks | `current_setting('mediate.subject_id', true)`, set for the length of the call |
| A document of a program | the `EXISTS` subquery over `assignments` in the `documents` read policy |
| A portion of a document | the accessors `mediate_document_program`, `mediate_document_office`, and `mediate_document_decontrol` |
| The banner's controls and the categories' implied controls | the `markings` join with a `LEFT JOIN` to the specified `categories` |
| The decontrol date | `documents.decontrol > current_setting('mediate.now', true)` |
| Re-authentication within the window | `current_setting('mediate.reauthenticated_at', true)` inside the gate |
| A different approver | `marking_proposals.proposer_id <> current_setting('mediate.subject_id', true)` |
| The operation of the question | `current_setting('mediate.operation', true) = '<operation>'`, the guard every read policy carries |
| A call outside a decision | the exemption policy of the role, which holds while no operation is in force |

## The mechanism per rule

| Rule | Mechanism | Enforced by |
|---|---|---|
| C1 Lawful purpose | `mediate_scope_read` on `documents`, an `EXISTS` over `assignments` and one over `office_roles` | the database |
| C2 Controls, all of | the blocked subquery in the same policy, which reads `employment` and `nationality` from `users` at every statement | the database |
| C3 Specified categories | the `LEFT JOIN` to `categories` on `specified`, whose `implied_controls` widen the declared ones | the database |
| C4 Banner | the banner `Example.Application.Documents` keeps at write time, beside `mediate_scope_read` on `portions`. That policy reaches the document through the accessors, so the document's own policy does not narrow it | the application and the database |
| C5 Decontrol | `mediate.now`, set by the adapter for the length of the call, compared with `decontrol` | the database |
| C6 Named list | membership of the document marking's `list` column, which no other clause reaches | the database |
| C7 Marking gates | `mediate_gate_change_marking`, `mediate_gate_set_decontrol`, and `mediate_gate_decontrol`, `WITH CHECK` policies on `documents`, `markings`, and `portions`. They carry no operation guard, so a write that never passed the seam meets them too | the database |
| C8 Re-authentication | `mediate.reauthenticated_at` inside those gates, within the window | the database |
| C9 Separation of duties | `mediate_scope_approve_marking` and its gate on `marking_proposals`, which require an approver of the office and a proposer who is someone else | the database |
| C10 Audited override | the read runs under a declared exemption, which the exemption policy of the application role admits. Permission, justification, event, and report are the example's code | the application |
| C11 Continuous evaluation | policies evaluate when a statement runs, so the next statement no longer admits a revoked row | the database |
| C12 Revocation clock | measured and recorded beside the configured maximum, never asserted | the adapter |
| C13 Scope fidelity | the read policy narrows the query the repo runs, so `scope` answers the rule `true` and returns exactly the rows `check` admits | the database |
