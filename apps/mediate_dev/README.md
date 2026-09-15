# Mediate dev

The test tools of this repository. No adopter needs them. No published package depends on them outside its test environment. The moduledocs say what each does.

- the ephemeral Postgres cluster of each `mix test` run, which `docs/contributing.md` §2 describes
- the sandbox each case template checks out
- the schema dump `mix mediate.schema_dump` writes under `priv/schema/`
- one Cerbos sidecar and one OpenFGA server per test run
- the structure test that holds every source file to `docs/design.md` §6
