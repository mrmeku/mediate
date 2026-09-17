# The example under row-level security

*Under this binding, which mechanism enforces each of the thirteen rules? For someone reading the example under `Mediate.Postgres`.*

This application binds the example of `example` to `Mediate.Postgres`. It boots the configuration, binds the example's schemas to the example's repo, and carries the migrations, of which the last writes the policies from `ExamplePostgres.Infrastructure.Policies`. `docs/example.md` has the rules and the scenarios, and `priv/schema/postgres.sql` has the policies as SQL.

| Rule | Mechanism | Test group |
|---|---|---|
| C1 | `mediate_scope_read` on `repositories`, an `EXISTS` over `memberships` and one over `team_roles` | enforcement |
| C2 | the blocked subquery in the same policy, which reads `employment` and `country` from `users` at every statement | enforcement |
| C3 | the `LEFT JOIN` to `labels` on `sensitive`, whose `implied_restrictions` widen the declared ones | enforcement |
| C4 | the rollup `Example.Application.Repositories` keeps at write time, beside `mediate_scope_read` on `directories`, which reaches the repository through the accessor functions | enforcement, least privilege |
| C5 | `mediate.now`, set by the adapter for the length of the call, compared with `embargo` | enforcement |
| C6 | membership of the visibility's `invited` column, which no other clause reaches | enforcement |
| C7 | `mediate_gate_change_visibility`, `mediate_gate_set_embargo`, and `mediate_gate_lift_embargo`, `WITH CHECK` policies with no operation guard | least privilege, emergency override |
| C8 | `mediate.reauthenticated_at` inside those gates, within the window | re-authentication |
| C9 | `mediate_scope_approve_visibility` and its gate on `visibility_proposals` | separation of duties |
| C10 | a declared exemption in `Example.Application.Repositories`, which the exemption policy of the application role admits, with permission, justification, event, and report in the example's code | least privilege, emergency override |
| C11 | policies evaluate when a statement runs | revocation and expiry |
| C12 | printed by the adapter's suite, never asserted | revocation and expiry |
| C13 | the read policy narrows the query the repo runs, so `scope` answers `true` | enforcement |

`ExamplePostgres.WriteGateTest` shows a gate holds a write that never passed the seam, which is a property of this binding and no rule of the example.
