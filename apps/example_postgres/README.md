# The example under row-level security

*Which mechanism enforces each of the thirteen clauses? For someone reading the example under `Mediate.Postgres`.*

This deployment binds the example of `example` to `Mediate.Postgres`. It boots the configuration, binds the example's schemas to the example's repo, and carries the migrations, of which the last writes the rules from `ExamplePostgres.Infrastructure.Policy` and releases the policy. `docs/example.md` states the clauses and the scenarios, and `priv/repo/structure.sql` holds the rules as the database prints them.

| Clause | Mechanism | Scenario group |
|---|---|---|
| C1 | `mediate_filter_read` on `repositories`: the access path, an `EXISTS` over `memberships` and one over `team_roles` | enforcement |
| C2 | the subquery of blocked rows in the same rule, which reads `employment` and `country` from `accounts` at every statement | enforcement |
| C3 | the `LEFT JOIN` to `labels` on `sensitive` inside that subquery, whose `implied_restrictions` widen the declared ones | enforcement |
| C4 | the rollup `Example.Application.Repositories` keeps at write time, beside `mediate_filter_read` on `directories`, which reaches the repository through the lookup functions | enforcement, least privilege |
| C5 | the setting `mediate.now`, which the engine sets for the length of the call, compared with `embargo` | enforcement |
| C6 | membership of the visibility's `invited` column, which combines with nothing else | enforcement |
| C7 | the gate rules `mediate_gate_change_visibility`, `mediate_gate_set_embargo` and `mediate_gate_lift_embargo`, whose `WITH CHECK` reads no `mediate.action`, so they hold for every statement; the mediated repo refuses a call that carries no decision | least privilege, audited override |
| C8 | the setting `mediate.reauthenticated_at`, read inside those gate rules and compared with the re-authentication window | re-authentication |
| C9 | `mediate_filter_approve_visibility` and `mediate_gate_approve_visibility` on `proposals`: a reviewer of the owning team who is not the proposer | separation of duties |
| C10 | a declared exemption in `Example.Application.Repositories`, which the application role's exempt rule admits, with permission, justification, event, and report in the example's code | least privilege, audited override |
| C11 | a rule reads its facts from the tables when the statement runs | revocation and expiry |
| C12 | no rule of the policy; the scenario suite prints the decision events, identity write events and resource read events, and asserts on none of them | revocation and expiry |
| C13 | `mediate_filter_read` narrows the query the mediated repo runs, so `Mediate.filter/4` answers a `dynamic` of `true` beside the decision | enforcement |

`ExamplePostgres.GateRuleTest` shows the database refusing a write the mediated repo never saw, which is a property of this deployment and no clause of the example.
