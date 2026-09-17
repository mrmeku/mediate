defmodule Mediate.Conformance do
  @moduledoc """
  The conformance mechanisms:

  - the law table of `docs/conformance.md` under "The laws"
  - the adapter case that runs it
  - the repo case that holds a mediated repo to the seam's guarantees

  The package ships them, so every adapter, in this
  repository or outside it, proves itself against the same contract. The
  caller supplies the population a run writes, as a
  `Mediate.Conformance.World`. So nothing here names a schema or a rule.
  """

  use Boundary,
    top_level?: true,
    deps: [Mediate, Mediate.Test, Ecto, ExUnit, ExUnitProperties, StreamData],
    exports: [
      AdapterCase,
      AdapterCase.Laws,
      Gen,
      Law,
      RepoCase,
      RepoCase.Rows,
      Seed,
      Versions,
      World
    ]
end
