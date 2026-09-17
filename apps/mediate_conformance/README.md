# Mediate conformance

*What is in this package? For an adapter author proving an adapter.*

The suites that hold an adapter and a mediated repo to [the conformance document](https://hexdocs.pm/mediate/conformance.html). `Mediate.Conformance.AdapterCase` runs the laws against an adapter, and `Mediate.Conformance.RepoCase` runs the guarantees against a repo. An adapter supplies a `Mediate.Conformance.World`, a repo supplies a `Mediate.Conformance.RepoCase.Rows`, and each template's moduledoc has the options. Add the package to the `:test` dependencies.
