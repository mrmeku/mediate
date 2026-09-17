defmodule Mediate.Conformance.Fixture do
  @moduledoc """
  This repository's own answers to the three behaviours the templates ask
  for, over the neutral schemas of `Mediate.Fixture`: a world, the rows the
  repo template writes, and the fake adapter's seed. An adapter outside
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
    exports: [Rows, Seed, World]
end
