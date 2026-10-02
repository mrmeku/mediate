# Mediate conformance

*What is in this package? For an engine author proving an engine.*

The cases that hold an engine and a mediated repo to [the conformance document](https://hexdocs.pm/mediate/conformance.html). `Mediate.Conformance.EngineCase` runs the engine requirements against an engine, and `Mediate.Conformance.RepoCase` runs the repo requirements against a repo. An engine supplies a `Mediate.Conformance.World`, a repo supplies a `Mediate.Conformance.Specimen`, and each case's moduledoc has the options. Add the package to the `:test` dependencies.
