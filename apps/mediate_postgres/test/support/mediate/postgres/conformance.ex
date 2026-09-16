defmodule Mediate.Postgres.Conformance do
  @moduledoc """
  The conformance artifact of row-level security: the migration that
  protects the neutral fixture's tables and writes its rule as policies.
  `Mediate.Conformance.World` says what the fixture is. The test run
  compiles it. An application never loads it.
  """

  use Boundary,
    top_level?: true,
    deps: [Mediate.Postgres, Mediate.Conformance, Mediate.TestRepos, Ecto],
    exports: [Rules, Versions]
end
