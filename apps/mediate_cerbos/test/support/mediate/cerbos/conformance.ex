defmodule Mediate.Cerbos.Conformance do
  @moduledoc """
  The conformance artifact of the Cerbos adapter: the attribute
  declarations of the neutral fixture and the subqueries behind them.
  `Mediate.Conformance.World` says what the fixture is. The test run
  compiles this module, and
  an application never loads it.
  """

  use Boundary,
    top_level?: true,
    deps: [Mediate, Mediate.Conformance, Mediate.Cerbos, Mediate.Fixture, Mediate.Test, Ecto],
    exports: [Attributes, Memberships, Versions]
end
