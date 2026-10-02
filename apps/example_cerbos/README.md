# The example under policy files

*Which mechanism enforces each of the thirteen clauses? For someone reading the example under `Mediate.Cerbos`.*

This deployment binds the example of `example` to `Mediate.Cerbos`. It boots the configuration, binds `ExampleCerbos.Infrastructure.Declarations` and the policy files under `priv/policies/` to the example's repo, and carries the migrations. `docs/example.md` states the clauses and the scenarios. `ExampleCerbos.Infrastructure.Subqueries` holds the subquery behind each attribute whose value depends on who asks, and `priv/repo/structure.sql` holds the example's tables, which is all the database holds under this deployment.

| Clause | Mechanism | Scenario group |
|---|---|---|
| C1 | the `access_path` rule of `repository.yaml`, over the `project_roles` and `team_roles` subquery attributes | enforcement |
| C2 | one deny rule per restriction kind in `repository.yaml`, named for the kind, over `effective_restrictions` and the principal's `employment` and `country` column attributes | enforcement |
| C3 | the `effective_restrictions` subquery, which widens the restriction kinds the visibility declares by the ones a sensitive label implies | enforcement |
| C4 | the rollup `Example.Application.Repositories` keeps at write time, beside `directory.yaml`, whose subqueries test the repository's embargo | enforcement, least privilege |
| C5 | `request.resource.attr.embargo` against `request.principal.attr.context.now`, inside each deny rule | enforcement |
| C6 | the `invited` subquery, which selects the principal's own id where the invited list names it | enforcement |
| C7 | the mediated repo refuses a write that carries no decision, before the server is asked | least privilege, audited override |
| C8 | `request.principal.attr.context.reauthenticated_at`, the one declared context fact, inside the `admin_in_fresh_session` rules | re-authentication |
| C9 | the `another_reviewer` rule of `proposal.yaml`: a reviewer of the owning team whose id differs from `proposer_id` | separation of duties |
| C10 | a declared exemption in `Example.Application.Repositories`, with permission, justification, event, and report in the example's code | least privilege, audited override |
| C11 | the engine reads every declared attribute value for each call, so a plan compiles over the tables as they stand | revocation and expiry |
| C12 | no rule of the policy; the scenario suite prints the decision events, identity write events and resource read events, and asserts on none of them | revocation and expiry |
| C13 | the plan the server answers a filter with, compiled over the declared attributes into the `dynamic` of `Mediate.filter/4` | enforcement |
