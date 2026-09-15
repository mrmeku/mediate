defmodule Mediate.Rbac.Conformance do
  @moduledoc """
  The conformance artifact of RBAC in code: the role table and the
  predicates that encode the neutral fixture's rule, the modules the
  conformance suite binds. The test run compiles them. An application never
  loads them. `docs/conformance.md` §3 says what each adapter carries.
  """

  use Boundary,
    top_level?: true,
    deps: [Mediate, Mediate.Conformance, Mediate.Rbac, Mediate.Fixture, Ecto],
    exports: [Assignment, Predicates, Roles, Tightened, Versions]
end
