# The example on a relationship graph

*Under this binding, which mechanism enforces each of the thirteen rules? For someone reading the example under `Mediate.Fga`.*

This application binds the example of `example` to `Mediate.Fga`. It boots the configuration, binds `priv/fga/model.fga`, `ExampleFga.Infrastructure.TupleMapping`, and `ExampleFga.Infrastructure.Guard` to the example's repo, starts the relay, and carries the migrations. `docs/example.md` has the rules and the scenarios, and `ExampleFga.Infrastructure.Tuples` says what each row states.

| Rule | Mechanism | Test group |
|---|---|---|
| C1 | `access_path` on `repository` in the model, the members of its project or of its owning team | enforcement |
| C2 | `can_read: access_path but not blocked` on `repository`, where the subject must clear each flag that applies | enforcement |
| C3 | the flags on `label`, which `repository` reaches through `from label`, so the mapping copies nothing | enforcement |
| C4 | the rollup `Example.Application.Repositories` keeps at write time, and `can_read: can_checkout from repository but not blocked` on `directory` | enforcement, least privilege |
| C5 | the condition `under_embargo` on the flag and label tuples, against `current_time` in the context | enforcement |
| C6 | `invited` on `repository`, with no path from it to `access_path` | enforcement |
| C7 | `can_change_visibility` on `repository` and the seam's refusal of a write with no decision | least privilege, emergency override |
| C8 | `ExampleFga.Infrastructure.Guard`, which reads `reauthenticated_at` from the environment before the adapter asks the server | re-authentication |
| C9 | `can_approve_visibility: reviewer from team but not proposer` on `proposal` | separation of duties |
| C10 | a declared exemption in `Example.Application.Repositories`, with permission, justification, event, and report in the example's code, and no relation in the model | least privilege, emergency override |
| C11 | every check walks the tuples the relay brings to what the tables require, marker by marker | revocation and expiry |
| C12 | printed by the adapter's suite, the relay pass included, never asserted | revocation and expiry |
| C13 | `ListObjects` under the cap, at which the adapter refuses and the caller asks per row | enforcement |
