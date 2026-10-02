defmodule Mediate.Conformance do
  @moduledoc """
  The conformance kit:

  - the two requirement tables of
    [the conformance document](https://hexdocs.pm/mediate/conformance.html),
    as data
  - the engine case, which runs the engine requirements against an engine
  - the repo case, which holds a mediated repo to the repo requirements

  The package ships them, so every engine, in this repository or outside
  it, proves itself against the same contract. The caller supplies the
  world a run writes, as a `Mediate.Conformance.World`. So nothing here
  names a schema or a rule.
  """

  use Boundary,
    top_level?: true,
    deps: [Mediate, Mediate.Test, Ecto, ExUnit, ExUnitProperties, StreamData],
    exports: [
      EngineCase,
      Generators,
      Mirror,
      Outage,
      Policy,
      Procedure,
      Procedure.Accounts,
      Procedure.Audit,
      Procedure.Change,
      RepoCase,
      Requirement,
      Specimen,
      World
    ]
end
