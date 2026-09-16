defmodule Mediate.Fga.Conformance do
  @moduledoc """
  The conformance artifact of this adapter:

  - the tuple mapping for the neutral fixture, which states that fixture's
    tables as tuples
  - a population of those tables for the case templates to write and take
    away
  - what those templates run under

  The model the tuples sit under is `priv/conformance/model.fga`, which is
  what the server reads. `Mediate.Conformance.World` says what the
  fixture is. The test run compiles these. An application never
  loads them.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Ecto,
      ExUnit,
      Mediate,
      Mediate.Conformance,
      Mediate.Fga,
      Mediate.Fga.Client.Fake,
      Mediate.Fixture,
      Mediate.Test,
      Mediate.Dev.Sandbox
    ],
    exports: [Mapping, Population, Setup, Versions]
end
