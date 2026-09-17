# Changelog

*What changed in each release? For an adopter deciding whether to upgrade.*

The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
versions are [semantic](https://semver.org/spec/v2.0.0.html). Every published
package of this repository carries one version and one tag.

## [Unreleased]

## [0.1.0] - 2026-09-17

The first release: the port, the seam, the events, the conformance suites, the
two Credo checks, and four adapters.

- `mediate`: `authorize/4`, `check/4`, `scope/4`, and `review/4`; the
  `Mediate.Adapter` behaviour; `use Mediate.Repo` and its schema declarations;
  the decision, change, access, and policy-version events; the configuration.
- `mediate_conformance`: the adapter case that runs the laws, and the repo case
  that runs the seam's guarantees.
- `mediate_credo`: `Mediate.Credo.NoRawSQL` and `Mediate.Credo.UnmediatedRepo`.
- `mediate_rbac`: rules as Elixir modules.
- `mediate_postgres`: rules as Postgres row-level security policies.
- `mediate_cerbos`: rules as policy files a sidecar reads.
- `mediate_fga`: rules as a relationship model in a store of its own.

[Unreleased]: https://github.com/mrmeku/mediate/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mrmeku/mediate/releases/tag/v0.1.0
