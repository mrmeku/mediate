defmodule Mediate.Postgres.Conformance do
  @moduledoc """
  The conformance artifact of row-level security: the migration that
  protects the reference world's tables and writes its rule as policies,
  and the policy artifact that tightens one of them.
  `Mediate.Conformance.Reference.World` says what the world is. The test
  run compiles them. A deployment never loads them.
  """

  use Boundary,
    top_level?: true,
    deps: [Mediate, Mediate.Postgres, Mediate.Conformance, Mediate.TestRepos, Ecto],
    exports: [Policy, Reference]
end
