# The example on a relationship graph

*Under this binding, which mechanism enforces each of the thirteen rules? For someone reading the example under `Mediate.Fga`.*

This application binds the example of `example` to `Mediate.Fga`. It boots the configuration, binds `priv/fga/model.fga`, `ExampleFga.Infrastructure.TupleMapping`, and `ExampleFga.Infrastructure.Guard` to the example's repo, starts the relay, and carries the migrations. `docs/example.md` has the rules and the scenarios, and `ExampleFga.Infrastructure.Tuples` says what each row states.

| Rule | Mechanism | Test group |
|---|---|---|
| C1 | `lawful_purpose` on `document` in the model, the members of its program or of its designating office | enforcement |
| C2 | `can_read: lawful_purpose but not blocked` on `document`, where the subject must clear each flag that applies | enforcement |
| C3 | the flags on `category`, which `document` reaches through `from category`, so the mapping copies nothing | enforcement |
| C4 | the banner `Example.Application.Documents` keeps at write time, and `can_read: can_read_redacted from document but not blocked` on `portion` | enforcement, least privilege |
| C5 | the condition `before_decontrol` on the flag and category tuples, against `current_time` in the context | enforcement |
| C6 | `listed` on `document`, with no path from it to `lawful_purpose` | enforcement |
| C7 | `can_change_marking` on `document` and the seam's refusal of a write with no decision | least privilege, emergency override |
| C8 | `ExampleFga.Infrastructure.Guard`, which reads `reauthenticated_at` from the environment before the adapter asks the server | re-authentication |
| C9 | `can_approve_marking: approver from office but not proposer` on `proposal` | separation of duties |
| C10 | a declared exemption in `Example.Application.Documents`, with permission, justification, event, and report in the example's code, and no relation in the model | least privilege, emergency override |
| C11 | every check walks the tuples the relay brings to what the tables require, marker by marker | revocation and expiry |
| C12 | printed by the adapter's suite, the relay pass included, never asserted | revocation and expiry |
| C13 | `ListObjects` under the cap, at which the adapter refuses and the caller asks per row | enforcement |
