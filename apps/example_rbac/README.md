# The example under RBAC in code

*Under this binding, which mechanism enforces each of the thirteen rules? For someone reading the example under `Mediate.Rbac`.*

This application binds the example of `example` to `Mediate.Rbac`. It boots the configuration, binds `ExampleRbac.Infrastructure.Policy` to the example's repo, and carries the migrations. `docs/example.md` has the rules and the scenarios.

| Rule | Mechanism | Test group |
|---|---|---|
| C1 | the `:assignment` and `:office` grants in `ExampleRbac.Infrastructure.Policy`, through the open program and the designating office | enforcement |
| C2 | the `:controls` predicate in `ExampleRbac.Infrastructure.Predicates`, one subquery over the marking, the subject's row, and the designating agency | enforcement |
| C3 | the left join to `categories` inside that subquery, whose `implied_controls` widen the declared ones | enforcement |
| C4 | the banner `Example.Application.Documents` keeps at write time, beside the `:controls` predicate on portions | enforcement, least privilege |
| C5 | the `controlled` clause of the same subquery, against the moment the port stamped on the call | enforcement |
| C6 | the `named_list` clause, membership of the marking's `list`, which combines with nothing else | enforcement |
| C7 | the role table in the policy, which grants the marking operations to the designator alone, and the seam's refusal without a decision | least privilege, emergency override |
| C8 | the `:session` predicate, which reads `reauthenticated_at` from the environment | re-authentication |
| C9 | the `:office` grant on the proposal beside the `:another_approver` predicate | separation of duties |
| C10 | a declared exemption in `Example.Application.Documents`, with permission, justification, event, and report in the example's code | least privilege, emergency override |
| C11 | every predicate is a `dynamic` the adapter puts in the query at the call | revocation and expiry |
| C12 | printed by the adapter's suite, never asserted | revocation and expiry |
| C13 | the same grants and predicates compose the query `scope` returns | enforcement |
