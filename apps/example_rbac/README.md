# The example under roles in code

*Which mechanism enforces each of the thirteen clauses? For someone reading the example under `Mediate.Rbac`.*

This deployment binds the example of `example` to `Mediate.Rbac`. It boots the configuration, binds `ExampleRbac.Infrastructure.Policy` to the example's repo, and carries the migrations. `docs/example.md` states the clauses and the scenarios.

| Clause | Mechanism | Scenario group |
|---|---|---|
| C1 | the `:membership` and `:team_role` grant rules in `ExampleRbac.Infrastructure.Policy`, through the project that is not archived and the owning team | enforcement |
| C2 | the `:restrictions` predicate rule, one subquery over the visibility, the subject's account row, and the owning enterprise | enforcement |
| C3 | the left join to `labels` inside that subquery, whose `implied_restrictions` widen the declared ones | enforcement |
| C4 | the rollup `Example.Application.Repositories` keeps at write time, beside the `:restrictions` predicate rule on directories | enforcement, least privilege |
| C5 | the embargo clause of the same subquery, against the moment the core stamped on the call | enforcement |
| C6 | the `invite_only` clause, membership of the visibility's invited list, which combines with nothing else | enforcement |
| C7 | the role table, where `admin` alone holds `change_visibility`, `set_embargo`, `lift_embargo` and `propose_visibility`; the mediated repo refuses a call that carries no decision | least privilege, audited override |
| C8 | the `:fresh_session` predicate rule, which reads `reauthenticated_at` from the context | re-authentication |
| C9 | the `:team_role` grant rule on the proposal beside the `:another_reviewer` predicate rule | separation of duties |
| C10 | a declared exemption in `Example.Application.Repositories`, with permission, justification, event, and report in the example's code | least privilege, audited override |
| C11 | every predicate rule answers a `dynamic` that the engine puts in the query at the call, so it reads the tables as they stand | revocation and expiry |
| C12 | no rule of the policy; the scenario suite prints the decision events, identity write events and resource read events, and asserts on none of them | revocation and expiry |
| C13 | `Mediate.filter/4` answers `{dynamic, decision}` composed from the same grant rules and predicate rules | enforcement |
