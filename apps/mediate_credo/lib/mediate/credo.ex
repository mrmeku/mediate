if Code.ensure_loaded?(Credo.Check) do
  defmodule Mediate.Credo do
    @moduledoc """
    Two checks an adopter names in `.credo.exs`. They are a package of
    their own, because they carry Credo and the contract does not.

    - `Mediate.Credo.Check.Warning.RawSQL`, `ME5001`, flags a call that
      reaches the database around the mediated repo.
    - `Mediate.Credo.Check.Warning.UnmediatedRepo`, `ME5002`, flags a repo
      that `use Ecto.Repo` without `use Mediate.Repo`.

    An id is `ME`, Credo's category digit, and a counter, so `ME5` is a
    warning from this package as `EX5` is one from Credo. A check reads
    source text, so this package depends on no other package here, and
    `Mediate.Conformance.RepoCase` is what proves the mediated repo at run
    time. The requirement on Credo is optional, so the Credo an adopter
    already runs is the one that loads these checks, and Credo is on the
    code path while this package compiles.
    """

    use Boundary, top_level?: true, deps: [Credo]
  end
end
