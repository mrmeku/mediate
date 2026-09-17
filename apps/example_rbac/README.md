# The example under RBAC in code

*Under this binding, which mechanism enforces each of the thirteen rules? For someone reading the example under `Mediate.Rbac`.*

This application binds the example of `example` to `Mediate.Rbac`. It boots the configuration, binds `ExampleRbac.Infrastructure.Policy` to the example's repo, and carries the migrations. `docs/example.md` has the rules and the scenarios.

| Rule | Mechanism | Test group |
|---|---|---|
| C1 | the `:membership` and `:team` grants in `ExampleRbac.Infrastructure.Policy`, through the open project and the owning team | enforcement |
| C2 | the `:restrictions` predicate in `ExampleRbac.Infrastructure.Predicates`, one subquery over the visibility, the subject's row, and the owning enterprise | enforcement |
| C3 | the left join to `labels` inside that subquery, whose `implied_restrictions` widen the declared ones | enforcement |
| C4 | the rollup `Example.Application.Repositories` keeps at write time, beside the `:restrictions` predicate on directories | enforcement, least privilege |
| C5 | the `restricted` clause of the same subquery, against the moment the port stamped on the call | enforcement |
| C6 | the `invite_only` clause, membership of the visibility's `invited` list, which combines with nothing else | enforcement |
| C7 | the role table in the policy, which grants the visibility operations to the admin alone, and the seam's refusal without a decision | least privilege, emergency override |
| C8 | the `:session` predicate, which reads `reauthenticated_at` from the environment | re-authentication |
| C9 | the `:team` grant on the proposal beside the `:another_reviewer` predicate | separation of duties |
| C10 | a declared exemption in `Example.Application.Repositories`, with permission, justification, event, and report in the example's code | least privilege, emergency override |
| C11 | every predicate is a `dynamic` the adapter puts in the query at the call | revocation and expiry |
| C12 | printed by the adapter's suite, never asserted | revocation and expiry |
| C13 | the same grants and predicates compose the query `scope` returns | enforcement |
