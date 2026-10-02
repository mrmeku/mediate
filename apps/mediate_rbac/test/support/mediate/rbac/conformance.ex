defmodule Mediate.Rbac.Conformance do
  @moduledoc """
  The conformance artifact of roles in code: the policy modules and the
  predicates that encode the reference world's rule, the modules the
  conformance suite binds. The test run compiles them. A deployment never
  loads them. `Mediate.Conformance.World` says what the world is.
  """

  use Boundary,
    top_level?: true,
    deps: [Mediate, Mediate.Conformance, Mediate.Conformance.Reference, Mediate.Rbac, Mediate.Fixture, Ecto],
    exports: [Assignment, Policy, Predicates, Reference, Seat, Tightened]
end
