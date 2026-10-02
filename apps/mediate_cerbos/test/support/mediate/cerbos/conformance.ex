defmodule Mediate.Cerbos.Conformance do
  @moduledoc """
  The conformance artifact of policy files: the declarations over the
  reference world, the subqueries behind them, the policy the `cm3`
  requirements tighten, the outage, and a server one test owns. The test
  run compiles them. A deployment never loads them.
  `Mediate.Conformance.World` says what the world is.
  """

  use Boundary,
    top_level?: true,
    deps: [Mediate, Mediate.Conformance, Mediate.Cerbos, Mediate.Fixture, Mediate.Test, Ecto],
    exports: [Memberships, Outage, Policy, PolicyFiles, Reference, Server]
end
