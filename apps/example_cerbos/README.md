# The example under a policy sidecar

*Under this binding, which mechanism enforces each of the thirteen rules? For someone reading the example under `Mediate.Cerbos`.*

This application binds the example of `example` to `Mediate.Cerbos`. It boots the configuration, binds `ExampleCerbos.Infrastructure.Attributes` and the policy files under `priv/policies/` to the example's repo, and carries the migrations. `docs/example.md` has the rules and the scenarios. `ExampleCerbos.Infrastructure.Facts` holds the subquery behind each attribute whose value depends on who asks.

| Rule | Mechanism | Test group |
|---|---|---|
| C1 | the allow rule of `repository.yaml`, over the `project_roles` and `team_roles` subqueries | enforcement |
| C2 | one deny rule per restriction in `repository.yaml`, over `effective_restrictions` and the principal's own columns | enforcement |
| C3 | the `effective_restrictions` subquery in `ExampleCerbos.Infrastructure.Facts`, which widens the declared restrictions by the implied ones of a sensitive label | enforcement |
| C4 | the rollup `Example.Application.Repositories` keeps at write time, beside `directory.yaml`, whose subqueries test the repository's embargo date | enforcement, least privilege |
| C5 | `request.principal.attr.environment.now` against `request.resource.attr.embargo` | enforcement |
| C6 | the `invited` subquery, which selects the principal's id where the visibility names it | enforcement |
| C7 | the seam's refusal of a write with no decision, before anyone asks the policy | least privilege, emergency override |
| C8 | `request.principal.attr.environment.reauthenticated_at`, a declared request-time fact, inside the visibility rules | re-authentication |
| C9 | `proposal.yaml`, whose allow rule requires a reviewer of the team and a proposer who is someone else | separation of duties |
| C10 | a declared exemption in `Example.Application.Repositories`, with permission, justification, event, and report in the example's code | least privilege, emergency override |
| C11 | the adapter reads the attribute values for each request | revocation and expiry |
| C12 | printed by the adapter's suite, never asserted | revocation and expiry |
| C13 | the query plan the sidecar answers with, compiled over declared attributes | enforcement |
