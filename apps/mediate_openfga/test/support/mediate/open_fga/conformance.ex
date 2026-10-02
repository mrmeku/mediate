defmodule Mediate.OpenFGA.Conformance do
  @moduledoc """
  The conformance artifact of this engine:

  - the reference mapping, which states the reference world's tables as
    tuples
  - a population of those tables for the cases to write and take away
  - what the cases run under, the mirror, the outage, and the policy the
    `cm3` requirements tighten

  The model the tuples sit under is `priv/conformance/model.fga`, which is
  what the server reads. `Mediate.Conformance.World` says what the world
  is. The test run compiles these. A deployment never loads them.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Ecto,
      ExUnit,
      Mediate,
      Mediate.Conformance,
      Mediate.Conformance.Reference,
      Mediate.OpenFGA,
      Mediate.OpenFGA.Client.Fake,
      Mediate.Fixture,
      Mediate.Test,
      Mediate.Dev.Sandbox
    ],
    exports: [Mirror, Outage, Policy, Population, Reference, Setup]
end
