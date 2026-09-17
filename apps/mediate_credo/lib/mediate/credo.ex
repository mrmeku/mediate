if Code.ensure_loaded?(Credo.Check) do
  defmodule Mediate.Credo do
    @moduledoc """
    Two checks an adopter adds to `.credo.exs`. They live in a package of
    their own, because they carry Credo and the contract does not.

    - `Mediate.Credo.NoRawSQL` flags SQL that reaches the database around
      the seam.
    - `Mediate.Credo.UnmediatedRepo` flags an Ecto repo without
      `use Mediate.Repo`.

    Both read source text, so this package depends on no other package here.
    A check reads what a file says, not what a call does at run time. So the
    checks are advisory, and the seam is what keeps the log complete. The
    requirement on Credo is optional, so the Credo an adopter already runs
    is the one that loads these checks, and Credo is on the code path while
    this package compiles.
    """

    use Boundary, top_level?: true, deps: [Credo]
  end
end
