# The example under OpenFGA

*Which mechanism enforces each of the thirteen clauses? For someone reading the example under `Mediate.OpenFGA`.*

This deployment binds the example of `example` to `Mediate.OpenFGA`. It boots the configuration, binds the model file under `priv/policies/`, `ExampleOpenFGA.Infrastructure.Mapping`, and `ExampleOpenFGA.Infrastructure.Guard` to the example's repo, starts the relay, and carries the migrations. `docs/example.md` states the clauses and the scenarios. The mapping holds the example's tables as tuples, and `priv/repo/structure.sql` holds the example's tables, the outbox, and the relay's cursor, which is all the database holds under this deployment.

| Clause | Mechanism | Scenario group |
|---|---|---|
| C1 | `access_path` on `repository` in the model, the members of its project or of its owning team | enforcement |
| C2 | `can_read: access_path but not blocked` on `repository`, where the subject must clear each restriction that applies | enforcement |
| C3 | the restriction relations on `label`, which `repository` reaches through `from label`, so the mapping copies nothing | enforcement |
| C4 | the rollup `Example.Application.Repositories` keeps at write time, and `can_read: can_checkout from repository but not blocked` on `directory` | enforcement, least privilege |
| C5 | the condition `under_embargo` on the restriction and label tuples, against `current_time` in the context | enforcement |
| C6 | `invited` on `repository`, with no path from it to `access_path` | enforcement |
| C7 | `can_change_visibility` on `repository`, and the mediated repo's refusal of a write with no decision | least privilege, audited override |
| C8 | `ExampleOpenFGA.Infrastructure.Guard`, which reads `reauthenticated_at` from the context before the engine asks the server | re-authentication |
| C9 | `can_approve_visibility: reviewer from team but not proposer` on `proposal` | separation of duties |
| C10 | a declared exemption in `Example.Application.Repositories`, with permission, justification, event, and report in the example's code, and no relation in the model | least privilege, audited override |
| C11 | every check walks the tuples the runner brings to what the tables require, marker by marker | revocation and expiry |
| C12 | printed by the deployment's suite, the relay pass included, never asserted | revocation and expiry |
| C13 | `ListObjects` under the cap, at which the engine refuses and the caller asks per row | enforcement |
