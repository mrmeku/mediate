defmodule Mediate.Cerbos.Conformance do
  @moduledoc """
  The conformance artifact of the Cerbos adapter: the attribute
  declarations of the neutral fixture and the subqueries behind them.
  `docs/conformance.md` §3 says what each adapter carries and where the
  policies the sidecar reads live. The test run compiles this module, and
  an application never loads it.
  """

  use Boundary,
    top_level?: true,
    deps: [Mediate, Mediate.Conformance, Mediate.Cerbos, Mediate.Fixture, Mediate.Test, Ecto],
    exports: [Attributes, Memberships, Versions]
end
