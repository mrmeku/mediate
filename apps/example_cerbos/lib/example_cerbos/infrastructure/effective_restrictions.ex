defmodule ExampleCerbos.Infrastructure.EffectiveRestrictions do
  # Hidden, because what the server reads is a declaration and not this
  # module. What is here is the one derivation the policy language does not
  # carry: which restriction kinds are in effect on a visibility.
  #
  # A kind is in effect when the visibility declares it, or when a sensitive
  # label the visibility names implies it (C3). The derivation is a union
  # over the kinds, one query per kind, each selecting the row and the kind
  # as text. A directory is under embargo while its repository is (C4, C5).
  # The embargo is on a row the directory does not carry, so the moment
  # arrives as an argument and the test is inside the subquery.
  @moduledoc false

  import Ecto.Query, only: [from: 2, union_all: 2]

  alias Example.Domain.Directory
  alias Example.Domain.Label
  alias Example.Domain.Repository
  alias Example.Domain.Restrictions
  alias Example.Domain.Visibility

  @doc "The restriction kinds in effect on each repository's rollup, declared or implied."
  @spec on_repositories() :: Ecto.Query.t()
  def on_repositories, do: union_of(&repository_restriction/1)

  @doc """
  The restriction kinds in effect on each directory's own visibility, while
  the repository's embargo is absent or after `at`.
  """
  @spec on_directories(DateTime.t()) :: Ecto.Query.t()
  def on_directories(%DateTime{} = at), do: union_of(&directory_restriction(&1, at))

  defp union_of(member) do
    [first | rest] = Enum.map(Restrictions.kinds(), member)

    Enum.reduce(rest, first, fn query, combined -> union_all(combined, ^query) end)
  end

  defp repository_restriction(kind) do
    name = Atom.to_string(kind)

    from(v in Visibility,
      left_join: l in Label,
      on: l.name in v.labels and l.sensitive,
      where: ^kind in v.restrictions or ^kind in l.implied_restrictions,
      distinct: true,
      select: %{id: v.repository_id, value: type(^name, :string)}
    )
  end

  # The directory's own visibility, under the repository's embargo. A kind
  # the repository's lifted embargo has released is in effect on none of
  # its directories.
  defp directory_restriction(kind, at) do
    name = Atom.to_string(kind)

    from(d in Directory,
      join: r in Repository,
      on: r.id == d.repository_id,
      left_join: l in Label,
      on: l.name in d.labels and l.sensitive,
      where: ^kind in d.restrictions or ^kind in l.implied_restrictions,
      where: is_nil(r.embargo) or r.embargo > ^at,
      distinct: true,
      select: %{id: d.id, value: type(^name, :string)}
    )
  end
end
