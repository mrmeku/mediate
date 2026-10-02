defmodule Mediate.Conformance.Reference do
  @moduledoc """
  This repository's own answers to the behaviours the cases ask for, over
  the neutral schemas of `Mediate.Fixture`: a world, the specimen the repo
  case writes, and the fake engine's mirror, outage, and policy. An engine outside
  this repository writes its own.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Ecto,
      ExUnitProperties,
      StreamData,
      Mediate,
      Mediate.Conformance,
      Mediate.Fixture,
      Mediate.Test,
      Mediate.Dev.Sandbox,
      Mediate.TestRepos
    ],
    exports: [Mirror, Outage, Policy, Specimen, World]
end
